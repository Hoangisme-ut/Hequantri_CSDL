import uuid
from collections.abc import Generator
from unittest import TestCase
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from httpx import Response
from sqlalchemy.exc import IntegrityError
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, col, create_engine, func, select

from app import crud
from app.api.deps import get_current_user, get_db
from app.api.routes import beacons, sites, users
from app.core.config import settings
from app.models import (
    Artifact,
    Language,
    Role,
    Site,
    SiteTranslation,
    SiteTranslationInput,
    User,
    UserCreate,
)
from app.services.site_translation import site_source_hash


def duplicate_error(code: int, constraint: str) -> IntegrityError:
    return IntegrityError("INSERT", {}, Exception(code, f"unique key '{constraint}'"))


class WritePathConflictTests(TestCase):
    """Exercise HTTP writes in memory and simulate SQL Server commit errors."""

    def setUp(self) -> None:
        engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        self.addCleanup(engine.dispose)
        SQLModel.metadata.create_all(engine)
        self.session = self.enterContext(Session(engine))
        self.session.add_all(
            [
                Role(name="admin", description="Administrator"),
                Role(name="visitor", description="Regular visitor"),
            ]
        )
        self.session.commit()
        self.site = Site(name="Test site")
        self.english = Language(code="en", name="English")
        self.session.add_all([self.site, self.english])
        self.session.commit()
        self.admin = User(
            email="admin@example.com", hashed_password="unused", is_superuser=True
        )

        def get_session() -> Generator[Session]:
            yield self.session

        app = FastAPI()
        for router in (beacons.router, sites.router, users.router):
            app.include_router(router, prefix=settings.API_V1_STR)
        app.dependency_overrides[get_db] = get_session
        app.dependency_overrides[get_current_user] = lambda: self.admin
        self.client: TestClient = self.enterContext(
            TestClient(app, raise_server_exceptions=False)
        )
        self.enterContext(patch.object(beacons, "acquire_transaction_lock"))
        self.enterContext(patch.object(users, "send_email"))

    def artifact(self, *, active: bool) -> Artifact:
        artifact = Artifact(
            site_id=self.site.id, code=uuid.uuid4().hex, is_active=active
        )
        self.session.add(artifact)
        self.session.commit()
        self.session.refresh(artifact)
        return artifact

    def create_beacon(self, artifact_id: uuid.UUID | None = None) -> Response:
        response = self.client.post(
            f"{settings.API_V1_STR}/beacons/",
            json={
                "site_id": str(self.site.id),
                "proximity_uuid": str(uuid.uuid4()),
                "major": 1,
                "minor": 1,
                "artifact_id": str(artifact_id) if artifact_id else None,
            },
        )
        assert isinstance(response, Response)
        return response

    def test_create_rejects_inactive_artifact(self) -> None:
        artifact = self.artifact(active=False)
        response = self.create_beacon(artifact.id)
        self.assertEqual(response.status_code, 409)
        self.assertEqual(
            response.json(), {"detail": "Artifact is inactive; cannot assign beacon"}
        )

    def test_update_rejects_new_inactive_artifact(self) -> None:
        inactive = self.artifact(active=False)
        active = self.artifact(active=True)
        for current in (None, active.id):
            with self.subTest(current=current):
                created = self.create_beacon(current)
                self.assertEqual(created.status_code, 201)
                beacon = created.json()
                response = self.client.put(
                    f"{settings.API_V1_STR}/beacons/{beacon['id']}",
                    json={"artifact_id": str(inactive.id)},
                )
                self.assertEqual(response.status_code, 409)
                stored = self.client.get(
                    f"{settings.API_V1_STR}/beacons/{beacon['id']}"
                ).json()
                self.assertEqual(stored["artifact_id"], beacon["artifact_id"])

    def test_existing_inactive_assignment_can_be_edited_and_unlinked(self) -> None:
        artifact = self.artifact(active=True)
        created = self.create_beacon(artifact.id)
        self.assertEqual(created.status_code, 201)
        beacon_id = created.json()["id"]
        artifact.is_active = False
        self.session.add(artifact)
        self.session.commit()

        for changes in ({"major": 2}, {"artifact_id": str(artifact.id), "minor": 2}):
            response = self.client.put(
                f"{settings.API_V1_STR}/beacons/{beacon_id}", json=changes
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["artifact_id"], str(artifact.id))
        self.site.is_active = False
        self.session.add(self.site)
        self.session.commit()
        response = self.client.put(
            f"{settings.API_V1_STR}/beacons/{beacon_id}", json={"artifact_id": None}
        )
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.json()["artifact_id"])

    def test_user_email_races_match_precheck_and_session_recovers(self) -> None:
        for endpoint in ("/users/", "/users/signup"):
            for code in (2601, 2627):
                with self.subTest(endpoint=endpoint, code=code):
                    email = f"{uuid.uuid4().hex}@example.com"
                    winner = User(email=email, hashed_password="existing password hash")
                    self.session.add(winner)
                    self.session.commit()
                    payload = {"email": email, "password": "Original123!"}
                    expected = self.client.post(
                        f"{settings.API_V1_STR}{endpoint}", json=payload
                    )
                    self.assertEqual(expected.status_code, 400)
                    with (
                        patch.object(crud, "get_user_by_email", return_value=None),
                        patch.object(
                            self.session,
                            "commit",
                            side_effect=duplicate_error(code, "ix_user_email"),
                        ),
                        patch.object(
                            self.session, "rollback", wraps=self.session.rollback
                        ) as rollback,
                    ):
                        response = self.client.post(
                            f"{settings.API_V1_STR}{endpoint}", json=payload
                        )
                    self.assertEqual(response.status_code, expected.status_code)
                    self.assertEqual(response.json(), expected.json())
                    rollback.assert_called_once()
                    self.session.refresh(winner)
                    self.assertEqual(winner.hashed_password, "existing password hash")
                    self.assertEqual(
                        self.session.exec(
                            select(func.count())
                            .select_from(User)
                            .where(col(User.email) == email)
                        ).one(),
                        1,
                    )
                    next_response = self.client.post(
                        f"{settings.API_V1_STR}{endpoint}",
                        json={
                            "email": f"{uuid.uuid4().hex}@example.com",
                            "password": "NextUser123!",
                        },
                    )
                    self.assertEqual(next_response.status_code, 200)

    def test_user_email_update_races_return_conflict_and_keep_data(self) -> None:
        for endpoint in ("/users/{id}", "/users/me"):
            for code in (2601, 2627):
                with self.subTest(endpoint=endpoint, code=code):
                    taken = f"{uuid.uuid4().hex}@example.com"
                    winner = User(email=taken, hashed_password="winner hash")
                    target = User(
                        email=f"{uuid.uuid4().hex}@example.com",
                        hashed_password="target hash",
                    )
                    self.session.add_all([winner, target])
                    self.session.commit()
                    if endpoint == "/users/me":
                        self.admin = target
                        target.is_superuser = True
                    path = endpoint.format(id=target.id)
                    original_email = target.email
                    expected = self.client.patch(
                        f"{settings.API_V1_STR}{path}", json={"email": taken}
                    )
                    self.assertEqual(expected.status_code, 409)
                    with (
                        patch.object(crud, "get_user_by_email", return_value=None),
                        patch.object(
                            self.session,
                            "commit",
                            side_effect=duplicate_error(code, "ix_user_email"),
                        ),
                        patch.object(
                            self.session, "rollback", wraps=self.session.rollback
                        ) as rollback,
                    ):
                        response = self.client.patch(
                            f"{settings.API_V1_STR}{path}", json={"email": taken}
                        )
                    self.assertEqual(response.status_code, 409)
                    self.assertEqual(response.json(), expected.json())
                    rollback.assert_called_once()
                    self.session.refresh(target)
                    self.session.refresh(winner)
                    self.assertEqual(target.email, original_email)
                    self.assertEqual(winner.email, taken)
                    self.assertEqual(target.hashed_password, "target hash")
                    # The session still works after the rollback.
                    ok = self.client.patch(
                        f"{settings.API_V1_STR}{path}",
                        json={"full_name": "After conflict"},
                    )
                    self.assertEqual(ok.status_code, 200)

    def test_user_email_update_unrelated_integrity_error_is_reraised(self) -> None:
        target = User(email=f"{uuid.uuid4().hex}@example.com", hashed_password="x")
        self.session.add(target)
        self.session.commit()
        with patch.object(
            self.session, "commit", side_effect=duplicate_error(2627, "other_key")
        ):
            response = self.client.patch(
                f"{settings.API_V1_STR}/users/{target.id}",
                json={"email": f"{uuid.uuid4().hex}@example.com"},
            )
        self.assertEqual(response.status_code, 500)

    def test_translation_race_returns_conflict_and_next_upsert_works(self) -> None:
        for code in (2601, 2627):
            with self.subTest(code=code):
                site = Site(name=f"Site {code}")
                self.session.add(site)
                self.session.flush()
                winner = SiteTranslation(
                    site_id=site.id,
                    language_id=self.english.id,
                    name="Winning translation",
                    source_hash=site_source_hash(site),
                    is_confirmed=True,
                )
                self.session.add(winner)
                self.session.commit()
                url = f"{settings.API_V1_STR}/sites/{site.id}/translations/{self.english.id}"
                missed_precheck = MagicMock()
                missed_precheck.first.return_value = None
                with (
                    patch.object(self.session, "exec", return_value=missed_precheck),
                    patch.object(
                        self.session,
                        "commit",
                        side_effect=duplicate_error(code, "uq_site_language"),
                    ),
                    patch.object(
                        self.session, "rollback", wraps=self.session.rollback
                    ) as rollback,
                ):
                    response = self.client.put(url, json={"name": "Losing translation"})
                self.assertEqual(response.status_code, 409)
                self.assertEqual(response.json(), {"detail": "Value already exists"})
                rollback.assert_called_once()
                self.session.refresh(winner)
                self.assertEqual(winner.name, "Winning translation")
                next_response = self.client.put(url, json={"name": "Next translation"})
                self.assertEqual(next_response.status_code, 200)
                self.assertEqual(next_response.json()["id"], str(winner.id))

    def test_unrelated_integrity_errors_are_reraised_after_rollback(self) -> None:
        for target in ("user", "translation"):
            for code, name in ((547, "ix_user_email"), (2627, "unrelated_constraint")):
                with self.subTest(target=target, code=code, name=name):
                    error = duplicate_error(code, name)
                    with (
                        patch.object(self.session, "commit", side_effect=error),
                        patch.object(
                            self.session, "rollback", wraps=self.session.rollback
                        ) as rollback,
                        self.assertRaises(IntegrityError) as raised,
                    ):
                        if target == "user":
                            crud.create_user(
                                session=self.session,
                                user_create=UserCreate(
                                    email=f"{uuid.uuid4().hex}@example.com",
                                    password="Original123!",
                                ),
                            )
                        else:
                            sites.upsert_site_translation(
                                session=self.session,
                                _admin=self.admin,
                                site_id=self.site.id,
                                language_id=self.english.id,
                                translation_in=SiteTranslationInput(name="Translation"),
                            )
                    self.assertIs(raised.exception, error)
                    rollback.assert_called_once()
                    self.assertFalse(self.session.in_transaction())

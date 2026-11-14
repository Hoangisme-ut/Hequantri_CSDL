import uuid
from collections.abc import Generator
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest import TestCase
from unittest.mock import call, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, col, create_engine, select

from app.api.deps import get_current_user, get_db
from app.api.routes import feedbacks
from app.core.config import settings
from app.models import (
    Artifact,
    ArtifactTranslation,
    Feedback,
    FeedbackUpdate,
    Language,
    Site,
    User,
)


class FeedbackModerationTests(TestCase):
    """SQLite covers route logic; only SQL Server's application lock is mocked."""

    def setUp(self) -> None:
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        self.addCleanup(self.engine.dispose)
        SQLModel.metadata.create_all(self.engine)
        self.session = self.enterContext(Session(self.engine))
        self.owner = User(email="visitor@example.com", hashed_password="unused")
        self.site = Site(name="Test site")
        self.language = Language(code="vi", name="Vietnamese", is_default=True)
        self.session.add_all([self.owner, self.site, self.language])
        self.session.commit()
        self.owner_id = self.owner.id
        self.admin = User(
            email="admin@example.com", hashed_password="unused", is_superuser=True
        )
        self.actor = self.admin
        self.now = datetime(2026, 1, 2, tzinfo=UTC)

        def get_session() -> Generator[Session]:
            yield self.session

        app = FastAPI()
        app.include_router(feedbacks.router, prefix=settings.API_V1_STR)
        app.dependency_overrides[get_db] = get_session
        app.dependency_overrides[get_current_user] = lambda: self.actor
        self.client = self.enterContext(TestClient(app))
        # create=True lets the regression run before the route imports the helper.
        self.lock = self.enterContext(
            patch.object(feedbacks, "acquire_transaction_lock", create=True)
        )
        self.enterContext(patch.object(feedbacks, "get_datetime_utc", lambda: self.now))

    def create_feedback(self, *, updated_at: datetime | None = None) -> Feedback:
        artifact = Artifact(site_id=self.site.id, code=uuid.uuid4().hex)
        self.session.add(artifact)
        self.session.flush()
        self.session.add(
            ArtifactTranslation(
                artifact_id=artifact.id,
                language_id=self.language.id,
                title=artifact.code,
            )
        )
        row = Feedback(
            artifact_id=artifact.id,
            user_id=self.owner_id,
            rating=5,
            comment="Original comment",
            status="pending",
            updated_at=updated_at,
        )
        self.session.add(row)
        self.session.commit()
        self.session.refresh(row)
        return row

    def test_stale_moderation_rejects_changed_comment_and_timestamp(self) -> None:
        for remembered in (None, self.now - timedelta(days=1)):
            with self.subTest(remembered=remembered):
                row = self.create_feedback(updated_at=remembered)
                feedback_id = row.id
                # A second session edits while the moderator retains a cached row.
                with Session(self.engine) as visitor:
                    edited = feedbacks.update_my_feedback(
                        session=visitor,
                        current_user=User(
                            id=self.owner_id,
                            email="visitor@example.com",
                            hashed_password="unused",
                        ),
                        feedback_id=feedback_id,
                        feedback_in=FeedbackUpdate(comment="Unreviewed edit"),
                    )
                response = self.client.patch(
                    f"{settings.API_V1_STR}/feedbacks/{feedback_id}/status",
                    json={
                        "status": "approved",
                        "expected_updated_at": remembered.isoformat()
                        if remembered
                        else None,
                    },
                )
                self.assertEqual(response.status_code, 409)
                self.assertEqual(
                    response.json(),
                    {"detail": "Feedback changed; reload before moderating"},
                )
                with Session(self.engine) as observer:
                    stored = observer.get(Feedback, feedback_id)
                    assert stored is not None
                    self.assertEqual(stored.status, "pending")
                    self.assertEqual(stored.comment, "Unreviewed edit")
                    self.assertEqual(stored.updated_at, edited.updated_at)

    def test_moderation_without_expected_timestamp_still_works(self) -> None:
        row = self.create_feedback()
        response = self.client.patch(
            f"{settings.API_V1_STR}/feedbacks/{row.id}/status",
            json={"status": "approved"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "approved")

    def test_matching_timestamp_allows_moderation(self) -> None:
        row = self.create_feedback(updated_at=self.now - timedelta(days=1))
        assert row.updated_at is not None
        response = self.client.patch(
            f"{settings.API_V1_STR}/feedbacks/{row.id}/status",
            json={
                "status": "approved",
                "expected_updated_at": row.updated_at.isoformat(),
            },
        )
        self.assertEqual(response.status_code, 200)

    def test_edit_and_moderation_use_same_feedback_lock(self) -> None:
        row = self.create_feedback()
        feedback_id = row.id
        self.actor = self.owner
        edit = self.client.put(
            f"{settings.API_V1_STR}/feedbacks/{feedback_id}",
            json={"comment": "Edited comment"},
        )
        self.assertEqual(edit.status_code, 200)
        self.assertEqual(edit.json()["status"], "pending")
        self.assertIsNotNone(edit.json()["updated_at"])
        self.actor = self.admin
        moderation = self.client.patch(
            f"{settings.API_V1_STR}/feedbacks/{feedback_id}/status",
            json={"status": "approved"},
        )
        self.assertEqual(moderation.status_code, 200)
        self.assertEqual(
            self.lock.call_args_list,
            [
                call(self.session, f"feedback:{feedback_id}"),
                call(self.session, f"feedback:{feedback_id}"),
            ],
        )

    def test_edit_refreshes_cached_feedback_after_acquiring_lock(self) -> None:
        row = self.create_feedback()
        feedback_id = row.id

        def hide_before_lock_returns(_session: Session, _resource: str) -> None:
            with Session(self.engine) as moderator:
                stored = moderator.get(Feedback, feedback_id)
                assert stored is not None
                stored.status = "hidden"
                moderator.add(stored)
                moderator.commit()

        self.lock.side_effect = hide_before_lock_returns
        result = feedbacks.update_my_feedback(
            session=self.session,
            current_user=User(
                id=self.owner_id,
                email="visitor@example.com",
                hashed_password="unused",
            ),
            feedback_id=feedback_id,
            feedback_in=FeedbackUpdate(comment="Edited hidden comment"),
        )
        self.assertEqual(result.status, "hidden")

    def test_titles_keep_default_language_and_missing_translation_fallback(
        self,
    ) -> None:
        translated = self.create_feedback()
        translated_id = str(translated.id)
        missing = self.create_feedback()
        missing_id = str(missing.id)
        default_translation = self.session.exec(
            select(ArtifactTranslation).where(
                col(ArtifactTranslation.artifact_id) == missing.artifact_id
            )
        ).one()
        self.session.delete(default_translation)
        english = Language(code="en", name="English")
        self.session.add(english)
        self.session.flush()
        self.session.add(
            ArtifactTranslation(
                artifact_id=missing.artifact_id,
                language_id=english.id,
                title="Other language must not become a fallback",
            )
        )
        self.language.is_active = False
        self.session.add(self.language)
        self.session.commit()

        response = self.client.get(f"{settings.API_V1_STR}/feedbacks/")

        self.assertEqual(response.status_code, 200)
        rows = {item["id"]: item for item in response.json()["data"]}
        self.assertEqual(
            rows[translated_id]["artifact_title"], rows[translated_id]["artifact_code"]
        )
        self.assertIsNone(rows[missing_id]["artifact_title"])

    def test_moderation_page_query_count_is_constant(self) -> None:
        for _ in range(5):
            self.create_feedback()
        counts = []
        for limit in (1, 5):
            queries: list[str] = []

            def capture(
                _conn: Any,
                _cursor: Any,
                statement: str,
                _params: Any,
                _context: Any,
                _many: bool,
                queries: list[str] = queries,
            ) -> None:
                if statement.lstrip().upper().startswith("SELECT"):
                    queries.append(statement)

            event.listen(self.engine, "before_cursor_execute", capture)
            try:
                response = self.client.get(
                    f"{settings.API_V1_STR}/feedbacks/",
                    params={"limit": limit, "user_id": str(self.owner_id)},
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(len(response.json()["data"]), limit)
                self.assertEqual(response.json()["count"], 5)
                self.assertTrue(
                    all(
                        item["artifact_title"] == item["artifact_code"]
                        for item in response.json()["data"]
                    )
                )
                counts.append(len(queries))
            finally:
                event.remove(self.engine, "before_cursor_execute", capture)
        self.assertEqual(counts[0], counts[1], counts)
        self.assertEqual(counts, [3, 3])

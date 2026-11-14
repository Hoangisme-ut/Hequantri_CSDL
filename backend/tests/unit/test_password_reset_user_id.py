import uuid
from collections.abc import Generator
from datetime import UTC, datetime, timedelta
from unittest import TestCase
from unittest.mock import patch

import jwt
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app import crud
from app.api.deps import get_db
from app.api.routes import login
from app.core.config import settings
from app.core.security import ALGORITHM, verify_password
from app.models import User, UserCreate, UserUpdate
from app.utils import generate_reset_password_email


class PasswordResetUserIdTests(TestCase):
    """Isolated route tests; no SQL Server fixtures or SMTP connections."""

    def setUp(self) -> None:
        engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        self.addCleanup(engine.dispose)
        SQLModel.metadata.create_all(engine)
        self.session = self.enterContext(Session(engine))

        def get_session() -> Generator[Session]:
            yield self.session

        app = FastAPI()
        app.include_router(login.router, prefix=settings.API_V1_STR)
        app.dependency_overrides[get_db] = get_session
        self.client = self.enterContext(TestClient(app))
        self.lock = self.enterContext(patch.object(login, "acquire_transaction_lock"))
        self.mail = self.enterContext(patch.object(login, "send_email"))

    def create_user(self, email: str | None = None) -> User:
        return crud.create_user(
            session=self.session,
            user_create=UserCreate(
                email=email or f"{uuid.uuid4().hex}@example.com",
                password="Original123!",
            ),
        )

    def recover_token(self, user: User) -> str:
        with patch.object(
            login, "generate_reset_password_email", wraps=generate_reset_password_email
        ) as render:
            response = self.client.post(
                f"{settings.API_V1_STR}/password-recovery/{user.email}"
            )
        self.assertEqual(response.status_code, 200)
        token = render.call_args.kwargs["token"]
        assert isinstance(token, str)
        return token

    def assert_password(self, user: User, password: str) -> None:
        self.session.refresh(user)
        self.assertTrue(verify_password(password, user.hashed_password)[0])

    def test_email_reassignment_does_not_reset_new_owner(self) -> None:
        original = self.create_user()
        old_email = original.email
        token = self.recover_token(original)
        crud.update_user(
            session=self.session,
            db_user=original,
            user_in=UserUpdate(email=f"{uuid.uuid4().hex}@example.com"),
        )
        replacement = self.create_user(old_email)

        response = self.client.post(
            f"{settings.API_V1_STR}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        )

        self.assertEqual(response.status_code, 200)
        self.assert_password(replacement, "Original123!")
        self.assert_password(original, "Changed123!")

    def test_deleted_account_token_cannot_reset_recreated_account(self) -> None:
        original = self.create_user()
        old_email = original.email
        token = self.recover_token(original)
        self.session.delete(original)
        self.session.commit()
        replacement = self.create_user(old_email)

        response = self.client.post(
            f"{settings.API_V1_STR}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"detail": "Invalid token"})
        self.assert_password(replacement, "Original123!")

    def test_used_token_cannot_change_password_again(self) -> None:
        user = self.create_user()
        token = self.recover_token(user)
        first = self.client.post(
            f"{settings.API_V1_STR}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        )
        replay = self.client.post(
            f"{settings.API_V1_STR}/reset-password/",
            json={"token": token, "new_password": "Replay123!"},
        )

        self.assertEqual(first.status_code, 200)
        self.assertEqual(replay.status_code, 400)
        self.assertEqual(replay.json(), {"detail": "Invalid token"})
        self.assert_password(user, "Changed123!")
        self.assertEqual(self.lock.call_count, 2)

    def test_legacy_email_subject_is_rejected(self) -> None:
        for purpose in (None, "password_reset"):
            with self.subTest(purpose=purpose):
                user = self.create_user()
                claims = {
                    "sub": user.email,
                    "exp": datetime.now(UTC) + timedelta(minutes=5),
                }
                if purpose is not None:
                    claims["purpose"] = purpose
                token = jwt.encode(claims, settings.SECRET_KEY, algorithm=ALGORITHM)
                response = self.client.post(
                    f"{settings.API_V1_STR}/reset-password/",
                    json={"token": token, "new_password": "Changed123!"},
                )

                self.assertEqual(response.status_code, 400)
                self.assertEqual(response.json(), {"detail": "Invalid token"})
                self.assert_password(user, "Original123!")

    def test_normal_recovery_uses_uuid_and_resets_password(self) -> None:
        user = self.create_user()
        token = self.recover_token(user)
        claims = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        self.assertEqual(claims["sub"], str(user.id))
        self.assertEqual(claims["purpose"], "password_reset")
        self.assertIn("jti", claims)

        response = self.client.post(
            f"{settings.API_V1_STR}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Password updated successfully"})
        self.assert_password(user, "Changed123!")

    def test_html_preview_also_issues_uuid_subject(self) -> None:
        user = self.create_user()
        with patch.object(
            login, "generate_reset_password_email", wraps=generate_reset_password_email
        ) as render:
            login.recover_password_html_content(user.email, self.session)
        claims = jwt.decode(
            render.call_args.kwargs["token"],
            settings.SECRET_KEY,
            algorithms=[ALGORITHM],
        )
        self.assertEqual(claims["sub"], str(user.id))

    def test_recovery_response_is_identical_for_unknown_email(self) -> None:
        user = self.create_user()
        known = self.client.post(
            f"{settings.API_V1_STR}/password-recovery/{user.email}"
        )
        unknown = self.client.post(
            f"{settings.API_V1_STR}/password-recovery/unknown@example.com"
        )
        self.assertEqual(known.status_code, unknown.status_code)
        self.assertEqual(known.status_code, 200)
        self.assertEqual(
            known.json(),
            {
                "message": "If that email is registered, we sent a password recovery link"
            },
        )
        self.assertEqual(known.json(), unknown.json())
        self.mail.assert_called_once()

from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app import crud
from app.core.config import settings
from app.utils import EmailDeliveryError, send_email
from tests.utils.heritage import API
from tests.utils.user import create_random_user
from tests.utils.utils import random_email


@pytest.mark.parametrize("failure", ["disabled", "rejected", "exception"])
def test_recovery_preserves_generic_200_on_delivery_failure(
    client: TestClient, db: Session, failure: str, caplog: pytest.LogCaptureFixture
) -> None:
    user = create_random_user(db)
    with (
        patch.object(
            settings, "SMTP_HOST", None if failure == "disabled" else "smtp.example.com"
        ),
        patch.object(settings, "EMAILS_FROM_EMAIL", "sender@example.com"),
        patch(
            "emails.message.Message.send",
            return_value=SimpleNamespace(success=False, status_code=550),
            side_effect=OSError("sensitive SMTP failure")
            if failure == "exception"
            else None,
        ) as transport,
    ):
        existing = client.post(f"{API}/password-recovery/{user.email}")
        missing = client.post(f"{API}/password-recovery/{random_email()}")
    assert existing.status_code == missing.status_code == 200
    assert (
        existing.json()
        == missing.json()
        == {"message": "If that email is registered, we sent a password recovery link"}
    )
    assert transport.call_count == (0 if failure == "disabled" else 1)
    # Check application delivery logs, not httpx's request URL (the legacy API
    # contract embeds the email in its path).
    delivery_logs = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name.startswith("app.")
    )
    assert "Password recovery email delivery failed" in delivery_logs
    assert user.email not in delivery_logs
    assert "sensitive SMTP failure" not in delivery_logs


@pytest.mark.parametrize("exception", [False, True])
def test_notification_failure_does_not_undo_created_user(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    exception: bool,
) -> None:
    email = random_email()
    with (
        patch.object(settings, "SMTP_HOST", "smtp.example.com"),
        patch.object(settings, "EMAILS_FROM_EMAIL", "sender@example.com"),
        patch(
            "emails.message.Message.send",
            return_value=SimpleNamespace(success=False, status_code=550),
            side_effect=OSError("transport down") if exception else None,
        ),
    ):
        response = client.post(
            f"{API}/users/",
            headers=superuser_token_headers,
            json={"email": email, "password": "DeliveryTest123!"},
        )
    assert response.status_code == 200
    user = crud.get_user_by_email(session=db, email=email)
    assert user is not None
    assert str(user.id) == response.json()["id"]


def test_checked_transport_success_and_sanitized_failure() -> None:
    with (
        patch.object(settings, "SMTP_HOST", "smtp.example.com"),
        patch.object(settings, "EMAILS_FROM_EMAIL", "sender@example.com"),
        patch(
            "emails.message.Message.send",
            return_value=SimpleNamespace(success=True, status_code=250),
        ) as transport,
    ):
        send_email(email_to="visitor@example.com", raise_on_failure=True)
        transport.assert_called_once()
        transport.side_effect = OSError("secret transport details")
        with pytest.raises(EmailDeliveryError, match="Email delivery failed") as error:
            send_email(email_to="visitor@example.com", raise_on_failure=True)
        assert "secret" not in str(error.value)

from app.core.config import settings
from app.utils import generate_reset_password_email


def test_reset_password_email_uses_configured_frontend_origin(monkeypatch) -> None:
    monkeypatch.setattr(settings, "FRONTEND_HOST", "http://heritage.test:8080")

    email = generate_reset_password_email(
        email_to="visitor@example.test",
        email="visitor@example.test",
        token="test-reset-token",
    )

    assert (
        'href="http://heritage.test:8080/reset-password?token=test-reset-token"'
        in email.html_content
    )

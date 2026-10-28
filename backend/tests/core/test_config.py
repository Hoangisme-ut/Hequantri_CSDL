import warnings

import pytest

from app.core.config import Settings


def test_use_mssql_driver() -> None:
    assert (
        Settings._use_mssql_driver("mssql://sa:pwd@localhost:1433/app")
        == "mssql+pymssql://sa:pwd@localhost:1433/app"
    )
    assert (
        Settings._use_mssql_driver("sqlserver://sa:pwd@localhost:1433/app")
        == "mssql+pymssql://sa:pwd@localhost:1433/app"
    )
    assert (
        Settings._use_mssql_driver("mssql+pymssql://sa:pwd@localhost:1433/app")
        == "mssql+pymssql://sa:pwd@localhost:1433/app"
    )


def test_enforce_non_default_secrets_warns_in_dev() -> None:
    with warnings.catch_warnings(record=True) as recorded:
        warnings.simplefilter("always")
        Settings(
            _env_file=None,
            SECRET_KEY="changethis",
            FIRST_SUPERUSER="admin@example.com",
            FIRST_SUPERUSER_PASSWORD="changethis",
            PROJECT_NAME="Test",
            DATABASE_URL="mssql+pymssql://sa:changethis@localhost:1433/app",
            FASTAPI_ENV="development",
        )
        assert len(recorded) >= 3


def test_enforce_non_default_secrets_raises_in_prod() -> None:
    with pytest.raises(ValueError, match='The value of SECRET_KEY is "changethis"'):
        Settings(
            _env_file=None,
            SECRET_KEY="changethis",
            FIRST_SUPERUSER="admin@example.com",
            FIRST_SUPERUSER_PASSWORD="secret",
            PROJECT_NAME="Test",
            DATABASE_URL="mssql+pymssql://sa:secret@localhost:1433/app",
            FASTAPI_ENV=None,
        )


def test_emails_enabled() -> None:
    # Disable both dotenv and inherited Docker/CI SMTP settings explicitly.
    s_disabled = Settings(
        _env_file=None,
        SMTP_HOST=None,
        EMAILS_FROM_EMAIL=None,
        SECRET_KEY="secret",
        FIRST_SUPERUSER="admin@example.com",
        FIRST_SUPERUSER_PASSWORD="secret",
        PROJECT_NAME="Test",
        DATABASE_URL="mssql+pymssql://sa:secret@localhost:1433/app",
        FASTAPI_ENV="development",
    )
    assert s_disabled.emails_enabled is False

    s_enabled = Settings(
        _env_file=None,
        SECRET_KEY="secret",
        FIRST_SUPERUSER="admin@example.com",
        FIRST_SUPERUSER_PASSWORD="secret",
        PROJECT_NAME="Test",
        DATABASE_URL="mssql+pymssql://sa:secret@localhost:1433/app",
        FASTAPI_ENV="development",
        SMTP_HOST="localhost",
        EMAILS_FROM_EMAIL="info@example.com",
    )
    assert s_enabled.emails_enabled is True

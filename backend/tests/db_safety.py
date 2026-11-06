"""Fail closed before importing the application engine or running DB fixtures."""

import os
import re
import secrets

from sqlalchemy import Engine, create_engine, text
from sqlalchemy.engine import URL, make_url


def validate_target(application_url: str, test_url: str, token: str) -> URL:
    if not test_url or len(token) < 32:
        raise RuntimeError(
            "Set TEST_DATABASE_URL and TEST_DATABASE_TOKEN for an isolated database"
        )
    target = make_url(test_url)
    application = make_url(application_url)
    if target.get_backend_name() != "mssql" or not re.fullmatch(
        r"test_[a-z0-9_]+", target.database or ""
    ):
        raise RuntimeError("Tests require a dedicated SQL Server test_* database")
    # Conservatively reject the application database name even with host aliases.
    if (target.database or "").casefold() == (application.database or "").casefold():
        raise RuntimeError(
            "The test database must differ from the application database"
        )
    return target


def verify_identity(engine: Engine, token: str) -> None:
    """Read-only check of a marker created ONLY when provisioning a fresh test DB."""
    try:
        with engine.connect() as connection:
            database = connection.execute(text("SELECT DB_NAME()")).scalar_one()
            rows = (
                connection.execute(text("SELECT token FROM dbo.test_database_identity"))
                .scalars()
                .all()
            )
        if (
            database != engine.url.database
            or len(rows) != 1
            or not secrets.compare_digest(rows[0], token)
        ):
            raise ValueError("Identity mismatch")
    except Exception:
        # Do not leak the connection URL, credentials, or marker in pytest errors.
        raise RuntimeError(
            "Test database identity verification failed; refusing database writes"
        ) from None


def activate_test_database() -> str:
    from app.core.config import settings

    token = os.environ.get("TEST_DATABASE_TOKEN", "")
    target = validate_target(
        settings.DATABASE_URL, os.environ.get("TEST_DATABASE_URL", ""), token
    )
    engine = create_engine(target, pool_pre_ping=True)
    try:
        verify_identity(engine, token)
    finally:
        engine.dispose()
    settings.DATABASE_URL = target.render_as_string(hide_password=False)
    return token

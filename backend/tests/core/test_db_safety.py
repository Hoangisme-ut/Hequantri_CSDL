from unittest.mock import MagicMock

import pytest
from sqlalchemy.engine import make_url

from tests.db_safety import validate_target, verify_identity

APP_URL = "mssql+pymssql://user:password@localhost/app"
TEST_URL = "mssql+pymssql://user:password@localhost/test_guard"
TOKEN = "a" * 64


@pytest.mark.parametrize(
    "url,token", [("", TOKEN), (TEST_URL, ""), (APP_URL, TOKEN), ("sqlite://", TOKEN)]
)
def test_reject_unsafe_target(url: str, token: str) -> None:
    with pytest.raises(RuntimeError):
        validate_target(APP_URL, url, token)


def test_reject_application_database_with_host_alias() -> None:
    with pytest.raises(RuntimeError):
        validate_target(TEST_URL, TEST_URL.replace("localhost", "127.0.0.1"), TOKEN)


def test_valid_target_still_requires_marker() -> None:
    assert validate_target(APP_URL, TEST_URL, TOKEN).database == "test_guard"
    engine = MagicMock()
    engine.url = make_url(TEST_URL)
    connection = engine.connect.return_value.__enter__.return_value
    connection.execute.side_effect = RuntimeError("sensitive connection error")
    with pytest.raises(RuntimeError, match="identity verification failed") as error:
        verify_identity(engine, TOKEN)
    assert "sensitive" not in str(error.value)


@pytest.mark.parametrize(
    "database,tokens",
    [
        ("app", [TOKEN]),
        ("test_guard", []),
        ("test_guard", ["wrong"]),
        ("test_guard", [TOKEN, TOKEN]),
    ],
)
def test_identity_mismatch(database: str, tokens: list[str]) -> None:
    engine = MagicMock()
    engine.url = make_url(TEST_URL)
    connection = engine.connect.return_value.__enter__.return_value
    connection.execute.return_value.scalar_one.return_value = database
    connection.execute.return_value.scalars.return_value.all.return_value = tokens
    with pytest.raises(RuntimeError, match="refusing database writes"):
        verify_identity(engine, TOKEN)


def test_verified_identity() -> None:
    engine = MagicMock()
    engine.url = make_url(TEST_URL)
    connection = engine.connect.return_value.__enter__.return_value
    connection.execute.return_value.scalar_one.return_value = "test_guard"
    connection.execute.return_value.scalars.return_value.all.return_value = [TOKEN]
    verify_identity(engine, TOKEN)

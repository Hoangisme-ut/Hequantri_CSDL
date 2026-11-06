from unittest.mock import MagicMock

import pytest
from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session

from app.core.db import engine
from app.core.transactions import acquire_transaction_lock, commit_with_conflicts


@pytest.mark.parametrize("result", [-1, -2, -3, -999])
def test_failed_lock_rolls_back(result):
    session = MagicMock()
    session.execute.return_value.scalar_one.return_value = result
    with pytest.raises(HTTPException) as error:
        acquire_transaction_lock(session, "test")
    assert error.value.status_code == 409
    session.rollback.assert_called_once()


def test_database_error_is_not_hidden():
    session = MagicMock()
    session.execute.side_effect = RuntimeError("DB failure")
    with pytest.raises(RuntimeError, match="DB failure"):
        acquire_transaction_lock(session, "test")
    session.rollback.assert_called_once()


def test_sql_server_timeout_and_release():
    with Session(engine) as owner, Session(engine) as contender:
        acquire_transaction_lock(owner, "test:lock-timeout")
        with pytest.raises(HTTPException) as error:
            acquire_transaction_lock(contender, "test:lock-timeout", timeout_ms=20)
        assert error.value.status_code == 409
        assert not contender.in_transaction()
        owner.rollback()
        acquire_transaction_lock(contender, "test:lock-timeout", timeout_ms=20)
        contender.commit()


@pytest.mark.parametrize(
    "code,name,conflict",
    [
        (2601, "expected", True),
        (2627, "expected", True),
        (547, "expected", False),
        (2627, "other", False),
    ],
)
def test_only_known_duplicate_constraints_are_conflicts(code, name, conflict):
    session = MagicMock()
    original = IntegrityError("INSERT", {}, Exception(code, f"constraint '{name}'"))
    session.commit.side_effect = original
    with pytest.raises(HTTPException if conflict else IntegrityError):
        commit_with_conflicts(session, "expected")
    session.rollback.assert_called_once()

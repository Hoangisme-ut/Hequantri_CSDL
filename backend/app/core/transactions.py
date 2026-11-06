"""SQL Server transaction locks shared by competing API writes."""

from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session


def acquire_transaction_lock(
    session: Session, resource: str, *, timeout_ms: int = 5000
) -> None:
    # Transaction ownership releases the lock on commit/rollback, including when
    # request dependencies close the session after validation errors.
    try:
        result = session.execute(
            text(
                "DECLARE @result int; EXEC @result = sys.sp_getapplock "
                "@Resource=:resource, @LockMode='Exclusive', "
                "@LockOwner='Transaction', @LockTimeout=:timeout; SELECT @result"
            ),
            {"resource": resource, "timeout": timeout_ms},
        ).scalar_one()
    except Exception:
        session.rollback()
        raise
    if result not in (0, 1):
        session.rollback()
        raise HTTPException(status_code=409, detail="Concurrent write; try again")


def commit_with_conflicts(session: Session, *constraints: str) -> None:
    """Map only SQL Server duplicate-key errors for the expected constraints."""
    try:
        session.commit()
    except IntegrityError as error:
        session.rollback()
        args = error.orig.args
        if (
            args
            and args[0] in (2601, 2627)
            and any(f"'{name}'" in str(args[1:]) for name in constraints)
        ):
            raise HTTPException(
                status_code=409, detail="Value already exists"
            ) from None
        raise

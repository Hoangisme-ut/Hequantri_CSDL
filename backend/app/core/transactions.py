"""SQL Server transaction locks shared by competing API writes."""

from fastapi import HTTPException
from sqlalchemy import text
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

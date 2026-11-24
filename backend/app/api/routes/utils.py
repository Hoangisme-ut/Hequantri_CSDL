from functools import cache
from pathlib import Path
from typing import Literal

from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel
from pydantic.networks import EmailStr
from sqlalchemy import text
from sqlmodel import Session, col, select

from app.api.deps import get_current_active_superuser
from app.core.config import settings
from app.core.db import engine
from app.models import Language, Message, User
from app.utils import generate_test_email, send_email

router = APIRouter(prefix="/utils", tags=["utils"])


class Readiness(BaseModel):
    checks: dict[str, Literal["ok", "failed", "skipped"]]


@cache
def _code_heads() -> frozenset[str]:
    migrations = Path(__file__).resolve().parents[2] / "alembic"
    return frozenset(ScriptDirectory(str(migrations)).get_heads())


def _has_current_revision(session: Session) -> bool:
    heads = _code_heads()
    current = MigrationContext.configure(session.connection()).get_current_heads()
    return bool(heads) and heads == frozenset(current)


def _has_required_seed(session: Session) -> bool:
    default_language = session.exec(
        select(Language.id).where(col(Language.is_default)).limit(1)
    ).first()
    first_superuser = session.exec(
        select(User.id)
        .where(User.email == settings.FIRST_SUPERUSER, col(User.is_superuser))
        .limit(1)
    ).first()
    return default_language is not None and first_superuser is not None


@router.post(
    "/test-email/",
    dependencies=[Depends(get_current_active_superuser)],
    status_code=201,
)
def test_email(email_to: EmailStr) -> Message:
    """
    Test emails.
    """
    email_data = generate_test_email(email_to=email_to)
    send_email(
        email_to=email_to,
        subject=email_data.subject,
        html_content=email_data.html_content,
    )
    return Message(message="Test email sent")


@router.get("/health-check/")
async def health_check() -> bool:
    return True


@router.get("/ready", responses={503: {"model": Readiness}})
def readiness(response: Response) -> Readiness:
    """Check database connectivity, schema revision, and required seed data."""
    result = Readiness(
        checks={"database": "failed", "alembic_revision": "skipped", "seed": "skipped"}
    )
    try:
        with Session(engine) as session:
            if session.connection().execute(text("SELECT 1")).scalar_one() == 1:
                result.checks["database"] = "ok"
                for name, check in (
                    ("alembic_revision", _has_current_revision),
                    ("seed", _has_required_seed),
                ):
                    try:
                        result.checks[name] = "ok" if check(session) else "failed"
                    except Exception:
                        # Probe responses expose only the check name and status.
                        result.checks[name] = "failed"
    except Exception:
        result.checks["database"] = "failed"

    if any(check != "ok" for check in result.checks.values()):
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return result

from collections.abc import Iterator
from pathlib import Path

import pytest
from alembic.script import ScriptDirectory
from fastapi.testclient import TestClient
from sqlalchemy import Connection, Engine, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, col, create_engine, select

from app.api.routes import utils
from app.core.config import settings
from app.main import app
from app.models import Language, User

READY_URL = f"{settings.API_V1_STR}/utils/ready"


@pytest.fixture
def readiness_engine(monkeypatch: pytest.MonkeyPatch) -> Iterator[Engine]:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    try:
        tables = [
            SQLModel.metadata.tables[name] for name in ("role", "language", "user")
        ]
        SQLModel.metadata.create_all(engine, tables=tables)
        migrations = Path(__file__).resolve().parents[3] / "app" / "alembic"
        head = ScriptDirectory(str(migrations)).get_current_head()
        with Session(engine) as session:
            session.execute(
                text(
                    "CREATE TABLE alembic_version (version_num VARCHAR(32) PRIMARY KEY)"
                )
            )
            session.execute(
                text("INSERT INTO alembic_version (version_num) VALUES (:head)"),
                {"head": head},
            )
            session.add(Language(code="en", name="English", is_default=True))
            session.add(
                User(
                    email=settings.FIRST_SUPERUSER,
                    hashed_password="unused-in-readiness-check",
                    is_superuser=True,
                )
            )
            session.commit()
        monkeypatch.setattr(utils, "engine", engine)
        yield engine
    finally:
        engine.dispose()


@pytest.mark.usefixtures("readiness_engine")
def test_readiness_passes() -> None:
    response = TestClient(app).get(READY_URL)

    assert response.status_code == 200
    assert response.json() == {
        "checks": {"database": "ok", "alembic_revision": "ok", "seed": "ok"}
    }


def test_database_failure_is_sanitized_and_liveness_still_passes(
    readiness_engine: Engine, monkeypatch: pytest.MonkeyPatch
) -> None:
    connection_string = "mssql+pymssql://fake-user:fake-password@example.invalid/app"

    def fail_to_connect() -> Connection:
        raise OperationalError(None, None, RuntimeError(connection_string))

    monkeypatch.setattr(readiness_engine, "connect", fail_to_connect)
    client = TestClient(app)
    response = client.get(READY_URL)

    assert response.status_code == 503
    assert response.json() == {
        "checks": {
            "database": "failed",
            "alembic_revision": "skipped",
            "seed": "skipped",
        }
    }
    assert connection_string not in response.text

    liveness = client.get(f"{settings.API_V1_STR}/utils/health-check/")
    assert liveness.status_code == 200
    assert liveness.json() is True


@pytest.mark.parametrize(
    "missing_seed", ["default_language", "first_superuser", "superuser_privilege"]
)
def test_missing_seed_fails(readiness_engine: Engine, missing_seed: str) -> None:
    with Session(readiness_engine) as session:
        if missing_seed == "default_language":
            language = session.exec(
                select(Language).where(col(Language.is_default))
            ).one()
            language.is_default = False
        elif missing_seed == "first_superuser":
            user = session.exec(select(User)).one()
            user.email = "another-superuser@example.com"
        else:
            user = session.exec(select(User)).one()
            user.is_superuser = False
        session.commit()

    response = TestClient(app).get(READY_URL)

    assert response.status_code == 503
    assert response.json() == {
        "checks": {"database": "ok", "alembic_revision": "ok", "seed": "failed"}
    }


@pytest.mark.parametrize(
    "change_revision",
    [
        "UPDATE alembic_version SET version_num = '9398b7ad0549'",
        "DROP TABLE alembic_version",
    ],
    ids=["old-revision", "missing-version-table"],
)
def test_wrong_or_missing_revision_fails(
    readiness_engine: Engine, change_revision: str
) -> None:
    with readiness_engine.begin() as connection:
        connection.execute(text(change_revision))

    response = TestClient(app).get(READY_URL)

    assert response.status_code == 503
    assert response.json() == {
        "checks": {"database": "ok", "alembic_revision": "failed", "seed": "ok"}
    }

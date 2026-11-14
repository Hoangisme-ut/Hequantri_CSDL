"""Runtime checks on the migrated, identity-verified SQL Server test database."""

from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text

from app.core.db import engine


def test_migration_head_and_sql_server_constraints():
    assert engine.dialect.name == "mssql"

    backend_dir = Path(__file__).resolve().parents[2]
    config = Config(str(backend_dir / "alembic.ini"))
    config.set_main_option(
        "script_location",
        str(backend_dir / "app" / "alembic"),
    )

    with engine.connect() as connection:
        assert (
            connection.execute(
                text("SELECT version_num FROM alembic_version")
            ).scalar_one()
            == ScriptDirectory.from_config(config).get_current_head()
        )

        constraints = connection.execute(
            text(
                "SELECT name, is_disabled, is_not_trusted "
                "FROM sys.check_constraints "
                "WHERE parent_object_id=OBJECT_ID('feedback')"
            )
        ).all()

        assert {
            (row.name, row.is_disabled, row.is_not_trusted) for row in constraints
        } >= {
            ("ck_feedback_rating", False, False),
            ("ck_feedback_status", False, False),
        }

        indexes = connection.execute(
            text(
                "SELECT name, is_unique, has_filter "
                "FROM sys.indexes "
                "WHERE name IN ("
                "'uq_language_default',"
                "'uq_beacon_artifact_id',"
                "'uq_beacon_identity',"
                "'uq_artifact_site_code',"
                "'uq_artifact_language'"
                ")"
            )
        ).all()

        assert {
            (row.name, bool(row.is_unique), bool(row.has_filter)) for row in indexes
        } == {
            ("uq_language_default", True, True),
            ("uq_beacon_artifact_id", True, True),
            ("uq_beacon_identity", True, False),
            ("uq_artifact_site_code", True, False),
            ("uq_artifact_language", True, False),
        }

    inspector = inspect(engine)

    for table, column in [
        ("site", "name"),
        ("artifacttranslation", "title"),
        ("feedback", "comment"),
    ]:
        columns = {c["name"]: c for c in inspector.get_columns(table)}
        assert str(columns[column]["type"]).startswith("NVARCHAR")

    assert inspector.get_pk_constraint("usedpasswordreset")["constrained_columns"] == [
        "token_digest"
    ]

    fks = inspector.get_foreign_keys("visitlog")
    assert {tuple(fk["constrained_columns"]) for fk in fks} == {
        ("user_id",),
        ("artifact_id",),
        ("beacon_id",),
        ("language_id",),
    }

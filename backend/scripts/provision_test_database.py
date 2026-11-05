"""Create a NEW test database and marker; never mark or reuse an existing DB.

Run only against a dedicated test SQL Server. No migrations or cleanup here.
"""

import os
import re

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url


def main() -> None:
    target = make_url(os.environ["TEST_DATABASE_URL"])
    token = os.environ["TEST_DATABASE_TOKEN"]
    name = target.database or ""
    if (
        target.get_backend_name() != "mssql"
        or not re.fullmatch(r"test_[a-z0-9_]+", name)
        or len(token) < 32
    ):
        raise RuntimeError(
            "Require SQL Server test_* database and a random token of at least 32 characters"
        )
    master = create_engine(target.set(database="master"), isolation_level="AUTOCOMMIT")
    try:
        with master.connect() as connection:
            exists = connection.execute(
                text("SELECT DB_ID(:name)"), {"name": name}
            ).scalar()
            if exists is not None:
                raise RuntimeError(
                    "Database already exists; refusing to provision or mark it"
                )
            # Identifier is restricted to ASCII letters/digits/underscores above.
            connection.execute(text(f"CREATE DATABASE [{name}]"))
    finally:
        master.dispose()
    engine = create_engine(target)
    try:
        with engine.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE dbo.test_database_identity (token varchar(128) NOT NULL)"
                )
            )
            connection.execute(
                text("INSERT INTO dbo.test_database_identity (token) VALUES (:token)"),
                {"token": token},
            )
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()

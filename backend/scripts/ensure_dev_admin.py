"""Create or explicitly reset the local Smart Heritage development admin.

This command is intentionally limited to the fixed local development account.
Existing credentials are never changed unless --reset-existing is supplied.
"""

import argparse
import logging
from getpass import getpass

from sqlalchemy.engine import make_url
from sqlmodel import Session

from app import crud
from app.core.config import settings
from app.core.db import engine
from app.core.security import verify_password
from app.models import UserCreate, UserUpdate

DEV_ADMIN_EMAIL = "admin@example.com"
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset-existing",
        action="store_true",
        help="Explicitly replace the existing local admin password.",
    )
    args = parser.parse_args()

    database = make_url(settings.DATABASE_URL)
    is_local_development_database = (
        database.host in {"db", "localhost", "127.0.0.1"}
        and database.database == "app"
    )
    if settings.FASTAPI_ENV != "development" or not is_local_development_database:
        parser.error(
            "This command requires FASTAPI_ENV=development and a local 'app' database."
        )

    password = getpass("Development admin password: ")
    confirmation = getpass("Confirm development admin password: ")
    if password != confirmation:
        parser.error("Passwords do not match.")
    if not 8 <= len(password) <= 128:
        parser.error("Password must be between 8 and 128 characters.")

    with Session(engine) as session:
        user = crud.get_user_by_email(session=session, email=DEV_ADMIN_EMAIL)
        if user is None:
            crud.create_user(
                session=session,
                user_create=UserCreate(
                    email=DEV_ADMIN_EMAIL,
                    password=password,
                    is_active=True,
                    is_superuser=True,
                ),
            )
            logger.info("Development admin created with an application-hashed password.")
            return

        password_matches = verify_password(password, user.hashed_password)[0]
        if password_matches and user.is_active and user.is_superuser:
            logger.info("Development admin already exists and matches; no changes made.")
            return

        if not args.reset_existing:
            parser.error(
                "The development admin already exists with different credentials or flags. "
                "No changes were made. Re-run with --reset-existing to explicitly update it."
            )

        crud.update_user(
            session=session,
            db_user=user,
            user_in=UserUpdate(
                password=password,
                is_active=True,
                is_superuser=True,
            ),
        )
        logger.info(
            "Existing development admin updated through the application password hasher."
        )


if __name__ == "__main__":
    main()

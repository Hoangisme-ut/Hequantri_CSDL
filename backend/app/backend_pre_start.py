import logging
import time

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 10
RETRY_DELAY_SECONDS = 3


def init() -> None:
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            target = make_url(settings.DATABASE_URL)
            if not target.database or target.database.casefold() == "master":
                raise ValueError("A named application database is required")
            engine = create_engine(settings.DATABASE_URL)
            try:
                with engine.connect() as connection:
                    connection.execute(text("SELECT 1"))
            finally:
                engine.dispose()
        except Exception:
            # Driver exceptions can include credentials; never log or chain them.
            if attempt < MAX_ATTEMPTS:
                logger.warning(
                    "Database is not ready (attempt %d/%d); retrying in %d seconds",
                    attempt,
                    MAX_ATTEMPTS,
                    RETRY_DELAY_SECONDS,
                )
                time.sleep(RETRY_DELAY_SECONDS)
        else:
            logger.info("Database is ready")
            return

    message = (
        f"Database readiness check failed after {MAX_ATTEMPTS} attempts. "
        "The target database must already exist: locally, use the db-init "
        "Compose service; on Azure SQL Database, create it in the Azure portal "
        "before startup. Use a named application database rather than master, "
        "and check its connection settings and permissions."
    )
    logger.error(message)
    raise RuntimeError(message) from None


def main() -> None:
    logger.info("Initializing service")
    init()
    logger.info("Service finished initializing")


if __name__ == "__main__":
    main()

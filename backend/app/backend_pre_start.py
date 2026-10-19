import logging

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def init() -> None:
    try:
        url = make_url(str(settings.DATABASE_URL))
        db_name = url.database
        if db_name:
            master_url = url.set(database="master")
            engine = create_engine(master_url, isolation_level="AUTOCOMMIT")
            with engine.connect() as conn:
                logger.info(f"Ensuring database '{db_name}' exists...")
                conn.execute(
                    text(f"IF DB_ID('{db_name}') IS NULL CREATE DATABASE [{db_name}]")
                )
            logger.info(f"Database '{db_name}' is ready.")
    except Exception as e:
        logger.error(f"Error checking/creating database: {e}")
        raise e


def main() -> None:
    logger.info("Initializing service")
    init()
    logger.info("Service finished initializing")


if __name__ == "__main__":
    main()

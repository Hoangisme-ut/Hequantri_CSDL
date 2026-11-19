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

        # 1. First attempt: connect directly to the target database
        try:
            target_engine = create_engine(url)
            with target_engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            logger.info("Database is ready")
            return
        except Exception:
            # If target database is not ready or does not exist yet (e.g. fresh local SQL Server)
            pass

        # 2. Ensure database exists via master
        if db_name:
            master_url = url.set(database="master")
            engine = create_engine(master_url, isolation_level="AUTOCOMMIT")
            with engine.connect() as conn:
                logger.info(f"Ensuring database '{db_name}' exists...")
                try:
                    conn.execute(
                        text(f"IF DB_ID('{db_name}') IS NULL CREATE DATABASE [{db_name}]")
                    )
                except Exception as create_err:
                    if "1801" in str(create_err) or "already exists" in str(create_err):
                        logger.info(f"Database '{db_name}' already exists.")
                    else:
                        raise create_err
            logger.info("Database is ready")
    except Exception as e:
        logger.error(f"Error checking/creating database: {e}")
        raise e


def main() -> None:
    logger.info("Initializing service")
    init()
    logger.info("Service finished initializing")


if __name__ == "__main__":
    main()

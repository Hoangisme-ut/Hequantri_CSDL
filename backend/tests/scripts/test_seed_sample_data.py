from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, func, select

from app.models import Artifact, ArtifactTranslation, Beacon, Language, Site
from app.seed_sample_data import seed_sample_data


def test_seed_sample_data_is_idempotent() -> None:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)

    with Session(engine) as session:
        seed_sample_data(session)
        seed_sample_data(session)

        assert session.exec(select(func.count()).select_from(Site)).one() == 2
        assert session.exec(select(func.count()).select_from(Artifact)).one() == 5
        assert session.exec(select(func.count()).select_from(Beacon)).one() == 3
        assert session.exec(select(func.count()).select_from(Language)).one() == 2
        assert (
            session.exec(select(func.count()).select_from(ArtifactTranslation)).one()
            == 10
        )

        language_codes = set(session.exec(select(Language.code)).all())
        assert language_codes == {"vi", "en"}
        assert session.exec(
            select(Language.code).where(Language.is_default)
        ).one() == "vi"

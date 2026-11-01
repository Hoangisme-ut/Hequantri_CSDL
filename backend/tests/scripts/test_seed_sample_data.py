import pytest
from sqlalchemy import event
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, func, select

from app import crud
from app.models import (
    Artifact,
    ArtifactTranslation,
    Beacon,
    Language,
    Media,
    MediaCreate,
    Site,
)
from app.seed_sample_data import ARTIFACTS, seed_sample_data


@pytest.fixture(autouse=True)
def db() -> None:
    """These tests use isolated SQLite, not the suite's shared SQL Server fixture."""


def test_seed_sample_data_is_idempotent() -> None:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)

    with Session(engine) as session:
        seed_sample_data(session)
        original_ids = set(session.exec(select(Media.id)).all())
        seed_sample_data(session)
        assert set(session.exec(select(Media.id)).all()) == original_ids
        assert len(original_ids) == 20

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
        assert (
            session.exec(select(Language.code).where(Language.is_default)).one() == "vi"
        )


def test_demo_content_and_repair_preserve_unrelated_data() -> None:
    engine = create_engine("sqlite://", poolclass=StaticPool)

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _record):
        connection.execute("PRAGMA foreign_keys=ON")

    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        seed_sample_data(session)
        artifact = session.get(Artifact, ARTIFACTS[0].id)
        assert artifact is not None
        custom_media = Media(
            artifact_id=artifact.id, url="https://example.com/custom.jpg"
        )
        session.add(custom_media)
        media = session.exec(
            select(Media).where(Media.language_id.is_not(None))
        ).first()
        assert media is not None
        session.delete(media)
        translation = session.exec(select(ArtifactTranslation)).first()
        assert translation is not None
        translation.title = "Edited demo"
        session.add(translation)
        session.commit()
        seed_sample_data(session)
        assert session.get(Media, custom_media.id) is not None
        assert session.exec(select(func.count()).select_from(Media)).one() == 21
        for seed in ARTIFACTS:
            artifact = session.get(Artifact, seed.id)
            assert artifact is not None and artifact.is_active
            site = session.get(Site, artifact.site_id)
            assert site is not None and site.is_active
            for language in session.exec(select(Language)).all():
                content = crud.get_artifact_content(
                    session=session, artifact=artifact, language=language
                )
                assert content.title == getattr(seed, f"title_{language.code}")
                assert content.description == getattr(
                    seed, f"description_{language.code}"
                )
                assert content.language_code == language.code
                assert not content.is_fallback
                demo_media = [m for m in content.media if m.id != custom_media.id]
                assert [m.media_type for m in demo_media] == ["image", "video", "audio"]
                assert [m.language_id for m in demo_media] == [None, None, language.id]
                for item in demo_media:
                    MediaCreate.model_validate(item.model_dump())
        for beacon in session.exec(select(Beacon)).all():
            artifact = session.get(Artifact, beacon.artifact_id)
            assert artifact is not None
            assert beacon.is_active and beacon.site_id == artifact.site_id

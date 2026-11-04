import pytest
from fastapi import HTTPException
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.api.routes import sites as sites_route
from app.models import Language, Site, SiteTranslationInput


@pytest.fixture
def session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as db:
        yield db
    SQLModel.metadata.drop_all(engine)
    engine.dispose()


def _site_and_english(session: Session) -> tuple[Site, Language]:
    site = Site(name="Vietnamese Site", description="Source text", address="Hanoi")
    english = Language(code="en", name="English", is_active=True)
    session.add(site)
    session.add(english)
    session.commit()
    session.refresh(site)
    session.refresh(english)
    return site, english


def test_public_site_uses_translation_or_marks_vietnamese_fallback(
    session: Session,
) -> None:
    site, english = _site_and_english(session)

    fallback = sites_route.read_site(session, None, site.id, lang="en")
    assert fallback.name == "Vietnamese Site"
    assert fallback.language_code == "vi"
    assert fallback.is_fallback is True

    translation = sites_route.SiteTranslation.model_validate(
        SiteTranslationInput(name="Heritage Site", description="English text"),
        update={
            "site_id": site.id,
            "language_id": english.id,
            "source_hash": sites_route.site_source_hash(site),
            "is_confirmed": True,
        },
    )
    session.add(translation)
    session.commit()

    localized = sites_route.read_site(session, None, site.id, lang="en")
    assert localized.name == "Heritage Site"
    assert localized.description == "English text"
    assert localized.language_code == "en"
    assert localized.is_fallback is False


def test_manual_translation_is_confirmed_without_changing_vietnamese_source(
    session: Session,
) -> None:
    site, english = _site_and_english(session)
    original_source = (site.name, site.description, site.address)

    saved = sites_route.upsert_site_translation(
        session=session,
        _admin=object(),
        site_id=site.id,
        language_id=english.id,
        translation_in=SiteTranslationInput(
            name="Heritage Site",
            description="Reviewed English description",
            address="English address",
        ),
    )
    session.refresh(site)

    assert saved.is_confirmed is True
    assert saved.language_code == "en"
    assert (site.name, site.description, site.address) == original_source

    edited = sites_route.upsert_site_translation(
        session=session,
        _admin=object(),
        site_id=site.id,
        language_id=english.id,
        translation_in=SiteTranslationInput(
            name="Updated Heritage Site",
            description="Updated English description",
            address="Updated English address",
        ),
    )
    assert edited.id == saved.id
    assert edited.is_confirmed is True
    assert (site.name, site.description, site.address) == original_source

    localized = sites_route.read_site(session, None, site.id, lang="en")
    assert localized.name == "Updated Heritage Site"
    assert localized.language_code == "en"
    assert localized.is_fallback is False

    site.description = "Changed Vietnamese source"
    session.add(site)
    session.commit()
    stale_fallback = sites_route.read_site(session, None, site.id, lang="en")
    assert stale_fallback.name == site.name
    assert stale_fallback.language_code == "vi"
    assert stale_fallback.is_fallback is True


def test_delete_english_translation_restores_vietnamese_fallback(
    session: Session,
) -> None:
    site, english = _site_and_english(session)
    sites_route.upsert_site_translation(
        session=session,
        _admin=object(),
        site_id=site.id,
        language_id=english.id,
        translation_in=SiteTranslationInput(name="Heritage Site"),
    )

    result = sites_route.delete_site_translation(
        session=session,
        _admin=object(),
        site_id=site.id,
        language_id=english.id,
    )

    assert result.message == "Site translation deleted successfully"
    fallback = sites_route.read_site(session, None, site.id, lang="en")
    assert fallback.name == site.name
    assert fallback.language_code == "vi"
    assert fallback.is_fallback is True


def test_vietnamese_source_cannot_be_deleted_as_a_translation(
    session: Session,
) -> None:
    site, _ = _site_and_english(session)
    vietnamese = Language(code="vi", name="Vietnamese", is_active=True)
    session.add(vietnamese)
    session.commit()
    session.refresh(vietnamese)

    with pytest.raises(HTTPException) as error:
        sites_route.delete_site_translation(
            session=session,
            _admin=object(),
            site_id=site.id,
            language_id=vietnamese.id,
        )

    assert error.value.status_code == 422

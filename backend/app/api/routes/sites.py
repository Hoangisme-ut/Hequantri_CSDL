import uuid
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import true
from sqlmodel import col, func, select

from app.api.deps import AdminUser, OptionalUser, SessionDep, is_admin
from app.models import (
    Language,
    Message,
    Site,
    SiteCreate,
    SitePublic,
    SitesPublic,
    SiteTranslation,
    SiteTranslationInput,
    SiteTranslationPublic,
    SiteUpdate,
    get_datetime_utc,
)
from app.services.site_translation import site_source_hash

router = APIRouter(prefix="/sites", tags=["sites"])


@router.get("/", response_model=SitesPublic)
def read_sites(
    session: SessionDep,
    current_user: OptionalUser,
    skip: int = 0,
    limit: int = Query(default=100, le=200),
    q: str | None = None,
    include_inactive: bool = False,
    lang: Literal["vi", "en"] = "vi",
) -> Any:
    """
    Danh sách di tích. **Public**.
    Chỉ admin mới xem được di tích đã ẩn (`include_inactive=true`).
    """
    conditions: list[Any] = []
    if not (include_inactive and is_admin(current_user)):
        conditions.append(col(Site.is_active) == true())
    if q:
        conditions.append(col(Site.name).contains(q))
    count = session.exec(
        select(func.count()).select_from(Site).where(*conditions)
    ).one()
    statement = (
        select(Site)
        .where(*conditions)
        .order_by(col(Site.name))
        .offset(skip)
        .limit(limit)
    )
    sites = session.exec(statement).all()
    return SitesPublic(data=_localized_sites(session, sites, lang), count=count)


@router.get("/{site_id}", response_model=SitePublic)
def read_site(
    session: SessionDep,
    current_user: OptionalUser,
    site_id: uuid.UUID,
    lang: Literal["vi", "en"] = "vi",
) -> Any:
    """
    Chi tiết di tích. **Public** (di tích đã ẩn chỉ admin xem được).
    """
    site = session.get(Site, site_id)
    if not site or (not site.is_active and not is_admin(current_user)):
        raise HTTPException(status_code=404, detail="Site not found")
    return _localized_site(session, site, lang)


def _localized_site(session: SessionDep, site: Site, lang: str) -> SitePublic:
    return _localized_sites(session, [site], lang)[0]


def _localized_sites(
    session: SessionDep, sites: list[Site], lang: str
) -> list[SitePublic]:
    translation_by_site: dict[uuid.UUID, SiteTranslation] = {}
    if lang == "en" and sites:
        language = session.exec(
            select(Language).where(Language.code == "en", Language.is_active == true())
        ).first()
        if language is not None:
            translations = session.exec(
                select(SiteTranslation).where(
                    SiteTranslation.language_id == language.id,
                    col(SiteTranslation.site_id).in_([site.id for site in sites]),
                )
            ).all()
            translation_by_site = {
                translation.site_id: translation for translation in translations
            }

    result: list[SitePublic] = []
    for site in sites:
        data = site.model_dump()
        data["language_code"] = "vi"
        data["is_fallback"] = False
        translation = translation_by_site.get(site.id)
        if lang == "en":
            if (
                translation is not None
                and translation.is_confirmed
                and translation.source_hash == site_source_hash(site)
            ):
                data.update(
                    name=translation.name,
                    description=translation.description,
                    address=translation.address,
                    language_code="en",
                )
            else:
                data["is_fallback"] = True
        result.append(SitePublic.model_validate(data))
    return result


@router.get("/{site_id}/translations", response_model=list[SiteTranslationPublic])
def read_site_translations(
    session: SessionDep, _admin: AdminUser, site_id: uuid.UUID
) -> Any:
    site = session.get(Site, site_id)
    if site is None:
        raise HTTPException(status_code=404, detail="Site not found")
    translations = session.exec(
        select(SiteTranslation, Language)
        .join(Language, SiteTranslation.language_id == Language.id)
        .where(SiteTranslation.site_id == site_id)
    ).all()
    return [
        SiteTranslationPublic.model_validate(
            translation,
            update={
                "language_code": language.code,
                "is_stale": translation.source_hash != site_source_hash(site),
            },
        )
        for translation, language in translations
    ]


@router.put(
    "/{site_id}/translations/{language_id}", response_model=SiteTranslationPublic
)
def upsert_site_translation(
    *,
    session: SessionDep,
    _admin: AdminUser,
    site_id: uuid.UUID,
    language_id: uuid.UUID,
    translation_in: SiteTranslationInput,
) -> Any:
    site = session.get(Site, site_id)
    if site is None:
        raise HTTPException(status_code=404, detail="Site not found")
    language = session.get(Language, language_id)
    if language is None:
        raise HTTPException(status_code=404, detail="Language not found")
    if language.code != "en":
        raise HTTPException(
            status_code=422, detail="Only English Site translations are editable"
        )
    translation = session.exec(
        select(SiteTranslation).where(
            SiteTranslation.site_id == site_id,
            SiteTranslation.language_id == language_id,
        )
    ).first()
    values = translation_in.model_dump()
    if translation is None:
        translation = SiteTranslation.model_validate(
            translation_in,
            update={
                "site_id": site_id,
                "language_id": language_id,
                "source_hash": site_source_hash(site),
                "translation_source": "manual",
                "is_confirmed": True,
                "updated_at": get_datetime_utc(),
            },
        )
    else:
        for key, value in values.items():
            setattr(translation, key, value)
        translation.source_hash = site_source_hash(site)
        translation.translation_source = "manual"
        translation.is_confirmed = True
        translation.updated_at = get_datetime_utc()
    session.add(translation)
    session.commit()
    session.refresh(translation)
    return SiteTranslationPublic.model_validate(
        translation, update={"language_code": language.code, "is_stale": False}
    )


@router.delete("/{site_id}/translations/{language_id}", response_model=Message)
def delete_site_translation(
    session: SessionDep,
    _admin: AdminUser,
    site_id: uuid.UUID,
    language_id: uuid.UUID,
) -> Message:
    site = session.get(Site, site_id)
    if site is None:
        raise HTTPException(status_code=404, detail="Site not found")
    language = session.get(Language, language_id)
    if language is None:
        raise HTTPException(status_code=404, detail="Language not found")
    if language.code != "en":
        raise HTTPException(
            status_code=422, detail="Only English Site translations can be deleted"
        )
    translation = session.exec(
        select(SiteTranslation).where(
            SiteTranslation.site_id == site_id,
            SiteTranslation.language_id == language.id,
        )
    ).first()
    if translation is None:
        raise HTTPException(status_code=404, detail="Site translation not found")
    session.delete(translation)
    session.commit()
    return Message(message="Site translation deleted successfully")


@router.post("/", response_model=SitePublic)
def create_site(*, session: SessionDep, _admin: AdminUser, site_in: SiteCreate) -> Any:
    """
    Tạo di tích. **Admin**.
    """
    site = Site.model_validate(site_in)
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


@router.put("/{site_id}", response_model=SitePublic)
def update_site(
    *, session: SessionDep, _admin: AdminUser, site_id: uuid.UUID, site_in: SiteUpdate
) -> Any:
    """
    Sửa di tích (cả bật lại `is_active`). **Admin**.
    """
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    site.sqlmodel_update(site_in.model_dump(exclude_unset=True))
    site.updated_at = get_datetime_utc()
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


@router.delete("/{site_id}")
def delete_site(session: SessionDep, _admin: AdminUser, site_id: uuid.UUID) -> Message:
    """
    Ẩn di tích (xóa mềm: is_active = false). **Admin**.

    Không sửa dữ liệu con: hiện vật + beacon của Site ẩn tự không trả cho du khách
    (kiểm tra lúc đọc). Bật lại Site (`PUT is_active=true`) -> hiển thị lại như cũ.
    """
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    site.is_active = False
    site.updated_at = get_datetime_utc()
    session.add(site)
    session.commit()
    return Message(message="Site deactivated successfully")

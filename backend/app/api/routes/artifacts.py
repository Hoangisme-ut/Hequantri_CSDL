import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import ColumnElement, true
from sqlmodel import col, func, select

from app import crud
from app.api.deps import AdminUser, OptionalUser, SessionDep, is_admin
from app.api.docs import errors
from app.core.transactions import commit_with_conflicts
from app.models import (
    Artifact,
    ArtifactContentPublic,
    ArtifactCreate,
    ArtifactPublic,
    ArtifactSummariesPublic,
    ArtifactSummary,
    ArtifactTranslation,
    ArtifactTranslationBase,
    ArtifactTranslationPublic,
    ArtifactUpdate,
    Beacon,
    Language,
    Message,
    Site,
)

router = APIRouter(prefix="/artifacts", tags=["artifacts"])


def _get_artifact_or_404(
    session: SessionDep, artifact_id: uuid.UUID, current_user: OptionalUser = None
) -> Artifact:
    if is_admin(current_user):
        artifact = session.get(Artifact, artifact_id)
    else:
        # khách chỉ thấy hiện vật đang bật VÀ thuộc Site đang bật
        artifact = crud.get_visible_artifact(session=session, artifact_id=artifact_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")
    return artifact


def _require_active_site(session: SessionDep, site_id: uuid.UUID) -> None:
    """Site phải tồn tại (404) và đang bật (409) khi thêm/chuyển hiện vật vào."""
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    if not site.is_active:
        raise HTTPException(
            status_code=409,
            detail="Site đang bị ẩn, không thể thêm hiện vật vào Site này",
        )


def _check_code_unique(
    session: SessionDep,
    site_id: uuid.UUID,
    code: str,
    exclude_id: uuid.UUID | None = None,
) -> None:
    stmt = select(Artifact).where(Artifact.site_id == site_id, Artifact.code == code)
    existing = session.exec(stmt).first()
    if existing and existing.id != exclude_id:
        raise HTTPException(
            status_code=409, detail="Artifact code already exists in this site"
        )


# ----------------------------- Public: app/web -----------------------------
@router.get("/", response_model=ArtifactSummariesPublic)
def read_artifacts(
    session: SessionDep,
    current_user: OptionalUser,
    site_id: uuid.UUID | None = None,
    lang: str | None = Query(default=None, description="Mã ngôn ngữ: vi, en..."),
    q: str | None = Query(default=None, description="Tìm theo mã hiện vật"),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
    include_inactive: bool = False,
) -> Any:
    """
    Danh sách hiện vật kèm tiêu đề theo ngôn ngữ. **Public**.
    """
    conditions: list[ColumnElement[bool]] = []
    if not (include_inactive and is_admin(current_user)):
        # chỉ hiện vật đang bật VÀ thuộc Site đang bật
        conditions.append(col(Artifact.is_active) == true())
        conditions.append(col(Site.is_active) == true())
    if site_id:
        conditions.append(col(Artifact.site_id) == site_id)
    if q:
        conditions.append(col(Artifact.code).contains(q))
    site_join = col(Site.id) == col(Artifact.site_id)
    count = session.exec(
        select(func.count())
        .select_from(Artifact)
        .join(Site, site_join)
        .where(*conditions)
    ).one()
    artifacts = session.exec(
        select(Artifact)
        .join(Site, site_join)
        .where(*conditions)
        .order_by(col(Artifact.code))
        .offset(skip)
        .limit(limit)
    ).all()

    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    summaries = []
    for a in artifacts:
        translation, used_lang = crud.pick_translation(
            session=session, artifact_id=a.id, language=language
        )
        summaries.append(
            ArtifactSummary.model_validate(
                a,
                update={
                    "title": translation.title if translation else None,
                    "language_code": used_lang.code if used_lang else None,
                    "is_fallback": bool(
                        translation
                        and language is not None
                        and translation.language_id != language.id
                    ),
                },
            )
        )
    return ArtifactSummariesPublic(data=summaries, count=count)


@router.get(
    "/{artifact_id}", response_model=ArtifactContentPublic, responses=errors(404)
)
def read_artifact(
    session: SessionDep,
    current_user: OptionalUser,
    artifact_id: uuid.UUID,
    lang: str | None = Query(default=None, description="Mã ngôn ngữ: vi, en..."),
) -> Any:
    """
    Chi tiết hiện vật + nội dung theo ngôn ngữ + media. **Public**.
    Nếu chưa có bản dịch cho `lang` thì dùng ngôn ngữ mặc định (`is_fallback = true`).
    """
    artifact = _get_artifact_or_404(session, artifact_id, current_user)
    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    return crud.get_artifact_content(
        session=session, artifact=artifact, language=language
    )


# --------------------------------- Admin ----------------------------------
@router.post("/", response_model=ArtifactPublic, responses=errors(401, 403, 404, 409))
def create_artifact(
    *, session: SessionDep, _admin: AdminUser, artifact_in: ArtifactCreate
) -> Any:
    """
    Tạo hiện vật. **Admin**. Mã `code` không được trùng trong cùng di tích.
    Không tạo được hiện vật dưới Site đang bị ẩn (409).
    """
    _require_active_site(session, artifact_in.site_id)
    _check_code_unique(session, artifact_in.site_id, artifact_in.code)
    artifact = Artifact.model_validate(artifact_in)
    session.add(artifact)
    commit_with_conflicts(session, "uq_artifact_site_code")
    session.refresh(artifact)
    return artifact


@router.put(
    "/{artifact_id}",
    response_model=ArtifactPublic,
    responses=errors(401, 403, 404, 409),
)
def update_artifact(
    *,
    session: SessionDep,
    _admin: AdminUser,
    artifact_id: uuid.UUID,
    artifact_in: ArtifactUpdate,
) -> Any:
    """
    Sửa hiện vật (cả bật lại `is_active`). **Admin**.

    Đổi `site_id`: Site mới phải tồn tại và đang bật (409 nếu bị ẩn); nếu hiện vật
    đang gắn Beacon thì phải gỡ Beacon trước (409) để Beacon và hiện vật luôn cùng Site.
    """
    artifact = session.get(Artifact, artifact_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")
    data = artifact_in.model_dump(exclude_unset=True)
    for field in ("site_id", "code", "is_active"):
        if field in data and data[field] is None:
            raise HTTPException(status_code=422, detail=f"{field} cannot be null")
    new_site_id = data.get("site_id", artifact.site_id)
    new_code = data.get("code", artifact.code)
    if "site_id" in data and new_site_id != artifact.site_id:
        _require_active_site(session, new_site_id)
        attached = session.exec(
            select(Beacon).where(col(Beacon.artifact_id) == artifact.id)
        ).first()
        if attached:
            raise HTTPException(
                status_code=409,
                detail="Hiện vật đang gắn Beacon, hãy gỡ Beacon trước khi đổi Site",
            )
    if "site_id" in data or "code" in data:
        _check_code_unique(session, new_site_id, new_code, exclude_id=artifact.id)
    artifact.sqlmodel_update(data)
    crud.touch_updated_at(artifact)
    session.add(artifact)
    commit_with_conflicts(session, "uq_artifact_site_code")
    session.refresh(artifact)
    return artifact


@router.delete("/{artifact_id}", responses=errors(401, 403, 404))
def delete_artifact(
    session: SessionDep, _admin: AdminUser, artifact_id: uuid.UUID
) -> Message:
    """
    Ẩn hiện vật (xóa mềm: is_active = false). **Admin**.
    """
    artifact = session.get(Artifact, artifact_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")
    artifact.is_active = False
    crud.touch_updated_at(artifact)
    session.add(artifact)
    session.commit()
    return Message(message="Artifact deactivated successfully")


# ----------------------- Nội dung theo từng ngôn ngữ ------------------------
@router.get(
    "/{artifact_id}/translations",
    response_model=list[ArtifactTranslationPublic],
    responses=errors(401, 403, 404),
)
def read_translations(
    session: SessionDep, _admin: AdminUser, artifact_id: uuid.UUID
) -> Any:
    """
    Tất cả bản dịch của hiện vật. **Admin**.
    """
    if not session.get(Artifact, artifact_id):
        raise HTTPException(status_code=404, detail="Artifact not found")
    return session.exec(
        select(ArtifactTranslation).where(
            ArtifactTranslation.artifact_id == artifact_id
        )
    ).all()


@router.put(
    "/{artifact_id}/translations/{language_id}",
    response_model=ArtifactTranslationPublic,
    responses=errors(401, 403, 404, 409),
)
def upsert_translation(
    *,
    session: SessionDep,
    _admin: AdminUser,
    artifact_id: uuid.UUID,
    language_id: uuid.UUID,
    translation_in: ArtifactTranslationBase,
) -> Any:
    """
    Thêm hoặc sửa nội dung hiện vật cho 1 ngôn ngữ (upsert). **Admin**.
    """
    if not session.get(Artifact, artifact_id):
        raise HTTPException(status_code=404, detail="Artifact not found")
    if not session.get(Language, language_id):
        raise HTTPException(status_code=404, detail="Language not found")
    translation = session.exec(
        select(ArtifactTranslation).where(
            ArtifactTranslation.artifact_id == artifact_id,
            ArtifactTranslation.language_id == language_id,
        )
    ).first()
    if translation:
        translation.sqlmodel_update(translation_in.model_dump())
        crud.touch_updated_at(translation)
    else:
        translation = ArtifactTranslation.model_validate(
            translation_in,
            update={"artifact_id": artifact_id, "language_id": language_id},
        )
    session.add(translation)
    commit_with_conflicts(session, "uq_artifact_language")
    session.refresh(translation)
    return translation


@router.delete(
    "/{artifact_id}/translations/{language_id}", responses=errors(401, 403, 404)
)
def delete_translation(
    session: SessionDep,
    _admin: AdminUser,
    artifact_id: uuid.UUID,
    language_id: uuid.UUID,
) -> Message:
    """
    Xóa bản dịch của 1 ngôn ngữ. **Admin**.
    """
    translation = session.exec(
        select(ArtifactTranslation).where(
            ArtifactTranslation.artifact_id == artifact_id,
            ArtifactTranslation.language_id == language_id,
        )
    ).first()
    if not translation:
        raise HTTPException(status_code=404, detail="Translation not found")
    session.delete(translation)
    session.commit()
    return Message(message="Translation deleted successfully")

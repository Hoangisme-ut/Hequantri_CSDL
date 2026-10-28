import uuid
from typing import Any

from fastapi import APIRouter, HTTPException
from sqlmodel import col, select

from app.api.deps import AdminUser, SessionDep
from app.models import (
    Artifact,
    Language,
    Media,
    MediaCreate,
    MediaPublic,
    MediaUpdate,
    Message,
    get_datetime_utc,
)

router = APIRouter(prefix="/artifacts/{artifact_id}/media", tags=["media"])


def _check_artifact(session: SessionDep, artifact_id: uuid.UUID) -> None:
    if session.get(Artifact, artifact_id) is None:
        raise HTTPException(status_code=404, detail="Artifact not found")


def _check_language(session: SessionDep, language_id: uuid.UUID | None) -> None:
    if language_id is not None and session.get(Language, language_id) is None:
        raise HTTPException(status_code=404, detail="Language not found")


def _get_media(
    session: SessionDep, artifact_id: uuid.UUID, media_id: uuid.UUID
) -> Media:
    _check_artifact(session, artifact_id)
    media = session.get(Media, media_id)
    if media is None or media.artifact_id != artifact_id:
        raise HTTPException(status_code=404, detail="Media not found")
    return media


@router.get("", response_model=list[MediaPublic])
def read_media_list(
    session: SessionDep, _admin: AdminUser, artifact_id: uuid.UUID
) -> Any:
    """List all media metadata for an artifact. Admin only."""
    _check_artifact(session, artifact_id)
    return session.exec(
        select(Media)
        .where(Media.artifact_id == artifact_id)
        .order_by(col(Media.sort_order), col(Media.id))
    ).all()


@router.get("/{media_id}", response_model=MediaPublic)
def read_media(
    session: SessionDep, _admin: AdminUser, artifact_id: uuid.UUID, media_id: uuid.UUID
) -> Any:
    return _get_media(session, artifact_id, media_id)


@router.post("", response_model=MediaPublic, status_code=201)
def create_media(
    *,
    session: SessionDep,
    _admin: AdminUser,
    artifact_id: uuid.UUID,
    media_in: MediaCreate,
) -> Any:
    """Save an HTTP(S) media URL and metadata; no file upload or download."""
    _check_artifact(session, artifact_id)
    _check_language(session, media_in.language_id)
    media = Media.model_validate(media_in, update={"artifact_id": artifact_id})
    session.add(media)
    session.commit()
    session.refresh(media)
    return media


@router.put("/{media_id}", response_model=MediaPublic)
def update_media(
    *,
    session: SessionDep,
    _admin: AdminUser,
    artifact_id: uuid.UUID,
    media_id: uuid.UUID,
    media_in: MediaUpdate,
) -> Any:
    """Update supplied fields; null clears caption or language_id."""
    media = _get_media(session, artifact_id, media_id)
    data = media_in.model_dump(exclude_unset=True)
    for field in ("media_type", "url", "sort_order"):
        if field in data and data[field] is None:
            raise HTTPException(status_code=422, detail=f"{field} cannot be null")
    if "language_id" in data:
        _check_language(session, data["language_id"])
    media.sqlmodel_update(data)
    media.updated_at = get_datetime_utc()
    session.add(media)
    session.commit()
    session.refresh(media)
    return media


@router.delete("/{media_id}", response_model=Message)
def delete_media(
    session: SessionDep, _admin: AdminUser, artifact_id: uuid.UUID, media_id: uuid.UUID
) -> Message:
    """Delete metadata only; the remote file is not modified."""
    media = _get_media(session, artifact_id, media_id)
    session.delete(media)
    session.commit()
    return Message(message="Media deleted successfully")

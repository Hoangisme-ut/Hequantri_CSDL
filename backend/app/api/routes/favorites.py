import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import col, func, select

from app import crud
from app.api.deps import SessionDep, VisitorUser
from app.models import (
    Artifact,
    Favorite,
    FavoriteCreate,
    FavoritePublic,
    FavoritesPublic,
    Message,
)

router = APIRouter(prefix="/favorites", tags=["favorites"])


def _find_favorite(
    session: SessionDep, user_id: uuid.UUID, artifact_id: uuid.UUID
) -> Favorite | None:
    return session.exec(
        select(Favorite).where(
            Favorite.user_id == user_id, Favorite.artifact_id == artifact_id
        )
    ).first()


@router.get("/", response_model=FavoritesPublic)
def read_favorites(
    session: SessionDep,
    current_user: VisitorUser,
    skip: int = 0,
    limit: int = Query(default=100, le=200),
) -> Any:
    conditions = [
        Favorite.user_id == current_user.id,
        col(Artifact.is_active),
        col(Artifact.site_id).in_(crud.visible_site_ids()),
    ]
    count = session.exec(
        select(func.count())
        .select_from(Favorite)
        .join(Artifact, col(Artifact.id) == col(Favorite.artifact_id))
        .where(*conditions)
    ).one()
    favorites = session.exec(
        select(Favorite)
        .join(Artifact, col(Artifact.id) == col(Favorite.artifact_id))
        .where(*conditions)
        .order_by(col(Favorite.created_at).desc(), col(Favorite.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return FavoritesPublic(
        data=[FavoritePublic.model_validate(f) for f in favorites], count=count
    )


@router.post("/", response_model=FavoritePublic, status_code=status.HTTP_201_CREATED)
def create_favorite(
    *, session: SessionDep, current_user: VisitorUser, favorite_in: FavoriteCreate
) -> Any:
    
    artifact = session.get(Artifact, favorite_in.artifact_id)
    if not artifact or not crud.is_artifact_visible(session=session, artifact=artifact):
        raise HTTPException(status_code=404, detail="Artifact not found")
    if _find_favorite(session, current_user.id, artifact.id):
        raise HTTPException(status_code=409, detail="Artifact already in favorites")
    favorite = Favorite(user_id=current_user.id, artifact_id=artifact.id)
    session.add(favorite)
    try:
        session.commit()
    except IntegrityError:
        # hai request cùng lúc: unique (user_id, artifact_id) chặn bản thứ hai
        session.rollback()
        raise HTTPException(status_code=409, detail="Artifact already in favorites")
    session.refresh(favorite)
    return favorite


@router.delete("/{artifact_id}")
def delete_favorite(
    session: SessionDep, current_user: VisitorUser, artifact_id: uuid.UUID
) -> Message:
    
    favorite = _find_favorite(session, current_user.id, artifact_id)
    if not favorite:
        raise HTTPException(status_code=404, detail="Favorite not found")
    session.delete(favorite)
    session.commit()
    return Message(message="Favorite removed successfully")
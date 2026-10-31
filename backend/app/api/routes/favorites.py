import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import ColumnElement, true
from sqlalchemy.exc import IntegrityError
from sqlmodel import col, func, select

from app import crud
from app.api.deps import SessionDep, VisitorUser
from app.models import (
    Artifact,
    Favorite,
    FavoriteCreate,
    FavoriteDetailPublic,
    FavoritePublic,
    FavoritesDetailPublic,
    Message,
    Site,
)

router = APIRouter(prefix="/favorites", tags=["favorites"])

_ERRORS: dict[int | str, dict[str, Any]] = {
    401: {"description": "Thiếu hoặc sai token đăng nhập"},
    403: {"description": "Không đủ quyền"},
}


def _get_own_favorite(
    session: SessionDep, user_id: uuid.UUID, artifact_id: uuid.UUID
) -> Favorite | None:
    return session.exec(
        select(Favorite).where(
            col(Favorite.user_id) == user_id,
            col(Favorite.artifact_id) == artifact_id,
        )
    ).first()


@router.get("/me", response_model=FavoritesDetailPublic, responses=_ERRORS)
def read_my_favorites(
    session: SessionDep,
    current_user: VisitorUser,
    lang: str | None = Query(default=None, description="Mã ngôn ngữ: vi, en..."),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Danh sách hiện vật yêu thích **của tôi** (mới nhất trước, có phân trang).
    **Visitor / Admin** (cần đăng nhập).

    Hiện vật đang bị ẩn (hoặc thuộc Site bị ẩn) không hiện trong danh sách;
    bản ghi yêu thích vẫn được giữ và hiện lại khi hiện vật được bật lại.
    """
    conditions: list[ColumnElement[bool]] = [
        col(Favorite.user_id) == current_user.id,
        col(Artifact.is_active) == true(),
        col(Site.is_active) == true(),
    ]
    joined = (
        select(Favorite)
        .join(Artifact, col(Artifact.id) == col(Favorite.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    )
    count = session.exec(
        select(func.count())
        .select_from(Favorite)
        .join(Artifact, col(Artifact.id) == col(Favorite.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    ).one()
    favorites = session.exec(
        joined.order_by(col(Favorite.created_at).desc(), col(Favorite.id))
        .offset(skip)
        .limit(limit)
    ).all()

    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    items = []
    for favorite in favorites:
        artifact = session.get(Artifact, favorite.artifact_id)
        if artifact is None:  # không xảy ra: đã join ở trên
            continue
        summary = crud.build_artifact_summary(
            session=session, artifact=artifact, language=language
        )
        items.append(
            FavoriteDetailPublic.model_validate(favorite, update={"artifact": summary})
        )
    return FavoritesDetailPublic(data=items, count=count)


@router.post(
    "/",
    response_model=FavoritePublic,
    status_code=status.HTTP_201_CREATED,
    responses={
        **_ERRORS,
        200: {"description": "Đã yêu thích từ trước (không tạo bản ghi mới)"},
        404: {"description": "Hiện vật không tồn tại hoặc đang bị ẩn"},
    },
)
def add_favorite(
    *,
    session: SessionDep,
    current_user: VisitorUser,
    favorite_in: FavoriteCreate,
    response: Response,
) -> Any:
    """
    Thêm hiện vật vào yêu thích. **Visitor / Admin** (cần đăng nhập).

    - Tạo mới: **201**.
    - Đã yêu thích rồi: **200**, trả lại bản ghi cũ, **không tạo trùng**.
    """
    artifact = crud.get_visible_artifact(
        session=session, artifact_id=favorite_in.artifact_id
    )
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    existing = _get_own_favorite(session, current_user.id, artifact.id)
    if existing:
        response.status_code = status.HTTP_200_OK
        return existing

    favorite = Favorite(user_id=current_user.id, artifact_id=artifact.id)
    session.add(favorite)
    try:
        session.commit()
    except IntegrityError:
        # 2 request cùng lúc: ràng buộc unique (user_id, artifact_id) chặn bản ghi trùng
        session.rollback()
        existing = _get_own_favorite(session, current_user.id, artifact.id)
        if existing is None:
            raise
        response.status_code = status.HTTP_200_OK
        return existing
    session.refresh(favorite)
    return favorite


@router.delete(
    "/{artifact_id}",
    responses={**_ERRORS, 404: {"description": "Hiện vật chưa nằm trong yêu thích"}},
)
def remove_favorite(
    session: SessionDep, current_user: VisitorUser, artifact_id: uuid.UUID
) -> Message:
    """
    Bỏ hiện vật khỏi yêu thích **của tôi**. **Visitor / Admin** (cần đăng nhập).
    Chỉ xóa được bản ghi của chính mình.
    """
    favorite = _get_own_favorite(session, current_user.id, artifact_id)
    if not favorite:
        raise HTTPException(status_code=404, detail="Favorite not found")
    session.delete(favorite)
    session.commit()
    return Message(message="Favorite removed successfully")

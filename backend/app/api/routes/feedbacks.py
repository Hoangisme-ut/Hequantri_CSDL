import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import ColumnElement, exists, or_, true
from sqlalchemy.exc import IntegrityError
from sqlmodel import col, func, select

from app import crud
from app.api.deps import AdminUser, SessionDep, VisitorUser
from app.api.docs import errors
from app.models import (
    Artifact,
    ArtifactReviewPublic,
    ArtifactReviewsPublic,
    ArtifactTranslation,
    Feedback,
    FeedbackCreate,
    FeedbackPublic,
    FeedbackReviewPublic,
    FeedbackReviewsPublic,
    FeedbacksPublic,
    FeedbackStatus,
    FeedbackStatusUpdate,
    FeedbackUpdate,
    Language,
    Site,
    User,
    get_datetime_utc,
)

router = APIRouter(prefix="/feedbacks", tags=["feedbacks"])


def _get_own_feedback(
    session: SessionDep, user_id: uuid.UUID, feedback_id: uuid.UUID
) -> Feedback:
    """Lấy feedback của CHÍNH người gọi. Của người khác -> 404 (không lộ là có tồn tại)."""
    feedback = session.exec(
        select(Feedback).where(
            col(Feedback.id) == feedback_id, col(Feedback.user_id) == user_id
        )
    ).first()
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    return feedback


# ------------------------------- Công khai (khách) ------------------------------
@router.get(
    "/artifact/{artifact_id}",
    response_model=ArtifactReviewsPublic,
    responses=errors(404, 422),
)
def read_artifact_reviews(
    session: SessionDep,
    artifact_id: uuid.UUID,
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Bình luận công khai của một hiện vật. **Public** (không cần token).

    - Chỉ trả feedback **đã duyệt** (`approved`) và **có comment**; nội dung
      `pending` / `hidden` không bao giờ xuất hiện ở đây.
    - Không trả `user_id` và `status`. Mới nhất trước, có phân trang.
    - Hiện vật đang bị ẩn (hoặc thuộc Site bị ẩn) -> 404.
    """
    artifact = crud.get_visible_artifact(session=session, artifact_id=artifact_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    conditions: list[ColumnElement[bool]] = [
        col(Feedback.artifact_id) == artifact.id,
        col(Feedback.status) == FeedbackStatus.APPROVED.value,
        col(Feedback.comment).is_not(None),
    ]
    count = session.exec(
        select(func.count()).select_from(Feedback).where(*conditions)
    ).one()
    reviews = session.exec(
        select(Feedback)
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc(), col(Feedback.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return ArtifactReviewsPublic(
        data=[ArtifactReviewPublic.model_validate(r) for r in reviews], count=count
    )


# --------------------------- Visitor (chỉ dữ liệu của mình) ---------------------
@router.get("/me", response_model=FeedbacksPublic, responses=errors(401, 403))
def read_my_feedbacks(
    session: SessionDep,
    current_user: VisitorUser,
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Đánh giá / phản hồi **của tôi** (mới nhất trước, có phân trang).
    **Visitor / Admin** (cần đăng nhập). Chỉ trả dữ liệu của chính người gọi, kèm
    `status` (pending / approved / hidden) để người dùng biết bình luận đã được duyệt chưa.

    Hiện vật đang bị ẩn (hoặc thuộc Site bị ẩn) không hiện trong danh sách.
    """
    conditions: list[ColumnElement[bool]] = [
        col(Feedback.user_id) == current_user.id,
        col(Artifact.is_active) == true(),
        col(Site.is_active) == true(),
    ]
    count = session.exec(
        select(func.count())
        .select_from(Feedback)
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    ).one()
    feedbacks = session.exec(
        select(Feedback)
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc(), col(Feedback.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return FeedbacksPublic(
        data=[FeedbackPublic.model_validate(f) for f in feedbacks], count=count
    )


@router.post(
    "/",
    response_model=FeedbackPublic,
    status_code=status.HTTP_201_CREATED,
    responses=errors(401, 403, 404, 409, 422),
)
def create_feedback(
    *,
    session: SessionDep,
    current_user: VisitorUser,
    feedback_in: FeedbackCreate,
) -> Any:
    """
    Gửi đánh giá (1-5 sao, kèm comment tùy chọn) cho một hiện vật.
    **Visitor / Admin** (cần đăng nhập).

    - Trạng thái do **server** quyết định (client gửi `status` sẽ bị bỏ qua):
      không có comment -> `approved`; có comment -> `pending` (chờ admin duyệt).
    - Mỗi người chỉ có **1** đánh giá cho mỗi hiện vật; gửi lần hai -> **409**
      (dùng `PUT /feedbacks/{id}` để sửa).
    - Hiện vật không tồn tại / đang ẩn / thuộc Site ẩn -> **404**.
    - `rating` ngoài 1-5, `comment` quá 2000 ký tự -> **422**.
    """
    artifact = crud.get_visible_artifact(
        session=session, artifact_id=feedback_in.artifact_id
    )
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    already = session.exec(
        select(Feedback).where(
            col(Feedback.user_id) == current_user.id,
            col(Feedback.artifact_id) == artifact.id,
        )
    ).first()
    if already:
        raise HTTPException(
            status_code=409,
            detail="Bạn đã đánh giá hiện vật này; dùng PUT /feedbacks/{id} để sửa",
        )

    feedback = Feedback(
        user_id=current_user.id,
        artifact_id=artifact.id,
        rating=feedback_in.rating,
        comment=feedback_in.comment,
        status=crud.initial_feedback_status(feedback_in.comment).value,
    )
    session.add(feedback)
    try:
        session.commit()
    except IntegrityError:
        # 2 request cùng lúc: ràng buộc unique (user_id, artifact_id) chặn bản thứ hai
        session.rollback()
        raise HTTPException(
            status_code=409, detail="Bạn đã đánh giá hiện vật này"
        ) from None
    session.refresh(feedback)
    return feedback


@router.put(
    "/{feedback_id}",
    response_model=FeedbackPublic,
    responses=errors(401, 403, 404, 422),
)
def update_my_feedback(
    *,
    session: SessionDep,
    current_user: VisitorUser,
    feedback_id: uuid.UUID,
    feedback_in: FeedbackUpdate,
) -> Any:
    """
    Sửa đánh giá **của tôi** (`rating` và/hoặc `comment`). **Visitor / Admin**.

    - Chỉ sửa được bản ghi của chính mình; của người khác -> **404**.
    - Đổi comment: `approved` -> `pending` (phải duyệt lại); `hidden` giữ nguyên `hidden`;
      xóa comment (null / rỗng) thì không còn gì để duyệt -> `approved`
      (trừ `hidden`). Chỉ đổi `rating` thì giữ nguyên trạng thái.
    - Hiện vật đang ẩn (hoặc thuộc Site ẩn) -> **404**.
    """
    feedback = _get_own_feedback(session, current_user.id, feedback_id)
    if not crud.get_visible_artifact(session=session, artifact_id=feedback.artifact_id):
        raise HTTPException(status_code=404, detail="Artifact not found")

    fields = feedback_in.model_fields_set
    new_comment = feedback_in.comment if "comment" in fields else feedback.comment
    feedback.status = crud.status_after_feedback_edit(
        current_status=feedback.status,
        old_comment=feedback.comment,
        new_comment=new_comment,
    )
    feedback.comment = new_comment
    if "rating" in fields and feedback_in.rating is not None:
        feedback.rating = feedback_in.rating
    feedback.updated_at = get_datetime_utc()
    session.add(feedback)
    session.commit()
    session.refresh(feedback)
    return feedback


# ---------------------------------- Admin ---------------------------------------
@router.get("/", response_model=FeedbackReviewsPublic, responses=errors(401, 403, 422))
def read_feedbacks(
    session: SessionDep,
    _admin: AdminUser,
    status_filter: FeedbackStatus | None = Query(
        default=None, alias="status", description="pending | approved | hidden"
    ),
    artifact_id: uuid.UUID | None = None,
    q: str | None = Query(
        default=None,
        description="Tìm theo tên/email người gửi, mã hiện vật, tên Site hoặc nội dung comment",
    ),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Danh sách feedback để kiểm duyệt, kèm thông tin người gửi và hiện vật. **Chỉ Admin**.
    Lọc theo `status` (ví dụ `pending` = đang chờ duyệt), `artifact_id` và từ khóa `q`;
    mới nhất trước.
    """
    conditions: list[ColumnElement[bool]] = []
    if status_filter is not None:
        conditions.append(col(Feedback.status) == status_filter.value)
    if artifact_id is not None:
        conditions.append(col(Feedback.artifact_id) == artifact_id)
    keyword = q.strip() if q else ""
    if keyword:
        conditions.append(
            or_(
                col(User.full_name).contains(keyword),
                col(User.email).contains(keyword),
                col(Artifact.code).contains(keyword),
                col(Feedback.comment).contains(keyword),
                col(Site.name).contains(keyword),
                exists(
                    select(1)
                    .select_from(ArtifactTranslation)
                    .where(
                        col(ArtifactTranslation.artifact_id) == col(Artifact.id),
                        col(ArtifactTranslation.title).contains(keyword),
                    )
                ),
            )
        )

    count = session.exec(
        select(func.count())
        .select_from(Feedback)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    ).one()
    rows = session.exec(
        select(Feedback, User, Artifact, Site)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc(), col(Feedback.id))
        .offset(skip)
        .limit(limit)
    ).all()

    results: list[FeedbackReviewPublic] = []
    for feedback, user, artifact, site in rows:
        # tiêu đề hiện vật theo ngôn ngữ mặc định (không có thì để trống)
        title = session.exec(
            select(ArtifactTranslation.title)
            .join(Language, col(Language.id) == col(ArtifactTranslation.language_id))
            .where(
                col(ArtifactTranslation.artifact_id) == artifact.id,
                col(Language.is_default) == true(),
            )
        ).first()
        results.append(
            FeedbackReviewPublic(
                **FeedbackPublic.model_validate(feedback).model_dump(),
                visitor_name=user.full_name,
                visitor_email=user.email,
                artifact_code=artifact.code,
                artifact_title=title,
                site_name=site.name,
            )
        )
    return FeedbackReviewsPublic(data=results, count=count)


@router.patch(
    "/{feedback_id}/status",
    response_model=FeedbackPublic,
    responses=errors(401, 403, 404, 422),
)
def moderate_feedback(
    *,
    session: SessionDep,
    _admin: AdminUser,
    feedback_id: uuid.UUID,
    status_in: FeedbackStatusUpdate,
) -> Any:
    """
    Duyệt hoặc từ chối feedback. **Chỉ Admin**.

    - `approved`: duyệt, comment hiện công khai.
    - `hidden`: từ chối/ẩn, comment không hiện công khai và không tính vào rating.
    - Giá trị khác (kể cả `pending`) -> **422**.
    """
    feedback = session.get(Feedback, feedback_id)
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")
    feedback.status = status_in.status
    feedback.updated_at = get_datetime_utc()
    session.add(feedback)
    session.commit()
    session.refresh(feedback)
    return feedback

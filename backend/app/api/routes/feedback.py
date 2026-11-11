import uuid
from enum import StrEnum
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import exists, or_
from sqlalchemy.exc import IntegrityError
from sqlmodel import SQLModel, col, func, select

from app import crud
from app.api.deps import AdminUser, SessionDep, VisitorUser, is_admin
from app.api.docs import errors
from app.models import (
    Artifact,
    ArtifactTranslation,
    Feedback,
    FeedbackCreate,
    FeedbackPublic,
    FeedbackReviewPublic,
    FeedbackReviewsPublic,
    FeedbacksPublic,
    FeedbackStatus,
    Language,
    Site,
    User,
    get_datetime_utc,
)

# DEPRECATED: hợp đồng cũ của Web Admin. Đường dẫn CHÍNH là `/feedbacks`
# (app/api/routes/feedbacks.py, đúng ERD: pending / approved / hidden).
# Giữ lại để Web Admin hiện tại không bị hỏng; xóa khi Web Admin đã chuyển sang
# `/feedbacks`. Khác biệt so với `/feedbacks`: luôn tạo `pending` (không tự
# `approved` khi không có comment), dùng `rejected` thay cho `hidden`, không có
# sửa feedback của mình và không có feed công khai theo hiện vật.
router = APIRouter(prefix="/feedback", tags=["feedback"], deprecated=True)


# ---------------------------------------------------------------------------
# Web Admin cũ dùng trạng thái "rejected"; ERD mới lưu trạng thái này là
# "hidden". Hai lớp enum/schema dưới đây giữ nguyên hợp đồng API cũ, còn phần
# ánh xạ sang DB nằm trong các helper.
# ---------------------------------------------------------------------------
class LegacyFeedbackStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class LegacyFeedbackStatusUpdate(SQLModel):
    status: LegacyFeedbackStatus


_LEGACY_TO_DB = {LegacyFeedbackStatus.REJECTED.value: FeedbackStatus.HIDDEN.value}
_DB_TO_LEGACY = {FeedbackStatus.HIDDEN.value: LegacyFeedbackStatus.REJECTED.value}


def _to_db_status(status: LegacyFeedbackStatus) -> str:
    return _LEGACY_TO_DB.get(status.value, status.value)


def _to_legacy_status(status: str) -> str:
    return _DB_TO_LEGACY.get(status, status)


def _feedback_public(row: Feedback) -> FeedbackPublic:
    """Serialize without mutating the ORM row (hidden <-> rejected is API-only)."""
    return FeedbackPublic.model_validate(row).model_copy(
        update={"status": _to_legacy_status(row.status)}
    )


# --------------------------------- Visitor ---------------------------------


@router.post(
    "/",
    response_model=FeedbackPublic,
    status_code=201,
    responses=errors(401, 403, 404, 409),
)
def submit_feedback(
    session: SessionDep, current_user: VisitorUser, body: FeedbackCreate
) -> Any:
    """Submit a feedback for a visible artifact. Visitor / Authenticated user."""
    if not crud.get_visible_artifact(session=session, artifact_id=body.artifact_id):
        raise HTTPException(status_code=404, detail="Artifact not found")
    existing = session.exec(
        select(Feedback).where(
            col(Feedback.user_id) == current_user.id,
            col(Feedback.artifact_id) == body.artifact_id,
        )
    ).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Feedback already exists")
    feedback = Feedback.model_validate(
        body, update={"user_id": current_user.id, "status": FeedbackStatus.PENDING}
    )
    session.add(feedback)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(status_code=409, detail="Feedback already exists") from None
    session.refresh(feedback)
    return _feedback_public(feedback)


@router.get("/me", response_model=FeedbacksPublic, responses=errors(401, 403))
def my_feedback(
    session: SessionDep,
    current_user: VisitorUser,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
) -> FeedbacksPublic:
    """Retrieve own feedback submissions. Visitor."""
    conditions = [col(Feedback.user_id) == current_user.id]
    count = session.exec(
        select(func.count()).select_from(Feedback).where(*conditions)
    ).one()
    rows = session.exec(
        select(Feedback)
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc(), col(Feedback.id))
        .offset(skip)
        .limit(limit)
    ).all()
    return FeedbacksPublic(data=[_feedback_public(row) for row in rows], count=count)


@router.get(
    "/{feedback_id}", response_model=FeedbackPublic, responses=errors(401, 403, 404)
)
def read_feedback(
    session: SessionDep, current_user: VisitorUser, feedback_id: uuid.UUID
) -> Any:
    """Retrieve a specific feedback record. Owner or Admin only."""
    row = session.get(Feedback, feedback_id)
    if row is None or (row.user_id != current_user.id and not is_admin(current_user)):
        raise HTTPException(status_code=404, detail="Feedback not found")
    return _feedback_public(row)


# ---------------------------------- Admin ----------------------------------


@router.get(
    "/",
    response_model=FeedbackReviewsPublic,
    responses=errors(401, 403),
)
def read_feedbacks(
    session: SessionDep,
    _admin: AdminUser,
    status: LegacyFeedbackStatus | None = Query(
        default=None,
        description="Filter by status: pending, approved, or rejected",
    ),
    artifact_id: uuid.UUID | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    q: str | None = Query(
        default=None,
        description="Search by visitor name, email, artifact code, or feedback comment",
    ),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """Retrieve feedback records with visitor and artifact information. Admin only."""
    conditions: list[Any] = []

    if status is not None:
        conditions.append(col(Feedback.status) == _to_db_status(status))

    if artifact_id is not None:
        conditions.append(col(Feedback.artifact_id) == artifact_id)

    if user_id is not None:
        conditions.append(col(Feedback.user_id) == user_id)

    if q:
        keyword = q.strip()
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
                            ArtifactTranslation.artifact_id == Artifact.id,
                            col(ArtifactTranslation.title).contains(keyword),
                        )
                    ),
                )
            )

    count_stmt = (
        select(func.count())
        .select_from(Feedback)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    )
    count = session.exec(count_stmt).one()

    stmt = (
        select(Feedback, User, Artifact, Site)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc(), col(Feedback.id))
        .offset(skip)
        .limit(limit)
    )
    rows = session.exec(stmt).all()

    results: list[FeedbackReviewPublic] = []
    for feedback, user, artifact, site in rows:
        title = session.exec(
            select(ArtifactTranslation.title)
            .join(
                Language,
                col(Language.id) == col(ArtifactTranslation.language_id),
            )
            .where(
                ArtifactTranslation.artifact_id == artifact.id,
                Language.is_default == True,  # noqa: E712
            )
        ).first()

        results.append(
            FeedbackReviewPublic(
                **_feedback_public(feedback).model_dump(),
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
    session: SessionDep,
    _admin: AdminUser,
    feedback_id: uuid.UUID,
    body: LegacyFeedbackStatusUpdate,
) -> Any:
    """Approve, reject, or reset a feedback record. Admin only."""
    row = session.get(Feedback, feedback_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Feedback not found")

    row.status = _to_db_status(body.status)
    row.updated_at = get_datetime_utc()
    session.add(row)
    session.commit()
    session.refresh(row)
    return _feedback_public(row)

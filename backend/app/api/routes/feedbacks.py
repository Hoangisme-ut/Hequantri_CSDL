import uuid
from enum import StrEnum

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import ColumnElement, exists, or_, true
from sqlalchemy.exc import IntegrityError
from sqlmodel import SQLModel, col, func, select
from sqlmodel._compat import SQLModelConfig

from app import crud
from app.api.deps import AdminUser, SessionDep, VisitorUser, is_admin
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
    FeedbackUpdate,
    Language,
    Site,
    User,
    get_datetime_utc,
)

router = APIRouter(prefix="/feedbacks", tags=["feedbacks"])


class FeedbackAdminStatus(StrEnum):
    """Statuses supported when filtering the admin feedback list."""

    PENDING = "pending"
    APPROVED = "approved"
    HIDDEN = "hidden"
    REJECTED = "rejected"


class FeedbackModerationStatus(StrEnum):
    """Statuses an admin can assign during moderation."""

    PENDING = "pending"
    APPROVED = "approved"
    HIDDEN = "hidden"
    REJECTED = "rejected"


class FeedbackAdminStatusUpdate(SQLModel):
    model_config = SQLModelConfig(
        json_schema_extra={
            "examples": [
                {"status": "approved"},
                {"status": "hidden"},
                {"status": "pending"},
                {"status": "rejected"},
            ]
        }
    )
    status: FeedbackModerationStatus


def _serialize_feedback(feedback: Feedback) -> FeedbackPublic:
    """Return the canonical API representation without mutating the ORM row."""
    return FeedbackPublic.model_validate(feedback)


# ---------------------------------------------------------------------------
# Shared visitor helpers
# ---------------------------------------------------------------------------


def _get_own_feedback(
    session: SessionDep,
    user_id: uuid.UUID,
    feedback_id: uuid.UUID,
) -> Feedback:
    """Get a feedback record belonging to the current user only."""
    feedback = session.exec(
        select(Feedback).where(
            col(Feedback.id) == feedback_id,
            col(Feedback.user_id) == user_id,
        )
    ).first()

    if feedback is None:
        raise HTTPException(status_code=404, detail="Feedback not found")

    return feedback


# ---------------------------------------------------------------------------
# Public: reviews belonging to an artifact
# ---------------------------------------------------------------------------


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
) -> ArtifactReviewsPublic:
    """
    Public reviews for a visible artifact.

    Only approved feedback with a non-empty comment is exposed.
    The response does not expose user_id or moderation status.
    """
    artifact = crud.get_visible_artifact(
        session=session,
        artifact_id=artifact_id,
    )
    if artifact is None:
        raise HTTPException(status_code=404, detail="Artifact not found")

    conditions: list[ColumnElement[bool]] = [
        col(Feedback.artifact_id) == artifact.id,
        col(Feedback.status) == FeedbackStatus.APPROVED.value,
        col(Feedback.comment).is_not(None),
    ]

    count = session.exec(
        select(func.count()).select_from(Feedback).where(*conditions)
    ).one()

    rows = session.exec(
        select(Feedback)
        .where(*conditions)
        .order_by(
            col(Feedback.created_at).desc(),
            col(Feedback.id),
        )
        .offset(skip)
        .limit(limit)
    ).all()

    return ArtifactReviewsPublic(
        data=[ArtifactReviewPublic.model_validate(row) for row in rows],
        count=count,
    )


# ---------------------------------------------------------------------------
# Visitor: own feedback
# ---------------------------------------------------------------------------


@router.get(
    "/me",
    response_model=FeedbacksPublic,
    responses=errors(401, 403),
)
def read_my_feedbacks(
    session: SessionDep,
    current_user: VisitorUser,
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    include_inactive: bool = Query(
        default=False,
        description=(
            "Set true to include feedback whose artifact or site is inactive."
        ),
    ),
) -> FeedbacksPublic:
    """
    Retrieve the current user's feedback.

    By default, only feedback belonging to active artifacts and sites is shown.
    Set include_inactive=true to include all of the user's historical feedback.
    """
    conditions: list[ColumnElement[bool]] = [
        col(Feedback.user_id) == current_user.id,
    ]

    statement = (
        select(Feedback)
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
    )

    count_statement = (
        select(func.count())
        .select_from(Feedback)
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
    )

    if not include_inactive:
        conditions.extend(
            [
                col(Artifact.is_active) == true(),
                col(Site.is_active) == true(),
            ]
        )

    count = session.exec(count_statement.where(*conditions)).one()

    rows = session.exec(
        statement.where(*conditions)
        .order_by(
            col(Feedback.created_at).desc(),
            col(Feedback.id),
        )
        .offset(skip)
        .limit(limit)
    ).all()

    return FeedbacksPublic(
        data=[_serialize_feedback(row) for row in rows],
        count=count,
    )


# ---------------------------------------------------------------------------
# Visitor: create feedback
# ---------------------------------------------------------------------------


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
) -> FeedbackPublic:
    """
    Submit one feedback for a visible artifact.

    Initial status is decided by the server:
    - No comment: approved.
    - Has comment: pending.

    A user can submit only one feedback per artifact.
    Use PUT /feedbacks/{feedback_id} to edit an existing feedback.
    """
    artifact = crud.get_visible_artifact(
        session=session,
        artifact_id=feedback_in.artifact_id,
    )
    if artifact is None:
        raise HTTPException(status_code=404, detail="Artifact not found")

    existing = session.exec(
        select(Feedback).where(
            col(Feedback.user_id) == current_user.id,
            col(Feedback.artifact_id) == artifact.id,
        )
    ).first()

    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail=("Bạn đã đánh giá hiện vật này; dùng PUT /feedbacks/{id} để sửa"),
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
        # The unique constraint on (user_id, artifact_id) also protects
        # against two simultaneous requests from the same user.
        session.rollback()
        raise HTTPException(
            status_code=409,
            detail="Bạn đã đánh giá hiện vật này",
        ) from None

    session.refresh(feedback)
    return _serialize_feedback(feedback)


# ---------------------------------------------------------------------------
# Visitor: update own feedback
# ---------------------------------------------------------------------------


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
) -> FeedbackPublic:
    """
    Update the current user's rating and/or comment.

    Status transitions:
    - Editing an approved comment sends it back to pending.
    - Editing a hidden feedback keeps it hidden.
    - Clearing a comment changes status to approved, except hidden stays hidden.
    - Changing only the rating keeps the current status.
    """
    feedback = _get_own_feedback(
        session=session,
        user_id=current_user.id,
        feedback_id=feedback_id,
    )

    artifact = crud.get_visible_artifact(
        session=session,
        artifact_id=feedback.artifact_id,
    )
    if artifact is None:
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

    return _serialize_feedback(feedback)


# ---------------------------------------------------------------------------
# Visitor: read one feedback
# ---------------------------------------------------------------------------


@router.get(
    "/{feedback_id}",
    response_model=FeedbackPublic,
    responses=errors(401, 403, 404),
)
def read_feedback(
    session: SessionDep,
    current_user: VisitorUser,
    feedback_id: uuid.UUID,
) -> FeedbackPublic:
    """
    Retrieve one feedback record.

    Only the owner or an Admin can read the record.
    Other users receive 404 to avoid revealing whether it exists.
    """
    feedback = session.get(Feedback, feedback_id)

    if feedback is None:
        raise HTTPException(
            status_code=404,
            detail="Feedback not found",
        )

    if feedback.user_id != current_user.id and not is_admin(current_user):
        raise HTTPException(
            status_code=404,
            detail="Feedback not found",
        )

    return _serialize_feedback(feedback)


# ---------------------------------------------------------------------------
# Admin: list and search feedback
# ---------------------------------------------------------------------------


@router.get(
    "/",
    response_model=FeedbackReviewsPublic,
    responses=errors(401, 403, 422),
)
def read_feedbacks(
    session: SessionDep,
    _admin: AdminUser,
    status_filter: FeedbackAdminStatus | None = Query(
        default=None,
        alias="status",
        description=(
            "Filter by status: pending, approved, hidden, or rejected "
            "(rejected is mapped to hidden)."
        ),
    ),
    artifact_id: uuid.UUID | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    q: str | None = Query(
        default=None,
        description="Search by visitor, artifact, site, or feedback comment.",
    ),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> FeedbackReviewsPublic:
    """
    Admin feedback list with filters, search, pagination and related details.

    Supports all filters from both previous routers:
    status, artifact_id, user_id and q.
    """
    conditions: list[ColumnElement[bool]] = []

    if status_filter is not None:
        normalized_status = (
            FeedbackStatus.HIDDEN.value
            if status_filter == FeedbackAdminStatus.REJECTED
            else status_filter.value
        )
        conditions.append(col(Feedback.status) == normalized_status)

    if artifact_id is not None:
        conditions.append(col(Feedback.artifact_id) == artifact_id)

    if user_id is not None:
        conditions.append(col(Feedback.user_id) == user_id)

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
        .join(
            User,
            col(User.id) == col(Feedback.user_id),
        )
        .join(
            Artifact,
            col(Artifact.id) == col(Feedback.artifact_id),
        )
        .join(
            Site,
            col(Site.id) == col(Artifact.site_id),
        )
        .where(*conditions)
    ).one()

    rows = session.exec(
        select(Feedback, User, Artifact, Site)
        .join(
            User,
            col(User.id) == col(Feedback.user_id),
        )
        .join(
            Artifact,
            col(Artifact.id) == col(Feedback.artifact_id),
        )
        .join(
            Site,
            col(Site.id) == col(Artifact.site_id),
        )
        .where(*conditions)
        .order_by(
            col(Feedback.created_at).desc(),
            col(Feedback.id),
        )
        .offset(skip)
        .limit(limit)
    ).all()

    results: list[FeedbackReviewPublic] = []

    for feedback, user, artifact, site in rows:
        title = session.exec(
            select(ArtifactTranslation.title)
            .join(
                Language,
                col(Language.id) == col(ArtifactTranslation.language_id),
            )
            .where(
                col(ArtifactTranslation.artifact_id) == artifact.id,
                col(Language.is_default) == true(),
            )
        ).first()

        results.append(
            FeedbackReviewPublic(
                **_serialize_feedback(feedback).model_dump(),
                visitor_name=user.full_name,
                visitor_email=user.email,
                artifact_code=artifact.code,
                artifact_title=title,
                site_name=site.name,
            )
        )

    return FeedbackReviewsPublic(
        data=results,
        count=count,
    )


# ---------------------------------------------------------------------------
# Admin: moderate feedback
# ---------------------------------------------------------------------------


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
    status_in: FeedbackAdminStatusUpdate,
) -> FeedbackPublic:
    """
    Admin can set feedback status to pending, approved, or hidden.
    The legacy status "rejected" is accepted and mapped to "hidden".
    """
    feedback = session.get(Feedback, feedback_id)

    if feedback is None:
        raise HTTPException(
            status_code=404,
            detail="Feedback not found",
        )
    if status_in.status == FeedbackModerationStatus.REJECTED:
        feedback.status = FeedbackStatus.HIDDEN.value
    else:
        feedback.status = status_in.status.value

    feedback.updated_at = get_datetime_utc()

    session.add(feedback)
    session.commit()
    session.refresh(feedback)

    return _serialize_feedback(feedback)

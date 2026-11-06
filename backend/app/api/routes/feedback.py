import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import exists, or_
from sqlmodel import col, func, select

from app.api.deps import AdminUser, SessionDep
from app.api.docs import errors
from app.models import (
    Artifact,
    ArtifactTranslation,
    Feedback,
    FeedbackReviewPublic,
    FeedbackReviewsPublic,
    FeedbackStatus,
    FeedbackStatusUpdate,
    FeedbackPublic,
    Language,
    Site,
    User,
)

router = APIRouter(prefix="/feedback", tags=["feedback"])


# ---------------------------------- Admin ----------------------------------

@router.get(
    "/",
    response_model=FeedbackReviewsPublic,
    responses=errors(401, 403),
)
def read_feedbacks(
    session: SessionDep,
    _admin: AdminUser,
    status: FeedbackStatus | None = Query(
        default=None,
        description="Filter by status: pending, approved, or rejected",
    ),
    q: str | None = Query(
        default=None,
        description="Search by visitor name, email, artifact code, or feedback comment",
    ),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Retrieve feedback records with visitor and artifact information. **Admin**.
    """

    conditions = []

    if status is not None:
        conditions.append(Feedback.status == status.value)

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

    # Count the total number of feedback records matching the filters.
    count_stmt = (
        select(func.count())
        .select_from(Feedback)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    )

    count = session.exec(count_stmt).one()

    # Retrieve feedback records and their related information.
    stmt = (
        select(Feedback, User, Artifact, Site)
        .join(User, col(User.id) == col(Feedback.user_id))
        .join(Artifact, col(Artifact.id) == col(Feedback.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(Feedback.created_at).desc())
        .offset(skip)
        .limit(limit)
    )

    rows = session.exec(stmt).all()

    results = []

    for feedback, user, artifact, site in rows:
        # Retrieve the artifact title in the default language.
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
def update_feedback_status(
    session: SessionDep,
    _admin: AdminUser,
    feedback_id: uuid.UUID,
    feedback_in: FeedbackStatusUpdate,
) -> Any:
    """
    Approve or reject a feedback record. **Admin**.
    """

    feedback = session.get(Feedback, feedback_id)

    if not feedback:
        raise HTTPException(
            status_code=404,
            detail="Feedback not found",
        )

    new_status = feedback_in.status.strip().lower()

    allowed_statuses = {
        FeedbackStatus.APPROVED.value,
        FeedbackStatus.REJECTED.value,
    }

    if new_status not in allowed_statuses:
        raise HTTPException(
            status_code=422,
            detail="Status must be 'approved' or 'rejected'",
        )

    feedback.status = new_status

    session.add(feedback)
    session.commit()
    session.refresh(feedback)

    return feedback

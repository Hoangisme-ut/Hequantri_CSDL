import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from sqlmodel import col, func, select

from app import crud
from app.api.deps import AdminUser, SessionDep, VisitorUser, is_admin
from app.api.docs import errors
from app.models import (
    Feedback,
    FeedbackCreate,
    FeedbackPublic,
    FeedbacksPublic,
    FeedbackStatus,
    FeedbackStatusUpdate,
)

router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.post(
    "/", response_model=FeedbackPublic, status_code=201, responses=errors(401, 403, 404)
)
def submit_feedback(
    session: SessionDep, current_user: VisitorUser, body: FeedbackCreate
) -> Any:
    if not crud.get_visible_artifact(session=session, artifact_id=body.artifact_id):
        raise HTTPException(status_code=404, detail="Artifact not found")
    feedback = Feedback.model_validate(
        body, update={"user_id": current_user.id, "status": FeedbackStatus.PENDING}
    )
    session.add(feedback)
    session.commit()
    session.refresh(feedback)
    return feedback


def _list(
    session: SessionDep, conditions: list[Any], skip: int, limit: int
) -> FeedbacksPublic:
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
    return FeedbacksPublic(
        data=[FeedbackPublic.model_validate(row) for row in rows], count=count
    )


@router.get("/me", response_model=FeedbacksPublic, responses=errors(401, 403))
def my_feedback(
    session: SessionDep,
    current_user: VisitorUser,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
) -> FeedbacksPublic:
    return _list(session, [col(Feedback.user_id) == current_user.id], skip, limit)


@router.get("/", response_model=FeedbacksPublic, responses=errors(401, 403))
def list_feedback(
    session: SessionDep,
    _admin: AdminUser,
    status: FeedbackStatus | None = None,
    artifact_id: uuid.UUID | None = None,
    user_id: uuid.UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
) -> FeedbacksPublic:
    conditions = []
    if status is not None:
        conditions.append(col(Feedback.status) == status)
    if artifact_id is not None:
        conditions.append(col(Feedback.artifact_id) == artifact_id)
    if user_id is not None:
        conditions.append(col(Feedback.user_id) == user_id)
    return _list(session, conditions, skip, limit)


@router.get(
    "/{feedback_id}", response_model=FeedbackPublic, responses=errors(401, 403, 404)
)
def read_feedback(
    session: SessionDep, current_user: VisitorUser, feedback_id: uuid.UUID
) -> Any:
    row = session.get(Feedback, feedback_id)
    if row is None or (row.user_id != current_user.id and not is_admin(current_user)):
        raise HTTPException(status_code=404, detail="Feedback not found")
    return row


@router.patch(
    "/{feedback_id}/status",
    response_model=FeedbackPublic,
    responses=errors(401, 403, 404),
)
def moderate_feedback(
    session: SessionDep,
    _admin: AdminUser,
    feedback_id: uuid.UUID,
    body: FeedbackStatusUpdate,
) -> Any:
    row = session.get(Feedback, feedback_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Feedback not found")
    row.status = body.status
    session.add(row)
    session.commit()
    session.refresh(row)
    return row

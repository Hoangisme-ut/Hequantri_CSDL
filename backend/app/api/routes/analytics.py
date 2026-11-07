"""Aggregates of recorded content views, not physical visitors or sessions."""

import uuid
from datetime import UTC, date, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import Date, cast, distinct, select
from sqlmodel import SQLModel, col, func

from app.api.deps import AdminUser, SessionDep
from app.models import Artifact, Site, VisitLog

router = APIRouter(prefix="/analytics", tags=["analytics"])


class Overview(SQLModel):
    views: int
    unique_users: int
    artifacts_viewed: int


class DailyViews(SQLModel):
    date: date
    views: int
    unique_users: int


class ArtifactViews(SQLModel):
    artifact_id: uuid.UUID
    site_id: uuid.UUID
    code: str
    views: int
    unique_users: int


class SiteViews(SQLModel):
    site_id: uuid.UUID
    name: str
    views: int
    unique_users: int


def filters(
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
    site_id: uuid.UUID | None = None,
) -> list[Any]:
    """UTC [from,to); omitted boundaries are unbounded. Require explicit offsets."""
    for boundary in (from_date, to_date):
        if boundary is not None and boundary.utcoffset() is None:
            raise HTTPException(
                status_code=422, detail="Time boundaries require a timezone"
            )
    if from_date is not None and to_date is not None and from_date >= to_date:
        raise HTTPException(status_code=422, detail="from must be earlier than to")
    conditions = []
    if from_date is not None:
        conditions.append(col(VisitLog.visited_at) >= from_date.astimezone(UTC))
    if to_date is not None:
        conditions.append(col(VisitLog.visited_at) < to_date.astimezone(UTC))
    if site_id is not None:
        conditions.append(col(Artifact.site_id) == site_id)
    return conditions


Filters = Annotated[list[Any], Depends(filters)]


def _counts() -> tuple[Any, Any]:
    return func.count().label("views"), func.count(
        distinct(col(VisitLog.user_id))
    ).label("unique_users")


@router.get("/overview", response_model=Overview)
def overview(session: SessionDep, _admin: AdminUser, conditions: Filters) -> Any:
    stmt = (
        select(
            *_counts(),
            func.count(distinct(col(VisitLog.artifact_id))).label("artifacts_viewed"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
    )
    return session.connection().execute(stmt).mappings().one()


@router.get("/visits", response_model=list[DailyViews])
def visits(session: SessionDep, _admin: AdminUser, conditions: Filters) -> Any:
    # UTCDateTime persists UTC to SQL Server. Aggregate in SQL, no event loading.
    day = cast(col(VisitLog.visited_at), Date)
    stmt = (
        select(day.label("date"), *_counts())
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions, col(VisitLog.visited_at).is_not(None))
        .group_by(day)
        .order_by(day)
    )
    return session.connection().execute(stmt).mappings().all()


@router.get("/top-artifacts", response_model=list[ArtifactViews])
def top_artifacts(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
    limit: int = Query(10, ge=1, le=100),
) -> Any:
    views, users = _counts()
    stmt = (
        select(
            col(Artifact.id).label("artifact_id"),
            col(Artifact.site_id),
            col(Artifact.code),
            views,
            users,
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
        .group_by(col(Artifact.id), col(Artifact.site_id), col(Artifact.code))
        .order_by(views.desc(), col(Artifact.id))
        .limit(limit)
    )
    return session.connection().execute(stmt).mappings().all()


@router.get("/sites", response_model=list[SiteViews])
def sites(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
) -> Any:
    views, users = _counts()
    stmt = (
        select(col(Site.id).label("site_id"), col(Site.name), views, users)
        .select_from(VisitLog)
        .join(Artifact)
        .join(Site)
        .where(*conditions)
        .group_by(col(Site.id), col(Site.name))
        .order_by(views.desc(), col(Site.id))
        .offset(skip)
        .limit(limit)
    )
    return session.connection().execute(stmt).mappings().all()

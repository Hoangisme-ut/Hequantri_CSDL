import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from sqlmodel import col, func, select

from app.api.deps import AdminUser, OptionalUser, SessionDep, is_admin
from app.models import (
    Message,
    Site,
    SiteCreate,
    SitePublic,
    SitesPublic,
    SiteUpdate,
    get_datetime_utc,
)

router = APIRouter(prefix="/sites", tags=["sites"])


@router.get("/", response_model=SitesPublic)
def read_sites(
    session: SessionDep,
    current_user: OptionalUser,
    skip: int = 0,
    limit: int = Query(default=100, le=200),
    q: str | None = None,
    include_inactive: bool = False,
) -> Any:
    """
    Danh sách di tích. **Public**.
    Chỉ admin mới xem được di tích đã ẩn (`include_inactive=true`).
    """
    conditions = []
    if not (include_inactive and is_admin(current_user)):
        conditions.append(col(Site.is_active))
    if q:
        conditions.append(col(Site.name).contains(q))
    count = session.exec(select(func.count()).select_from(Site).where(*conditions)).one()
    statement = (
        select(Site).where(*conditions).order_by(col(Site.name)).offset(skip).limit(limit)
    )
    sites = session.exec(statement).all()
    return SitesPublic(data=[SitePublic.model_validate(s) for s in sites], count=count)


@router.get("/{site_id}", response_model=SitePublic)
def read_site(
    session: SessionDep, current_user: OptionalUser, site_id: uuid.UUID
) -> Any:
    """
    Chi tiết di tích. **Public** (di tích đã ẩn chỉ admin xem được).
    """
    site = session.get(Site, site_id)
    if not site or (not site.is_active and not is_admin(current_user)):
        raise HTTPException(status_code=404, detail="Site not found")
    return site


@router.post("/", response_model=SitePublic)
def create_site(*, session: SessionDep, _admin: AdminUser, site_in: SiteCreate) -> Any:
    """
    Tạo di tích. **Admin**.
    """
    site = Site.model_validate(site_in)
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


@router.put("/{site_id}", response_model=SitePublic)
def update_site(
    *, session: SessionDep, _admin: AdminUser, site_id: uuid.UUID, site_in: SiteUpdate
) -> Any:
    """
    Sửa di tích (cả bật lại `is_active`). **Admin**.
    """
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    site.sqlmodel_update(site_in.model_dump(exclude_unset=True))
    site.updated_at = get_datetime_utc()
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


@router.delete("/{site_id}")
def delete_site(session: SessionDep, _admin: AdminUser, site_id: uuid.UUID) -> Message:
    """
    Ẩn di tích (xóa mềm: is_active = false). **Admin**.

    Không sửa dữ liệu con: hiện vật + beacon của Site ẩn tự không trả cho du khách
    (kiểm tra lúc đọc). Bật lại Site (`PUT is_active=true`) -> hiển thị lại như cũ.
    """
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    site.is_active = False
    site.updated_at = get_datetime_utc()
    session.add(site)
    session.commit()
    return Message(message="Site deactivated successfully")
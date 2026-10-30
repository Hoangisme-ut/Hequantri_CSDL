import uuid
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status
from sqlmodel import col, func, select

from app import crud
from app.api.deps import AdminUser, SessionDep, VisitorUser
from app.models import (
    Artifact,
    Beacon,
    BeaconCreate,
    BeaconPublic,
    BeaconResolvePublic,
    BeaconsPublic,
    BeaconUpdate,
    Message,
    Site,
    get_datetime_utc,
)

router = APIRouter(prefix="/beacons", tags=["beacons"])

REQUIRED_UPDATE_FIELDS = {"proximity_uuid", "major", "minor", "site_id"}


def _validate_links(
    session: SessionDep,
    site_id: uuid.UUID,
    artifact_id: uuid.UUID | None,
    beacon_id: uuid.UUID | None = None,
    *,
    check_site_active: bool = True,
    check_artifact_active: bool = True,
) -> None:
    """Site phải tồn tại; hiện vật gán phải cùng site, chưa gắn beacon khác.

    R3: không đặt beacon vào Site đang ẩn, không gán hiện vật đã ẩn / thuộc Site ẩn.
    Hai cờ `check_*` = False khi admin chỉ chỉnh thông số beacon (không đổi Site /
    Artifact) nên vẫn chỉnh được beacon ở Site đang ẩn.
    """
    site = session.get(Site, site_id)
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    if check_site_active and not site.is_active:
        raise HTTPException(
            status_code=409, detail="Site đang bị ẩn, không thể thêm/chuyển beacon vào"
        )
    if artifact_id is None:
        return
    artifact = session.get(Artifact, artifact_id)
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")
    if artifact.site_id != site_id:
        raise HTTPException(
            status_code=400, detail="Beacon và Artifact phải thuộc cùng một Site"
        )
    if check_artifact_active and not crud.is_artifact_visible(
        session=session, artifact=artifact
    ):
        raise HTTPException(
            status_code=409,
            detail="Hiện vật đang bị ẩn (hoặc thuộc Site bị ẩn), không thể gán beacon",
        )
    other = session.exec(select(Beacon).where(Beacon.artifact_id == artifact_id)).first()
    if other and other.id != beacon_id:
        raise HTTPException(
            status_code=409, detail="Artifact đã được gán cho beacon khác"
        )


def _check_identity_unique(
    session: SessionDep,
    proximity_uuid: str,
    major: int,
    minor: int,
    exclude_id: uuid.UUID | None = None,
) -> None:
    existing = session.exec(
        select(Beacon).where(
            Beacon.proximity_uuid == proximity_uuid,
            Beacon.major == major,
            Beacon.minor == minor,
        )
    ).first()
    if existing and existing.id != exclude_id:
        raise HTTPException(
            status_code=409, detail="Beacon (uuid, major, minor) already exists"
        )


# ------------------------- App du khách: quét beacon -------------------------
@router.get("/resolve", response_model=BeaconResolvePublic)
def resolve_beacon(
    session: SessionDep,
    current_user: VisitorUser,
    proximity_uuid: uuid.UUID = Query(description="iBeacon UUID"),
    major: int = Query(ge=0, le=65535),
    minor: int = Query(ge=0, le=65535),
    lang: str | None = Query(default=None, description="Mã ngôn ngữ: vi, en..."),
) -> Any:
    """
    **App gọi khi quét được beacon**: trả hiện vật gắn với beacon + nội dung đúng
    ngôn ngữ + media. Ngôn ngữ: `lang` -> ngôn ngữ ưa thích của user -> mặc định.
    **Visitor / Admin** (cần đăng nhập).
    """
    beacon = session.exec(
        select(Beacon).where(
            Beacon.proximity_uuid == str(proximity_uuid).upper(),
            Beacon.major == major,
            Beacon.minor == minor,
            col(Beacon.is_active),
        )
    ).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="Beacon not found")
    if beacon.artifact_id is None:
        raise HTTPException(status_code=404, detail="Beacon chưa được gán hiện vật")
    # R2: Site của beacon bị ẩn -> du khách không nhận được nội dung
    if not crud.is_site_active(session=session, site_id=beacon.site_id):
        raise HTTPException(status_code=404, detail="Beacon not found")
    artifact = session.get(Artifact, beacon.artifact_id)
    if not artifact or not artifact.is_active:
        raise HTTPException(status_code=404, detail="Artifact not found")
    # R5: dữ liệu cũ bị lệch Site -> không trả nội dung sai quan hệ
    if artifact.site_id != beacon.site_id:
        raise HTTPException(
            status_code=409, detail="Cấu hình sai: Beacon và Artifact khác Site"
        )

    beacon.last_seen_at = get_datetime_utc()
    session.add(beacon)
    session.commit()
    session.refresh(beacon)

    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    content = crud.get_artifact_content(
        session=session, artifact=artifact, language=language
    )
    return BeaconResolvePublic(
        beacon=BeaconPublic.model_validate(beacon), artifact=content
    )


# ------------------------------ Admin: quản lý ------------------------------
@router.get("/{beacon_id}", response_model=BeaconPublic)
def read_beacon(
    session: SessionDep, _admin: AdminUser, beacon_id: uuid.UUID
) -> Any:
    """Lấy chi tiết một beacon. **Admin**."""
    beacon = session.get(Beacon, beacon_id)
    if not beacon:
        raise HTTPException(status_code=404, detail="Beacon not found")
    return beacon


@router.get("/", response_model=BeaconsPublic)
def read_beacons(
    session: SessionDep,
    _admin: AdminUser,
    site_id: uuid.UUID | None = None,
    artifact_id: uuid.UUID | None = None,
    skip: int = 0,
    limit: int = Query(default=100, le=200),
) -> Any:
    """
    Danh sách beacon. **Admin**.
    """
    conditions = []
    if site_id:
        conditions.append(Beacon.site_id == site_id)
    if artifact_id:
        conditions.append(Beacon.artifact_id == artifact_id)
    count = session.exec(select(func.count()).select_from(Beacon).where(*conditions)).one()
    beacons = session.exec(
        select(Beacon)
        .where(*conditions)
        .order_by(col(Beacon.created_at).desc())
        .offset(skip)
        .limit(limit)
    ).all()
    return BeaconsPublic(
        data=[BeaconPublic.model_validate(b) for b in beacons], count=count
    )


@router.post("/", response_model=BeaconPublic, status_code=status.HTTP_201_CREATED)
def create_beacon(
    *, session: SessionDep, _admin: AdminUser, beacon_in: BeaconCreate
) -> Any:
    """
    Đăng ký beacon (và có thể gán hiện vật luôn). **Admin**.
    """
    puuid = beacon_in.proximity_uuid.upper()
    _validate_links(session, beacon_in.site_id, beacon_in.artifact_id)
    _check_identity_unique(session, puuid, beacon_in.major, beacon_in.minor)
    beacon = Beacon.model_validate(beacon_in, update={"proximity_uuid": puuid})
    session.add(beacon)
    session.commit()
    session.refresh(beacon)
    return beacon


@router.put("/{beacon_id}", response_model=BeaconPublic)
def update_beacon(
    *,
    session: SessionDep,
    _admin: AdminUser,
    beacon_id: uuid.UUID,
    beacon_in: BeaconUpdate,
) -> Any:
    """
    Cấu hình beacon / gán hoặc gỡ hiện vật (`artifact_id: null` để gỡ). **Admin**.
    """
    beacon = session.get(Beacon, beacon_id)
    if not beacon:
        raise HTTPException(status_code=404, detail="Beacon not found")
    data = beacon_in.model_dump(exclude_unset=True)
    null_required_fields = REQUIRED_UPDATE_FIELDS.intersection(
        key for key, value in data.items() if value is None
    )
    if null_required_fields:
        field_names = ", ".join(sorted(null_required_fields))
        raise HTTPException(
            status_code=422,
            detail=f"Fields cannot be null: {field_names}",
        )
    new_site = data.get("site_id", beacon.site_id)
    new_artifact = data["artifact_id"] if "artifact_id" in data else beacon.artifact_id
    _validate_links(
        session,
        new_site,
        new_artifact,
        beacon_id=beacon.id,
        # chỉ kiểm tra "ẩn" khi thực sự đổi Site / đổi Artifact
        check_site_active=new_site != beacon.site_id,
        check_artifact_active=new_artifact != beacon.artifact_id,
    )
    _check_identity_unique(
        session,
        data.get("proximity_uuid", beacon.proximity_uuid),
        data.get("major", beacon.major),
        data.get("minor", beacon.minor),
        exclude_id=beacon.id,
    )
    beacon.sqlmodel_update(data)
    beacon.updated_at = get_datetime_utc()
    session.add(beacon)
    session.commit()
    session.refresh(beacon)
    return beacon


@router.delete("/{beacon_id}")
def delete_beacon(
    session: SessionDep, _admin: AdminUser, beacon_id: uuid.UUID
) -> Message:
    """
    Tắt beacon (xóa mềm) và gỡ khỏi hiện vật. **Admin**.
    """
    beacon = session.get(Beacon, beacon_id)
    if not beacon:
        raise HTTPException(status_code=404, detail="Beacon not found")
    beacon.is_active = False
    beacon.artifact_id = None
    beacon.updated_at = get_datetime_utc()
    session.add(beacon)
    session.commit()
    return Message(message="Beacon deactivated successfully")
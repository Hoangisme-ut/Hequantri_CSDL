"""Kiểm thử nhất quán Site - Artifact - Beacon.

Quy tắc đã chốt (xem app/crud.py và các route sites / artifacts / beacons):
- R1: hiện vật đang gắn beacon thì không được đổi Site (phải gỡ beacon trước).
- R2: Site bị ẩn -> hiện vật + beacon con không trả cho du khách (kiểm tra lúc đọc,
  không sửa dữ liệu con); bật lại Site thì hiển thị lại như cũ.
- R3: không tạo / chuyển hiện vật hoặc beacon vào Site đang ẩn, không gán hiện vật ẩn.
- R4: ẩn hiện vật -> gỡ beacon khỏi hiện vật đó (beacon vẫn còn để gán lại).
- R5: dữ liệu cũ bị lệch Site giữa Beacon và Artifact -> không trả nội dung sai quan hệ.
"""

import uuid

import pytest
from fastapi import HTTPException
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.api.routes.artifacts import (
    create_artifact,
    delete_artifact,
    read_artifact,
    read_artifacts,
    update_artifact,
)
from app.api.routes.beacons import create_beacon, resolve_beacon, update_beacon
from app.api.routes.sites import delete_site, update_site
from app.models import (
    Artifact,
    ArtifactCreate,
    ArtifactUpdate,
    Beacon,
    BeaconCreate,
    BeaconUpdate,
    Site,
    SiteUpdate,
    User,
)


@pytest.fixture
def session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as db_session:
        yield db_session


@pytest.fixture
def admin_user() -> User:
    return User(
        email="consistency-admin@example.com",
        hashed_password="not-used-in-unit-tests",
        is_superuser=True,
    )


@pytest.fixture
def visitor_user() -> User:
    return User(
        email="consistency-visitor@example.com",
        hashed_password="not-used-in-unit-tests",
        is_superuser=False,
    )


def make_site(session: Session, name: str = "Test site", *, is_active: bool = True) -> Site:
    site = Site(name=name, is_active=is_active)
    session.add(site)
    session.commit()
    session.refresh(site)
    return site


def make_artifact(
    session: Session, site: Site, *, is_active: bool = True
) -> Artifact:
    artifact = Artifact(
        site_id=site.id, code=f"ART-{uuid.uuid4().hex[:8]}", is_active=is_active
    )
    session.add(artifact)
    session.commit()
    session.refresh(artifact)
    return artifact


def make_beacon(
    session: Session,
    admin: User,
    site: Site,
    artifact: Artifact | None = None,
    *,
    minor: int = 1,
) -> Beacon:
    return create_beacon(
        session=session,
        _admin=admin,
        beacon_in=BeaconCreate(
            proximity_uuid=str(uuid.uuid4()),
            major=1,
            minor=minor,
            site_id=site.id,
            artifact_id=artifact.id if artifact else None,
        ),
    )


def hide_site(session: Session, admin: User, site: Site) -> None:
    delete_site(session=session, _admin=admin, site_id=site.id)
    session.refresh(site)
    assert site.is_active is False


def list_artifacts_for(
    session: Session, user: User | None, *, include_inactive: bool = False
) -> list[uuid.UUID]:
    result = read_artifacts(
        session=session,
        current_user=user,
        site_id=None,
        lang=None,
        q=None,
        skip=0,
        limit=100,
        include_inactive=include_inactive,
    )
    return [item.id for item in result.data]


def resolve(session: Session, user: User, beacon: Beacon):  # type: ignore[no-untyped-def]
    return resolve_beacon(
        session=session,
        current_user=user,
        proximity_uuid=uuid.UUID(beacon.proximity_uuid),
        major=beacon.major,
        minor=beacon.minor,
        lang=None,
    )


# ------------------------------------ R1 ------------------------------------
def test_artifact_with_beacon_cannot_change_site(
    session: Session, admin_user: User
) -> None:
    site_a = make_site(session, "Site A")
    site_b = make_site(session, "Site B")
    artifact = make_artifact(session, site_a)
    beacon = make_beacon(session, admin_user, site_a, artifact)

    with pytest.raises(HTTPException) as exc_info:
        update_artifact(
            session=session,
            admin=admin_user,
            artifact_id=artifact.id,
            artifact_in=ArtifactUpdate(site_id=site_b.id),
        )
    assert exc_info.value.status_code == 409

    # dữ liệu không bị đổi: hiện vật vẫn ở Site A, beacon vẫn gắn hiện vật
    session.refresh(artifact)
    session.refresh(beacon)
    assert artifact.site_id == site_a.id
    assert beacon.site_id == site_a.id
    assert beacon.artifact_id == artifact.id


def test_artifact_can_change_site_after_beacon_is_detached(
    session: Session, admin_user: User
) -> None:
    site_a = make_site(session, "Site A")
    site_b = make_site(session, "Site B")
    artifact = make_artifact(session, site_a)
    beacon = make_beacon(session, admin_user, site_a, artifact)

    update_beacon(
        session=session,
        _admin=admin_user,
        beacon_id=beacon.id,
        beacon_in=BeaconUpdate(artifact_id=None),
    )
    moved = update_artifact(
        session=session,
        admin=admin_user,
        artifact_id=artifact.id,
        artifact_in=ArtifactUpdate(site_id=site_b.id),
    )

    assert moved.site_id == site_b.id
    session.refresh(beacon)
    assert beacon.site_id == site_a.id
    assert beacon.artifact_id is None


def test_artifact_without_beacon_can_change_site(
    session: Session, admin_user: User
) -> None:
    site_a = make_site(session, "Site A")
    site_b = make_site(session, "Site B")
    artifact = make_artifact(session, site_a)

    moved = update_artifact(
        session=session,
        admin=admin_user,
        artifact_id=artifact.id,
        artifact_in=ArtifactUpdate(site_id=site_b.id),
    )

    assert moved.site_id == site_b.id


def test_update_artifact_rejects_null_site_id(
    session: Session, admin_user: User
) -> None:
    site = make_site(session)
    artifact = make_artifact(session, site)

    with pytest.raises(HTTPException) as exc_info:
        update_artifact(
            session=session,
            admin=admin_user,
            artifact_id=artifact.id,
            artifact_in=ArtifactUpdate(site_id=None),
        )
    assert exc_info.value.status_code == 422


def test_beacon_cannot_move_to_other_site_while_holding_artifact(
    session: Session, admin_user: User
) -> None:
    site_a = make_site(session, "Site A")
    site_b = make_site(session, "Site B")
    artifact = make_artifact(session, site_a)
    beacon = make_beacon(session, admin_user, site_a, artifact)

    with pytest.raises(HTTPException) as exc_info:
        update_beacon(
            session=session,
            _admin=admin_user,
            beacon_id=beacon.id,
            beacon_in=BeaconUpdate(site_id=site_b.id),
        )
    assert exc_info.value.status_code == 400

    session.refresh(beacon)
    assert beacon.site_id == site_a.id
    assert beacon.artifact_id == artifact.id


# ------------------------------------ R2 ------------------------------------
def test_hidden_site_hides_artifacts_from_visitors_and_restores_on_reactivate(
    session: Session, admin_user: User, visitor_user: User
) -> None:
    site = make_site(session)
    artifact = make_artifact(session, site)
    assert artifact.id in list_artifacts_for(session, None)

    hide_site(session, admin_user, site)

    # khách (kể cả chưa đăng nhập) không thấy; dữ liệu con không bị sửa
    assert artifact.id not in list_artifacts_for(session, None)
    assert artifact.id not in list_artifacts_for(session, visitor_user)
    # visitor gửi include_inactive=true cũng không xem được
    assert artifact.id not in list_artifacts_for(
        session, visitor_user, include_inactive=True
    )
    for user in (None, visitor_user):
        with pytest.raises(HTTPException) as exc_info:
            read_artifact(
                session=session,
                current_user=user,
                artifact_id=artifact.id,
                lang=None,
            )
        assert exc_info.value.status_code == 404
    session.refresh(artifact)
    assert artifact.is_active is True

    # admin vẫn xem được để quản lý
    assert artifact.id in list_artifacts_for(session, admin_user, include_inactive=True)
    detail = read_artifact(
        session=session, current_user=admin_user, artifact_id=artifact.id, lang=None
    )
    assert detail.id == artifact.id

    # bật lại Site -> hiển thị lại như cũ
    update_site(
        session=session,
        _admin=admin_user,
        site_id=site.id,
        site_in=SiteUpdate(is_active=True),
    )
    assert artifact.id in list_artifacts_for(session, None)
    visible = read_artifact(
        session=session, current_user=None, artifact_id=artifact.id, lang=None
    )
    assert visible.id == artifact.id


def test_resolve_beacon_returns_nothing_when_site_is_hidden(
    session: Session, admin_user: User, visitor_user: User
) -> None:
    site = make_site(session)
    artifact = make_artifact(session, site)
    beacon = make_beacon(session, admin_user, site, artifact)

    ok = resolve(session, visitor_user, beacon)
    assert ok.artifact.id == artifact.id
    assert ok.beacon.id == beacon.id

    hide_site(session, admin_user, site)

    with pytest.raises(HTTPException) as exc_info:
        resolve(session, visitor_user, beacon)
    assert exc_info.value.status_code == 404

    # dữ liệu con giữ nguyên, bật lại Site thì quét lại được
    session.refresh(beacon)
    assert beacon.artifact_id == artifact.id
    update_site(
        session=session,
        _admin=admin_user,
        site_id=site.id,
        site_in=SiteUpdate(is_active=True),
    )
    again = resolve(session, visitor_user, beacon)
    assert again.artifact.id == artifact.id


# ------------------------------------ R3 ------------------------------------
def test_cannot_create_artifact_in_hidden_or_missing_site(
    session: Session, admin_user: User
) -> None:
    hidden = make_site(session, "Hidden", is_active=False)

    with pytest.raises(HTTPException) as exc_info:
        create_artifact(
            session=session,
            admin=admin_user,
            artifact_in=ArtifactCreate(site_id=hidden.id, code="ART-HIDDEN"),
        )
    assert exc_info.value.status_code == 409

    with pytest.raises(HTTPException) as exc_info:
        create_artifact(
            session=session,
            admin=admin_user,
            artifact_in=ArtifactCreate(site_id=uuid.uuid4(), code="ART-MISSING"),
        )
    assert exc_info.value.status_code == 404


def test_cannot_move_artifact_into_hidden_site(
    session: Session, admin_user: User
) -> None:
    site = make_site(session, "Active")
    hidden = make_site(session, "Hidden", is_active=False)
    artifact = make_artifact(session, site)

    with pytest.raises(HTTPException) as exc_info:
        update_artifact(
            session=session,
            admin=admin_user,
            artifact_id=artifact.id,
            artifact_in=ArtifactUpdate(site_id=hidden.id),
        )
    assert exc_info.value.status_code == 409

    session.refresh(artifact)
    assert artifact.site_id == site.id


def test_cannot_create_beacon_in_hidden_site(
    session: Session, admin_user: User
) -> None:
    hidden = make_site(session, "Hidden", is_active=False)

    with pytest.raises(HTTPException) as exc_info:
        make_beacon(session, admin_user, hidden)
    assert exc_info.value.status_code == 409


def test_cannot_assign_hidden_artifact_to_beacon(
    session: Session, admin_user: User
) -> None:
    site = make_site(session)
    hidden_artifact = make_artifact(session, site, is_active=False)

    with pytest.raises(HTTPException) as exc_info:
        make_beacon(session, admin_user, site, hidden_artifact)
    assert exc_info.value.status_code == 409

    # gán qua update cũng bị chặn
    beacon = make_beacon(session, admin_user, site, minor=2)
    with pytest.raises(HTTPException) as exc_info:
        update_beacon(
            session=session,
            _admin=admin_user,
            beacon_id=beacon.id,
            beacon_in=BeaconUpdate(artifact_id=hidden_artifact.id),
        )
    assert exc_info.value.status_code == 409


def test_beacon_at_hidden_site_can_still_be_tuned_but_not_reassigned(
    session: Session, admin_user: User
) -> None:
    site = make_site(session)
    other = make_site(session, "Other")
    other_hidden = make_site(session, "Other hidden", is_active=False)
    beacon = make_beacon(session, admin_user, site)
    hide_site(session, admin_user, site)

    # chỉ chỉnh thông số (không đổi Site / Artifact) -> vẫn được
    tuned = update_beacon(
        session=session,
        _admin=admin_user,
        beacon_id=beacon.id,
        beacon_in=BeaconUpdate(tx_power=-65),
    )
    assert tuned.tx_power == -65

    # nhưng không được chuyển sang một Site đang ẩn
    with pytest.raises(HTTPException) as exc_info:
        update_beacon(
            session=session,
            _admin=admin_user,
            beacon_id=beacon.id,
            beacon_in=BeaconUpdate(site_id=other_hidden.id),
        )
    assert exc_info.value.status_code == 409
    # chuyển sang Site đang hiển thị thì được
    moved = update_beacon(
        session=session,
        _admin=admin_user,
        beacon_id=beacon.id,
        beacon_in=BeaconUpdate(site_id=other.id),
    )
    assert moved.site_id == other.id


# ------------------------------------ R4 ------------------------------------
def test_hiding_artifact_detaches_its_beacon(
    session: Session, admin_user: User, visitor_user: User
) -> None:
    site = make_site(session)
    artifact = make_artifact(session, site)
    beacon = make_beacon(session, admin_user, site, artifact)

    update_artifact(
        session=session,
        admin=admin_user,
        artifact_id=artifact.id,
        artifact_in=ArtifactUpdate(is_active=False),
    )

    session.refresh(beacon)
    assert beacon.artifact_id is None
    assert beacon.is_active is True  # thiết bị vẫn còn để gán lại
    with pytest.raises(HTTPException) as exc_info:
        resolve(session, visitor_user, beacon)
    assert exc_info.value.status_code == 404


def test_deleting_artifact_detaches_its_beacon(
    session: Session, admin_user: User
) -> None:
    site = make_site(session)
    artifact = make_artifact(session, site)
    beacon = make_beacon(session, admin_user, site, artifact)

    result = delete_artifact(
        session=session, admin=admin_user, artifact_id=artifact.id
    )

    assert result.message == "Artifact deactivated successfully"
    session.refresh(artifact)
    session.refresh(beacon)
    assert artifact.is_active is False
    assert beacon.artifact_id is None
    assert beacon.is_active is True


# ------------------------------------ R5 ------------------------------------
def test_resolve_beacon_rejects_legacy_site_mismatch(
    session: Session, admin_user: User, visitor_user: User
) -> None:
    site_a = make_site(session, "Site A")
    site_b = make_site(session, "Site B")
    artifact = make_artifact(session, site_a)
    beacon = make_beacon(session, admin_user, site_a, artifact)

    # mô phỏng dữ liệu cũ bị lệch (ghi thẳng DB, bỏ qua API)
    beacon.site_id = site_b.id
    session.add(beacon)
    session.commit()

    with pytest.raises(HTTPException) as exc_info:
        resolve(session, visitor_user, beacon)
    assert exc_info.value.status_code == 409


def test_resolve_beacon_without_artifact_or_inactive_returns_404(
    session: Session, admin_user: User, visitor_user: User
) -> None:
    site = make_site(session)
    unassigned = make_beacon(session, admin_user, site, minor=1)
    with pytest.raises(HTTPException) as exc_info:
        resolve(session, visitor_user, unassigned)
    assert exc_info.value.status_code == 404

    artifact = make_artifact(session, site)
    assigned = make_beacon(session, admin_user, site, artifact, minor=2)
    # hiện vật bị ẩn thẳng trong DB mà beacon còn gắn (dữ liệu cũ) -> không trả nội dung
    artifact.is_active = False
    session.add(artifact)
    session.commit()
    with pytest.raises(HTTPException) as exc_info:
        resolve(session, visitor_user, assigned)
    assert exc_info.value.status_code == 404
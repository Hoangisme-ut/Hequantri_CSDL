import uuid

import pytest
from fastapi import HTTPException
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.api.routes.beacons import (
    create_beacon,
    delete_beacon,
    read_beacon,
    read_beacons,
    update_beacon,
)
from app.models import Artifact, BeaconCreate, BeaconUpdate, Site, User


@pytest.fixture
def beacon_session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture
def admin_user() -> User:
    return User(
        email="beacon-admin@example.com",
        hashed_password="not-used-in-unit-tests",
        is_superuser=True,
    )


def create_site_and_artifact(session: Session) -> tuple[Site, Artifact]:
    site = Site(name="Test site")
    session.add(site)
    session.commit()
    session.refresh(site)

    artifact = Artifact(site_id=site.id, code=f"ART-{uuid.uuid4().hex[:8]}")
    session.add(artifact)
    session.commit()
    session.refresh(artifact)
    return site, artifact


def test_beacon_crud_and_artifact_assignment(
    beacon_session: Session, admin_user: User
) -> None:
    site, artifact = create_site_and_artifact(beacon_session)
    proximity_uuid = uuid.uuid4()

    created = create_beacon(
        session=beacon_session,
        _admin=admin_user,
        beacon_in=BeaconCreate(
            proximity_uuid=str(proximity_uuid),
            major=10,
            minor=20,
            site_id=site.id,
            artifact_id=artifact.id,
        ),
    )
    assert created.proximity_uuid == str(proximity_uuid).upper()
    assert created.artifact_id == artifact.id

    detail = read_beacon(
        session=beacon_session, _admin=admin_user, beacon_id=created.id
    )
    assert detail.id == created.id

    listing = read_beacons(
        session=beacon_session,
        _admin=admin_user,
        artifact_id=artifact.id,
        limit=100,
    )
    assert listing.count == 1
    assert listing.data[0].id == created.id

    updated = update_beacon(
        session=beacon_session,
        _admin=admin_user,
        beacon_id=created.id,
        beacon_in=BeaconUpdate(minor=21, artifact_id=None),
    )
    assert updated.minor == 21
    assert updated.artifact_id is None
    assert updated.updated_at is not None

    result = delete_beacon(
        session=beacon_session, _admin=admin_user, beacon_id=created.id
    )
    beacon_session.refresh(created)
    assert result.message == "Beacon deactivated successfully"
    assert created.is_active is False
    assert created.artifact_id is None


def test_create_beacon_rejects_duplicate_identity(
    beacon_session: Session, admin_user: User
) -> None:
    site, _ = create_site_and_artifact(beacon_session)
    beacon_in = BeaconCreate(
        proximity_uuid=str(uuid.uuid4()),
        major=1,
        minor=2,
        site_id=site.id,
    )
    create_beacon(session=beacon_session, _admin=admin_user, beacon_in=beacon_in)

    with pytest.raises(HTTPException) as exc_info:
        create_beacon(session=beacon_session, _admin=admin_user, beacon_in=beacon_in)

    assert exc_info.value.status_code == 409


def test_create_beacon_rejects_artifact_from_another_site(
    beacon_session: Session, admin_user: User
) -> None:
    first_site, _ = create_site_and_artifact(beacon_session)
    _, other_artifact = create_site_and_artifact(beacon_session)

    with pytest.raises(HTTPException) as exc_info:
        create_beacon(
            session=beacon_session,
            _admin=admin_user,
            beacon_in=BeaconCreate(
                proximity_uuid=str(uuid.uuid4()),
                major=1,
                minor=2,
                site_id=first_site.id,
                artifact_id=other_artifact.id,
            ),
        )

    assert exc_info.value.status_code == 400


def test_artifact_cannot_be_assigned_to_two_beacons(
    beacon_session: Session, admin_user: User
) -> None:
    site, artifact = create_site_and_artifact(beacon_session)
    first_beacon = BeaconCreate(
        proximity_uuid=str(uuid.uuid4()),
        major=1,
        minor=1,
        site_id=site.id,
        artifact_id=artifact.id,
    )
    second_beacon = BeaconCreate(
        proximity_uuid=str(uuid.uuid4()),
        major=1,
        minor=2,
        site_id=site.id,
        artifact_id=artifact.id,
    )
    create_beacon(
        session=beacon_session, _admin=admin_user, beacon_in=first_beacon
    )

    with pytest.raises(HTTPException) as exc_info:
        create_beacon(
            session=beacon_session, _admin=admin_user, beacon_in=second_beacon
        )

    assert exc_info.value.status_code == 409


def test_update_beacon_rejects_null_required_field(
    beacon_session: Session, admin_user: User
) -> None:
    site, _ = create_site_and_artifact(beacon_session)
    created = create_beacon(
        session=beacon_session,
        _admin=admin_user,
        beacon_in=BeaconCreate(
            proximity_uuid=str(uuid.uuid4()),
            major=1,
            minor=2,
            site_id=site.id,
        ),
    )

    with pytest.raises(HTTPException) as exc_info:
        update_beacon(
            session=beacon_session,
            _admin=admin_user,
            beacon_id=created.id,
            beacon_in=BeaconUpdate(major=None),
        )

    assert exc_info.value.status_code == 422

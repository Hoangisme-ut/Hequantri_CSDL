import uuid
from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.api.deps import get_current_user, get_db
from app.api.routes import beacons, media
from app.models import Artifact, ArtifactTranslation, Beacon, Language, Role, Site, User


@pytest.fixture
def db() -> Generator[Session]:
    """Override the global database fixture with an isolated database."""
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session
    engine.dispose()


@pytest.fixture
def media_api(db: Session):
    app = FastAPI()
    app.include_router(media.router)
    app.include_router(beacons.router)
    admin = User(
        email="admin@example.com", hashed_password="unused", role=Role(name="admin")
    )
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: admin
    site = Site(name="Museum")
    db.add(site)
    db.flush()
    artifact = Artifact(site_id=site.id, code="ART-1")
    vi = Language(code="vi", name="Vietnamese", is_default=True)
    en = Language(code="en", name="English")
    db.add_all([artifact, vi, en])
    db.flush()
    beacon = Beacon(
        site_id=site.id,
        artifact_id=artifact.id,
        proximity_uuid=str(uuid.uuid4()).upper(),
        major=1,
        minor=2,
    )
    db.add(beacon)
    db.add(
        ArtifactTranslation(
            artifact_id=artifact.id, language_id=vi.id, title="Artifact"
        )
    )
    db.commit()
    with TestClient(app) as client:
        yield client, app, artifact, vi, en, beacon


def test_media_crud_and_beacon_resolve(media_api) -> None:
    client, _, artifact, vi, en, beacon = media_api
    path = f"/artifacts/{artifact.id}/media"
    records = []
    for kind, language, order in [
        ("image", None, 2),
        ("audio", str(vi.id), 1),
        ("video", str(en.id), 0),
    ]:
        response = client.post(
            path,
            json={
                "media_type": kind,
                "url": f"https://example.com/{kind}",
                "language_id": language,
                "sort_order": order,
            },
        )
        assert response.status_code == 201
        records.append(response.json())
    assert len(client.get(path).json()) == 3
    item_path = f"{path}/{records[0]['id']}"
    assert client.get(item_path).json() == records[0]

    query = {
        "proximity_uuid": beacon.proximity_uuid,
        "major": 1,
        "minor": 2,
        "lang": "vi",
    }
    resolved = client.get("/beacons/resolve", params=query)
    assert resolved.status_code == 200
    assert [m["id"] for m in resolved.json()["artifact"]["media"]] == [
        records[1]["id"],
        records[0]["id"],
    ]

    updated = client.put(
        item_path,
        json={
            "url": "https://example.com/new",
            "caption": "New",
            "language_id": str(en.id),
            "media_type": "video",
        },
    )
    assert updated.status_code == 200
    assert updated.json()["updated_at"] is not None
    assert updated.json()["url"] == "https://example.com/new"
    assert (
        len(client.get("/beacons/resolve", params=query).json()["artifact"]["media"])
        == 1
    )
    cleared = client.put(item_path, json={"caption": None, "language_id": None})
    assert cleared.json()["caption"] is None
    assert cleared.json()["language_id"] is None
    assert cleared.json()["url"] == "https://example.com/new"
    assert client.delete(item_path).status_code == 200
    assert client.get(item_path).status_code == 404
    assert (
        len(client.get("/beacons/resolve", params=query).json()["artifact"]["media"])
        == 1
    )


@pytest.mark.parametrize(
    "payload",
    [
        {"url": ""},
        {"url": "not-a-url"},
        {"url": "/relative.jpg"},
        {"url": "ftp://example.com/file"},
        {"url": "javascript:alert(1)"},
        {"url": "https://example.com/" + "a" * 500},
        {"media_type": "document"},
        {"url": None},
        {"media_type": None},
        {"sort_order": None},
        {"language_id": "invalid"},
    ],
)
def test_invalid_metadata(media_api, payload) -> None:
    client, _, artifact, *_ = media_api
    path = f"/artifacts/{artifact.id}/media"
    valid = {"url": "https://example.com/image"}
    created = client.post(path, json=valid).json()
    assert client.post(path, json=valid | payload).status_code == 422
    item_path = f"{path}/{created['id']}"
    assert client.put(item_path, json=payload).status_code == 422
    assert client.get(item_path).json() == created


def test_missing_links_and_wrong_artifact(media_api, db: Session) -> None:
    client, _, artifact, *_ = media_api
    path = f"/artifacts/{artifact.id}/media"
    valid = {"url": "https://example.com/image"}
    created = client.post(path, json=valid).json()
    missing_language = {"language_id": str(uuid.uuid4())}
    assert client.post(path, json=valid | missing_language).status_code == 404
    assert (
        client.put(f"{path}/{created['id']}", json=missing_language).status_code == 404
    )
    other = Artifact(site_id=artifact.site_id, code="OTHER")
    db.add(other)
    db.commit()
    for artifact_id in (uuid.uuid4(), other.id):
        wrong_path = f"/artifacts/{artifact_id}/media/{created['id']}"
        assert client.get(wrong_path).status_code == 404
        assert client.put(wrong_path, json=valid).status_code == 404
        assert client.delete(wrong_path).status_code == 404
    missing_path = f"/artifacts/{uuid.uuid4()}/media"
    assert client.get(missing_path).status_code == 404
    assert client.post(missing_path, json=valid).status_code == 404
    assert client.get(f"{path}/{created['id']}").json() == created


@pytest.mark.parametrize("anonymous", [False, True])
def test_media_requires_admin(media_api, anonymous: bool) -> None:
    client, app, artifact, *_ = media_api
    path = f"/artifacts/{artifact.id}/media"
    created = client.post(path, json={"url": "https://example.com/image"}).json()
    if anonymous:
        del app.dependency_overrides[get_current_user]
    else:
        app.dependency_overrides[get_current_user] = lambda: User(
            email="visitor@example.com", hashed_password="unused"
        )
    expected = 401 if anonymous else 403
    for method, url in [
        ("get", path),
        ("post", path),
        ("get", f"{path}/{created['id']}"),
        ("put", f"{path}/{created['id']}"),
        ("delete", f"{path}/{created['id']}"),
    ]:
        assert (
            client.request(
                method, url, json={"url": "https://example.com/new"}
            ).status_code
            == expected
        )

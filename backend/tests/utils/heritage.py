import uuid
from collections.abc import Iterable
from typing import Any

from fastapi.testclient import TestClient
from sqlmodel import Session, col, delete, select

from app.core.config import settings
from app.models import (
    Artifact,
    ArtifactTranslation,
    Beacon,
    Favorite,
    Feedback,
    Media,
    Site,
    VisitLog,
)

API = settings.API_V1_STR


def random_name(prefix: str = "Test") -> str:
    return f"{prefix} {uuid.uuid4().hex[:8]}"


def random_code(prefix: str = "T") -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8].upper()}"


def create_site(
    client: TestClient, headers: dict[str, str], **extra: Any
) -> dict[str, Any]:
    payload = {"name": random_name("Site"), **extra}
    response = client.post(f"{API}/sites/", headers=headers, json=payload)
    assert response.status_code == 200, response.text
    return response.json()  # type: ignore[no-any-return]


def create_artifact(
    client: TestClient, headers: dict[str, str], site_id: str, **extra: Any
) -> dict[str, Any]:
    payload = {"site_id": site_id, "code": random_code("ART"), **extra}
    response = client.post(f"{API}/artifacts/", headers=headers, json=payload)
    assert response.status_code == 200, response.text
    return response.json()  # type: ignore[no-any-return]


def create_beacon(
    client: TestClient,
    headers: dict[str, str],
    site_id: str,
    artifact_id: str | None = None,
    **extra: Any,
) -> dict[str, Any]:
    payload = {
        "proximity_uuid": str(uuid.uuid4()),
        "major": 1,
        "minor": 1,
        "site_id": site_id,
        "artifact_id": artifact_id,
        **extra,
    }
    response = client.post(f"{API}/beacons/", headers=headers, json=payload)
    assert response.status_code == 201, response.text
    return response.json()  # type: ignore[no-any-return]


def get_language_id(client: TestClient, code: str = "vi") -> str:
    languages = client.get(f"{API}/languages/").json()["data"]
    return next(item["id"] for item in languages if item["code"] == code)


def add_translation(
    client: TestClient,
    headers: dict[str, str],
    artifact_id: str,
    language_id: str,
    title: str,
    **extra: Any,
) -> dict[str, Any]:
    response = client.put(
        f"{API}/artifacts/{artifact_id}/translations/{language_id}",
        headers=headers,
        json={"title": title, **extra},
    )
    assert response.status_code == 200, response.text
    return response.json()  # type: ignore[no-any-return]


def resolve_params(beacon: dict[str, Any]) -> str:
    return (
        f"proximity_uuid={beacon['proximity_uuid']}"
        f"&major={beacon['major']}&minor={beacon['minor']}"
    )


def purge_sites(db: Session, site_ids: Iterable[str]) -> None:
    """Xóa dữ liệu test theo đúng thứ tự khóa ngoại (SQL Server dùng NO ACTION)."""
    ids = [uuid.UUID(str(site_id)) for site_id in site_ids]
    if not ids:
        return
    artifact_ids = select(Artifact.id).where(col(Artifact.site_id).in_(ids))
    db.execute(delete(VisitLog).where(col(VisitLog.artifact_id).in_(artifact_ids)))
    db.execute(delete(Favorite).where(col(Favorite.artifact_id).in_(artifact_ids)))
    db.execute(delete(Feedback).where(col(Feedback.artifact_id).in_(artifact_ids)))
    db.execute(delete(Beacon).where(col(Beacon.site_id).in_(ids)))
    db.execute(delete(Media).where(col(Media.artifact_id).in_(artifact_ids)))
    db.execute(
        delete(ArtifactTranslation).where(
            col(ArtifactTranslation.artifact_id).in_(artifact_ids)
        )
    )
    db.execute(delete(Artifact).where(col(Artifact.site_id).in_(ids)))
    db.execute(delete(Site).where(col(Site.id).in_(ids)))
    db.commit()

import uuid

from fastapi.testclient import TestClient
from sqlmodel import Session

from app.core.config import settings
from app.models import Site


def test_site_crud_lifecycle(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
) -> None:
    payload = {
        "name": "Test heritage site",
        "address": "1 Test Street",
        "description": "Created by the Site API test.",
        "latitude": 10.25,
        "longitude": 106.75,
        "cover_image_url": None,
        "is_active": True,
    }
    site_id: uuid.UUID | None = None

    try:
        response = client.post(
            f"{settings.API_V1_STR}/sites/",
            headers=superuser_token_headers,
            json=payload,
        )
        assert response.status_code == 200
        created = response.json()
        site_id = uuid.UUID(created["id"])
        assert created["name"] == payload["name"]
        assert created["created_at"] is not None
        assert created["updated_at"] is None

        listed = client.get(f"{settings.API_V1_STR}/sites/?q=Test%20heritage")
        assert listed.status_code == 200
        assert any(item["id"] == str(site_id) for item in listed.json()["data"])

        detail = client.get(f"{settings.API_V1_STR}/sites/{site_id}")
        assert detail.status_code == 200
        assert detail.json()["address"] == payload["address"]

        update = client.put(
            f"{settings.API_V1_STR}/sites/{site_id}",
            headers=superuser_token_headers,
            json={"name": "Updated test heritage site", "latitude": 11.5},
        )
        assert update.status_code == 200
        assert update.json()["id"] == str(site_id)
        assert update.json()["name"] == "Updated test heritage site"
        assert update.json()["latitude"] == 11.5
        assert update.json()["updated_at"] is not None

        deleted = client.delete(
            f"{settings.API_V1_STR}/sites/{site_id}",
            headers=superuser_token_headers,
        )
        assert deleted.status_code == 200
        assert deleted.json()["message"] == "Site deactivated successfully"

        assert client.get(f"{settings.API_V1_STR}/sites/{site_id}").status_code == 404
        admin_detail = client.get(
            f"{settings.API_V1_STR}/sites/{site_id}",
            headers=superuser_token_headers,
        )
        assert admin_detail.status_code == 200
        assert admin_detail.json()["is_active"] is False
        assert admin_detail.json()["updated_at"] is not None
    finally:
        if site_id is not None:
            site = db.get(Site, site_id)
            if site is not None:
                db.delete(site)
                db.commit()


def test_site_validation_and_missing_id(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    invalid = client.post(
        f"{settings.API_V1_STR}/sites/",
        headers=superuser_token_headers,
        json={"name": "Invalid coordinates", "latitude": 91},
    )
    assert invalid.status_code == 422

    missing_id = uuid.uuid4()
    assert client.get(f"{settings.API_V1_STR}/sites/{missing_id}").status_code == 404

    update = client.put(
        f"{settings.API_V1_STR}/sites/{missing_id}",
        headers=superuser_token_headers,
        json={"name": "Missing site"},
    )
    assert update.status_code == 404

    delete = client.delete(
        f"{settings.API_V1_STR}/sites/{missing_id}",
        headers=superuser_token_headers,
    )
    assert delete.status_code == 404


def test_site_writes_require_admin(
    client: TestClient, normal_user_token_headers: dict[str, str]
) -> None:
    response = client.post(
        f"{settings.API_V1_STR}/sites/",
        headers=normal_user_token_headers,
        json={"name": "Unauthorized site"},
    )
    assert response.status_code == 403

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models import Beacon
from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
    create_beacon,
    create_site,
    get_language_id,
    purge_sites,
    resolve_params,
)


@pytest.fixture
def site_ids(db: Session) -> Generator[list[str]]:
    """Ghi lại id Site tạo trong test để dọn dữ liệu cuối test."""
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


def test_cannot_change_site_of_artifact_that_has_beacon(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site_a = create_site(client, superuser_token_headers)
    site_b = create_site(client, superuser_token_headers)
    site_ids += [site_a["id"], site_b["id"]]
    artifact = create_artifact(client, superuser_token_headers, site_a["id"])
    beacon = create_beacon(
        client, superuser_token_headers, site_a["id"], artifact["id"]
    )

    blocked = client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"site_id": site_b["id"]},
    )
    assert blocked.status_code == 409
    unchanged = client.get(
        f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers
    )
    assert unchanged.json()["site_id"] == site_a["id"]

    unassigned = client.put(
        f"{API}/beacons/{beacon['id']}",
        headers=superuser_token_headers,
        json={"artifact_id": None},
    )
    assert unassigned.status_code == 200
    moved = client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"site_id": site_b["id"]},
    )
    assert moved.status_code == 200
    assert moved.json()["site_id"] == site_b["id"]

    # Beacon đã gỡ hiện vật nên không còn trả nội dung của hiện vật đã chuyển Site
    resolved = client.get(
        f"{API}/beacons/resolve?{resolve_params(beacon)}",
        headers=normal_user_token_headers,
    )
    assert resolved.status_code == 404


def test_cannot_assign_artifact_of_other_site_to_beacon(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site_a = create_site(client, superuser_token_headers)
    site_b = create_site(client, superuser_token_headers)
    site_ids += [site_a["id"], site_b["id"]]
    artifact_b = create_artifact(client, superuser_token_headers, site_b["id"])
    beacon_a = create_beacon(client, superuser_token_headers, site_a["id"])

    response = client.put(
        f"{API}/beacons/{beacon_a['id']}",
        headers=superuser_token_headers,
        json={"artifact_id": artifact_b["id"]},
    )
    assert response.status_code == 400


def test_hidden_site_hides_artifact_and_beacon_content(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    add_translation(
        client,
        superuser_token_headers,
        artifact["id"],
        get_language_id(client),
        "Trống đồng",
    )
    beacon = create_beacon(client, superuser_token_headers, site["id"], artifact["id"])
    resolve_url = f"{API}/beacons/resolve?{resolve_params(beacon)}&lang=vi"

    # Đang hiện: khách xem được
    assert client.get(f"{API}/artifacts/{artifact['id']}").status_code == 200
    visible = client.get(resolve_url, headers=normal_user_token_headers)
    assert visible.status_code == 200
    assert visible.json()["artifact"]["title"] == "Trống đồng"

    # Ẩn Site: khách không thấy gì, admin vẫn xem được
    hidden = client.delete(f"{API}/sites/{site['id']}", headers=superuser_token_headers)
    assert hidden.status_code == 200
    assert client.get(f"{API}/artifacts/{artifact['id']}").status_code == 404
    listed = client.get(f"{API}/artifacts/?site_id={site['id']}").json()
    assert listed["count"] == 0
    assert listed["data"] == []
    assert client.get(resolve_url, headers=normal_user_token_headers).status_code == 404
    admin_view = client.get(
        f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers
    )
    assert admin_view.status_code == 200
    admin_list = client.get(
        f"{API}/artifacts/?site_id={site['id']}&include_inactive=true",
        headers=superuser_token_headers,
    ).json()
    assert admin_list["count"] == 1

    # Bật lại Site: dữ liệu không bị mất, mọi thứ hiện lại
    restored = client.put(
        f"{API}/sites/{site['id']}",
        headers=superuser_token_headers,
        json={"is_active": True},
    )
    assert restored.status_code == 200
    assert client.get(f"{API}/artifacts/{artifact['id']}").status_code == 200
    again = client.get(resolve_url, headers=normal_user_token_headers)
    assert again.status_code == 200
    assert again.json()["artifact"]["id"] == artifact["id"]


def test_cannot_create_data_under_hidden_site(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    active_site = create_site(client, superuser_token_headers)
    hidden_site = create_site(client, superuser_token_headers)
    site_ids += [active_site["id"], hidden_site["id"]]
    artifact = create_artifact(client, superuser_token_headers, active_site["id"])
    client.delete(f"{API}/sites/{hidden_site['id']}", headers=superuser_token_headers)

    create_art = client.post(
        f"{API}/artifacts/",
        headers=superuser_token_headers,
        json={"site_id": hidden_site["id"], "code": "HIDDEN-1"},
    )
    assert create_art.status_code == 409

    create_bea = client.post(
        f"{API}/beacons/",
        headers=superuser_token_headers,
        json={
            "proximity_uuid": "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
            "major": 7,
            "minor": 7,
            "site_id": hidden_site["id"],
        },
    )
    assert create_bea.status_code == 409

    move = client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"site_id": hidden_site["id"]},
    )
    assert move.status_code == 409


def test_can_unassign_beacon_on_hidden_site_but_not_assign(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    other = create_artifact(client, superuser_token_headers, site["id"])
    beacon = create_beacon(client, superuser_token_headers, site["id"], artifact["id"])
    client.delete(f"{API}/sites/{site['id']}", headers=superuser_token_headers)

    assign = client.put(
        f"{API}/beacons/{beacon['id']}",
        headers=superuser_token_headers,
        json={"artifact_id": other["id"]},
    )
    assert assign.status_code == 409
    unassign = client.put(
        f"{API}/beacons/{beacon['id']}",
        headers=superuser_token_headers,
        json={"artifact_id": None},
    )
    assert unassign.status_code == 200
    assert unassign.json()["artifact_id"] is None


def test_resolve_never_returns_content_when_site_mismatch(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    """Dữ liệu bị lệch (sửa thẳng DB) vẫn không được trả nội dung sai quan hệ."""
    site_a = create_site(client, superuser_token_headers)
    site_b = create_site(client, superuser_token_headers)
    site_ids += [site_a["id"], site_b["id"]]
    artifact_b = create_artifact(client, superuser_token_headers, site_b["id"])
    beacon_a = create_beacon(client, superuser_token_headers, site_a["id"])

    row = db.get(Beacon, beacon_a["id"])
    assert row is not None
    row.artifact_id = uuid.UUID(artifact_b["id"])
    db.add(row)
    db.commit()

    response = client.get(
        f"{API}/beacons/resolve?{resolve_params(beacon_a)}",
        headers=normal_user_token_headers,
    )
    assert response.status_code == 409
    assert "artifact" not in response.json()

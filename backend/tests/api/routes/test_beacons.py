"""Kiểm thử HTTP cho API beacon: quét (resolve) và quản trị."""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models import Media
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
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


def _site_with_beacon(
    client: TestClient, admin: dict[str, str], site_ids: list[str]
) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    site = create_site(client, admin)
    site_ids.append(site["id"])
    artifact = create_artifact(client, admin, site["id"])
    add_translation(
        client, admin, artifact["id"], get_language_id(client, "vi"), "Trống đồng"
    )
    add_translation(
        client, admin, artifact["id"], get_language_id(client, "en"), "Bronze drum"
    )
    beacon = create_beacon(client, admin, site["id"], artifact["id"])
    return site, artifact, beacon


def test_resolve_beacon_returns_artifact_in_requested_language(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    _, artifact, beacon = _site_with_beacon(client, superuser_token_headers, site_ids)
    db.add(
        Media(
            artifact_id=uuid.UUID(artifact["id"]),
            media_type="image",
            url="/media/drum.jpg",
            sort_order=1,
        )
    )
    db.commit()
    url = f"{API}/beacons/resolve?{resolve_params(beacon)}"

    english = client.get(f"{url}&lang=en", headers=normal_user_token_headers)
    assert english.status_code == 200
    body = english.json()
    assert body["beacon"]["id"] == beacon["id"]
    assert body["beacon"]["last_seen_at"] is not None
    assert body["artifact"]["id"] == artifact["id"]
    assert body["artifact"]["title"] == "Bronze drum"
    assert [m["url"] for m in body["artifact"]["media"]] == ["/media/drum.jpg"]

    vietnamese = client.get(f"{url}&lang=vi", headers=normal_user_token_headers)
    assert vietnamese.json()["artifact"]["title"] == "Trống đồng"

    # UUID chữ thường vẫn nhận ra; admin cũng gọi được
    lower = url.replace(beacon["proximity_uuid"], beacon["proximity_uuid"].lower())
    assert client.get(lower, headers=superuser_token_headers).status_code == 200


def test_resolve_beacon_error_cases(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    unassigned = create_beacon(client, superuser_token_headers, site["id"])
    visitor = normal_user_token_headers
    base = f"{API}/beacons/resolve"

    # thiếu token -> 401
    assert client.get(f"{base}?{resolve_params(unassigned)}").status_code == 401
    # beacon chưa gán hiện vật / không tồn tại -> 404
    assert (
        client.get(f"{base}?{resolve_params(unassigned)}", headers=visitor).status_code
        == 404
    )
    unknown = f"{base}?proximity_uuid={uuid.uuid4()}&major=1&minor=1"
    assert client.get(unknown, headers=visitor).status_code == 404
    # dữ liệu sai -> 422
    bad_uuid = f"{base}?proximity_uuid=abc&major=1&minor=1"
    assert client.get(bad_uuid, headers=visitor).status_code == 422
    too_big = f"{base}?proximity_uuid={uuid.uuid4()}&major=70000&minor=1"
    assert client.get(too_big, headers=visitor).status_code == 422
    missing = f"{base}?proximity_uuid={uuid.uuid4()}&major=1"
    assert client.get(missing, headers=visitor).status_code == 422


def test_deactivated_beacon_cannot_be_resolved(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    _, _, beacon = _site_with_beacon(client, superuser_token_headers, site_ids)
    deleted = client.delete(
        f"{API}/beacons/{beacon['id']}", headers=superuser_token_headers
    )
    assert deleted.status_code == 200
    response = client.get(
        f"{API}/beacons/resolve?{resolve_params(beacon)}",
        headers=normal_user_token_headers,
    )
    assert response.status_code == 404
    detail = client.get(
        f"{API}/beacons/{beacon['id']}", headers=superuser_token_headers
    ).json()
    assert detail["is_active"] is False
    assert detail["artifact_id"] is None


def test_beacon_admin_crud_over_http(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    other = create_artifact(client, superuser_token_headers, site["id"])
    headers = superuser_token_headers
    puuid = str(uuid.uuid4())
    body = {
        "proximity_uuid": puuid.lower(),
        "major": 10,
        "minor": 20,
        "site_id": site["id"],
        "artifact_id": artifact["id"],
    }

    created = client.post(f"{API}/beacons/", headers=headers, json=body)
    assert created.status_code == 201
    beacon = created.json()
    assert beacon["proximity_uuid"] == puuid.upper()  # lưu chữ HOA
    assert beacon["tx_power"] == -59  # mặc định theo ERD
    assert beacon["rssi_threshold"] == -80

    # Trùng (uuid, major, minor) -> 409
    assert client.post(f"{API}/beacons/", headers=headers, json=body).status_code == 409
    # Hiện vật đã gắn beacon khác -> 409
    second = {**body, "minor": 21}
    assert (
        client.post(f"{API}/beacons/", headers=headers, json=second).status_code == 409
    )

    detail = client.get(f"{API}/beacons/{beacon['id']}", headers=headers)
    assert detail.status_code == 200
    listed = client.get(
        f"{API}/beacons/?site_id={site['id']}&artifact_id={artifact['id']}",
        headers=headers,
    ).json()
    assert [item["id"] for item in listed["data"]] == [beacon["id"]]

    moved = client.put(
        f"{API}/beacons/{beacon['id']}",
        headers=headers,
        json={"artifact_id": other["id"], "battery_level": 80},
    )
    assert moved.status_code == 200
    assert moved.json()["artifact_id"] == other["id"]
    assert moved.json()["battery_level"] == 80
    assert moved.json()["updated_at"] is not None

    # Trường bắt buộc không được đặt null
    null_field = client.put(
        f"{API}/beacons/{beacon['id']}", headers=headers, json={"major": None}
    )
    assert null_field.status_code == 422


def test_beacon_active_null_rejected_and_unassignment_preserved(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    beacon = create_beacon(client, superuser_token_headers, site["id"], artifact["id"])
    url = f"{API}/beacons/{beacon['id']}"
    headers = superuser_token_headers
    assert client.put(url, headers=headers, json={"is_active": None}).status_code == 422
    assert client.get(url, headers=headers).json() == beacon
    unassigned = client.put(url, headers=headers, json={"artifact_id": None})
    assert unassigned.status_code == 200
    assert unassigned.json()["artifact_id"] is None
    assert unassigned.json()["is_active"] is True
    disabled = client.put(url, headers=headers, json={"is_active": False})
    assert disabled.status_code == 200
    assert disabled.json()["is_active"] is False


def test_beacon_validation_errors(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    headers = superuser_token_headers
    ok_body = {
        "proximity_uuid": str(uuid.uuid4()),
        "major": 1,
        "minor": 1,
        "site_id": site["id"],
    }
    for change in (
        {"major": 70000},
        {"minor": -1},
        {"site_id": "abc"},
        {"proximity_uuid": "x" * 40},
    ):
        response = client.post(
            f"{API}/beacons/", headers=headers, json={**ok_body, **change}
        )
        assert response.status_code == 422, change
    unknown_site = {**ok_body, "site_id": str(uuid.uuid4())}
    assert (
        client.post(f"{API}/beacons/", headers=headers, json=unknown_site).status_code
        == 404
    )
    unknown_artifact = {**ok_body, "artifact_id": str(uuid.uuid4())}
    assert (
        client.post(
            f"{API}/beacons/", headers=headers, json=unknown_artifact
        ).status_code
        == 404
    )
    assert (
        client.get(f"{API}/beacons/{uuid.uuid4()}", headers=headers).status_code == 404
    )
    assert client.get(f"{API}/beacons/?limit=201", headers=headers).status_code == 422


def test_beacon_admin_endpoints_require_admin(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    beacon = create_beacon(client, superuser_token_headers, site["id"])
    base = f"{API}/beacons"
    new_body = {
        "proximity_uuid": str(uuid.uuid4()),
        "major": 5,
        "minor": 5,
        "site_id": site["id"],
    }
    calls = [
        ("get", f"{base}/", None),
        ("get", f"{base}/{beacon['id']}", None),
        ("post", f"{base}/", new_body),
        ("put", f"{base}/{beacon['id']}", {"battery_level": 1}),
        ("delete", f"{base}/{beacon['id']}", None),
    ]
    for method, url, body in calls:
        kwargs = {"json": body} if body is not None else {}
        assert getattr(client, method)(url, **kwargs).status_code == 401, (method, url)
        visitor = getattr(client, method)(
            url, headers=normal_user_token_headers, **kwargs
        )
        assert visitor.status_code == 403, (method, url)
    still = client.get(f"{base}/{beacon['id']}", headers=superuser_token_headers).json()
    assert still["is_active"] is True

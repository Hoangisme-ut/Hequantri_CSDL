"""Kiểm thử luồng đầu-cuối của các API mới (cho app du khách).

Luồng: admin chuẩn bị dữ liệu -> visitor quét beacon -> ghi lượt xem ->
yêu thích -> xem lịch sử; sau đó ẩn Site và bật lại.
"""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

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


def test_visitor_journey_from_beacon_to_history(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    admin, visitor = superuser_token_headers, normal_user_token_headers
    # 1. Admin chuẩn bị di tích, hiện vật hai ngôn ngữ và beacon
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

    # 2. Visitor xem danh sách (public) theo ngôn ngữ
    sites = client.get(f"{API}/sites/").json()["data"]
    assert site["id"] in [item["id"] for item in sites]
    listed = client.get(f"{API}/artifacts/?site_id={site['id']}&lang=en").json()
    assert listed["data"][0]["title"] == "Bronze drum"

    # 3. Quét beacon -> nhận nội dung đúng ngôn ngữ
    scan = client.get(
        f"{API}/beacons/resolve?{resolve_params(beacon)}&lang=en", headers=visitor
    )
    assert scan.status_code == 200
    assert scan.json()["artifact"]["title"] == "Bronze drum"

    # 4. Ghi lượt xem: lần đầu 201, lặp lại (như nhận BLE nhiều lần) 200
    payload = {"artifact_id": artifact["id"], "beacon_id": beacon["id"], "rssi": -60}
    first = client.post(f"{API}/visits/", headers=visitor, json=payload)
    again = client.post(f"{API}/visits/", headers=visitor, json=payload)
    assert (first.status_code, again.status_code) == (201, 200)
    assert again.json()["id"] == first.json()["id"]

    # 5. Yêu thích: lần đầu 201, lặp lại 200
    fav = {"artifact_id": artifact["id"]}
    f1 = client.post(f"{API}/favorites/", headers=visitor, json=fav)
    f2 = client.post(f"{API}/favorites/", headers=visitor, json=fav)
    assert (f1.status_code, f2.status_code) == (201, 200)

    # 6. Lịch sử và yêu thích có đúng một dòng cho hiện vật này
    def mine(path: str) -> list[dict[str, str]]:
        data = client.get(f"{API}{path}?lang=en&limit=100", headers=visitor).json()
        return [x for x in data["data"] if x["artifact_id"] == artifact["id"]]

    assert len(mine("/visits/me")) == 1
    assert mine("/visits/me")[0]["artifact"]["title"] == "Bronze drum"
    assert len(mine("/favorites/me")) == 1

    # 7. Ẩn Site: lịch sử, yêu thích và quét beacon đều không còn trả hiện vật
    client.delete(f"{API}/sites/{site['id']}", headers=admin)
    assert mine("/visits/me") == []
    assert mine("/favorites/me") == []
    hidden_scan = client.get(
        f"{API}/beacons/resolve?{resolve_params(beacon)}", headers=visitor
    )
    assert hidden_scan.status_code == 404

    # 8. Bật lại Site: dữ liệu của du khách vẫn còn
    client.put(f"{API}/sites/{site['id']}", headers=admin, json={"is_active": True})
    assert len(mine("/visits/me")) == 1
    assert len(mine("/favorites/me")) == 1


@pytest.mark.parametrize(
    ("method", "path", "body"),
    [
        ("get", "/favorites/me", None),
        ("post", "/favorites/", {"artifact_id": str(uuid.uuid4())}),
        ("delete", f"/favorites/{uuid.uuid4()}", None),
        ("get", "/visits/me", None),
        ("post", "/visits/", {"artifact_id": str(uuid.uuid4())}),
        (
            "get",
            f"/beacons/resolve?proximity_uuid={uuid.uuid4()}&major=1&minor=1",
            None,
        ),
    ],
)
def test_new_visitor_apis_require_token(
    client: TestClient, method: str, path: str, body: dict[str, str] | None
) -> None:
    kwargs = {"json": body} if body is not None else {}
    response = getattr(client, method)(f"{API}{path}", **kwargs)
    assert response.status_code == 401

"""Kiểm thử HTTP cho API lượt xem và lịch sử tham quan (/visits)."""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app import crud
from app.models import VisitLog
from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
    create_beacon,
    create_site,
    get_language_id,
    purge_sites,
)
from tests.utils.user import authentication_token_from_email


@pytest.fixture
def site_ids(db: Session) -> Generator[list[str]]:
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


@pytest.fixture
def other_user_headers(client: TestClient, db: Session) -> dict[str, str]:
    return authentication_token_from_email(
        client=client, email="visit-other@example.com", db=db
    )


def _artifact(
    client: TestClient, admin: dict[str, str], site_ids: list[str], title: str
) -> dict[str, str]:
    site = create_site(client, admin)
    site_ids.append(site["id"])
    artifact = create_artifact(client, admin, site["id"])
    add_translation(client, admin, artifact["id"], get_language_id(client), title)
    return artifact


def test_record_visit_and_read_history(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids, "Trống đồng")
    created = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "rssi": -62, "duration_seconds": 30},
    )
    assert created.status_code == 201
    visit = created.json()
    assert visit["artifact_id"] == artifact["id"]
    assert visit["rssi"] == -62
    assert visit["language_id"] is not None  # tự lấy ngôn ngữ mặc định
    assert visit["visited_at"] is not None

    history = client.get(f"{API}/visits/me", headers=normal_user_token_headers)
    assert history.status_code == 200
    body = history.json()
    mine = [item for item in body["data"] if item["id"] == visit["id"]]
    assert len(mine) == 1
    assert mine[0]["artifact"]["title"] == "Trống đồng"


def test_repeated_signal_within_window_is_one_visit(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    """Gửi lại nhiều lần (như nhận BLE lặp) chỉ tạo 1 lượt xem."""
    artifact = _artifact(client, superuser_token_headers, site_ids, "Bình gốm")
    payload = {"artifact_id": artifact["id"]}
    responses = [
        client.post(f"{API}/visits/", headers=normal_user_token_headers, json=payload)
        for _ in range(3)
    ]
    assert [r.status_code for r in responses] == [201, 200, 200]
    assert len({r.json()["id"] for r in responses}) == 1
    rows = db.exec(
        select(VisitLog).where(col(VisitLog.artifact_id) == uuid.UUID(artifact["id"]))
    ).all()
    assert len(rows) == 1


def test_new_visit_after_window_is_recorded(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids, "Tượng")
    payload = {"artifact_id": artifact["id"]}
    first = client.post(
        f"{API}/visits/", headers=normal_user_token_headers, json=payload
    )
    assert first.status_code == 201

    # Lùi thời điểm của lượt xem cũ ra ngoài cửa sổ chặn trùng
    row = db.get(VisitLog, uuid.UUID(first.json()["id"]))
    assert row is not None
    assert row.visited_at is not None
    row.visited_at = row.visited_at.replace(year=row.visited_at.year - 1)
    db.add(row)
    db.commit()
    assert crud.VISIT_DEDUP_SECONDS == 300

    second = client.post(
        f"{API}/visits/", headers=normal_user_token_headers, json=payload
    )
    assert second.status_code == 201
    assert second.json()["id"] != first.json()["id"]


def test_visits_require_token(client: TestClient) -> None:
    assert client.get(f"{API}/visits/me").status_code == 401
    response = client.post(f"{API}/visits/", json={"artifact_id": str(uuid.uuid4())})
    assert response.status_code == 401


def test_visit_validation_errors(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    unknown = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": str(uuid.uuid4())},
    )
    assert unknown.status_code == 404

    artifact = _artifact(client, superuser_token_headers, site_ids, "A")
    other = _artifact(client, superuser_token_headers, site_ids, "B")
    beacon_of_other = create_beacon(
        client,
        superuser_token_headers,
        client.get(
            f"{API}/artifacts/{other['id']}", headers=superuser_token_headers
        ).json()["site_id"],
        other["id"],
    )
    wrong_beacon = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "beacon_id": beacon_of_other["id"]},
    )
    assert wrong_beacon.status_code == 400

    no_beacon = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "beacon_id": str(uuid.uuid4())},
    )
    assert no_beacon.status_code == 404
    no_lang = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "language_id": str(uuid.uuid4())},
    )
    assert no_lang.status_code == 404
    negative = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "duration_seconds": -1},
    )
    assert negative.status_code == 422

    client.delete(f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers)
    hidden = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert hidden.status_code == 404


def test_visit_with_matching_beacon(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    beacon = create_beacon(client, superuser_token_headers, site["id"], artifact["id"])
    response = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"], "beacon_id": beacon["id"]},
    )
    assert response.status_code == 201
    assert response.json()["beacon_id"] == beacon["id"]


def test_history_is_private_and_paginated(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    other_user_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact_ids = []
    for index in range(3):
        artifact = create_artifact(client, superuser_token_headers, site["id"])
        add_translation(
            client,
            superuser_token_headers,
            artifact["id"],
            get_language_id(client),
            f"Hiện vật {index}",
        )
        artifact_ids.append(artifact["id"])
        client.post(
            f"{API}/visits/",
            headers=other_user_headers,
            json={"artifact_id": artifact["id"]},
        )

    page = client.get(
        f"{API}/visits/me?skip=1&limit=1", headers=other_user_headers
    ).json()
    assert page["count"] >= 3
    assert len(page["data"]) == 1
    # mới nhất trước: lượt đầu trang 0 là hiện vật cuối cùng được xem
    first_page = client.get(
        f"{API}/visits/me?limit=3", headers=other_user_headers
    ).json()
    assert [v["artifact_id"] for v in first_page["data"]] == artifact_ids[::-1]

    # Người khác không thấy lịch sử của tôi
    others = client.get(f"{API}/visits/me", headers=normal_user_token_headers).json()
    assert all(v["artifact_id"] not in artifact_ids for v in others["data"])

    for bad in ("limit=0", "limit=101", "skip=-1"):
        assert (
            client.get(f"{API}/visits/me?{bad}", headers=other_user_headers).status_code
            == 422
        )

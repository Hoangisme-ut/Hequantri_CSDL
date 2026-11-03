"""Kiểm thử HTTP cho API yêu thích hiện vật (/favorites)."""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
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
        client=client, email="favorite-other@example.com", db=db
    )


def _setup_artifact(
    client: TestClient, admin: dict[str, str], site_ids: list[str], title: str
) -> dict[str, str]:
    site = create_site(client, admin)
    site_ids.append(site["id"])
    artifact = create_artifact(client, admin, site["id"])
    add_translation(client, admin, artifact["id"], get_language_id(client), title)
    return artifact


def test_add_list_and_remove_favorite(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _setup_artifact(client, superuser_token_headers, site_ids, "Trống đồng")

    created = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert created.status_code == 201
    favorite = created.json()
    assert favorite["artifact_id"] == artifact["id"]

    listed = client.get(f"{API}/favorites/me", headers=normal_user_token_headers)
    assert listed.status_code == 200
    body = listed.json()
    mine = [item for item in body["data"] if item["artifact_id"] == artifact["id"]]
    assert len(mine) == 1
    assert mine[0]["artifact"]["title"] == "Trống đồng"

    removed = client.delete(
        f"{API}/favorites/{artifact['id']}", headers=normal_user_token_headers
    )
    assert removed.status_code == 200
    again = client.delete(
        f"{API}/favorites/{artifact['id']}", headers=normal_user_token_headers
    )
    assert again.status_code == 404
    after = client.get(f"{API}/favorites/me", headers=normal_user_token_headers).json()
    assert all(item["artifact_id"] != artifact["id"] for item in after["data"])


def test_adding_twice_does_not_create_duplicate(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _setup_artifact(client, superuser_token_headers, site_ids, "Bình gốm")
    first = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    second = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    listed = client.get(f"{API}/favorites/me", headers=normal_user_token_headers).json()
    assert [i["artifact_id"] for i in listed["data"]].count(artifact["id"]) == 1


def test_favorites_require_token(client: TestClient) -> None:
    random_id = str(uuid.uuid4())
    assert client.get(f"{API}/favorites/me").status_code == 401
    assert (
        client.post(f"{API}/favorites/", json={"artifact_id": random_id}).status_code
        == 401
    )
    assert client.delete(f"{API}/favorites/{random_id}").status_code == 401


def test_cannot_favorite_unknown_or_hidden_artifact(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    unknown = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": str(uuid.uuid4())},
    )
    assert unknown.status_code == 404

    artifact = _setup_artifact(client, superuser_token_headers, site_ids, "Ẩn")
    client.delete(f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers)
    hidden = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert hidden.status_code == 404

    invalid = client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": "not-a-uuid"},
    )
    assert invalid.status_code == 422


def test_hidden_artifact_disappears_from_favorites_and_comes_back(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _setup_artifact(client, superuser_token_headers, site_ids, "Tượng")
    client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    client.delete(f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers)
    hidden = client.get(f"{API}/favorites/me", headers=normal_user_token_headers).json()
    assert all(item["artifact_id"] != artifact["id"] for item in hidden["data"])

    client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"is_active": True},
    )
    back = client.get(f"{API}/favorites/me", headers=normal_user_token_headers).json()
    assert any(item["artifact_id"] == artifact["id"] for item in back["data"])


def test_favorites_are_private_between_users(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    other_user_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    artifact = _setup_artifact(client, superuser_token_headers, site_ids, "Riêng tư")
    client.post(
        f"{API}/favorites/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )

    # Người khác không thấy và không xóa được bản ghi của tôi
    others = client.get(f"{API}/favorites/me", headers=other_user_headers).json()
    assert all(item["artifact_id"] != artifact["id"] for item in others["data"])
    stolen = client.delete(
        f"{API}/favorites/{artifact['id']}", headers=other_user_headers
    )
    assert stolen.status_code == 404
    mine = client.get(f"{API}/favorites/me", headers=normal_user_token_headers).json()
    assert any(item["artifact_id"] == artifact["id"] for item in mine["data"])

    # Người khác yêu thích cùng hiện vật vẫn tạo bản ghi riêng
    theirs = client.post(
        f"{API}/favorites/",
        headers=other_user_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert theirs.status_code == 201


def test_favorites_pagination_and_language(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    other_user_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    vi_id = get_language_id(client, "vi")
    for index in range(3):
        artifact = create_artifact(client, superuser_token_headers, site["id"])
        add_translation(
            client, superuser_token_headers, artifact["id"], vi_id, f"Hiện vật {index}"
        )
        client.post(
            f"{API}/favorites/",
            headers=other_user_headers,
            json={"artifact_id": artifact["id"]},
        )

    page = client.get(
        f"{API}/favorites/me?skip=1&limit=1&lang=en", headers=other_user_headers
    ).json()
    assert page["count"] >= 3
    assert len(page["data"]) == 1
    # Chưa có bản dịch tiếng Anh -> dùng tiếng Việt và đánh dấu dự phòng
    assert page["data"][0]["artifact"]["is_fallback"] is True
    assert page["data"][0]["artifact"]["language_code"] == "vi"

    assert (
        client.get(
            f"{API}/favorites/me?limit=0", headers=other_user_headers
        ).status_code
        == 422
    )

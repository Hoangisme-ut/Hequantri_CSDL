"""Kiểm thử HTTP bổ sung cho API Site: dữ liệu sai, thiếu token, sai quyền."""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from tests.utils.heritage import API, create_site, purge_sites


@pytest.fixture
def site_ids(db: Session) -> Generator[list[str]]:
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


def test_read_sites_is_public_and_paginated(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    for _ in range(3):
        site_ids.append(create_site(client, superuser_token_headers)["id"])
    page = client.get(f"{API}/sites/?skip=1&limit=1")
    assert page.status_code == 200
    body = page.json()
    assert body["count"] >= 3
    assert len(body["data"]) == 1
    assert client.get(f"{API}/sites/?limit=201").status_code == 422


def test_hidden_site_visible_only_to_admin_with_flag(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    client.delete(f"{API}/sites/{site['id']}", headers=superuser_token_headers)

    def ids(headers: dict[str, str] | None) -> list[str]:
        response = client.get(f"{API}/sites/?include_inactive=true", headers=headers)
        return [item["id"] for item in response.json()["data"]]

    assert site["id"] not in ids(None)
    assert site["id"] not in ids(normal_user_token_headers)
    assert site["id"] in ids(superuser_token_headers)


def test_site_validation_errors(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    empty_name = client.post(
        f"{API}/sites/", headers=superuser_token_headers, json={"name": ""}
    )
    assert empty_name.status_code == 422
    missing_name = client.post(
        f"{API}/sites/", headers=superuser_token_headers, json={}
    )
    assert missing_name.status_code == 422
    unknown = client.get(f"{API}/sites/{uuid.uuid4()}")
    assert unknown.status_code == 404
    bad_id = client.get(f"{API}/sites/not-a-uuid")
    assert bad_id.status_code == 422
    update_unknown = client.put(
        f"{API}/sites/{uuid.uuid4()}",
        headers=superuser_token_headers,
        json={"name": "x"},
    )
    assert update_unknown.status_code == 404


def test_site_write_requires_admin(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    target = f"{API}/sites/{site['id']}"

    assert client.post(f"{API}/sites/", json={"name": "x"}).status_code == 401
    assert client.put(target, json={"name": "x"}).status_code == 401
    assert client.delete(target).status_code == 401

    visitor = normal_user_token_headers
    assert (
        client.post(f"{API}/sites/", headers=visitor, json={"name": "x"}).status_code
        == 403
    )
    assert client.put(target, headers=visitor, json={"name": "x"}).status_code == 403
    assert client.delete(target, headers=visitor).status_code == 403
    # dữ liệu không bị đổi
    assert client.get(target).json()["name"] == site["name"]

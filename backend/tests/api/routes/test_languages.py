"""Kiểm thử HTTP cho API ngôn ngữ (/languages)."""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, delete

from app.models import Language
from tests.utils.heritage import API


@pytest.fixture
def created_languages(db: Session) -> Generator[list[str]]:
    """Dọn ngôn ngữ tạo trong test (API chỉ xóa mềm nên xóa cứng bằng DB)."""
    ids: list[str] = []
    yield ids
    db.execute(
        delete(Language).where(col(Language.id).in_([uuid.UUID(i) for i in ids]))
    )
    db.commit()


def _code() -> str:
    return f"t{uuid.uuid4().hex[:6]}"


def test_list_languages_is_public_and_has_default(client: TestClient) -> None:
    response = client.get(f"{API}/languages/")
    assert response.status_code == 200
    body = response.json()
    codes = {item["code"]: item for item in body["data"]}
    assert {"vi", "en"} <= set(codes)
    assert codes["vi"]["is_default"] is True
    assert sum(item["is_default"] for item in body["data"]) == 1
    assert body["count"] == len(body["data"])


def test_language_lifecycle_as_admin(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    created_languages: list[str],
) -> None:
    code = _code()
    created = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": code, "name": "Tiếng thử nghiệm"},
    )
    assert created.status_code == 200
    language = created.json()
    created_languages.append(language["id"])
    assert language["is_default"] is False

    duplicate = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": code, "name": "Trùng mã"},
    )
    assert duplicate.status_code == 409

    updated = client.put(
        f"{API}/languages/{language['id']}",
        headers=superuser_token_headers,
        json={"name": "Tên mới"},
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Tên mới"

    deleted = client.delete(
        f"{API}/languages/{language['id']}", headers=superuser_token_headers
    )
    assert deleted.status_code == 200
    listed = client.get(f"{API}/languages/").json()["data"]
    assert all(item["id"] != language["id"] for item in listed)


def test_switching_default_language_keeps_exactly_one_default(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    created_languages: list[str],
) -> None:
    languages = client.get(f"{API}/languages/").json()["data"]
    vi = next(item for item in languages if item["code"] == "vi")
    new = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": _code(), "name": "Mặc định mới"},
    ).json()
    created_languages.append(new["id"])
    try:
        switched = client.put(
            f"{API}/languages/{new['id']}",
            headers=superuser_token_headers,
            json={"is_default": True},
        )
        assert switched.status_code == 200
        data = client.get(f"{API}/languages/").json()["data"]
        defaults = [item["code"] for item in data if item["is_default"]]
        assert defaults == [new["code"]]

        # Không được bỏ cờ mặc định mà không chỉ định ngôn ngữ thay thế
        refused = client.put(
            f"{API}/languages/{new['id']}",
            headers=superuser_token_headers,
            json={"is_default": False},
        )
        assert refused.status_code == 400
        # Không tắt được ngôn ngữ đang là mặc định
        assert (
            client.delete(
                f"{API}/languages/{new['id']}", headers=superuser_token_headers
            ).status_code
            == 400
        )
    finally:
        client.put(
            f"{API}/languages/{vi['id']}",
            headers=superuser_token_headers,
            json={"is_default": True},
        )
    data = client.get(f"{API}/languages/").json()["data"]
    assert [item["code"] for item in data if item["is_default"]] == ["vi"]


def test_language_validation_errors(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    missing_name = client.post(
        f"{API}/languages/", headers=superuser_token_headers, json={"code": "zz"}
    )
    assert missing_name.status_code == 422
    too_long = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": "x" * 11, "name": "Quá dài"},
    )
    assert too_long.status_code == 422
    unknown = client.put(
        f"{API}/languages/{uuid.uuid4()}",
        headers=superuser_token_headers,
        json={"name": "x"},
    )
    assert unknown.status_code == 404
    bad_id = client.put(
        f"{API}/languages/not-a-uuid",
        headers=superuser_token_headers,
        json={"name": "x"},
    )
    assert bad_id.status_code == 422


def test_language_write_requires_admin(
    client: TestClient, normal_user_token_headers: dict[str, str]
) -> None:
    body = {"code": _code(), "name": "Không được tạo"}
    target = f"{API}/languages/{uuid.uuid4()}"
    # thiếu token -> 401
    assert client.post(f"{API}/languages/", json=body).status_code == 401
    assert client.put(target, json={"name": "x"}).status_code == 401
    assert client.delete(target).status_code == 401
    # visitor -> 403
    visitor = normal_user_token_headers
    assert (
        client.post(f"{API}/languages/", headers=visitor, json=body).status_code == 403
    )
    assert client.put(target, headers=visitor, json={"name": "x"}).status_code == 403
    assert client.delete(target, headers=visitor).status_code == 403


@pytest.mark.parametrize("field", ["code", "name", "is_active", "is_default"])
def test_language_update_rejects_null_required_fields(
    client: TestClient, superuser_token_headers: dict[str, str], field: str
) -> None:
    before = client.get(f"{API}/languages/").json()
    language = before["data"][0]
    response = client.put(
        f"{API}/languages/{language['id']}",
        headers=superuser_token_headers,
        json={field: None},
    )
    assert response.status_code == 422
    assert client.get(f"{API}/languages/").json() == before


def test_default_cannot_be_inactive_through_create_or_update(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    created_languages: list[str],
) -> None:
    headers = superuser_token_headers
    before = client.get(f"{API}/languages/").json()
    default = next(item for item in before["data"] if item["is_default"])
    invalid = client.post(
        f"{API}/languages/",
        headers=headers,
        json={
            "code": _code(),
            "name": "Invalid",
            "is_active": False,
            "is_default": True,
        },
    )
    assert invalid.status_code == 400
    assert (
        client.put(
            f"{API}/languages/{default['id']}",
            headers=headers,
            json={"is_active": False},
        ).status_code
        == 400
    )
    assert client.get(f"{API}/languages/").json() == before
    hidden = client.post(
        f"{API}/languages/",
        headers=headers,
        json={"code": _code(), "name": "Hidden", "is_active": False},
    ).json()
    created_languages.append(hidden["id"])
    assert (
        client.put(
            f"{API}/languages/{hidden['id']}",
            headers=headers,
            json={"is_default": True},
        ).status_code
        == 400
    )
    assert (
        client.put(
            f"{API}/languages/{hidden['id']}", headers=headers, json={}
        ).status_code
        == 200
    )


def test_only_admin_can_list_inactive_languages_and_restore_them(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    created_languages: list[str],
) -> None:
    hidden = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": _code(), "name": "Hidden", "is_active": False},
    ).json()
    created_languages.append(hidden["id"])
    for headers in ({}, normal_user_token_headers, superuser_token_headers):
        default = client.get(f"{API}/languages/", headers=headers).json()
        assert hidden["id"] not in {x["id"] for x in default["data"]}
        response = client.get(
            f"{API}/languages/?include_inactive=true", headers=headers
        ).json()
        assert (hidden["id"] in {x["id"] for x in response["data"]}) == (
            headers == superuser_token_headers
        )
        assert response["count"] == len(response["data"])
    restored = client.put(
        f"{API}/languages/{hidden['id']}",
        headers=superuser_token_headers,
        json={"is_active": True},
    )
    assert restored.status_code == 200
    assert hidden["id"] in {
        x["id"] for x in client.get(f"{API}/languages/").json()["data"]
    }

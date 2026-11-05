"""Kiểm thử HTTP cho API hiện vật (/artifacts) và nội dung theo ngôn ngữ."""

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
    random_code,
)


@pytest.fixture
def site_ids(db: Session) -> Generator[list[str]]:
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


@pytest.mark.parametrize("field", ["site_id", "code", "is_active"])
def test_artifact_update_null_required_fields_leave_record_unchanged(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
    field: str,
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(
        client, superuser_token_headers, site["id"], era="Old era"
    )
    url = f"{API}/artifacts/{artifact['id']}"
    before = client.get(url).json()
    response = client.put(url, headers=superuser_token_headers, json={field: None})
    assert response.status_code == 422
    assert client.get(url).json() == before
    cleared = client.put(url, headers=superuser_token_headers, json={"era": None})
    assert cleared.status_code == 200
    assert cleared.json()["era"] is None
    assert cleared.json()["code"] == artifact["code"]
    assert cleared.json()["site_id"] == site["id"]
    assert cleared.json()["is_active"] is True
    assert client.put(url, headers=superuser_token_headers, json={}).status_code == 200


def test_artifact_crud_lifecycle(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    other_site = create_site(client, superuser_token_headers)
    site_ids += [site["id"], other_site["id"]]
    code = random_code("CRUD")

    created = client.post(
        f"{API}/artifacts/",
        headers=superuser_token_headers,
        json={"site_id": site["id"], "code": code, "era": "Thế kỷ 11"},
    )
    assert created.status_code == 200
    artifact = created.json()
    assert artifact["is_active"] is True
    assert artifact["updated_at"] is None

    # Trùng mã trong cùng Site -> 409; khác Site thì được
    dup = client.post(
        f"{API}/artifacts/",
        headers=superuser_token_headers,
        json={"site_id": site["id"], "code": code},
    )
    assert dup.status_code == 409
    same_code_other_site = client.post(
        f"{API}/artifacts/",
        headers=superuser_token_headers,
        json={"site_id": other_site["id"], "code": code},
    )
    assert same_code_other_site.status_code == 200

    listed = client.get(f"{API}/artifacts/?site_id={site['id']}&q={code}").json()
    assert listed["count"] == 1
    assert listed["data"][0]["id"] == artifact["id"]

    updated = client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"era": "Thế kỷ 12"},
    )
    assert updated.status_code == 200
    assert updated.json()["era"] == "Thế kỷ 12"
    assert updated.json()["updated_at"] is not None

    # Đổi mã thành mã đã có trong Site -> 409
    second = create_artifact(client, superuser_token_headers, site["id"])
    clash = client.put(
        f"{API}/artifacts/{second['id']}",
        headers=superuser_token_headers,
        json={"code": code},
    )
    assert clash.status_code == 409

    # Xóa mềm: khách không thấy, admin vẫn thấy và bật lại được
    hidden = client.delete(
        f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers
    )
    assert hidden.status_code == 200
    assert client.get(f"{API}/artifacts/{artifact['id']}").status_code == 404
    assert (
        client.get(
            f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers
        ).status_code
        == 200
    )
    restored = client.put(
        f"{API}/artifacts/{artifact['id']}",
        headers=superuser_token_headers,
        json={"is_active": True},
    )
    assert restored.status_code == 200
    assert client.get(f"{API}/artifacts/{artifact['id']}").status_code == 200


def test_artifact_validation_errors(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    headers = superuser_token_headers

    missing_code = client.post(
        f"{API}/artifacts/", headers=headers, json={"site_id": site["id"]}
    )
    assert missing_code.status_code == 422
    unknown_site = client.post(
        f"{API}/artifacts/",
        headers=headers,
        json={"site_id": str(uuid.uuid4()), "code": "X-1"},
    )
    assert unknown_site.status_code == 404
    bad_site = client.post(
        f"{API}/artifacts/", headers=headers, json={"site_id": "abc", "code": "X-1"}
    )
    assert bad_site.status_code == 422
    unknown = client.get(f"{API}/artifacts/{uuid.uuid4()}")
    assert unknown.status_code == 404
    assert client.get(f"{API}/artifacts/not-a-uuid").status_code == 422
    assert client.get(f"{API}/artifacts/?limit=201").status_code == 422
    update_unknown = client.put(
        f"{API}/artifacts/{uuid.uuid4()}", headers=headers, json={"era": "x"}
    )
    assert update_unknown.status_code == 404


def test_artifact_write_and_translation_admin_only(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    vi_id = get_language_id(client)
    base = f"{API}/artifacts/{artifact['id']}"
    translation = f"{base}/translations/{vi_id}"
    calls = [
        ("post", f"{API}/artifacts/", {"site_id": site["id"], "code": "NOPE"}),
        ("put", base, {"era": "x"}),
        ("delete", base, None),
        ("get", f"{base}/translations", None),
        ("put", translation, {"title": "x"}),
        ("delete", translation, None),
    ]
    for method, url, body in calls:
        kwargs = {"json": body} if body is not None else {}
        no_token = getattr(client, method)(url, **kwargs)
        assert no_token.status_code == 401, (method, url)
        visitor = getattr(client, method)(
            url, headers=normal_user_token_headers, **kwargs
        )
        assert visitor.status_code == 403, (method, url)
    # dữ liệu không bị đổi
    assert client.get(base).json()["era"] is None


def test_translation_upsert_and_delete(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    vi_id = get_language_id(client)
    url = f"{API}/artifacts/{artifact['id']}/translations/{vi_id}"

    first = client.put(url, headers=superuser_token_headers, json={"title": "Bản 1"})
    assert first.status_code == 200
    second = client.put(
        url,
        headers=superuser_token_headers,
        json={"title": "Bản 2", "history_content": "Nội dung dài tiếng Việt có dấu."},
    )
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]  # cập nhật, không tạo mới
    listed = client.get(
        f"{API}/artifacts/{artifact['id']}/translations",
        headers=superuser_token_headers,
    ).json()
    assert [item["title"] for item in listed] == ["Bản 2"]

    empty_title = client.put(url, headers=superuser_token_headers, json={"title": ""})
    assert empty_title.status_code == 422
    unknown_lang = client.put(
        f"{API}/artifacts/{artifact['id']}/translations/{uuid.uuid4()}",
        headers=superuser_token_headers,
        json={"title": "x"},
    )
    assert unknown_lang.status_code == 404

    assert client.delete(url, headers=superuser_token_headers).status_code == 200
    assert client.delete(url, headers=superuser_token_headers).status_code == 404


def test_language_fallback_rules(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    site_ids: list[str],
) -> None:
    site = create_site(client, superuser_token_headers)
    site_ids.append(site["id"])
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    base = f"{API}/artifacts/{artifact['id']}"

    # Chưa có bản dịch nào: vẫn trả hiện vật, nội dung rỗng
    empty = client.get(f"{base}?lang=vi").json()
    assert empty["title"] is None
    assert empty["language_code"] is None

    add_translation(
        client,
        superuser_token_headers,
        artifact["id"],
        get_language_id(client, "vi"),
        "Trống đồng",
    )
    # Chỉ có tiếng Việt: xin tiếng Anh -> dự phòng tiếng Việt (mặc định)
    fallback = client.get(f"{base}?lang=en").json()
    assert fallback["title"] == "Trống đồng"
    assert fallback["language_code"] == "vi"
    assert fallback["is_fallback"] is True
    direct = client.get(f"{base}?lang=vi").json()
    assert direct["is_fallback"] is False

    # Có tiếng Anh: trả đúng ngôn ngữ
    add_translation(
        client,
        superuser_token_headers,
        artifact["id"],
        get_language_id(client, "en"),
        "Bronze drum",
    )
    english = client.get(f"{base}?lang=en").json()
    assert english["title"] == "Bronze drum"
    assert english["is_fallback"] is False

    # Mã ngôn ngữ lạ hoặc bỏ trống -> ngôn ngữ mặc định (tiếng Việt), không lỗi
    for suffix in ("?lang=xx", ""):
        response = client.get(f"{base}{suffix}")
        assert response.status_code == 200
        assert response.json()["title"] == "Trống đồng"

    # Danh sách cũng theo ngôn ngữ
    listed = client.get(f"{API}/artifacts/?site_id={site['id']}&lang=en").json()
    assert listed["data"][0]["title"] == "Bronze drum"


def test_user_preferred_language_is_used_when_no_lang_param(
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
        get_language_id(client, "vi"),
        "Tiếng Việt",
    )
    add_translation(
        client,
        superuser_token_headers,
        artifact["id"],
        get_language_id(client, "en"),
        "English",
    )
    url = f"{API}/artifacts/{artifact['id']}"
    en_id = get_language_id(client, "en")
    try:
        set_pref = client.patch(
            f"{API}/users/me",
            headers=normal_user_token_headers,
            json={"language_id": en_id},
        )
        assert set_pref.status_code == 200
        response = client.get(url, headers=normal_user_token_headers)
        assert response.json()["title"] == "English"
        # Tham số ?lang= luôn thắng ngôn ngữ ưa thích
        override = client.get(f"{url}?lang=vi", headers=normal_user_token_headers)
        assert override.json()["title"] == "Tiếng Việt"
    finally:
        client.patch(
            f"{API}/users/me",
            headers=normal_user_token_headers,
            json={"language_id": None},
        )

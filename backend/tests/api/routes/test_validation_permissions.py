"""Kiểm thử validation (ngôn ngữ mặc định, FK, null) và chính sách quyền hai tầng.

Chính sách quyền (khớp ``test_role_policy.py``):
- Tầng NỘI DUNG di sản (``AdminUser``): xác định theo **role admin**.
- Tầng NGƯỜI DÙNG (``get_current_active_superuser``): cần **is_superuser = true**.
  Role admin không tự thành superuser; gán role không tự nâng quyền.
- Thiếu token -> 401; không đủ quyền -> 403; id không tồn tại -> 404;
  dữ liệu sai quy tắc (null, rỗng) -> 4xx, không bao giờ 500.
"""

import uuid
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, delete

from app import crud
from app.core.config import settings
from app.models import Language, User, UserCreate
from tests.utils.heritage import API, create_artifact, create_site, purge_sites
from tests.utils.user import user_authentication_headers
from tests.utils.utils import random_email, random_lower_string

Headers = dict[str, str]


# ---------------------------------- Fixtures -------------------------------------
@pytest.fixture
def created_languages(db: Session) -> Generator[list[str]]:
    ids: list[str] = []
    yield ids
    db.execute(
        delete(Language).where(col(Language.id).in_([uuid.UUID(i) for i in ids]))
    )
    db.commit()


@pytest.fixture
def created_users(db: Session) -> Generator[list[uuid.UUID]]:
    ids: list[uuid.UUID] = []
    yield ids
    db.execute(delete(User).where(col(User.id).in_(ids)))
    db.commit()


def _new_language(
    client: TestClient, admin: Headers, created: list[str], **extra: object
) -> dict[str, object]:
    body = {"code": f"t{uuid.uuid4().hex[:6]}", "name": "Test", **extra}
    response = client.post(f"{API}/languages/", headers=admin, json=body)
    assert response.status_code == 200, response.text
    created.append(response.json()["id"])
    return response.json()  # type: ignore[no-any-return]


def _language(client: TestClient, code: str) -> dict[str, object]:
    data = client.get(f"{API}/languages/").json()["data"]
    return next(item for item in data if item["code"] == code)


def _role_id(db: Session, name: str) -> uuid.UUID:
    role = crud.get_role_by_name(session=db, name=name)
    assert role is not None
    return role.id


def _new_user(
    db: Session, created: list[uuid.UUID], **extra: object
) -> tuple[User, str]:
    password = random_lower_string()
    user = crud.create_user(
        session=db,
        user_create=UserCreate(email=random_email(), password=password, **extra),  # type: ignore[arg-type]
    )
    created.append(user.id)
    return user, password


def _users(path: str = "") -> str:
    return f"{settings.API_V1_STR}/users/{path}"


# ------------------------- Ngôn ngữ mặc định qua PUT -----------------------------
def test_put_cannot_deactivate_default_language(
    client: TestClient, superuser_token_headers: Headers
) -> None:
    vi = _language(client, "vi")
    assert vi["is_default"] is True

    refused = client.put(
        f"{API}/languages/{vi['id']}",
        headers=superuser_token_headers,
        json={"is_active": False},
    )
    assert refused.status_code == 400

    refused_both = client.put(
        f"{API}/languages/{vi['id']}",
        headers=superuser_token_headers,
        json={"is_active": False, "is_default": True},
    )
    assert refused_both.status_code == 400

    # trạng thái không đổi: vi vẫn bật và vẫn là mặc định duy nhất
    data = client.get(f"{API}/languages/").json()["data"]
    assert [item["code"] for item in data if item["is_default"]] == ["vi"]
    assert _language(client, "vi")["is_active"] is True


def test_put_cannot_make_inactive_language_default(
    client: TestClient,
    superuser_token_headers: Headers,
    created_languages: list[str],
) -> None:
    admin = superuser_token_headers
    lang = _new_language(client, admin, created_languages)
    url = f"{API}/languages/{lang['id']}"
    assert client.put(url, headers=admin, json={"is_active": False}).status_code == 200

    # đang tắt -> không đặt làm mặc định được
    assert client.put(url, headers=admin, json={"is_default": True}).status_code == 400
    assert _language(client, "vi")["is_default"] is True

    # nhưng bật lại trong cùng request thì được
    vi = _language(client, "vi")
    try:
        ok = client.put(
            url, headers=admin, json={"is_active": True, "is_default": True}
        )
        assert ok.status_code == 200, ok.text
        assert ok.json()["is_default"] is True
        assert ok.json()["is_active"] is True
    finally:
        client.put(
            f"{API}/languages/{vi['id']}", headers=admin, json={"is_default": True}
        )
    data = client.get(f"{API}/languages/").json()["data"]
    assert [item["code"] for item in data if item["is_default"]] == ["vi"]


def test_create_default_language_must_be_active(
    client: TestClient, superuser_token_headers: Headers
) -> None:
    response = client.post(
        f"{API}/languages/",
        headers=superuser_token_headers,
        json={"code": "zz", "name": "Sai", "is_default": True, "is_active": False},
    )
    assert response.status_code == 422


@pytest.mark.parametrize(
    "body",
    [
        {"code": None},
        {"name": None},
        {"is_active": None},
        {"is_default": None},
        {"code": "   "},
        {"name": ""},
        {"name": "   "},
    ],
)
def test_language_update_rejects_null_and_blank(
    client: TestClient,
    superuser_token_headers: Headers,
    created_languages: list[str],
    body: dict[str, object],
) -> None:
    lang = _new_language(client, superuser_token_headers, created_languages)
    response = client.put(
        f"{API}/languages/{lang['id']}", headers=superuser_token_headers, json=body
    )
    assert response.status_code == 422, response.text
    # dữ liệu không bị đổi
    assert _language_by_id(client, str(lang["id"]))["name"] == "Test"


def _language_by_id(client: TestClient, language_id: str) -> dict[str, object]:
    data = client.get(f"{API}/languages/").json()["data"]
    return next(item for item in data if item["id"] == language_id)


def test_language_update_trims_text(
    client: TestClient,
    superuser_token_headers: Headers,
    created_languages: list[str],
) -> None:
    lang = _new_language(client, superuser_token_headers, created_languages)
    response = client.put(
        f"{API}/languages/{lang['id']}",
        headers=superuser_token_headers,
        json={"name": "  Tên mới  "},
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Tên mới"


# ----------------------- Ngôn ngữ ưa thích trong hồ sơ ---------------------------
def test_profile_language_must_exist_and_be_active(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    created_languages: list[str],
) -> None:
    visitor = normal_user_token_headers
    me = _users("me")

    unknown = client.patch(me, headers=visitor, json={"language_id": str(uuid.uuid4())})
    assert unknown.status_code == 404

    inactive = _new_language(client, superuser_token_headers, created_languages)
    assert (
        client.delete(
            f"{API}/languages/{inactive['id']}", headers=superuser_token_headers
        ).status_code
        == 200
    )
    refused = client.patch(me, headers=visitor, json={"language_id": inactive["id"]})
    assert refused.status_code == 400

    en = _language(client, "en")
    ok = client.patch(me, headers=visitor, json={"language_id": en["id"]})
    assert ok.status_code == 200
    assert ok.json()["language_id"] == en["id"]
    try:
        # null = bỏ ngôn ngữ ưa thích (được phép)
        cleared = client.patch(me, headers=visitor, json={"language_id": None})
        assert cleared.status_code == 200
        assert cleared.json()["language_id"] is None
    finally:
        client.patch(me, headers=visitor, json={"language_id": None})


def test_profile_rejects_null_email_and_bad_ids(
    client: TestClient, normal_user_token_headers: Headers
) -> None:
    visitor = normal_user_token_headers
    assert (
        client.patch(_users("me"), headers=visitor, json={"email": None}).status_code
        == 422
    )
    assert (
        client.patch(
            _users("me"), headers=visitor, json={"language_id": "not-a-uuid"}
        ).status_code
        == 422
    )


def test_visit_language_must_exist_and_be_active(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    created_languages: list[str],
) -> None:
    """Cùng quy tắc FK ngôn ngữ với API ghi lượt xem: không tồn tại -> 404, đang tắt -> 400."""
    admin = superuser_token_headers
    site = create_site(client, admin)
    try:
        artifact = create_artifact(client, admin, site["id"])
        inactive = _new_language(client, admin, created_languages)
        client.delete(f"{API}/languages/{inactive['id']}", headers=admin)

        def visit(language_id: str) -> int:
            return client.post(
                f"{API}/visits/",
                headers=normal_user_token_headers,
                json={"artifact_id": artifact["id"], "language_id": language_id},
            ).status_code

        assert visit(str(uuid.uuid4())) == 404
        assert visit(str(inactive["id"])) == 400
    finally:
        purge_sites(db, [site["id"]])


# ------------------------- Admin sửa user: null / FK ------------------------------
@pytest.mark.parametrize(
    "body",
    [
        {"email": None},
        {"is_active": None},
        {"is_superuser": None},
        {"password": None},
    ],
)
def test_admin_update_user_rejects_null(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    created_users: list[uuid.UUID],
    body: dict[str, object],
) -> None:
    user, _ = _new_user(db, created_users)
    response = client.patch(
        _users(str(user.id)), headers=superuser_token_headers, json=body
    )
    assert response.status_code == 422, response.text


def test_admin_update_user_unknown_role_is_404(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    created_users: list[uuid.UUID],
) -> None:
    user, _ = _new_user(db, created_users)
    response = client.patch(
        _users(str(user.id)),
        headers=superuser_token_headers,
        json={"role_id": str(uuid.uuid4())},
    )
    assert response.status_code == 404


# ----------------------- Tự bảo vệ tài khoản quản trị ----------------------------
@pytest.mark.parametrize(
    ("body", "expected_status"),
    [
        ({"is_superuser": False}, 400),
        ({"is_active": False}, 400),
        ({"role": "visitor"}, 409),  # superuser không được mang role visitor
    ],
)
def test_admin_cannot_demote_or_deactivate_self(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    body: dict[str, object],
    expected_status: int,
) -> None:
    admin = superuser_token_headers
    me = client.get(_users("me"), headers=admin).json()
    payload = dict(body)
    if payload.pop("role", None) == "visitor":
        payload["role_id"] = str(_role_id(db, "visitor"))
    response = client.patch(_users(me["id"]), headers=admin, json=payload)
    assert response.status_code == expected_status, response.text
    again = client.get(_users("me"), headers=admin).json()
    assert again["role_name"] == "admin"
    assert again["is_superuser"] is True
    assert again["is_active"] is True


# ----------------------- Một quy tắc quyền cho mọi endpoint ----------------------
def test_user_admin_endpoints_status_codes(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
) -> None:
    target = _users(str(uuid.uuid4()))
    assert client.patch(target, json={"full_name": "x"}).status_code == 401
    forbidden = client.patch(
        target, headers=normal_user_token_headers, json={"full_name": "x"}
    )
    assert forbidden.status_code == 403
    missing = client.patch(
        target, headers=superuser_token_headers, json={"full_name": "x"}
    )
    assert missing.status_code == 404


def test_permission_tiers_are_consistent_across_endpoints(
    client: TestClient,
    db: Session,
    created_users: list[uuid.UUID],
) -> None:
    """Hai tầng quyền cho cùng một kết quả trên mọi endpoint cùng tầng.

    - Tầng người dùng: ``GET /users/`` và ``POST /password-recovery-html-content/...``
      (đều dùng ``get_current_active_superuser``) -> cần is_superuser.
    - Tầng nội dung: ``GET /analytics/overview`` (``AdminUser``) -> cần role admin
      (user cũ không có role thì is_superuser là dự phòng).
    """
    users_url = _users()
    recovery_url = (
        f"{settings.API_V1_STR}/password-recovery-html-content/{random_email()}"
    )
    content_url = f"{API}/analytics/overview"

    def headers_for(user: User, password: str) -> Headers:
        return user_authentication_headers(
            client=client, email=user.email, password=password
        )

    def tiers(headers: Headers) -> tuple[bool, bool, bool]:
        # "được qua" = khác 401/403 (recovery với email lạ trả 404 cho người đủ quyền)
        return (
            client.get(users_url, headers=headers).status_code not in (401, 403),
            client.post(recovery_url, headers=headers).status_code not in (401, 403),
            client.get(content_url, headers=headers).status_code not in (401, 403),
        )

    # 1) superuser + role admin -> cả hai tầng
    superuser, pw1 = _new_user(db, created_users, is_superuser=True)
    assert tiers(headers_for(superuser, pw1)) == (True, True, True)

    # 2) role admin nhưng KHÔNG superuser -> chỉ tầng nội dung
    content_admin, pw2 = _new_user(db, created_users)
    content_admin.role_id = _role_id(db, "admin")
    db.add(content_admin)
    db.commit()
    assert content_admin.is_superuser is False
    assert tiers(headers_for(content_admin, pw2)) == (False, False, True)

    # 3) visitor -> không tầng nào
    visitor, pw3 = _new_user(db, created_users)
    assert tiers(headers_for(visitor, pw3)) == (False, False, False)

    # 4) user cũ chưa có role nhưng is_superuser -> dự phòng: được cả hai tầng
    legacy, pw4 = _new_user(db, created_users, is_superuser=True)
    legacy.role_id = None
    db.add(legacy)
    db.commit()
    assert tiers(headers_for(legacy, pw4)) == (True, True, True)
    assert client.get(_users("me"), headers=headers_for(legacy, pw4)).json()[
        "role_name"
    ] == ("admin")

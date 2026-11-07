"""Kiểm thử validation (ngôn ngữ mặc định, FK, null) và quy tắc quyền role/superuser.

Quy tắc đã chốt (P3 dùng để kiểm tra quyền):
- ``role`` (admin / visitor) là nguồn sự thật. ``AdminUser`` và ``get_current_active_superuser``
  đều dùng ``is_admin`` -> cùng một kết quả cho cùng một người dùng.
- ``is_superuser`` chỉ là bản sao đồng bộ (admin <=> true); user cũ chưa có role thì
  ``is_superuser`` được dùng làm dự phòng.
- Thiếu token -> 401; đủ token nhưng không đủ quyền -> 403; id không tồn tại -> 404;
  dữ liệu sai quy tắc (null, rỗng, mâu thuẫn) -> 4xx, không bao giờ 500.
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
        {"role_id": None},
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


# ---------------------- Thống nhất role <-> is_superuser -------------------------
def test_role_is_source_of_truth_and_syncs_superuser(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    created_users: list[uuid.UUID],
) -> None:
    admin = superuser_token_headers
    user, _ = _new_user(db, created_users)
    url = _users(str(user.id))
    assert user.is_superuser is False

    promoted = client.patch(
        url, headers=admin, json={"role_id": str(_role_id(db, "admin"))}
    )
    assert promoted.status_code == 200, promoted.text
    assert promoted.json()["is_superuser"] is True
    assert promoted.json()["role_id"] == str(_role_id(db, "admin"))

    demoted = client.patch(
        url, headers=admin, json={"role_id": str(_role_id(db, "visitor"))}
    )
    assert demoted.status_code == 200
    assert demoted.json()["is_superuser"] is False

    # chiều ngược lại: đổi is_superuser -> role đổi theo
    again = client.patch(url, headers=admin, json={"is_superuser": True})
    assert again.status_code == 200
    assert again.json()["role_id"] == str(_role_id(db, "admin"))


def test_conflicting_role_and_superuser_is_400(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    created_users: list[uuid.UUID],
) -> None:
    user, _ = _new_user(db, created_users)
    response = client.patch(
        _users(str(user.id)),
        headers=superuser_token_headers,
        json={"role_id": str(_role_id(db, "admin")), "is_superuser": False},
    )
    assert response.status_code == 400
    db.refresh(user)
    assert user.is_superuser is False


@pytest.mark.parametrize(
    "body",
    [
        {"is_superuser": False},
        {"is_active": False},
        {"role": "visitor"},
    ],
)
def test_admin_cannot_demote_or_deactivate_self(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    body: dict[str, object],
) -> None:
    admin = superuser_token_headers
    me = client.get(_users("me"), headers=admin).json()
    payload = dict(body)
    if payload.pop("role", None) == "visitor":
        payload["role_id"] = str(_role_id(db, "visitor"))
    response = client.patch(_users(me["id"]), headers=admin, json=payload)
    assert response.status_code == 400, response.text
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


def test_admin_check_is_identical_for_role_and_superuser_dependencies(
    client: TestClient,
    db: Session,
    created_users: list[uuid.UUID],
) -> None:
    """AdminUser (/users/) và get_current_active_superuser (/password-recovery-html-content/...)
    phải cho cùng kết quả với cùng một người dùng."""
    users_url = _users()
    # endpoint dùng get_current_active_superuser; email ngẫu nhiên -> admin nhận 404
    # (không gửi email), người không đủ quyền nhận 403
    superuser_only_url = (
        f"{settings.API_V1_STR}/password-recovery-html-content/{random_email()}"
    )

    def headers_for(user: User, password: str) -> Headers:
        return user_authentication_headers(
            client=client, email=user.email, password=password
        )

    # 1) role admin (is_superuser đồng bộ) -> qua cả hai
    admin_user, admin_pw = _new_user(db, created_users, is_superuser=True)
    admin_headers = headers_for(admin_user, admin_pw)
    assert client.get(users_url, headers=admin_headers).status_code == 200
    assert client.post(superuser_only_url, headers=admin_headers).status_code != 403

    # 2) role visitor nhưng cờ is_superuser lệch (dữ liệu cũ/sai) -> bị chặn ở cả hai,
    #    vì role là nguồn sự thật
    odd_user, odd_pw = _new_user(db, created_users)
    odd_user.is_superuser = True
    db.add(odd_user)
    db.commit()
    odd_headers = headers_for(odd_user, odd_pw)
    assert client.get(users_url, headers=odd_headers).status_code == 403
    assert client.post(superuser_only_url, headers=odd_headers).status_code == 403

    # 3) user cũ chưa có role nhưng is_superuser = true -> dự phòng: được coi là admin
    legacy, legacy_pw = _new_user(db, created_users, is_superuser=True)
    legacy.role_id = None
    db.add(legacy)
    db.commit()
    legacy_headers = headers_for(legacy, legacy_pw)
    assert client.get(users_url, headers=legacy_headers).status_code == 200
    assert client.post(superuser_only_url, headers=legacy_headers).status_code != 403
    assert client.get(_users("me"), headers=legacy_headers).json()["role_name"] == (
        "admin"
    )

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.models import Language, Role
from tests.utils.heritage import API
from tests.utils.user import create_random_user


@pytest.mark.parametrize("field", ["email", "password", "is_active", "is_superuser"])
def test_admin_rejects_null_required_user_fields(
    client: TestClient, db: Session, superuser_token_headers: dict[str, str], field: str
) -> None:
    user = create_random_user(db)
    url = f"{API}/users/{user.id}"
    before = client.get(url, headers=superuser_token_headers).json()
    assert (
        client.patch(
            url, headers=superuser_token_headers, json={field: None}
        ).status_code
        == 422
    )
    assert client.get(url, headers=superuser_token_headers).json() == before


def test_profile_language_validation_and_nullable_fields(
    client: TestClient, db: Session, normal_user_token_headers: dict[str, str]
) -> None:
    headers = normal_user_token_headers
    url = f"{API}/users/me"
    before = client.get(url, headers=headers).json()
    assert client.patch(url, headers=headers, json={"email": None}).status_code == 422
    assert (
        client.patch(
            url, headers=headers, json={"language_id": str(uuid.uuid4())}
        ).status_code
        == 404
    )
    inactive = Language(
        code=f"x{uuid.uuid4().hex[:6]}", name="Inactive", is_active=False
    )
    db.add(inactive)
    db.commit()
    try:
        assert (
            client.patch(
                url, headers=headers, json={"language_id": str(inactive.id)}
            ).status_code
            == 400
        )
        assert client.get(url, headers=headers).json() == before
        active = db.exec(select(Language).where(Language.code == "en")).one()
        assert (
            client.patch(
                url, headers=headers, json={"language_id": str(active.id)}
            ).status_code
            == 200
        )
        cleared = client.patch(
            url, headers=headers, json={"language_id": None, "full_name": None}
        )
        assert cleared.status_code == 200
        assert cleared.json()["language_id"] is None
        assert cleared.json()["full_name"] is None
        assert client.patch(url, headers=headers, json={}).status_code == 200
    finally:
        db.delete(inactive)
        db.commit()


def test_admin_role_reference_validation_and_clear(
    client: TestClient, db: Session, superuser_token_headers: dict[str, str]
) -> None:
    user = create_random_user(db)
    url = f"{API}/users/{user.id}"
    headers = superuser_token_headers
    before = client.get(url, headers=headers).json()
    assert (
        client.patch(
            url, headers=headers, json={"role_id": str(uuid.uuid4())}
        ).status_code
        == 404
    )
    assert client.get(url, headers=headers).json() == before
    admin = db.exec(select(Role).where(Role.name == "admin")).one()
    assigned = client.patch(url, headers=headers, json={"role_id": str(admin.id)})
    assert assigned.status_code == 200
    assert assigned.json()["is_superuser"] is False
    cleared = client.patch(
        url, headers=headers, json={"role_id": None, "full_name": None}
    )
    assert cleared.status_code == 200
    assert cleared.json()["role_id"] is None
    assert cleared.json()["full_name"] is None

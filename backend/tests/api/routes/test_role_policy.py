import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app import crud
from app.models import Role, UserCreate
from tests.utils.heritage import API
from tests.utils.user import user_authentication_headers
from tests.utils.utils import random_email


@pytest.mark.parametrize(
    "was_superuser,new_superuser,role_name,status_code",
    [
        (False, True, "visitor", 409),
        (True, True, "visitor", 409),
        (False, False, "admin", 200),
        (True, False, "admin", 200),
        (False, True, "admin", 200),
        (True, True, None, 200),
    ],
)
def test_role_assignment_matrix(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    was_superuser: bool,
    new_superuser: bool,
    role_name: str | None,
    status_code: int,
) -> None:
    user = crud.create_user(
        session=db,
        user_create=UserCreate(
            email=random_email(), password="RolePolicy123!", is_superuser=was_superuser
        ),
    )
    role = (
        db.exec(select(Role).where(Role.name == role_name)).first()
        if role_name
        else None
    )
    url = f"{API}/users/{user.id}"
    before = client.get(url, headers=superuser_token_headers).json()
    response = client.patch(
        url,
        headers=superuser_token_headers,
        json={"is_superuser": new_superuser, "role_id": str(role.id) if role else None},
    )
    assert response.status_code == status_code
    after = client.get(url, headers=superuser_token_headers).json()
    if status_code == 409:
        assert after == before
    else:
        assert after["is_superuser"] is new_superuser
        assert after["role_id"] == (str(role.id) if role else None)


def test_role_admin_is_not_promoted_and_cannot_manage_users(
    client: TestClient, db: Session, superuser_token_headers: dict[str, str]
) -> None:
    password = "RolePolicy123!"
    user = crud.create_user(
        session=db, user_create=UserCreate(email=random_email(), password=password)
    )
    role = db.exec(select(Role).where(Role.name == "admin")).one()
    url = f"{API}/users/{user.id}"
    assigned = client.patch(
        url, headers=superuser_token_headers, json={"role_id": str(role.id)}
    )
    assert assigned.status_code == 200
    assert assigned.json()["is_superuser"] is False
    headers = user_authentication_headers(
        client=client, email=user.email, password=password
    )
    assert client.get(f"{API}/beacons/", headers=headers).status_code == 200
    assert client.get(f"{API}/users/", headers=headers).status_code == 403
    assert (
        client.patch(url, headers=headers, json={"is_superuser": True}).status_code
        == 403
    )
    # Legacy boolean-only callers still get synchronized roles on promotion/demotion.
    for enabled, name in [(True, "admin"), (False, "visitor")]:
        result = client.patch(
            url, headers=superuser_token_headers, json={"is_superuser": enabled}
        )
        assert result.status_code == 200
        expected = db.exec(select(Role).where(Role.name == name)).one()
        assert result.json()["role_id"] == str(expected.id)


def test_role_only_update_cannot_silently_demote_superuser_role(
    client: TestClient, db: Session, superuser_token_headers: dict[str, str]
) -> None:
    user = crud.create_user(
        session=db,
        user_create=UserCreate(
            email=random_email(), password="RolePolicy123!", is_superuser=True
        ),
    )
    visitor = db.exec(select(Role).where(Role.name == "visitor")).one()
    response = client.patch(
        f"{API}/users/{user.id}",
        headers=superuser_token_headers,
        json={"role_id": str(visitor.id)},
    )
    assert response.status_code == 409

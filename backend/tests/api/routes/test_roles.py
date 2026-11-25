from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app import crud
from app.models import Role, UserCreate
from tests.utils.heritage import API
from tests.utils.user import user_authentication_headers
from tests.utils.utils import random_email


def test_read_roles_as_superuser(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
) -> None:
    response = client.get(
        f"{API}/roles/",
        headers=superuser_token_headers,
    )

    assert response.status_code == 200

    roles = response.json()
    assert isinstance(roles, list)

    role_names = [role["name"] for role in roles]
    assert role_names == ["admin", "visitor"]

    for role in roles:
        assert "id" in role
        assert "name" in role
        assert "description" in role


def test_read_roles_as_admin_forbidden(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
) -> None:
    admin_role = db.exec(
        select(Role).where(Role.name == "admin")
    ).one()

    password = "AdminRole123!"
    admin = crud.create_user(
        session=db,
        user_create=UserCreate(
            email=random_email(),
            password=password,
            is_superuser=False,
            role_id=admin_role.id,
        ),
    )

    headers = user_authentication_headers(
        client=client,
        email=admin.email,
        password=password,
    )

    response = client.get(
        f"{API}/roles/",
        headers=headers,
    )

    assert response.status_code == 403
    assert response.json() == {
        "detail": "The user doesn't have enough privileges"
    }


def test_read_roles_as_visitor_forbidden(
    client: TestClient,
    normal_user_token_headers: dict[str, str],
) -> None:
    response = client.get(
        f"{API}/roles/",
        headers=normal_user_token_headers,
    )

    assert response.status_code == 403
    assert response.json() == {
        "detail": "The user doesn't have enough privileges"
    }


def test_read_roles_without_authentication(
    client: TestClient,
) -> None:
    response = client.get(f"{API}/roles/")

    assert response.status_code == 401
    assert response.json() == {"detail": "Not authenticated"}

from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app import crud
from app.core.config import settings
from app.models import Role, User, UserCreate
from tests.utils.user import user_authentication_headers
from tests.utils.utils import random_email


def test_create_user(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
) -> None:
    response = client.post(
        f"{settings.API_V1_STR}/private/users/",
        headers=superuser_token_headers,
        json={
            "email": random_email(),
            "password": "password123",
            "full_name": "Pollo Listo",
        },
    )

    assert response.status_code == 200

    data = response.json()

    user = db.exec(
        select(User).where(User.id == data["id"])
    ).first()

    visitor_role = db.exec(
        select(Role).where(Role.name == "visitor")
    ).first()

    assert user is not None
    assert visitor_role is not None
    assert user.email == data["email"]
    assert user.full_name == "Pollo Listo"
    assert user.is_superuser is False
    assert user.role_id == visitor_role.id


def test_create_user_requires_authentication(
    client: TestClient,
) -> None:
    response = client.post(
        f"{settings.API_V1_STR}/private/users/",
        json={
            "email": random_email(),
            "password": "password123",
            "full_name": "Unauthorized User",
        },
    )

    assert response.status_code == 401


def test_create_user_forbidden_for_visitor(
    client: TestClient,
    normal_user_token_headers: dict[str, str],
) -> None:
    response = client.post(
        f"{settings.API_V1_STR}/private/users/",
        headers=normal_user_token_headers,
        json={
            "email": random_email(),
            "password": "password123",
            "full_name": "Visitor Attempt",
        },
    )

    assert response.status_code == 403


def test_create_user_forbidden_for_regular_admin(
    client: TestClient,
    db: Session,
) -> None:
    password = "RegularAdmin123!"

    admin_role = db.exec(
        select(Role).where(Role.name == "admin")
    ).first()

    assert admin_role is not None

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

    response = client.post(
        f"{settings.API_V1_STR}/private/users/",
        headers=headers,
        json={
            "email": random_email(),
            "password": "password123",
            "full_name": "Regular Admin Attempt",
        },
    )

    assert response.status_code == 403

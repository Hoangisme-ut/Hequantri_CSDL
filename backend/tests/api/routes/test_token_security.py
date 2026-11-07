import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from threading import Barrier

import jwt
import pytest

from app import crud
from app.core.config import settings
from app.models import UserCreate
from app.utils import generate_password_reset_token
from tests.utils.heritage import API


def signed(claims):
    return jwt.encode(claims, settings.SECRET_KEY, algorithm="HS256")


@pytest.mark.parametrize(
    "claims",
    [
        {"sub": "not-a-uuid"},
        {},
        {"sub": None},
        {"sub": 123},
        {"sub": str(uuid.uuid4()), "purpose": "password_reset"},
        {"sub": str(uuid.uuid4()), "exp": 0},
    ],
)
def test_invalid_access_subject_and_purpose(client, claims):
    token = signed({"exp": datetime.now(UTC) + timedelta(minutes=5), **claims})
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get(f"{API}/users/me", headers=headers).status_code == 403
    assert client.get(f"{API}/artifacts/", headers=headers).status_code == 200


@pytest.mark.parametrize("legacy", [True, False])
def test_reset_is_consumed_atomically_and_access_sessions_survive(client, db, legacy):
    user = crud.create_user(
        session=db,
        user_create=UserCreate(
            email=f"{uuid.uuid4().hex}@example.com", password="Original123!"
        ),
    )
    access = signed(
        {"sub": str(user.id), "exp": datetime.now(UTC) + timedelta(minutes=5)}
    )
    token = (
        signed(
            {
                "sub": user.email,
                "exp": datetime.now(UTC) + timedelta(minutes=5),
                "nbf": datetime.now(UTC),
            }
        )
        if legacy
        else generate_password_reset_token(user.email)
    )
    assert (
        client.get(
            f"{API}/users/me", headers={"Authorization": f"Bearer {token}"}
        ).status_code
        == 403
    )
    start = Barrier(2)

    def reset(_):
        start.wait(timeout=5)
        return client.post(
            f"{API}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        )

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(reset, range(2)))
    assert sorted(r.status_code for r in responses) == [200, 400]
    assert (
        client.post(
            f"{API}/reset-password/",
            json={"token": token, "new_password": "Replay123!"},
        ).status_code
        == 400
    )
    assert (
        client.get(
            f"{API}/users/me", headers={"Authorization": f"Bearer {access}"}
        ).status_code
        == 200
    )
    assert (
        client.post(
            f"{API}/login/access-token",
            data={"username": user.email, "password": "Changed123!"},
        ).status_code
        == 200
    )


@pytest.mark.parametrize(
    "claims",
    [
        {},
        {"sub": str(uuid.uuid4())},
        {"sub": "person@example.com", "purpose": "access"},
        {"sub": "person@example.com", "exp": 0},
        {"sub": None},
        {"sub": 123},
    ],
)
def test_invalid_reset_tokens(client, claims):
    token = signed({"exp": datetime.now(UTC) + timedelta(minutes=5), **claims})
    assert (
        client.post(
            f"{API}/reset-password/",
            json={"token": token, "new_password": "Changed123!"},
        ).status_code
        == 400
    )

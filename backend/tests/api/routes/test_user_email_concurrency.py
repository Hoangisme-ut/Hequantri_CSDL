import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from time import sleep

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app.core.security import create_access_token
from app.main import app
from app.models import User
from tests.utils.heritage import API
from tests.utils.user import create_random_user


@pytest.mark.parametrize("endpoint", ["admin", "me"])
def test_concurrent_email_update_returns_one_conflict(
    db, superuser_token_headers, monkeypatch, endpoint
):
    """Two users are moved to the same new email at almost the same time."""
    users = [create_random_user(db) for _ in range(2)]
    ids = [user.id for user in users]
    old_emails = {user.id: user.email for user in users}
    headers = [
        {
            "Authorization": f"Bearer {create_access_token(user.id, timedelta(minutes=5))}"
        }
        for user in users
    ]
    target = f"{uuid.uuid4().hex}@example.com"
    start = Barrier(2)
    original = Session.commit

    def slow_commit(session):
        if any(isinstance(row, User) for row in (*session.new, *session.dirty)):
            sleep(0.3)  # Both pre-checks pass before the first commit finishes.
        return original(session)

    monkeypatch.setattr(Session, "commit", slow_commit)

    def write(index):
        with TestClient(app, raise_server_exceptions=False) as c:
            start.wait(timeout=5)
            if endpoint == "admin":
                return c.patch(
                    f"{API}/users/{ids[index]}",
                    headers=superuser_token_headers,
                    json={"email": target},
                )
            return c.patch(
                f"{API}/users/me", headers=headers[index], json={"email": target}
            )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(write, range(2)))
        assert sorted(r.status_code for r in results) == [200, 409]
        loser_index = next(i for i, r in enumerate(results) if r.status_code == 409)
        assert results[loser_index].json() == {
            "detail": "User with this email already exists"
        }
        db.expire_all()
        assert len(db.exec(select(User).where(col(User.email) == target)).all()) == 1
        # The rejected user keeps the old email.
        loser = db.get(User, ids[loser_index])
        assert loser is not None and loser.email == old_emails[ids[loser_index]]
    finally:
        db.expire_all()
        for row in db.exec(select(User).where(col(User.id).in_(ids))).all():
            db.delete(row)
        db.commit()

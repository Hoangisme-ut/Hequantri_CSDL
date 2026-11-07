import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from time import sleep

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app.main import app
from app.models import Language
from tests.utils.heritage import API


@pytest.mark.parametrize("operation", ["code", "default"])
def test_concurrent_languages(
    client, db, superuser_token_headers, monkeypatch, operation
):
    original_default = db.exec(select(Language).where(col(Language.is_default))).one()
    original_id = original_default.id
    code = uuid.uuid4().hex[:8]
    targets = [Language(code=uuid.uuid4().hex[:8], name="Race") for _ in range(2)]
    for row in targets:
        db.add(row)
    db.commit()
    ids = [row.id for row in targets]
    start = Barrier(2)
    original = Session.commit

    def slow_commit(session):
        if any(isinstance(row, Language) for row in (*session.new, *session.dirty)):
            sleep(0.2)
        return original(session)

    monkeypatch.setattr(Session, "commit", slow_commit)

    def write(index):
        with TestClient(app, raise_server_exceptions=False) as c:
            start.wait(timeout=5)
            if operation == "code":
                return c.post(
                    f"{API}/languages/",
                    headers=superuser_token_headers,
                    json={"code": code, "name": "Race"},
                )
            return c.put(
                f"{API}/languages/{ids[index]}",
                headers=superuser_token_headers,
                json={"is_default": True},
            )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(write, range(2)))
        codes = sorted(r.status_code for r in results)
        assert codes == ([200, 409] if operation == "code" else [200, 200]), codes
        db.expire_all()
        defaults = db.exec(select(Language).where(col(Language.is_default))).all()
        assert len(defaults) == 1 and defaults[0].is_active
        if operation == "default":
            assert defaults[0].id in ids
    finally:
        # Restore the default through the public policy, then remove only test rows.
        assert (
            client.put(
                f"{API}/languages/{original_id}",
                headers=superuser_token_headers,
                json={"is_default": True},
            ).status_code
            == 200
        )
        db.expire_all()
        for row in db.exec(
            select(Language).where(
                col(Language.code).in_([code, *(row.code for row in targets)])
            )
        ).all():
            db.delete(row)
        db.commit()

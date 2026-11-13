"""Real SQL Server coverage for the EXISTING 300-second visit contract.

No fixture overrides get_db; concurrent requests use independent sessions.
The business owner's approval is tracked separately in docs/qa.
"""

import multiprocessing
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app import crud
from app.main import app
from app.models import VisitLog, get_datetime_utc
from tests.utils.heritage import API, create_artifact, create_site, purge_sites
from tests.utils.user import authentication_token_from_email
from tests.utils.visit_worker import record_visit_worker


@pytest.fixture
def artifacts(client, superuser_token_headers, db):
    site = create_site(client, superuser_token_headers)
    try:
        yield [
            create_artifact(client, superuser_token_headers, site["id"])
            for _ in range(2)
        ]
    finally:
        purge_sites(db, [site["id"]])


def stored_visits(db, artifact_id):
    db.expire_all()
    return db.exec(
        select(VisitLog).where(col(VisitLog.artifact_id) == uuid.UUID(artifact_id))
    ).all()


def concurrent_posts(payloads):
    start = Barrier(len(payloads))

    def post(item):
        headers, artifact_id = item
        with TestClient(app, raise_server_exceptions=False) as client:
            start.wait(timeout=10)
            return client.post(
                f"{API}/visits/", headers=headers, json={"artifact_id": artifact_id}
            )

    with ThreadPoolExecutor(max_workers=len(payloads)) as pool:
        return list(pool.map(post, payloads))


@pytest.mark.parametrize("dimension", ["user", "artifact"], ids=["VL-03", "VL-04"])
def test_independent_visits_are_not_serialized_together(
    client, db, normal_user_token_headers, artifacts, monkeypatch, dimension
):
    other = authentication_token_from_email(
        client=client, db=db, email=f"visit-{uuid.uuid4().hex}@example.com"
    )
    # Both reads must overlap. A global lock would time out at this barrier.
    read_together = Barrier(2)
    original = crud.find_recent_visit

    def overlapping_read(**kwargs):
        result = original(**kwargs)
        read_together.wait(timeout=10)
        return result

    monkeypatch.setattr(crud, "find_recent_visit", overlapping_read)
    responses = concurrent_posts(
        [
            (normal_user_token_headers, artifacts[0]["id"]),
            (
                other if dimension == "user" else normal_user_token_headers,
                artifacts[0 if dimension == "user" else 1]["id"],
            ),
        ]
    )
    assert [r.status_code for r in responses] == [201, 201]
    rows = stored_visits(db, artifacts[0]["id"])
    if dimension == "user":
        assert len(rows) == 2
        assert len({r.user_id for r in rows}) == 2
    else:
        assert len(rows) == 1
        other_rows = stored_visits(db, artifacts[1]["id"])
        assert len(other_rows) == 1
        assert rows[0].user_id == other_rows[0].user_id


@pytest.mark.parametrize(
    "age", [299, 300, 301], ids=["VL-05-before", "VL-05-boundary", "VL-05-after"]
)
def test_window_boundary_and_concurrent_return(
    client, db, normal_user_token_headers, artifacts, monkeypatch, age
):
    artifact_id = artifacts[0]["id"]
    first = client.post(
        f"{API}/visits/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact_id},
    )
    assert first.status_code == 201
    now = get_datetime_utc()
    row = db.get(VisitLog, uuid.UUID(first.json()["id"]))
    row.visited_at = now - timedelta(seconds=age)
    db.add(row)
    db.commit()
    monkeypatch.setattr(crud, "get_datetime_utc", lambda: now)
    responses = concurrent_posts([(normal_user_token_headers, artifact_id)] * 2)
    assert sorted(r.status_code for r in responses) == (
        [200, 201] if age > 300 else [200, 200]
    )
    assert len({r.json()["id"] for r in responses}) == 1
    rows = stored_visits(db, artifact_id)
    assert len(rows) == (2 if age > 300 else 1)
    assert (responses[0].json()["id"] != first.json()["id"]) == (age > 300)


def test_flushed_insert_rolls_back_and_retry_releases_lock(
    db, normal_user_token_headers, artifacts, monkeypatch
):
    """VL-06: a real INSERT is flushed, then the request fails before commit."""
    artifact_id = artifacts[0]["id"]
    original = Session.commit
    flushed = []

    def fail_after_flush(session):
        if any(isinstance(row, VisitLog) for row in session.new):
            session.flush()
            flushed.append(True)
            raise RuntimeError("Injected failure after VisitLog INSERT")
        return original(session)

    with monkeypatch.context() as patch:
        patch.setattr(Session, "commit", fail_after_flush)
        with TestClient(app, raise_server_exceptions=False) as client:
            failed = client.post(
                f"{API}/visits/",
                headers=normal_user_token_headers,
                json={"artifact_id": artifact_id},
            )
        assert failed.status_code == 500
    assert flushed == [True]
    assert stored_visits(db, artifact_id) == []
    responses = concurrent_posts([(normal_user_token_headers, artifact_id)] * 2)
    assert sorted(r.status_code for r in responses) == [200, 201]
    assert len({r.json()["id"] for r in responses}) == 1
    assert len(stored_visits(db, artifact_id)) == 1


def test_separate_application_processes_share_database_lock(
    db, normal_user_token_headers, artifacts
):
    """VL-07: independent interpreters, app engines and HTTP requests."""
    context = multiprocessing.get_context("spawn")
    start = context.Barrier(2)
    results = context.Queue()
    workers = [
        context.Process(
            target=record_visit_worker,
            args=(start, results, normal_user_token_headers, artifacts[0]["id"]),
        )
        for _ in range(2)
    ]
    try:
        for worker in workers:
            worker.start()
        replies = [results.get(timeout=40) for _ in workers]
        for worker in workers:
            worker.join(timeout=10)
            assert worker.exitcode == 0
        assert len({pid for pid, _, _ in replies}) == 2
        assert sorted(code for _, code, _ in replies) == [200, 201]
        assert len({body["id"] for _, _, body in replies}) == 1
        assert len(stored_visits(db, artifacts[0]["id"])) == 1
    finally:
        for worker in workers:
            if worker.is_alive():
                worker.terminate()
                worker.join(timeout=10)
        results.close()


def test_unprotected_negative_control_reproduces_read_insert_race(
    db, normal_user_token_headers, artifacts, monkeypatch
):
    """Prove the harness detects duplicate INSERT operations without the SQL lock."""
    from app.api.routes import visits

    original = crud.find_recent_visit
    read_together = Barrier(2)

    def racing_read(**kwargs):
        result = original(**kwargs)
        read_together.wait(timeout=10)
        return result

    monkeypatch.setattr(visits, "acquire_transaction_lock", lambda *_: None)
    monkeypatch.setattr(crud, "find_recent_visit", racing_read)
    responses = concurrent_posts([(normal_user_token_headers, artifacts[0]["id"])] * 2)
    assert [r.status_code for r in responses] == [201, 201]
    assert len({r.json()["id"] for r in responses}) == 2
    assert len(stored_visits(db, artifacts[0]["id"])) == 2

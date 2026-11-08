import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from time import sleep

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app.main import app
from app.models import Artifact, Beacon
from tests.utils.heritage import (
    API,
    create_artifact,
    create_beacon,
    create_site,
    purge_sites,
)


@pytest.mark.parametrize(
    "operation", ["identity", "assignment", "move_create", "move_update"]
)
def test_concurrent_beacon_invariants(
    client, db, superuser_token_headers, monkeypatch, operation
):
    sites = [create_site(client, superuser_token_headers) for _ in range(2)]
    artifact = create_artifact(client, superuser_token_headers, sites[0]["id"])
    unassigned = create_beacon(client, superuser_token_headers, sites[0]["id"])
    identity = str(uuid.uuid4())
    start = Barrier(2)
    original = Session.commit

    def slow_commit(session):
        if any(
            isinstance(row, (Artifact, Beacon))
            for row in (*session.new, *session.dirty)
        ):
            sleep(0.2)
        return original(session)

    monkeypatch.setattr(Session, "commit", slow_commit)

    def write(index):
        with TestClient(app, raise_server_exceptions=False) as c:
            start.wait(timeout=5)
            if operation.startswith("move") and index == 0:
                return c.put(
                    f"{API}/artifacts/{artifact['id']}",
                    headers=superuser_token_headers,
                    json={"site_id": sites[1]["id"]},
                )
            if operation == "move_update":
                return c.put(
                    f"{API}/beacons/{unassigned['id']}",
                    headers=superuser_token_headers,
                    json={"artifact_id": artifact["id"]},
                )
            return c.post(
                f"{API}/beacons/",
                headers=superuser_token_headers,
                json={
                    "site_id": sites[0]["id"],
                    "artifact_id": artifact["id"] if operation != "identity" else None,
                    "proximity_uuid": identity
                    if operation == "identity"
                    else str(uuid.uuid4()),
                    "major": 1,
                    "minor": 1,
                },
            )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(write, range(2)))
        codes = [r.status_code for r in results]
        assert sum(code in (200, 201) for code in codes) == 1, codes
        assert all(code in (200, 201, 400, 409) for code in codes), codes
        db.expire_all()
        row = db.get(Artifact, uuid.UUID(artifact["id"]))
        links = db.exec(select(Beacon).where(col(Beacon.artifact_id) == row.id)).all()
        assert len(links) <= 1
        assert all(b.site_id == row.site_id for b in links)
    finally:
        purge_sites(db, [site["id"] for site in sites])

import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from time import sleep

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app import crud
from app.models import Beacon, Language, VisitLog
from tests.utils.heritage import (
    API,
    create_artifact,
    create_beacon,
    create_site,
    purge_sites,
)


@pytest.fixture
def graph(client, superuser_token_headers, db):
    site = create_site(client, superuser_token_headers)
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    beacon = create_beacon(client, superuser_token_headers, site["id"], artifact["id"])
    yield site, artifact, beacon
    purge_sites(db, [site["id"]])


@pytest.mark.parametrize("requests", [2, 12], ids=["VL-01", "VL-02"])
def test_concurrent_visits_are_deduplicated(
    client: TestClient,
    normal_user_token_headers,
    graph,
    db: Session,
    monkeypatch,
    requests,
):
    _, artifact, _ = graph
    original = crud.find_recent_visit
    start = Barrier(requests)

    def slow_read(**kwargs):
        result = original(**kwargs)
        sleep(0.2)  # Expose the former read/insert race on independent connections.
        return result

    monkeypatch.setattr(crud, "find_recent_visit", slow_read)

    def record(_):
        start.wait(timeout=5)
        return client.post(
            f"{API}/visits/",
            headers=normal_user_token_headers,
            json={"artifact_id": artifact["id"]},
        )

    with ThreadPoolExecutor(max_workers=requests) as pool:
        responses = list(pool.map(record, range(requests)))
    assert sorted(r.status_code for r in responses) == [200] * (requests - 1) + [201]
    assert len({r.json()["id"] for r in responses}) == 1
    rows = db.exec(
        select(VisitLog).where(col(VisitLog.artifact_id) == uuid.UUID(artifact["id"]))
    ).all()
    assert len(rows) == 1


@pytest.mark.parametrize(
    "invalid", ["inactive_beacon", "wrong_site", "inactive_language"]
)
def test_invalid_links_never_write(
    client, normal_user_token_headers, graph, db, invalid
):
    site, artifact, beacon = graph
    payload = {"artifact_id": artifact["id"], "beacon_id": beacon["id"]}
    language = None
    extra_site = None
    if invalid == "inactive_language":
        language = Language(code=uuid.uuid4().hex[:8], name="Disabled", is_active=False)
        db.add(language)
        db.commit()
        payload["language_id"] = str(language.id)
    else:
        row = db.get(Beacon, uuid.UUID(beacon["id"]))
        if invalid == "inactive_beacon":
            row.is_active = False
        else:
            from app.models import Site

            extra_site = Site(name="Other site")
            db.add(extra_site)
            db.flush()
            row.site_id = extra_site.id
        db.add(row)
        db.commit()
    try:
        response = client.post(
            f"{API}/visits/", headers=normal_user_token_headers, json=payload
        )
        assert response.status_code in (400, 404)
        assert not db.exec(
            select(VisitLog).where(
                col(VisitLog.artifact_id) == uuid.UUID(artifact["id"])
            )
        ).all()
    finally:
        if language:
            db.delete(language)
        if extra_site:
            row.site_id = uuid.UUID(site["id"])
            db.add(row)
            db.flush()
            db.delete(extra_site)
        db.commit()

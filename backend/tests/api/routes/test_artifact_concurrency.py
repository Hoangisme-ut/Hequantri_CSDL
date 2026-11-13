import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from time import sleep

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app.main import app
from app.models import Artifact, ArtifactTranslation
from tests.utils.heritage import (
    API,
    create_artifact,
    create_site,
    get_language_id,
    purge_sites,
)


@pytest.mark.parametrize("operation", ["create", "translation"])
def test_concurrent_uniqueness_returns_conflict(
    client, db, superuser_token_headers, monkeypatch, operation
):
    site = create_site(client, superuser_token_headers)
    artifact = create_artifact(client, superuser_token_headers, site["id"])
    language = get_language_id(client)
    original = Session.commit
    start = Barrier(2)

    def slow_commit(session):
        if any(isinstance(row, (Artifact, ArtifactTranslation)) for row in session.new):
            sleep(0.2)
        return original(session)

    monkeypatch.setattr(Session, "commit", slow_commit)

    def write(_):
        with TestClient(app, raise_server_exceptions=False) as c:
            start.wait(timeout=5)
            if operation == "create":
                return c.post(
                    f"{API}/artifacts/",
                    headers=superuser_token_headers,
                    json={"site_id": site["id"], "code": "RACE"},
                )
            return c.put(
                f"{API}/artifacts/{artifact['id']}/translations/{language}",
                headers=superuser_token_headers,
                json={"title": "Đồng thời"},
            )

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(write, range(2)))
        assert sorted(r.status_code for r in results) == [200, 409]
        if operation == "create":
            assert (
                len(
                    db.exec(
                        select(Artifact).where(
                            col(Artifact.site_id) == uuid.UUID(site["id"]),
                            Artifact.code == "RACE",
                        )
                    ).all()
                )
                == 1
            )
        else:
            assert (
                len(
                    db.exec(
                        select(ArtifactTranslation).where(
                            col(ArtifactTranslation.artifact_id)
                            == uuid.UUID(artifact["id"])
                        )
                    ).all()
                )
                == 1
            )
        # The losing request rolled back; a subsequent write still succeeds.
        create_artifact(client, superuser_token_headers, site["id"])
    finally:
        purge_sites(db, [site["id"]])

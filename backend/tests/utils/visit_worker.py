"""Spawn-safe HTTP worker: activate the isolated database before app imports."""

import os


def record_visit_worker(start, results, headers, artifact_id):
    from tests.db_safety import activate_test_database

    activate_test_database()

    from fastapi.testclient import TestClient

    from app.core.config import settings
    from app.main import app

    with TestClient(app, raise_server_exceptions=False) as client:
        start.wait(timeout=20)
        response = client.post(
            f"{settings.API_V1_STR}/visits/",
            headers=headers,
            json={"artifact_id": artifact_id},
        )
        results.put((os.getpid(), response.status_code, response.json()))

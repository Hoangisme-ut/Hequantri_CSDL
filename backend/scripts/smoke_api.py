"""Run after migration + seed against a disposable smoke-test database."""

import logging
import os
import uuid

import httpx

from app.core.config import settings


def main() -> None:
    base_url = os.environ.get("SMOKE_BASE_URL", "http://localhost:8000")
    with httpx.Client(base_url=base_url, timeout=30, follow_redirects=True) as client:
        health = client.get("/api/v1/utils/health-check/")
        health.raise_for_status()
        login = client.post(
            "/api/v1/login/access-token",
            data={
                "username": settings.FIRST_SUPERUSER,
                "password": settings.FIRST_SUPERUSER_PASSWORD,
            },
        )
        login.raise_for_status()
        client.headers["Authorization"] = f"Bearer {login.json()['access_token']}"
        me = client.get("/api/v1/users/me")
        me.raise_for_status()
        assert me.json()["is_superuser"] is True

        def post(path: str, payload: dict) -> dict:
            response = client.post(f"/api/v1/{path}", json=payload)
            response.raise_for_status()
            return response.json()

        site = post("sites/", {"name": "Smoke test"})
        artifact = post("artifacts/", {"site_id": site["id"], "code": "SMOKE"})
        media = post(
            f"artifacts/{artifact['id']}/media",
            {"media_type": "image", "url": "https://example.com/smoke.jpg"},
        )
        identity = {"proximity_uuid": str(uuid.uuid4()), "major": 1, "minor": 1}
        post(
            "beacons/",
            identity | {"site_id": site["id"], "artifact_id": artifact["id"]},
        )
        resolved = client.get("/api/v1/beacons/resolve", params=identity)
        resolved.raise_for_status()
        assert resolved.json()["artifact"]["media"][0]["id"] == media["id"]
        logging.info(
            "PASS: health -> seeded Admin login -> API writes -> beacon resolves media"
        )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()

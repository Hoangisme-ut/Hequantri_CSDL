import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import event

from app.core.db import engine
from app.models import VisitLog
from tests.utils.heritage import API, create_artifact, create_site, purge_sites


@pytest.fixture
def sample(client, db, superuser_token_headers, normal_user_token_headers):
    site = create_site(client, superuser_token_headers, name="Di tích Việt Nam")
    artifacts = [
        create_artifact(client, superuser_token_headers, site["id"]) for _ in range(2)
    ]
    users = [
        client.get(f"{API}/users/me", headers=h).json()["id"]
        for h in (superuser_token_headers, normal_user_token_headers)
    ]
    start = datetime(2025, 1, 1, tzinfo=UTC)
    for artifact, user, at in [
        (0, 0, start),
        (0, 0, start + timedelta(hours=2)),
        (1, 1, start + timedelta(days=1)),
        (1, 1, start + timedelta(days=2)),
        (1, 1, start - timedelta(seconds=1)),
    ]:
        db.add(
            VisitLog(
                artifact_id=uuid.UUID(artifacts[artifact]["id"]),
                user_id=uuid.UUID(users[user]),
                visited_at=at,
            )
        )
    db.commit()
    yield site, artifacts
    purge_sites(db, [site["id"]])


@pytest.mark.parametrize("path", ["overview", "visits", "top-artifacts", "sites"])
def test_analytics_admin_only(client, normal_user_token_headers, path):
    assert client.get(f"{API}/analytics/{path}").status_code == 401
    assert (
        client.get(
            f"{API}/analytics/{path}", headers=normal_user_token_headers
        ).status_code
        == 403
    )


def test_aggregates_and_half_open_utc_range(client, superuser_token_headers, sample):
    site, artifacts = sample
    params = {
        "site_id": site["id"],
        "from": "2025-01-01T07:00:00+07:00",
        "to": "2025-01-03T00:00:00Z",
    }
    queries = []

    def capture(_conn, _cursor, statement, _params, _context, _many):
        if "visitlog" in statement.lower():
            queries.append(statement)

    event.listen(engine, "before_cursor_execute", capture)
    try:
        overview = client.get(
            f"{API}/analytics/overview", headers=superuser_token_headers, params=params
        )
        assert overview.status_code == 200
        assert overview.json() == {"views": 3, "unique_users": 2, "artifacts_viewed": 2}
        daily = client.get(
            f"{API}/analytics/visits", headers=superuser_token_headers, params=params
        ).json()
        assert daily == [
            {"date": "2025-01-01", "views": 2, "unique_users": 1},
            {"date": "2025-01-02", "views": 1, "unique_users": 1},
        ]
        top = client.get(
            f"{API}/analytics/top-artifacts",
            headers=superuser_token_headers,
            params={**params, "limit": 1},
        ).json()
        assert len(top) == 1
        assert top[0]["artifact_id"] == artifacts[0]["id"]
        assert top[0]["views"] == 2
        sites = client.get(
            f"{API}/analytics/sites", headers=superuser_token_headers, params=params
        ).json()
        assert sites == [
            {"site_id": site["id"], "name": site["name"], "views": 3, "unique_users": 2}
        ]
        assert len(queries) == 4  # Exactly one aggregate query per endpoint.
        assert all("count(" in query.lower() for query in queries)
    finally:
        event.remove(engine, "before_cursor_execute", capture)


def test_empty_and_bad_ranges(client, superuser_token_headers):
    headers = superuser_token_headers
    params = {"site_id": str(uuid.uuid4())}
    assert client.get(
        f"{API}/analytics/overview", headers=headers, params=params
    ).json() == {"views": 0, "unique_users": 0, "artifacts_viewed": 0}
    for path in ("visits", "top-artifacts", "sites"):
        assert (
            client.get(f"{API}/analytics/{path}", headers=headers, params=params).json()
            == []
        )
    for params in (
        {"from": "2025-01-01"},
        {"from": "2025-02-01T00:00:00Z", "to": "2025-01-01T00:00:00Z"},
        {"from": "bad"},
        {"site_id": "bad"},
    ):
        assert (
            client.get(
                f"{API}/analytics/overview", headers=headers, params=params
            ).status_code
            == 422
        )

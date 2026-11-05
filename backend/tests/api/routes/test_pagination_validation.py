import pytest
from fastapi.testclient import TestClient

from tests.utils.heritage import API


@pytest.mark.parametrize(
    "endpoint", ["sites", "artifacts", "beacons", "users", "items"]
)
@pytest.mark.parametrize("query", ["skip=-1", "limit=-1", "limit=0"])
def test_pagination_rejects_invalid_bounds(
    client: TestClient,
    superuser_token_headers: dict[str, str],
    endpoint: str,
    query: str,
) -> None:
    response = client.get(f"{API}/{endpoint}/?{query}", headers=superuser_token_headers)
    assert response.status_code == 422
    assert response.json()["detail"][0]["loc"] == ["query", query.split("=")[0]]


@pytest.mark.parametrize(
    "endpoint", ["sites", "artifacts", "beacons", "users", "items"]
)
def test_valid_pagination_keeps_existing_limits(
    client: TestClient, superuser_token_headers: dict[str, str], endpoint: str
) -> None:
    small = client.get(
        f"{API}/{endpoint}/?skip=0&limit=1", headers=superuser_token_headers
    )
    assert small.status_code == 200
    assert len(small.json()["data"]) <= 1
    high = client.get(f"{API}/{endpoint}/?limit=201", headers=superuser_token_headers)
    assert high.status_code == (200 if endpoint in {"users", "items"} else 422)

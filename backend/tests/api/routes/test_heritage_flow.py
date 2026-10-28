import uuid

from fastapi.testclient import TestClient

from app.core.config import settings

BASE = settings.API_V1_STR


def test_language_defaults_and_visibility(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    headers = superuser_token_headers
    languages = client.get(f"{BASE}/languages/").json()["data"]
    original = next(language for language in languages if language["is_default"])
    payload = {"code": uuid.uuid4().hex[:10], "name": "Test language"}
    response = client.post(f"{BASE}/languages/", headers=headers, json=payload)
    assert response.status_code == 200
    language_id = response.json()["id"]
    path = f"{BASE}/languages/{language_id}"
    try:
        assert (
            client.post(f"{BASE}/languages/", headers=headers, json=payload).status_code
            == 409
        )
        assert (
            client.put(
                path, headers=headers, json={"code": original["code"]}
            ).status_code
            == 409
        )
        assert (
            client.put(path, headers=headers, json={"is_default": True}).status_code
            == 200
        )
        defaults = [
            x
            for x in client.get(f"{BASE}/languages/").json()["data"]
            if x["is_default"]
        ]
        assert [x["id"] for x in defaults] == [language_id]
        assert (
            client.put(path, headers=headers, json={"is_default": False}).status_code
            == 400
        )
        assert client.delete(path, headers=headers).status_code == 400
    finally:
        assert (
            client.put(
                f"{BASE}/languages/{original['id']}",
                headers=headers,
                json={"is_default": True},
            ).status_code
            == 200
        )
        assert client.delete(path, headers=headers).status_code == 200
    assert language_id not in [
        x["id"] for x in client.get(f"{BASE}/languages/").json()["data"]
    ]
    missing = f"{BASE}/languages/{uuid.uuid4()}"
    assert (
        client.put(missing, headers=headers, json={"name": "Missing"}).status_code
        == 404
    )
    assert client.delete(missing, headers=headers).status_code == 404


def test_artifact_translation_lifecycle(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    headers = superuser_token_headers
    site = client.post(
        f"{BASE}/sites/", headers=headers, json={"name": "Integration site"}
    ).json()
    payload = {"site_id": site["id"], "code": uuid.uuid4().hex}
    response = client.post(f"{BASE}/artifacts/", headers=headers, json=payload)
    assert response.status_code == 200
    artifact = response.json()
    path = f"{BASE}/artifacts/{artifact['id']}"
    assert (
        client.post(f"{BASE}/artifacts/", headers=headers, json=payload).status_code
        == 409
    )
    assert (
        client.post(
            f"{BASE}/artifacts/",
            headers=headers,
            json=payload | {"site_id": str(uuid.uuid4())},
        ).status_code
        == 404
    )
    language = next(
        x for x in client.get(f"{BASE}/languages/").json()["data"] if x["is_default"]
    )
    translation_path = f"{path}/translations/{language['id']}"
    for title in ("Original title", "Updated title"):
        result = client.put(translation_path, headers=headers, json={"title": title})
        assert result.status_code == 200
        detail = client.get(path, params={"lang": language["code"]}).json()
        assert detail["title"] == title
        assert detail["is_fallback"] is False
    assert len(client.get(f"{path}/translations", headers=headers).json()) == 1
    listing = client.get(
        f"{BASE}/artifacts/", params={"site_id": site["id"], "q": payload["code"]}
    )
    assert listing.json()["count"] == 1
    assert listing.json()["data"][0]["title"] == "Updated title"
    updated = client.put(path, headers=headers, json={"era": "Modern"})
    assert updated.status_code == 200
    assert updated.json()["updated_at"] is not None
    assert client.delete(translation_path, headers=headers).status_code == 200
    assert client.delete(translation_path, headers=headers).status_code == 404
    assert client.get(path).json()["title"] is None
    assert client.delete(path, headers=headers).status_code == 200
    assert client.get(path).status_code == 404
    assert client.get(path, headers=headers).status_code == 200
    assert (
        client.get(f"{BASE}/artifacts/", params={"site_id": site["id"]}).json()["count"]
        == 0
    )
    missing = f"{BASE}/artifacts/{uuid.uuid4()}"
    assert client.get(missing).status_code == 404
    assert (
        client.put(missing, headers=headers, json={"era": "Missing"}).status_code == 404
    )
    assert client.delete(missing, headers=headers).status_code == 404

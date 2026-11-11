import uuid

import pytest
from sqlalchemy.exc import IntegrityError

from app.models import Feedback
from tests.utils.heritage import API, create_artifact, create_site, purge_sites
from tests.utils.user import authentication_token_from_email


@pytest.fixture
def artifact(client, superuser_token_headers, db):
    site = create_site(client, superuser_token_headers)
    row = create_artifact(client, superuser_token_headers, site["id"])
    yield row
    purge_sites(db, [site["id"]])


def test_feedback_privacy_and_moderation(
    client, db, artifact, normal_user_token_headers, superuser_token_headers
):
    visitor = normal_user_token_headers
    admin = superuser_token_headers
    body = {
        "artifact_id": artifact["id"],
        "rating": 5,
        "comment": "Hiện vật rất đẹp",
        "status": "approved",
        "user_id": str(uuid.uuid4()),
    }
    response = client.post(f"{API}/feedback/", headers=visitor, json=body)
    assert response.status_code == 201
    row = response.json()
    assert row["status"] == "pending"
    assert row["comment"] == body["comment"]
    other = authentication_token_from_email(
        client=client, email="feedback-other@example.com", db=db
    )
    assert client.get(f"{API}/feedback/{row['id']}", headers=other).status_code == 404
    assert all(
        x["id"] != row["id"]
        for x in client.get(f"{API}/feedback/me", headers=other).json()["data"]
    )
    assert client.get(f"{API}/feedback/", headers=visitor).status_code == 403
    assert client.get(f"{API}/feedback/").status_code == 401
    assert client.get(f"{API}/feedback/{row['id']}", headers=visitor).json() == row
    assert (
        client.patch(
            f"{API}/feedback/{row['id']}/status",
            headers=visitor,
            json={"status": "approved"},
        ).status_code
        == 403
    )
    for status in ("approved", "rejected", "pending"):
        result = client.patch(
            f"{API}/feedback/{row['id']}/status", headers=admin, json={"status": status}
        )
        assert result.status_code == 200
        assert result.json()["status"] == status
        listed = client.get(
            f"{API}/feedback/?status={status}&artifact_id={artifact['id']}&user_id={row['user_id']}",
            headers=admin,
        ).json()
        assert listed["count"] == 1
        assert listed["data"][0]["id"] == row["id"]
    assert (
        client.patch(
            f"{API}/feedback/{row['id']}/status",
            headers=admin,
            json={"status": "invalid"},
        ).status_code
        == 422
    )
    assert (
        client.get(f"{API}/feedback/?status=invalid", headers=admin).status_code == 422
    )
    assert client.get(f"{API}/feedback/?skip=-1", headers=admin).status_code == 422
    assert (
        client.get(f"{API}/feedback/me?limit=101", headers=visitor).status_code == 422
    )
    assert (
        client.get(f"{API}/feedback/{uuid.uuid4()}", headers=admin).status_code == 404
    )
    assert (
        client.patch(
            f"{API}/feedback/{uuid.uuid4()}/status",
            headers=admin,
            json={"status": "approved"},
        ).status_code
        == 404
    )
    # Neither moderation state nor approval grants other visitors access.
    assert client.get(f"{API}/feedback/{row['id']}", headers=other).status_code == 404


def test_feedback_validation(
    client, artifact, normal_user_token_headers, superuser_token_headers
):
    for rating in (0, 6):
        assert (
            client.post(
                f"{API}/feedback/",
                headers=normal_user_token_headers,
                json={"artifact_id": artifact["id"], "rating": rating},
            ).status_code
            == 422
        )
    assert (
        client.post(
            f"{API}/feedback/",
            headers=normal_user_token_headers,
            json={"artifact_id": str(uuid.uuid4()), "rating": 3},
        ).status_code
        == 404
    )
    client.delete(f"{API}/sites/{artifact['site_id']}", headers=superuser_token_headers)
    assert (
        client.post(
            f"{API}/feedback/",
            headers=normal_user_token_headers,
            json={"artifact_id": artifact["id"], "rating": 3},
        ).status_code
        == 404
    )


@pytest.mark.parametrize("values", [{"rating": 0}, {"status": "invalid"}])
def test_feedback_database_constraints(
    client, db, artifact, normal_user_token_headers, values
):
    user = client.get(f"{API}/users/me", headers=normal_user_token_headers).json()
    row = Feedback(
        user_id=uuid.UUID(user["id"]), artifact_id=uuid.UUID(artifact["id"]), rating=3
    )
    for key, value in values.items():
        setattr(row, key, value)
    db.add(row)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_legacy_feedback_is_deprecated_and_feedbacks_is_primary(client):
    """/feedbacks là đường chính; mọi thao tác của /feedback phải đánh dấu deprecated."""
    import re

    paths = client.get(f"{API}/openapi.json").json()["paths"]
    legacy = [p for p in paths if re.fullmatch(rf"{re.escape(API)}/feedback(/.*)?", p)]
    primary = [p for p in paths if p.startswith(f"{API}/feedbacks")]
    assert legacy and primary
    for path in legacy:
        for method, operation in paths[path].items():
            assert operation.get("deprecated") is True, f"{method} {path}"
    for path in primary:
        for method, operation in paths[path].items():
            assert not operation.get("deprecated"), f"{method} {path}"

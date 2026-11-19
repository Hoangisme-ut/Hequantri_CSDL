"""Web-equivalent API writes through SQL Server; no browser/client integration."""

import uuid

from sqlmodel import select

from app.models import ArtifactTranslation, Feedback, VisitLog
from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
    create_beacon,
    create_site,
    get_language_id,
    purge_sites,
    resolve_params,
)


def test_admin_to_visitor_to_analytics(
    client, db, superuser_token_headers, normal_user_token_headers
):
    admin, visitor = superuser_token_headers, normal_user_token_headers
    site = create_site(
        client, admin, name="Di tích Cố đô Huế", description="Di sản văn hóa Việt Nam"
    )
    try:
        artifact = create_artifact(client, admin, site["id"])
        language_id = get_language_id(client)
        title = "Trống đồng Đông Sơn — lịch sử Việt Nam"
        translation = add_translation(
            client,
            admin,
            artifact["id"],
            language_id,
            title,
            history_content="Nghệ thuật đúc đồng truyền thống",
        )
        persisted = db.get(ArtifactTranslation, uuid.UUID(translation["id"]))
        assert persisted.title == title
        beacon = create_beacon(client, admin, site["id"], artifact["id"])
        resolved = client.get(
            f"{API}/beacons/resolve?{resolve_params(beacon)}&lang=vi", headers=visitor
        )
        assert resolved.status_code == 200
        assert set(resolved.json()) == {"beacon", "artifact"}
        assert resolved.json()["artifact"]["title"] == title
        assert resolved.json()["artifact"]["language_code"] == "vi"
        assert resolved.json()["artifact"]["is_fallback"] is False
        assert (
            client.post(
                f"{API}/artifacts/",
                headers=visitor,
                json={"site_id": site["id"], "code": "DENIED"},
            ).status_code
            == 403
        )

        favorite = client.post(
            f"{API}/favorites/", headers=visitor, json={"artifact_id": artifact["id"]}
        )
        assert favorite.status_code == 201
        assert (
            client.post(
                f"{API}/favorites/",
                headers=visitor,
                json={"artifact_id": artifact["id"]},
            ).status_code
            == 200
        )
        visits = [
            client.post(
                f"{API}/visits/",
                headers=visitor,
                json={
                    "artifact_id": artifact["id"],
                    "beacon_id": beacon["id"],
                    "language_id": language_id,
                },
            )
            for _ in range(2)
        ]
        assert [r.status_code for r in visits] == [201, 200]
        assert visits[0].json() == visits[1].json()
        for endpoint in ("favorites/me", "visits/me"):
            response = client.get(f"{API}/{endpoint}", headers=visitor).json()
            item = next(
                x for x in response["data"] if x["artifact_id"] == artifact["id"]
            )
            assert item["artifact"]["title"] == title
        feedback = client.post(
            f"{API}/feedbacks/",
            headers=visitor,
            json={
                "artifact_id": artifact["id"],
                "rating": 5,
                "comment": "Nội dung tiếng Việt rõ ràng",
            },
        ).json()
        assert feedback["status"] == "pending"
        assert (
            client.patch(
                f"{API}/feedbacks/{feedback['id']}/status",
                headers=admin,
                json={"status": "approved"},
            ).status_code
            == 200
        )
        db.expire_all()
        stored = db.get(Feedback, uuid.UUID(feedback["id"]))
        assert (
            stored.comment == "Nội dung tiếng Việt rõ ràng"
            and stored.status == "approved"
        )
        rows = db.exec(
            select(VisitLog).where(VisitLog.artifact_id == uuid.UUID(artifact["id"]))
        ).all()
        assert len(rows) == 1
        assert rows[0].beacon_id == uuid.UUID(beacon["id"])
        assert rows[0].language_id == uuid.UUID(language_id)
        assert (
            client.get(f"{API}/analytics/overview", headers=visitor).status_code == 403
        )
        overview = client.get(
            f"{API}/analytics/overview?site_id={site['id']}", headers=admin
        )
        assert overview.json() == {"views": 1, "unique_users": 1, "artifacts_viewed": 1}
        assert (
            client.delete(f"{API}/sites/{site['id']}", headers=admin).status_code == 200
        )
        assert (
            client.get(
                f"{API}/beacons/resolve?{resolve_params(beacon)}", headers=visitor
            ).status_code
            == 404
        )
        assert (
            client.post(
                f"{API}/feedbacks/",
                headers=visitor,
                json={"artifact_id": artifact["id"], "rating": 5},
            ).status_code
            == 404
        )
        # Hiding content does not erase recorded analytics.
        assert (
            client.get(
                f"{API}/analytics/overview?site_id={site['id']}", headers=admin
            ).json()
            == overview.json()
        )
    finally:
        purge_sites(db, [site["id"]])

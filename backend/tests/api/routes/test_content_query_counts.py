import uuid

import pytest
from sqlalchemy import event

from app.core.db import engine
from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
    create_site,
    get_language_id,
    purge_sites,
)
from tests.utils.user import authentication_token_from_email


@pytest.mark.parametrize("path", ["artifacts/", "favorites/me", "visits/me"])
def test_page_query_count_is_constant(client, db, superuser_token_headers, path):
    visitor = authentication_token_from_email(
        client=client, db=db, email=f"{uuid.uuid4().hex}@example.com"
    )
    site = create_site(client, superuser_token_headers)
    language_id = get_language_id(client)
    try:
        for i in range(5):
            artifact = create_artifact(client, superuser_token_headers, site["id"])
            add_translation(
                client,
                superuser_token_headers,
                artifact["id"],
                language_id,
                f"Hiện vật {i}",
            )
            assert (
                client.post(
                    f"{API}/favorites/",
                    headers=visitor,
                    json={"artifact_id": artifact["id"]},
                ).status_code
                == 201
            )
            assert (
                client.post(
                    f"{API}/visits/",
                    headers=visitor,
                    json={"artifact_id": artifact["id"]},
                ).status_code
                == 201
            )
        counts = []
        for limit in (1, 5):
            queries = []

            def capture(
                _conn, _cursor, statement, _params, _context, _many, queries=queries
            ):
                if statement.lstrip().upper().startswith("SELECT"):
                    queries.append(statement)

            event.listen(engine, "before_cursor_execute", capture)
            try:
                params = {"limit": limit, "lang": "vi"}
                if path == "artifacts/":
                    params["site_id"] = site["id"]
                response = client.get(f"{API}/{path}", headers=visitor, params=params)
                assert response.status_code == 200
                assert len(response.json()["data"]) == limit
                assert response.json()["count"] == 5
                counts.append(len(queries))
            finally:
                event.remove(engine, "before_cursor_execute", capture)
        assert counts[1] == counts[0], counts
        assert counts == ([6, 6] if path == "artifacts/" else [7, 7]), counts
    finally:
        purge_sites(db, [site["id"]])

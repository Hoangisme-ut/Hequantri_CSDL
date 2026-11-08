"""Read-only SQL assertions for the opt-in Web -> Flutter acceptance harness."""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))


def main() -> None:
    from tests.db_safety import validate_target, verify_identity

    phase = sys.argv[1]
    assert phase in {"favorite-added", "favorite-removed"}
    token = os.environ["TEST_DATABASE_TOKEN"]
    target = validate_target(
        os.environ["DATABASE_URL"], os.environ["TEST_DATABASE_URL"], token
    )
    graph = json.loads(Path(os.environ["QA_HANDOFF_FILE"]).read_text(encoding="utf-8"))
    mobile = json.loads(
        Path(os.environ["QA_MOBILE_RESULTS_FILE"]).read_text(encoding="utf-8")
    )
    engine = create_engine(target)
    try:
        verify_identity(engine, token)
        params = {
            "artifact": graph["artifact"]["id"],
            "site": graph["site"]["id"],
            "beacon": graph["beacon"]["id"],
            "user": mobile["user_id"],
        }
        with engine.connect() as connection:
            artifact = (
                connection.execute(
                    text(
                        "SELECT code, site_id, cover_image_url FROM artifact WHERE id=:artifact"
                    ),
                    params,
                )
                .mappings()
                .one()
            )
            assert artifact["code"] == graph["artifact"]["code"]
            assert str(artifact["site_id"]).lower() == params["site"]
            assert artifact["cover_image_url"] == graph["image"]
            translations = dict(
                connection.execute(
                    text(
                        "SELECT l.code, t.title FROM artifacttranslation t "
                        "JOIN language l ON l.id=t.language_id WHERE t.artifact_id=:artifact"
                    ),
                    params,
                ).all()
            )
            assert translations == {
                "vi": graph["updatedTitle"],
                "en": "Acceptance bronze drum",
            }
            urls = (
                connection.execute(
                    text("SELECT url FROM media WHERE artifact_id=:artifact"), params
                )
                .scalars()
                .all()
            )
            assert graph["image"] in urls
            beacon = connection.execute(
                text("SELECT artifact_id, site_id FROM beacon WHERE id=:beacon"), params
            ).one()
            assert str(beacon.artifact_id).lower() == params["artifact"]
            assert str(beacon.site_id).lower() == params["site"]
            favorites = (
                connection.execute(
                    text("SELECT user_id FROM favorite WHERE artifact_id=:artifact"),
                    params,
                )
                .scalars()
                .all()
            )
            assert [str(user).lower() for user in favorites] == (
                [params["user"]] if phase == "favorite-added" else []
            )
            visits = (
                connection.execute(
                    text(
                        "SELECT id, user_id, beacon_id, visited_at, rssi FROM visitlog WHERE artifact_id=:artifact"
                    ),
                    params,
                )
                .mappings()
                .all()
            )
            assert len(visits) == 1
            visit = visits[0]
            assert str(visit["id"]).lower() == mobile["visit_id"]
            assert str(visit["user_id"]).lower() == params["user"]
            assert str(visit["beacon_id"]).lower() == params["beacon"]
            assert visit["visited_at"] is not None and visit["rssi"] == -60
            assert visit["visited_at"] == datetime.fromisoformat(
                mobile["visited_at_utc"]
            )
            database = connection.execute(text("SELECT DB_NAME()")).scalar_one()
        evidence = {
            "phase": phase,
            "status": "PASS",
            "database": database,
            **params,
            "translations": translations,
            "media_urls": urls,
            "favorite_count": len(favorites),
            "visit_count": len(visits),
            "visit_id": str(visit["id"]),
            "visited_at_utc": visit["visited_at"].isoformat(),
        }
        (Path(os.environ["QA_EVIDENCE_DIR"]) / f"sql-{phase}.json").write_text(
            json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"SQL Server {phase}: PASS (identity verified; SELECT only)")
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()

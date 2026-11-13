"""Kiểm thử HTTP cho API dashboard (/dashboard).

Bộ dữ liệu kiểm thử đặt ở NĂM 2001 (cố định) nên không lẫn với dữ liệu thật/seed trong DB:
mọi phép đối chiếu dùng bộ lọc ngày nằm trong năm 2001. Riêng phần tổng Site/Artifact/Beacon
(không lọc theo ngày) được đối chiếu bằng MỨC TĂNG so với trước khi tạo dữ liệu.

Bộ dữ liệu (giờ UTC) - 3 hiện vật A, B, C, 2 người dùng, 2 ngôn ngữ:

    #  thời điểm              hiện vật  ngôn ngữ  người
    1  2001-03-10 10:00:00    A         vi        admin
    2  2001-03-10 23:59:59    A         vi        user
    3  2001-03-11 00:00:00    B         en        user
    4  2001-03-11 12:00:00    A         en        admin
    5  2001-03-13 08:00:00    A         vi        admin
    6  2001-03-13 09:00:00    C         (null)    user

Kết quả mong đợi: tổng 6 lượt, 2 người xem; theo ngày 10/3=2, 11/3=2, 12/3=0, 13/3=2;
A=4, B=1, C=1; ngôn ngữ vi=3, en=2, không ghi=1.
"""

import uuid
from collections.abc import Generator
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models import Feedback, FeedbackStatus, VisitLog
from tests.utils.heritage import (
    API,
    add_translation,
    create_artifact,
    create_beacon,
    create_site,
    get_language_id,
    purge_sites,
)

D = f"{API}/dashboard"
RANGE = {"from_date": "2001-03-10", "to_date": "2001-03-13"}


def _utc(day: int, hour: int, minute: int = 0, second: int = 0) -> datetime:
    return datetime(2001, 3, day, hour, minute, second, tzinfo=UTC)


@dataclass
class Dataset:
    site_id: str
    a: dict[str, Any]
    b: dict[str, Any]
    c: dict[str, Any]
    vi_id: str
    en_id: str


@pytest.fixture
def dataset(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
) -> Generator[Dataset]:
    admin = superuser_token_headers
    site = create_site(client, admin)
    suffix = uuid.uuid4().hex[:6].upper()
    # code đặt tên để thứ tự hòa điểm (B trước C) xác định
    a = create_artifact(client, admin, site["id"], code=f"DASH-{suffix}-A")
    b = create_artifact(client, admin, site["id"], code=f"DASH-{suffix}-B")
    c = create_artifact(client, admin, site["id"], code=f"DASH-{suffix}-C")
    vi_id = get_language_id(client, "vi")
    en_id = get_language_id(client, "en")
    add_translation(client, admin, a["id"], vi_id, "Trống đồng")
    add_translation(client, admin, a["id"], en_id, "Bronze drum")
    add_translation(client, admin, b["id"], vi_id, "Bình gốm")  # B chỉ có tiếng Việt
    # C không có bản dịch nào

    admin_id = uuid.UUID(client.get(f"{API}/users/me", headers=admin).json()["id"])
    user_id = uuid.UUID(
        client.get(f"{API}/users/me", headers=normal_user_token_headers).json()["id"]
    )
    vi, en = uuid.UUID(vi_id), uuid.UUID(en_id)
    rows = [
        (admin_id, a, vi, _utc(10, 10)),
        (user_id, a, vi, _utc(10, 23, 59, 59)),
        (user_id, b, en, _utc(11, 0)),
        (admin_id, a, en, _utc(11, 12)),
        (admin_id, a, vi, _utc(13, 8)),
        (user_id, c, None, _utc(13, 9)),
    ]
    for uid, artifact, lang, when in rows:
        db.add(
            VisitLog(
                user_id=uid,
                artifact_id=uuid.UUID(artifact["id"]),
                language_id=lang,
                visited_at=when,
            )
        )
    db.commit()
    yield Dataset(site["id"], a, b, c, vi_id, en_id)
    purge_sites(db, [site["id"]])


# ------------------------------- Quyền truy cập ----------------------------------
@pytest.mark.parametrize(
    "path", ["/summary", "/visits-by-day", "/top-artifacts", "/visits-by-language"]
)
def test_dashboard_requires_admin(
    client: TestClient,
    normal_user_token_headers: dict[str, str],
    path: str,
) -> None:
    assert client.get(f"{D}{path}").status_code == 401
    forbidden = client.get(f"{D}{path}", headers=normal_user_token_headers)
    assert forbidden.status_code == 403


# ----------------------------------- Summary --------------------------------------
def test_summary_counts_match_dataset(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
) -> None:
    admin = superuser_token_headers
    before = client.get(f"{D}/summary", headers=admin).json()

    site = create_site(client, admin)
    site2 = create_site(client, admin)
    art1 = create_artifact(client, admin, site["id"])
    art2 = create_artifact(client, admin, site["id"])
    create_beacon(client, admin, site["id"], art1["id"], minor=1)
    create_beacon(client, admin, site["id"], art2["id"], minor=2)
    try:
        # ẩn 1 site (soft delete) -> total giữ nguyên, active giảm 1 so với "đang tạo"
        assert (
            client.delete(f"{API}/sites/{site2['id']}", headers=admin).status_code
            == 200
        )
        after = client.get(f"{D}/summary", headers=admin).json()
        assert after["sites"]["total"] - before["sites"]["total"] == 2
        assert after["sites"]["active"] - before["sites"]["active"] == 1
        assert after["artifacts"]["total"] - before["artifacts"]["total"] == 2
        assert after["artifacts"]["active"] - before["artifacts"]["active"] == 2
        assert after["beacons"]["total"] - before["beacons"]["total"] == 2
        assert after["beacons"]["active"] - before["beacons"]["active"] == 2
    finally:
        purge_sites(db, [site["id"], site2["id"]])


@pytest.mark.usefixtures("dataset")
def test_summary_visits_in_range(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    response = client.get(f"{D}/summary", headers=superuser_token_headers, params=RANGE)
    assert response.status_code == 200
    visits = response.json()["visits"]
    assert visits == {"total": 6, "unique_visitors": 2}
    assert response.json()["from_date"] == "2001-03-10"
    assert response.json()["to_date"] == "2001-03-13"


# --------------------------------- Visits by day ----------------------------------
@pytest.mark.usefixtures("dataset")
def test_visits_by_day_fills_empty_days_and_matches_total(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    response = client.get(
        f"{D}/visits-by-day", headers=superuser_token_headers, params=RANGE
    )
    assert response.status_code == 200
    body = response.json()
    assert [(d["day"], d["count"]) for d in body["data"]] == [
        ("2001-03-10", 2),
        ("2001-03-11", 2),
        ("2001-03-12", 0),
        ("2001-03-13", 2),
    ]
    assert body["total"] == 6
    summary = client.get(
        f"{D}/summary", headers=superuser_token_headers, params=RANGE
    ).json()
    assert body["total"] == summary["visits"]["total"]


@pytest.mark.usefixtures("dataset")
def test_date_filter_boundaries_are_inclusive_per_day(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    admin = superuser_token_headers

    def total(**params: str) -> int:
        r = client.get(f"{D}/summary", headers=admin, params=params)
        assert r.status_code == 200, r.text
        return int(r.json()["visits"]["total"])

    # 23:59:59 ngày 10/3 vẫn thuộc 10/3; 00:00:00 ngày 11/3 thuộc 11/3
    assert total(from_date="2001-03-10", to_date="2001-03-10") == 2
    assert total(from_date="2001-03-11", to_date="2001-03-11") == 2
    assert total(from_date="2001-03-12", to_date="2001-03-12") == 0
    assert total(from_date="2001-03-12", to_date="2001-03-31") == 2
    assert total(from_date="2001-03-10", to_date="2001-03-11") == 4
    assert total(to_date="2001-03-11", from_date="2001-03-11") == 2


def test_visits_by_day_rejects_bad_ranges(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    admin = superuser_token_headers
    reversed_range = client.get(
        f"{D}/visits-by-day",
        headers=admin,
        params={"from_date": "2001-03-13", "to_date": "2001-03-10"},
    )
    assert reversed_range.status_code == 422
    too_long = client.get(
        f"{D}/visits-by-day",
        headers=admin,
        params={"from_date": "2001-01-01", "to_date": "2002-12-31"},
    )
    assert too_long.status_code == 422
    not_a_date = client.get(f"{D}/summary", headers=admin, params={"from_date": "abc"})
    assert not_a_date.status_code == 422


def test_visits_by_day_default_range_is_last_30_days(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    body = client.get(f"{D}/visits-by-day", headers=superuser_token_headers).json()
    assert len(body["data"]) == 30
    assert body["data"][-1]["day"] == datetime.now(UTC).date().isoformat()


# ---------------------------------- Top artifacts ---------------------------------
def test_top_artifacts_ranked_with_titles(
    client: TestClient, superuser_token_headers: dict[str, str], dataset: Dataset
) -> None:
    response = client.get(
        f"{D}/top-artifacts", headers=superuser_token_headers, params=RANGE
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert [(x["artifact_id"], x["visit_count"]) for x in data] == [
        (dataset.a["id"], 4),
        (dataset.b["id"], 1),  # hòa điểm với C -> theo code (B < C)
        (dataset.c["id"], 1),
    ]
    assert data[0]["code"] == dataset.a["code"]
    assert data[0]["site_id"] == dataset.site_id
    assert data[0]["is_active"] is True
    # tiêu đề: mặc định (vi) / dự phòng / không có bản dịch
    assert data[0]["title"] == "Trống đồng"
    assert data[1]["title"] == "Bình gốm"
    assert data[2]["title"] is None
    assert sum(x["visit_count"] for x in data) == 6


def test_top_artifacts_limit_lang_and_filter(
    client: TestClient, superuser_token_headers: dict[str, str], dataset: Dataset
) -> None:
    admin = superuser_token_headers
    en = client.get(
        f"{D}/top-artifacts",
        headers=admin,
        params={**RANGE, "limit": 1, "lang": "en"},
    ).json()["data"]
    assert len(en) == 1
    assert en[0]["title"] == "Bronze drum"

    only_11 = client.get(
        f"{D}/top-artifacts",
        headers=admin,
        params={"from_date": "2001-03-11", "to_date": "2001-03-11"},
    ).json()["data"]
    assert {(x["artifact_id"], x["visit_count"]) for x in only_11} == {
        (dataset.a["id"], 1),
        (dataset.b["id"], 1),
    }

    for bad in (0, 51):
        assert (
            client.get(
                f"{D}/top-artifacts", headers=admin, params={"limit": bad}
            ).status_code
            == 422
        )


def test_top_artifacts_still_counts_hidden_artifact(
    client: TestClient, superuser_token_headers: dict[str, str], dataset: Dataset
) -> None:
    admin = superuser_token_headers
    hide = client.delete(f"{API}/artifacts/{dataset.a['id']}", headers=admin)
    assert hide.status_code == 200, hide.text
    data = client.get(f"{D}/top-artifacts", headers=admin, params=RANGE).json()["data"]
    assert data[0]["artifact_id"] == dataset.a["id"]
    assert data[0]["visit_count"] == 4
    assert data[0]["is_active"] is False


# -------------------------------- Visits by language ------------------------------
def test_visits_by_language_matches_dataset(
    client: TestClient, superuser_token_headers: dict[str, str], dataset: Dataset
) -> None:
    response = client.get(
        f"{D}/visits-by-language", headers=superuser_token_headers, params=RANGE
    )
    assert response.status_code == 200
    body = response.json()
    by_code = {item["code"]: item["count"] for item in body["data"]}
    assert by_code == {"vi": 3, "en": 2, None: 1}
    assert body["data"][0]["code"] == "vi"  # nhiều nhất đứng đầu
    assert body["data"][0]["language_id"] == dataset.vi_id
    assert body["data"][0]["name"]
    assert body["total"] == 6

    one_day = client.get(
        f"{D}/visits-by-language",
        headers=superuser_token_headers,
        params={"from_date": "2001-03-11", "to_date": "2001-03-11"},
    ).json()
    assert {item["code"]: item["count"] for item in one_day["data"]} == {"en": 2}


@pytest.mark.usefixtures("dataset")
def test_all_endpoints_agree_on_same_range(
    client: TestClient, superuser_token_headers: dict[str, str]
) -> None:
    admin = superuser_token_headers
    total = client.get(f"{D}/summary", headers=admin, params=RANGE).json()["visits"][
        "total"
    ]
    by_day = client.get(f"{D}/visits-by-day", headers=admin, params=RANGE).json()
    by_lang = client.get(f"{D}/visits-by-language", headers=admin, params=RANGE).json()
    top = client.get(f"{D}/top-artifacts", headers=admin, params=RANGE).json()
    assert total == by_day["total"] == by_lang["total"] == 6
    assert sum(x["visit_count"] for x in top["data"]) == total


# ------------------------------------ Rating --------------------------------------
def test_rating_stats_exclude_hidden_feedback(
    client: TestClient,
    db: Session,
    superuser_token_headers: dict[str, str],
    normal_user_token_headers: dict[str, str],
    dataset: Dataset,
) -> None:
    """Quy tắc đã chốt: rating tính từ mọi feedback trừ `hidden` (pending vẫn tính)."""
    admin = superuser_token_headers
    before = client.get(f"{D}/summary", headers=admin).json()["ratings"]
    admin_id = uuid.UUID(client.get(f"{API}/users/me", headers=admin).json()["id"])
    user_id = uuid.UUID(
        client.get(f"{API}/users/me", headers=normal_user_token_headers).json()["id"]
    )
    a, b = uuid.UUID(dataset.a["id"]), uuid.UUID(dataset.b["id"])
    db.add_all(
        [
            Feedback(
                user_id=admin_id,
                artifact_id=a,
                rating=5,
                comment=None,
                status=FeedbackStatus.APPROVED.value,
            ),
            Feedback(
                user_id=user_id,
                artifact_id=a,
                rating=4,
                comment="Hay",
                status=FeedbackStatus.PENDING.value,
            ),
            Feedback(
                user_id=user_id,
                artifact_id=b,
                rating=1,
                comment="Spam",
                status=FeedbackStatus.HIDDEN.value,
            ),
        ]
    )
    db.commit()

    after = client.get(f"{D}/summary", headers=admin).json()["ratings"]
    assert after["count"] - before["count"] == 2  # bản hidden không được tính
    if before["count"] == 0:
        assert after["average"] == 4.5

    top = client.get(f"{D}/top-artifacts", headers=admin, params=RANGE).json()["data"]
    by_id = {item["artifact_id"]: item for item in top}
    assert by_id[dataset.a["id"]]["rating_count"] == 2
    assert by_id[dataset.a["id"]]["average_rating"] == 4.5
    assert by_id[dataset.b["id"]]["rating_count"] == 0  # chỉ có bản hidden
    assert by_id[dataset.b["id"]]["average_rating"] is None
    assert by_id[dataset.c["id"]]["rating_count"] == 0

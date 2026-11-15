import uuid
from datetime import UTC, datetime, timedelta
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

import pytest
import reportlab
from openpyxl import load_workbook
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from sqlalchemy import event

from app.api.routes import analytics
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


@pytest.mark.parametrize(
    "path",
    ["overview", "visits", "top-artifacts", "sites", "export/excel", "export/pdf"],
)
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


@pytest.mark.parametrize("kind", ["excel", "pdf"])
def test_exports_match_filtered_sql_server_aggregates(
    client, superuser_token_headers, sample, kind
):
    site, artifacts = sample
    with (
        patch.object(
            analytics,
            "_register_pdf_fonts",
            return_value=("Helvetica", "Helvetica-Bold"),
        ),
        patch.object(analytics, "LongTable", wraps=analytics.LongTable) as tables,
    ):
        response = client.get(
            f"{API}/analytics/export/{kind}",
            headers=superuser_token_headers,
            params={
                "site_id": site["id"],
                "from": "2025-01-01T07:00:00+07:00",
                "to": "2025-01-03T00:00:00Z",
            },
        )
    assert response.status_code == 200
    assert response.headers["content-disposition"] == (
        f'attachment; filename="analytics-report.{"xlsx" if kind == "excel" else "pdf"}"'
    )
    if kind == "excel":
        workbook = load_workbook(BytesIO(response.content))
        try:
            overview, daily, sites, top, languages = workbook.worksheets
            assert [overview.cell(i, 2).value for i in (2, 3, 4)] == [3, 2, 2]
            assert list(daily.values)[1:] == [
                (datetime(2025, 1, 1), 2, 1),
                (datetime(2025, 1, 2), 1, 1),
            ]
            assert list(sites.values)[1] == (site["id"], site["name"], 3, 2)
            assert list(top.values)[1] == (
                artifacts[0]["id"],
                artifacts[0]["code"],
                2,
                1,
            )
            assert sum(row[2] for row in list(languages.values)[1:]) == 3
        finally:
            workbook.close()
    else:
        assert response.headers["content-type"] == "application/pdf"
        assert response.content.startswith(b"%PDF-")
        assert response.content.rstrip().endswith(b"%%EOF")
        rows = [item.args[0] for item in tables.call_args_list]
        assert [row[1].getPlainText() for row in rows[0][1:]] == ["3", "2", "2"]
        assert [[cell.getPlainText() for cell in row] for row in rows[1][1:]] == [
            ["2025-01-01", "2", "1"],
            ["2025-01-02", "1", "1"],
        ]
        assert rows[2][1][0].getPlainText() == site["name"]
        assert rows[3][1][0].getPlainText() == artifacts[0]["code"]


EXPORT_SHEETS = [
    "Tong quan",
    "Luot xem theo ngay",
    "Thong ke Site",
    "Top 10 hien vat",
    "Theo ngon ngu",
]


def _rows(workbook, name):
    return [list(row) for row in workbook[name].iter_rows(values_only=True)]


@pytest.mark.parametrize("path", ["export/excel", "export/pdf"])
def test_export_admin_only(client, normal_user_token_headers, path):
    assert client.get(f"{API}/analytics/{path}").status_code == 401
    assert (
        client.get(
            f"{API}/analytics/{path}", headers=normal_user_token_headers
        ).status_code
        == 403
    )


def test_export_excel_content(client, superuser_token_headers, sample):
    site, artifacts = sample
    response = client.get(
        f"{API}/analytics/export/excel",
        headers=superuser_token_headers,
        params={"site_id": site["id"]},
    )
    assert response.status_code == 200
    assert response.headers["content-type"].startswith(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    assert "analytics-report.xlsx" in response.headers["content-disposition"]

    workbook = load_workbook(BytesIO(response.content))
    assert workbook.sheetnames == EXPORT_SHEETS

    assert _rows(workbook, "Tong quan") == [
        ["Chi so", "Gia tri"],
        ["Tong luot xem", 5],
        ["Nguoi dung duy nhat", 2],
        ["Hien vat duoc xem", 2],
    ]
    daily = _rows(workbook, "Luot xem theo ngay")
    assert len(daily) == 5  # header + 4 days with views
    assert sum(row[1] for row in daily[1:]) == 5
    assert _rows(workbook, "Thong ke Site")[1:] == [[site["id"], site["name"], 5, 2]]
    top = _rows(workbook, "Top 10 hien vat")[1:]
    assert [(row[0], row[2]) for row in top] == [
        (artifacts[1]["id"], 3),
        (artifacts[0]["id"], 2),
    ]
    # Sample visits have no language: they are reported as "unknown".
    assert _rows(workbook, "Theo ngon ngu")[1:] == [["unknown", "Khong xac dinh", 5]]


def test_export_excel_respects_time_range(client, superuser_token_headers, sample):
    site, _ = sample
    response = client.get(
        f"{API}/analytics/export/excel",
        headers=superuser_token_headers,
        params={
            "site_id": site["id"],
            "from": "2025-01-01T00:00:00Z",
            "to": "2025-01-02T00:00:00Z",
        },
    )
    assert response.status_code == 200
    workbook = load_workbook(BytesIO(response.content))
    assert _rows(workbook, "Tong quan")[1:] == [
        ["Tong luot xem", 2],
        ["Nguoi dung duy nhat", 1],
        ["Hien vat duoc xem", 1],
    ]


def test_export_excel_empty_result(client, superuser_token_headers):
    response = client.get(
        f"{API}/analytics/export/excel",
        headers=superuser_token_headers,
        params={"site_id": str(uuid.uuid4())},
    )
    assert response.status_code == 200
    workbook = load_workbook(BytesIO(response.content))
    assert workbook.sheetnames == EXPORT_SHEETS
    assert _rows(workbook, "Tong quan")[1][1] == 0
    for name in EXPORT_SHEETS[1:]:
        assert len(_rows(workbook, name)) == 1  # header only


@pytest.mark.parametrize("path", ["export/excel", "export/pdf"])
def test_export_rejects_bad_ranges(client, superuser_token_headers, path):
    for params in (
        {"from": "2025-01-01"},
        {"from": "2025-02-01T00:00:00Z", "to": "2025-01-01T00:00:00Z"},
    ):
        assert (
            client.get(
                f"{API}/analytics/{path}",
                headers=superuser_token_headers,
                params=params,
            ).status_code
            == 422
        )


@pytest.fixture
def pdf_font(monkeypatch) -> None:
    font_directory = Path(reportlab.__file__).parent / "fonts"
    names = ("AnalyticsTestRegular", "AnalyticsTestBold")
    for name, filename in zip(names, ("Vera.ttf", "VeraBd.ttf"), strict=True):
        pdfmetrics.registerFont(TTFont(name, str(font_directory / filename)))
    monkeypatch.setattr(analytics, "_register_pdf_fonts", lambda: names)


@pytest.mark.usefixtures("pdf_font")
def test_export_pdf(client, superuser_token_headers, sample):
    site, _ = sample
    response = client.get(
        f"{API}/analytics/export/pdf",
        headers=superuser_token_headers,
        params={"site_id": site["id"]},
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert "analytics-report.pdf" in response.headers["content-disposition"]
    assert response.content.startswith(b"%PDF")


@pytest.mark.usefixtures("pdf_font")
def test_export_pdf_empty_result(client, superuser_token_headers):
    response = client.get(
        f"{API}/analytics/export/pdf",
        headers=superuser_token_headers,
        params={"site_id": str(uuid.uuid4())},
    )
    assert response.status_code == 200
    assert response.content.startswith(b"%PDF")

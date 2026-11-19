"""Excel export keeps user-entered text as text and never creates formulas."""

import uuid
import zipfile
from datetime import UTC, datetime
from io import BytesIO

import pytest
from openpyxl import Workbook, load_workbook

from app.api.routes.analytics import _append_row
from app.models import VisitLog
from tests.utils.heritage import API, create_artifact, create_site, purge_sites

DANGEROUS = [
    '=HYPERLINK("http://example.com","click")',
    "=1+1",
    "+SUM(1,1)",
    "-2+3",
    "@SUM(1,1)",
    "\t=1+1",
    "\r=1+1",
]


def test_append_row_stores_dangerous_text_as_text():
    ws = Workbook().active
    _append_row(ws, [*DANGEROUS, "Hội An - Phố cổ", 5, None])
    cells = list(ws[1])
    for cell, original in zip(cells[: len(DANGEROUS)], DANGEROUS, strict=True):
        assert cell.value == original  # the text is not altered
        assert cell.data_type == "s"  # and it is not a formula
        assert cell.quotePrefix is True
    assert cells[len(DANGEROUS)].value == "Hội An - Phố cổ"
    assert not cells[len(DANGEROUS)].quotePrefix
    assert cells[len(DANGEROUS) + 1].value == 5  # numbers stay numbers
    assert cells[len(DANGEROUS) + 1].data_type == "n"


def test_append_row_removes_characters_xlsx_cannot_store():
    ws = Workbook().active
    _append_row(ws, ["Đền\x00 Ngọc\x07 Sơn", "=A1\x01"])
    assert [cell.value for cell in ws[1]] == ["Đền Ngọc Sơn", "=A1"]
    assert ws["B1"].data_type == "s"


@pytest.fixture
def risky_data(client, db, superuser_token_headers):
    site = create_site(
        client,
        superuser_token_headers,
        name='=HYPERLINK("http://example.com","Hồ Gươm")',
    )
    artifact = create_artifact(client, superuser_token_headers, site["id"], code="=1+1")
    admin_id = client.get(f"{API}/users/me", headers=superuser_token_headers).json()[
        "id"
    ]
    db.add(
        VisitLog(
            artifact_id=uuid.UUID(artifact["id"]),
            user_id=uuid.UUID(admin_id),
            visited_at=datetime(2025, 1, 1, tzinfo=UTC),
        )
    )
    db.commit()
    yield site, artifact
    purge_sites(db, [site["id"]])


def test_export_excel_has_no_formulas_from_user_text(
    client, superuser_token_headers, risky_data
):
    site, artifact = risky_data
    response = client.get(
        f"{API}/analytics/export/excel",
        headers=superuser_token_headers,
        params={"site_id": site["id"]},
    )
    assert response.status_code == 200

    # Raw XML: no formula element exists anywhere in the workbook.
    with zipfile.ZipFile(BytesIO(response.content)) as archive:
        for name in archive.namelist():
            if name.startswith("xl/worksheets/sheet"):
                assert b"<f>" not in archive.read(name), name

    workbook = load_workbook(BytesIO(response.content))
    for sheet in workbook.worksheets:
        for row in sheet.iter_rows():
            assert all(cell.data_type != "f" for cell in row), sheet.title

    overview = [list(r) for r in workbook["Tong quan"].iter_rows(min_row=2)]
    assert [row[1].value for row in overview] == [1, 1, 1]

    site_row = [list(r) for r in workbook["Thong ke Site"].iter_rows(min_row=2)]
    assert len(site_row) == 1
    name_cell = site_row[0][1]
    assert name_cell.value == site["name"]  # exact text, Vietnamese kept
    assert name_cell.data_type == "s" and name_cell.quotePrefix is True

    top_row = [list(r) for r in workbook["Top 10 hien vat"].iter_rows(min_row=2)]
    assert top_row[0][1].value == artifact["code"] == "=1+1"
    assert top_row[0][1].data_type == "s"
    # Numbers are still numbers.
    assert top_row[0][2].value == 1 and top_row[0][2].data_type == "n"

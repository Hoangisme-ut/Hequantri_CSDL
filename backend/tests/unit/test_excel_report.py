"""Kiểm thử bộ ghi file Excel (không cần cơ sở dữ liệu)."""

import io
import zipfile
from datetime import UTC, date, datetime
from xml.etree import ElementTree

import pytest

from app.services.excel_report import Sheet, build_workbook

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def _parts(content: bytes) -> dict[str, bytes]:
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        assert archive.testzip() is None
        return {name: archive.read(name) for name in archive.namelist()}


def test_workbook_is_valid_zip_of_well_formed_xml() -> None:
    content = build_workbook(
        [Sheet("Báo cáo", ["Tên", "Số"], [["Trống đồng", 3], ["Bình gốm", 1.5]])]
    )
    parts = _parts(content)
    assert {
        "[Content_Types].xml",
        "_rels/.rels",
        "xl/workbook.xml",
        "xl/_rels/workbook.xml.rels",
        "xl/styles.xml",
        "xl/worksheets/sheet1.xml",
    } <= set(parts)
    for data in parts.values():
        ElementTree.fromstring(data)  # XML hợp lệ
    sheet = ElementTree.fromstring(parts["xl/worksheets/sheet1.xml"])
    assert len(sheet.findall(".//m:row", NS)) == 3  # tiêu đề + 2 dòng


def test_text_is_never_a_formula_and_special_chars_are_safe() -> None:
    content = build_workbook(
        [Sheet("S", ["A"], [["=1+1"], ["<b>&\"'"], ["lỗi\x00ẩn\x0b"]])]
    )
    sheet = ElementTree.fromstring(_parts(content)["xl/worksheets/sheet1.xml"])
    assert sheet.findall(".//m:f", NS) == []  # không có công thức nào
    texts = [
        "".join(c.itertext()) for c in sheet.iterfind(".//m:c[@t='inlineStr']", NS)
    ]
    assert "=1+1" in texts
    assert "<b>&\"'" in texts
    assert "lỗiẩn" in texts  # ký tự điều khiển bị bỏ


def test_dates_numbers_and_empty_cells() -> None:
    content = build_workbook(
        [
            Sheet(
                "S",
                ["D", "T", "N", "F", "E"],
                [
                    [
                        date(2001, 3, 10),
                        datetime(2026, 11, 12, 3, tzinfo=UTC),
                        4,
                        4.5,
                        None,
                    ]
                ],
            )
        ]
    )
    sheet = ElementTree.fromstring(_parts(content)["xl/worksheets/sheet1.xml"])
    cells = {c.get("r"): c for c in sheet.iterfind(".//m:row[@r='2']/m:c", NS)}
    assert cells["A2"].findtext("m:v", namespaces=NS) == "36960"  # 2001-03-10
    assert float(cells["B2"].findtext("m:v", namespaces=NS)) == pytest.approx(46338.125)
    assert cells["C2"].findtext("m:v", namespaces=NS) == "4"
    assert cells["D2"].findtext("m:v", namespaces=NS) == "4.5"
    assert "E2" not in cells  # None -> bỏ trống


def test_sheet_names_are_sanitized_and_unique() -> None:
    content = build_workbook(
        [Sheet("A/B:C", ["x"]), Sheet("a/b:c", ["x"]), Sheet("y" * 50, ["x"])]
    )
    workbook = ElementTree.fromstring(_parts(content)["xl/workbook.xml"])
    names = [sheet.get("name") for sheet in workbook.iterfind(".//m:sheet", NS)]
    assert names[0] == "A-B-C"
    assert names[1] == "a-b-c (2)"  # tên trùng (không phân biệt hoa thường)
    assert all(name is not None and len(name) <= 31 for name in names)


def test_needs_at_least_one_sheet() -> None:
    with pytest.raises(ValueError):
        build_workbook([])

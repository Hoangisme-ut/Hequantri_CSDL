"""Tạo file Excel (.xlsx) cho báo cáo dashboard, chỉ dùng thư viện chuẩn.

Không thêm phụ thuộc mới (openpyxl...) vào dự án. File .xlsx là một gói zip các tệp XML;
module này chỉ ghi phần cần cho báo cáo: nhiều sheet, dòng tiêu đề đậm, cố định dòng
tiêu đề, độ rộng cột, số, ngày và văn bản.

Mọi chuỗi được ghi dạng văn bản thuần (`inlineStr`) nên Excel không bao giờ coi nội dung
như công thức, kể cả khi bắt đầu bằng `=`, `+`, `-` hoặc `@`.
"""

import io
import re
import zipfile
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from typing import Any
from xml.sax.saxutils import escape

XLSX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

_MAX_SHEET_NAME = 31
_MAX_TEXT = 32767  # giới hạn ký tự trong một ô của Excel
_MAX_COLUMN_WIDTH = 60
_EXCEL_EPOCH = datetime(1899, 12, 30)
# Ký tự điều khiển không hợp lệ trong XML 1.0 (Excel sẽ báo file hỏng nếu có)
_ILLEGAL_XML = re.compile("[\x00-\x08\x0b\x0c\x0e-\x1f￾￿]")
_BAD_SHEET_CHARS = re.compile(r"[\[\]:*?/\\]")

# Chỉ số kiểu ô trong styles.xml bên dưới
_STYLE_DEFAULT, _STYLE_HEADER, _STYLE_DATE, _STYLE_DECIMAL, _STYLE_DATETIME = range(5)


@dataclass
class Sheet:
    name: str
    header: list[str]
    rows: list[list[Any]] = field(default_factory=list)


def _column_letter(index: int) -> str:
    """0 -> A, 25 -> Z, 26 -> AA."""
    letters = ""
    index += 1
    while index:
        index, remainder = divmod(index - 1, 26)
        letters = chr(65 + remainder) + letters
    return letters


def _clean_text(value: str) -> str:
    return _ILLEGAL_XML.sub("", value)[:_MAX_TEXT]


def _sheet_names(sheets: list[Sheet]) -> list[str]:
    """Tên sheet hợp lệ với Excel: <= 31 ký tự, không có []:*?/\\, không trùng nhau."""
    used: set[str] = set()
    names: list[str] = []
    for sheet in sheets:
        base = _BAD_SHEET_CHARS.sub("-", _clean_text(sheet.name)).strip("'") or "Sheet"
        name = base[:_MAX_SHEET_NAME]
        counter = 2
        while name.lower() in used:
            suffix = f" ({counter})"
            name = base[: _MAX_SHEET_NAME - len(suffix)] + suffix
            counter += 1
        used.add(name.lower())
        names.append(name)
    return names


def _cell(ref: str, value: Any, *, header: bool = False) -> str:
    if value is None:
        return ""
    if header:
        text = escape(_clean_text(str(value)))
        return (
            f'<c r="{ref}" s="{_STYLE_HEADER}" t="inlineStr">'
            f'<is><t xml:space="preserve">{text}</t></is></c>'
        )
    if isinstance(value, bool):  # bool là con của int nên phải kiểm tra trước
        return f'<c r="{ref}" t="b"><v>{int(value)}</v></c>'
    if isinstance(value, int):
        return f'<c r="{ref}"><v>{value}</v></c>'
    if isinstance(value, float):
        return f'<c r="{ref}" s="{_STYLE_DECIMAL}"><v>{value!r}</v></c>'
    if isinstance(value, datetime):
        moment = value.astimezone(UTC).replace(tzinfo=None) if value.tzinfo else value
        serial = (moment - _EXCEL_EPOCH).total_seconds() / 86400
        return f'<c r="{ref}" s="{_STYLE_DATETIME}"><v>{serial!r}</v></c>'
    if isinstance(value, date):
        serial = (value - _EXCEL_EPOCH.date()).days
        return f'<c r="{ref}" s="{_STYLE_DATE}"><v>{serial}</v></c>'
    text = escape(_clean_text(str(value)))
    return f'<c r="{ref}" t="inlineStr"><is><t xml:space="preserve">{text}</t></is></c>'


def _display_length(value: Any) -> int:
    if value is None:
        return 0
    if isinstance(value, datetime):
        return 19
    if isinstance(value, date):
        return 10
    return max((len(line) for line in str(value).splitlines()), default=0)


def _sheet_xml(sheet: Sheet) -> str:
    column_count = max([len(sheet.header), *(len(row) for row in sheet.rows)])
    widths = [
        min(
            _MAX_COLUMN_WIDTH,
            max(
                8,
                _display_length(sheet.header[i] if i < len(sheet.header) else None),
                *(_display_length(row[i]) for row in sheet.rows if i < len(row)),
            )
            + 2,
        )
        for i in range(column_count)
    ]
    cols = "".join(
        f'<col min="{i + 1}" max="{i + 1}" width="{width}" customWidth="1"/>'
        for i, width in enumerate(widths)
    )
    all_rows = [[*sheet.header], *sheet.rows]
    body = []
    for row_index, row in enumerate(all_rows, start=1):
        cells = "".join(
            _cell(
                f"{_column_letter(col_index)}{row_index}",
                value,
                header=row_index == 1,
            )
            for col_index, value in enumerate(row)
        )
        body.append(f'<row r="{row_index}">{cells}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        "</sheetView></sheetViews>"
        f"<cols>{cols}</cols>"
        f"<sheetData>{''.join(body)}</sheetData>"
        "</worksheet>"
    )


_STYLES_XML = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="2">'
    '<numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/>'
    '<numFmt numFmtId="165" formatCode="yyyy\\-mm\\-dd\\ hh:mm:ss"/>'
    "</numFmts>"
    '<fonts count="2">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    "</fonts>"
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFD9E1F2"/>'
    '<bgColor indexed="64"/></patternFill></fill>'
    "</fills>"
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border>'
    "</borders>"
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
    "</cellStyleXfs>"
    '<cellXfs count="5">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" '
    'applyFont="1" applyFill="1" applyAlignment="1">'
    '<alignment vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
    '<xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
    "</cellXfs>"
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/>'
    "</cellStyles>"
    "</styleSheet>"
)


def build_workbook(sheets: list[Sheet]) -> bytes:
    """Ghi các sheet thành nội dung file .xlsx (bytes)."""
    if not sheets:
        raise ValueError("Cần ít nhất một sheet")
    names = _sheet_names(sheets)
    sheet_overrides = "".join(
        f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/'
        'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        for i in range(1, len(sheets) + 1)
    )
    content_types = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
        'package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
        'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.'
        'openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        f"{sheet_overrides}</Types>"
    )
    root_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
        'relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.'
        'org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/></Relationships>'
    )
    workbook = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
        'relationships"><sheets>'
        + "".join(
            f'<sheet name="{escape(name, {chr(34): "&quot;"})}" sheetId="{i}" '
            f'r:id="rId{i}"/>'
            for i, name in enumerate(names, start=1)
        )
        + "</sheets></workbook>"
    )
    relationships = "".join(
        f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/'
        f'officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>'
        for i in range(1, len(sheets) + 1)
    )
    workbook_rels = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
        f'relationships">{relationships}'
        f'<Relationship Id="rId{len(sheets) + 1}" Type="http://schemas.openxmlformats.'
        'org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        "</Relationships>"
    )

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types)
        archive.writestr("_rels/.rels", root_rels)
        archive.writestr("xl/workbook.xml", workbook)
        archive.writestr("xl/_rels/workbook.xml.rels", workbook_rels)
        archive.writestr("xl/styles.xml", _STYLES_XML)
        for i, sheet in enumerate(sheets, start=1):
            archive.writestr(f"xl/worksheets/sheet{i}.xml", _sheet_xml(sheet))
    return buffer.getvalue()

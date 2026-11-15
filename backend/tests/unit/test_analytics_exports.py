import uuid
from datetime import UTC, date, datetime
from io import BytesIO
from pathlib import Path
from typing import Any
from unittest import TestCase
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from openpyxl import Workbook, load_workbook
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import LongTable
from sqlmodel import Session

from app.api.deps import get_current_user, get_db
from app.api.routes import analytics
from app.models import User


class AnalyticsExportTests(TestCase):
    """Exercise real report rendering with mocked aggregate query results."""

    def setUp(self) -> None:
        self.session = MagicMock(spec=Session)
        self.connection = self.session.connection.return_value
        self.actor = User(
            email="export-admin@example.com",
            hashed_password="unused",
            is_superuser=True,
        )
        app = FastAPI()
        app.include_router(analytics.router, prefix="/api/v1")
        app.dependency_overrides[get_db] = lambda: self.session
        app.dependency_overrides[get_current_user] = lambda: self.actor
        self.client = self.enterContext(TestClient(app))
        self.site_id = uuid.uuid4()
        self.artifact_id = uuid.uuid4()

    def set_report_data(
        self, *, empty: bool = False, missing_site_name: bool = False
    ) -> None:
        rows: list[Any] = [
            {"views": 5, "unique_users": 2, "artifacts_viewed": 1},
            [{"date": date(2025, 1, 1), "views": 5, "unique_users": 2}],
            [
                {
                    "site_id": self.site_id,
                    "name": "North & <River> Site",
                    "views": 5,
                    "unique_users": 2,
                }
            ],
            [
                {
                    "artifact_id": self.artifact_id,
                    "code": "A<1&2>",
                    "views": 5,
                    "unique_users": 2,
                }
            ],
            [
                {"code": "en", "name": "English", "views": 4},
                {"code": None, "name": None, "views": 1},
            ],
        ]
        if missing_site_name:
            rows[2][0]["name"] = None
        if empty:
            rows = [
                {"views": 0, "unique_users": 0, "artifacts_viewed": 0},
                [],
                [],
                [],
                [],
            ]
        results = []
        for row in rows:
            result = MagicMock()
            result.mappings.return_value.one.return_value = row
            result.mappings.return_value.all.return_value = row
            results.append(result)
        self.connection.execute.side_effect = results

    def test_excel_contains_all_aggregate_sections_and_language_fallback(self) -> None:
        self.set_report_data()
        response = self.client.get("/api/v1/analytics/export/excel")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["content-type"],
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        self.assertEqual(
            response.headers["content-disposition"],
            'attachment; filename="analytics-report.xlsx"',
        )
        workbook = load_workbook(BytesIO(response.content))
        self.addCleanup(workbook.close)
        self.assertEqual(len(workbook.worksheets), 5)
        overview, daily, sites, artifacts, languages = workbook.worksheets
        self.assertEqual([overview.cell(i, 2).value for i in (2, 3, 4)], [5, 2, 1])
        self.assertEqual(list(daily.values)[1], (datetime(2025, 1, 1), 5, 2))
        self.assertEqual(
            list(sites.values)[1], (str(self.site_id), "North & <River> Site", 5, 2)
        )
        self.assertEqual(
            list(artifacts.values)[1], (str(self.artifact_id), "A<1&2>", 5, 2)
        )
        self.assertEqual(list(languages.values)[1], ("en", "English", 4))
        unknown = list(languages.values)[2]
        self.assertEqual((unknown[0], unknown[2]), ("unknown", 1))
        self.assertTrue(unknown[1])
        for sheet in workbook.worksheets:
            self.assertEqual(sheet.freeze_panes, "A2")
            self.assertEqual(sheet.auto_filter.ref, sheet.dimensions)

    def test_excel_empty_report_has_zero_totals_and_header_only_details(self) -> None:
        self.set_report_data(empty=True)
        response = self.client.get("/api/v1/analytics/export/excel")
        self.assertEqual(response.status_code, 200)
        workbook = load_workbook(BytesIO(response.content))
        self.addCleanup(workbook.close)
        self.assertEqual(
            [workbook.worksheets[0].cell(i, 2).value for i in (2, 3, 4)], [0, 0, 0]
        )
        self.assertTrue(all(sheet.max_row == 1 for sheet in workbook.worksheets[1:]))

    def test_pdf_renders_real_file_and_escapes_report_values(self) -> None:
        self.set_report_data()
        with (
            patch.object(
                analytics,
                "_register_pdf_fonts",
                return_value=("Helvetica", "Helvetica-Bold"),
            ),
            patch.object(analytics, "LongTable", wraps=LongTable) as tables,
        ):
            response = self.client.get("/api/v1/analytics/export/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "application/pdf")
        self.assertEqual(
            response.headers["content-disposition"],
            'attachment; filename="analytics-report.pdf"',
        )
        self.assertTrue(response.content.startswith(b"%PDF-"))
        self.assertTrue(response.content.rstrip().endswith(b"%%EOF"))
        self.assertIn(b"/Title (Analytics Report)", response.content)
        self.assertEqual(tables.call_count, 5)
        table_rows = [item.args[0] for item in tables.call_args_list]
        self.assertEqual(
            [row[1].getPlainText() for row in table_rows[0][1:]], ["5", "2", "1"]
        )
        self.assertEqual(
            [cell.getPlainText() for cell in table_rows[1][1]], ["2025-01-01", "5", "2"]
        )
        self.assertEqual(table_rows[2][1][0].getPlainText(), "North & <River> Site")
        self.assertEqual(table_rows[3][1][0].getPlainText(), "A<1&2>")
        self.assertEqual(table_rows[4][2][0].getPlainText(), "unknown")
        self.assertTrue(table_rows[4][2][1].getPlainText())

    def test_pdf_empty_report_has_placeholders_in_all_detail_tables(self) -> None:
        self.set_report_data(empty=True)
        with (
            patch.object(
                analytics,
                "_register_pdf_fonts",
                return_value=("Helvetica", "Helvetica-Bold"),
            ),
            patch.object(analytics, "LongTable", wraps=LongTable) as tables,
        ):
            response = self.client.get("/api/v1/analytics/export/pdf")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.content.startswith(b"%PDF-"))
        for item in tables.call_args_list[1:]:
            rows = item.args[0]
            self.assertEqual(len(rows), 2)
            self.assertEqual(len(rows[0]), len(rows[1]))
            self.assertTrue(rows[1][0].getPlainText())
            self.assertTrue(all(cell.getPlainText() == "" for cell in rows[1][1:]))

    def test_pdf_uses_a_label_when_site_name_is_missing(self) -> None:
        self.set_report_data(missing_site_name=True)
        with (
            patch.object(
                analytics,
                "_register_pdf_fonts",
                return_value=("Helvetica", "Helvetica-Bold"),
            ),
            patch.object(analytics, "LongTable", wraps=LongTable) as tables,
        ):
            response = self.client.get("/api/v1/analytics/export/pdf")
        self.assertEqual(response.status_code, 200)
        site_label = tables.call_args_list[2].args[0][1][0].getPlainText()
        self.assertTrue(site_label)
        self.assertNotEqual(site_label, "None")

    def test_export_filters_are_applied_to_every_aggregate_query(self) -> None:
        for kind in ("excel", "pdf"):
            with self.subTest(kind=kind):
                self.set_report_data()
                self.connection.execute.reset_mock()
                with patch.object(
                    analytics,
                    "_register_pdf_fonts",
                    return_value=("Helvetica", "Helvetica-Bold"),
                ):
                    response = self.client.get(
                        f"/api/v1/analytics/export/{kind}",
                        params={
                            "site_id": str(self.site_id),
                            "from": "2025-01-01T07:00:00+07:00",
                            "to": "2025-01-02T00:00:00Z",
                        },
                    )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(self.connection.execute.call_count, 5)
                for item in self.connection.execute.call_args_list:
                    parameters = item.args[0].compile().params
                    self.assertIn(self.site_id, parameters.values())
                    self.assertIn(datetime(2025, 1, 1, tzinfo=UTC), parameters.values())
                    self.assertIn(datetime(2025, 1, 2, tzinfo=UTC), parameters.values())

    def test_exports_reject_invalid_ranges_before_querying(self) -> None:
        for kind in ("excel", "pdf"):
            for parameters in (
                {"from": "2025-01-01"},
                {"from": "2025-02-01T00:00:00Z", "to": "2025-01-01T00:00:00Z"},
                {"site_id": "invalid"},
            ):
                with self.subTest(kind=kind, parameters=parameters):
                    response = self.client.get(
                        f"/api/v1/analytics/export/{kind}", params=parameters
                    )
                    self.assertEqual(response.status_code, 422)
        self.connection.execute.assert_not_called()

    def test_sheet_format_handles_empty_cells_and_bounds_column_widths(self) -> None:
        workbook = Workbook()
        self.addCleanup(workbook.close)
        sheet = workbook.worksheets[0]
        sheet.append(["Short", "Long", "Empty"])
        sheet.append(["X", "Y" * 100, None])
        analytics._format_export_sheet(sheet)
        self.assertEqual(sheet.freeze_panes, "A2")
        self.assertEqual(sheet.auto_filter.ref, "A1:C2")
        self.assertEqual(sheet.column_dimensions["A"].width, 14)
        self.assertEqual(sheet.column_dimensions["B"].width, 40)
        self.assertEqual(sheet.column_dimensions["C"].width, 14)

    def test_pdf_font_registration_uses_first_available_pair(self) -> None:
        with (
            patch.object(Path, "is_file", return_value=True),
            patch.object(pdfmetrics, "getRegisteredFontNames", return_value=[]),
            patch.object(analytics, "TTFont") as font,
            patch.object(pdfmetrics, "registerFont") as register,
        ):
            self.assertEqual(
                analytics._register_pdf_fonts(), ("AnalyticsRegular", "AnalyticsBold")
            )
        self.assertEqual(register.call_count, 2)
        self.assertEqual(
            [item.args[0] for item in font.call_args_list],
            ["AnalyticsRegular", "AnalyticsBold"],
        )
        self.assertTrue(font.call_args_list[0].args[1].endswith("DejaVuSans.ttf"))

    def test_pdf_font_registration_reuses_existing_fonts(self) -> None:
        with (
            patch.object(Path, "is_file", return_value=True),
            patch.object(
                pdfmetrics,
                "getRegisteredFontNames",
                return_value=["AnalyticsRegular", "AnalyticsBold"],
            ),
            patch.object(analytics, "TTFont") as font,
            patch.object(pdfmetrics, "registerFont") as register,
        ):
            self.assertEqual(
                analytics._register_pdf_fonts(), ("AnalyticsRegular", "AnalyticsBold")
            )
        font.assert_not_called()
        register.assert_not_called()

    def test_pdf_font_registration_falls_back_to_second_pair(self) -> None:
        with (
            patch.object(Path, "is_file", side_effect=[True, False, True, True]),
            patch.object(pdfmetrics, "getRegisteredFontNames", return_value=[]),
            patch.object(analytics, "TTFont") as font,
            patch.object(pdfmetrics, "registerFont"),
        ):
            self.assertEqual(
                analytics._register_pdf_fonts(), ("AnalyticsRegular", "AnalyticsBold")
            )
        self.assertTrue(font.call_args_list[0].args[1].endswith("arial.ttf"))
        self.assertTrue(font.call_args_list[1].args[1].endswith("arialbd.ttf"))

    def test_pdf_font_registration_reports_missing_fonts(self) -> None:
        with (
            patch.object(Path, "is_file", return_value=False),
            patch.object(pdfmetrics, "registerFont") as register,
        ):
            with self.assertRaisesRegex(RuntimeError, "Cannot find a .* PDF font"):
                analytics._register_pdf_fonts()
        register.assert_not_called()

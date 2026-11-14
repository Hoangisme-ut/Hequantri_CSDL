"""Aggregates of recorded content views, not physical visitors or sessions."""

import uuid
from datetime import UTC, date, datetime
from io import BytesIO
from pathlib import Path
from typing import Annotated, Any
from xml.sax.saxutils import escape

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    LongTable,
    Paragraph,
    SimpleDocTemplate,
    TableStyle,
)
from sqlalchemy import Date, cast, distinct, select
from sqlmodel import SQLModel, col, func

from app.api.deps import AdminUser, SessionDep
from app.models import Artifact, Language, Site, VisitLog

router = APIRouter(prefix="/analytics", tags=["analytics"])


class Overview(SQLModel):
    views: int
    unique_users: int
    artifacts_viewed: int


class DailyViews(SQLModel):
    date: date
    views: int
    unique_users: int


class ArtifactViews(SQLModel):
    artifact_id: uuid.UUID
    site_id: uuid.UUID
    code: str
    views: int
    unique_users: int


class SiteViews(SQLModel):
    site_id: uuid.UUID
    name: str
    views: int
    unique_users: int


def filters(
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
    site_id: uuid.UUID | None = None,
) -> list[Any]:
    """UTC [from,to); omitted boundaries are unbounded. Require explicit offsets."""
    for boundary in (from_date, to_date):
        if boundary is not None and boundary.utcoffset() is None:
            raise HTTPException(
                status_code=422, detail="Time boundaries require a timezone"
            )
    if from_date is not None and to_date is not None and from_date >= to_date:
        raise HTTPException(status_code=422, detail="from must be earlier than to")
    conditions = []
    if from_date is not None:
        conditions.append(col(VisitLog.visited_at) >= from_date.astimezone(UTC))
    if to_date is not None:
        conditions.append(col(VisitLog.visited_at) < to_date.astimezone(UTC))
    if site_id is not None:
        conditions.append(col(Artifact.site_id) == site_id)
    return conditions


Filters = Annotated[list[Any], Depends(filters)]


def _counts() -> tuple[Any, Any]:
    return func.count().label("views"), func.count(
        distinct(col(VisitLog.user_id))
    ).label("unique_users")


@router.get("/overview", response_model=Overview)
def overview(session: SessionDep, _admin: AdminUser, conditions: Filters) -> Any:
    stmt = (
        select(
            *_counts(),
            func.count(distinct(col(VisitLog.artifact_id))).label("artifacts_viewed"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
    )
    return session.connection().execute(stmt).mappings().one()


@router.get("/visits", response_model=list[DailyViews])
def visits(session: SessionDep, _admin: AdminUser, conditions: Filters) -> Any:
    # UTCDateTime persists UTC to SQL Server. Aggregate in SQL, no event loading.
    day = cast(col(VisitLog.visited_at), Date)
    stmt = (
        select(day.label("date"), *_counts())
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions, col(VisitLog.visited_at).is_not(None))
        .group_by(day)
        .order_by(day)
    )
    return session.connection().execute(stmt).mappings().all()


@router.get("/top-artifacts", response_model=list[ArtifactViews])
def top_artifacts(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
    limit: int = Query(10, ge=1, le=100),
) -> Any:
    views, users = _counts()
    stmt = (
        select(
            col(Artifact.id).label("artifact_id"),
            col(Artifact.site_id),
            col(Artifact.code),
            views,
            users,
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
        .group_by(col(Artifact.id), col(Artifact.site_id), col(Artifact.code))
        .order_by(views.desc(), col(Artifact.id))
        .limit(limit)
    )
    return session.connection().execute(stmt).mappings().all()


@router.get("/sites", response_model=list[SiteViews])
def sites(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
) -> Any:
    views, users = _counts()
    stmt = (
        select(col(Site.id).label("site_id"), col(Site.name), views, users)
        .select_from(VisitLog)
        .join(Artifact)
        .join(Site)
        .where(*conditions)
        .group_by(col(Site.id), col(Site.name))
        .order_by(views.desc(), col(Site.id))
        .offset(skip)
        .limit(limit)
    )
    return session.connection().execute(stmt).mappings().all()

def _format_export_sheet(ws: Any) -> None:
    """Format an Excel worksheet for readability."""
    header_fill = PatternFill(
        fill_type="solid",
        fgColor="1F4E78",
    )
    header_font = Font(
        bold=True,
        color="FFFFFF",
    )

    for cell in ws[1]:
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(
            horizontal="center",
            vertical="center",
            wrap_text=True,
        )

    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions
    ws.row_dimensions[1].height = 30

    for column_cells in ws.columns:
        max_length = 0
        column_letter = column_cells[0].column_letter

        for cell in column_cells:
            if cell.value is not None:
                max_length = max(
                    max_length,
                    len(str(cell.value)),
                )

        ws.column_dimensions[column_letter].width = min(
            max(max_length + 4, 14),
            40,
        )


def _register_pdf_fonts() -> tuple[str, str]:
    """Register fonts supporting Vietnamese characters."""

    font_candidates = [
        (
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
        ),
        (
            Path("C:/Windows/Fonts/arial.ttf"),
            Path("C:/Windows/Fonts/arialbd.ttf"),
        ),
    ]

    for regular_path, bold_path in font_candidates:
        if regular_path.is_file() and bold_path.is_file():
            if "AnalyticsRegular" not in pdfmetrics.getRegisteredFontNames():
                pdfmetrics.registerFont(
                    TTFont("AnalyticsRegular", str(regular_path))
                )

            if "AnalyticsBold" not in pdfmetrics.getRegisteredFontNames():
                pdfmetrics.registerFont(
                    TTFont("AnalyticsBold", str(bold_path))
                )

            return "AnalyticsRegular", "AnalyticsBold"

    raise RuntimeError(
        "Cannot find a Vietnamese-compatible PDF font."
    )


@router.get("/export/excel")
def export_excel(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
) -> StreamingResponse:
    """Export analytics report to Excel. Admin only."""

    connection = session.connection()

    # --------------------------------------------------
    # 1. Overview
    # --------------------------------------------------
    overview_stmt = (
        select(
            *_counts(),
            func.count(
                distinct(col(VisitLog.artifact_id))
            ).label("artifacts_viewed"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
    )

    overview_data = connection.execute(
        overview_stmt
    ).mappings().one()

    # --------------------------------------------------
    # 2. Visits by day
    # --------------------------------------------------
    day = cast(col(VisitLog.visited_at), Date)

    daily_stmt = (
        select(
            day.label("date"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(
            *conditions,
            col(VisitLog.visited_at).is_not(None),
        )
        .group_by(day)
        .order_by(day)
    )

    daily_data = connection.execute(
        daily_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 3. Statistics by Site
    # --------------------------------------------------
    site_stmt = (
        select(
            col(Site.id).label("site_id"),
            col(Site.name).label("name"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .join(Site)
        .where(*conditions)
        .group_by(
            col(Site.id),
            col(Site.name),
        )
        .order_by(
            func.count().desc(),
            col(Site.id),
        )
    )

    site_data = connection.execute(
        site_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 4. Top 10 artifacts
    # --------------------------------------------------
    artifact_stmt = (
        select(
            col(Artifact.id).label("artifact_id"),
            col(Artifact.code).label("code"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
        .group_by(
            col(Artifact.id),
            col(Artifact.code),
        )
        .order_by(
            func.count().desc(),
            col(Artifact.id),
        )
        .limit(10)
    )

    artifact_data = connection.execute(
        artifact_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 5. Statistics by language
    # --------------------------------------------------
    language_stmt = (
        select(
            col(Language.code).label("code"),
            col(Language.name).label("name"),
            func.count().label("views"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .outerjoin(
            Language,
            col(Language.id) == col(VisitLog.language_id),
        )
        .where(*conditions)
        .group_by(
            col(Language.code),
            col(Language.name),
        )
        .order_by(
            func.count().desc(),
            col(Language.code),
        )
    )

    language_data = connection.execute(
        language_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 6. Create Excel workbook
    # --------------------------------------------------
    workbook = Workbook()

    # Sheet 1: Overview
    ws = workbook.active
    ws.title = "Tong quan"

    ws.append(["Chi so", "Gia tri"])
    ws.append(["Tong luot xem", overview_data["views"]])
    ws.append([
        "Nguoi dung duy nhat",
        overview_data["unique_users"],
    ])
    ws.append([
        "Hien vat duoc xem",
        overview_data["artifacts_viewed"],
    ])

    _format_export_sheet(ws)

    # Sheet 2: Visits by day
    ws = workbook.create_sheet("Luot xem theo ngay")

    ws.append([
        "Ngay",
        "Luot xem",
        "Nguoi dung duy nhat",
    ])

    for item in daily_data:
        ws.append([
            item["date"],
            item["views"],
            item["unique_users"],
        ])

    _format_export_sheet(ws)

    # Sheet 3: Statistics by Site
    ws = workbook.create_sheet("Thong ke Site")

    ws.append([
        "Site ID",
        "Ten Site",
        "Luot xem",
        "Nguoi dung duy nhat",
    ])

    for item in site_data:
        ws.append([
            str(item["site_id"]),
            item["name"],
            item["views"],
            item["unique_users"],
        ])

    _format_export_sheet(ws)

    # Sheet 4: Top 10 artifacts
    ws = workbook.create_sheet("Top 10 hien vat")

    ws.append([
        "Artifact ID",
        "Ma hien vat",
        "Luot xem",
        "Nguoi dung duy nhat",
    ])

    for item in artifact_data:
        ws.append([
            str(item["artifact_id"]),
            item["code"],
            item["views"],
            item["unique_users"],
        ])

    _format_export_sheet(ws)

    # Sheet 5: Visits by language
    ws = workbook.create_sheet("Theo ngon ngu")

    ws.append([
        "Ma ngon ngu",
        "Ten ngon ngu",
        "Luot xem",
    ])

    for item in language_data:
        ws.append([
            item["code"] or "unknown",
            item["name"] or "Khong xac dinh",
            item["views"],
        ])

    _format_export_sheet(ws)

    # --------------------------------------------------
    # 7. Return Excel file
    # --------------------------------------------------
    output = BytesIO()
    workbook.save(output)
    output.seek(0)

    return StreamingResponse(
        output,
        media_type=(
            "application/vnd.openxmlformats-officedocument."
            "spreadsheetml.sheet"
        ),
        headers={
            "Content-Disposition": (
                'attachment; filename="analytics-report.xlsx"'
            )
        },
    )


@router.get("/export/pdf")
def export_pdf(
    session: SessionDep,
    _admin: AdminUser,
    conditions: Filters,
) -> StreamingResponse:
    """Export analytics report to PDF. Admin only."""

    connection = session.connection()

    # --------------------------------------------------
    # 1. Overview
    # --------------------------------------------------
    overview_stmt = (
        select(
            *_counts(),
            func.count(
                distinct(col(VisitLog.artifact_id))
            ).label("artifacts_viewed"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
    )

    overview_data = connection.execute(
        overview_stmt
    ).mappings().one()

    # --------------------------------------------------
    # 2. Visits by day
    # --------------------------------------------------
    day = cast(col(VisitLog.visited_at), Date)

    daily_stmt = (
        select(
            day.label("date"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(
            *conditions,
            col(VisitLog.visited_at).is_not(None),
        )
        .group_by(day)
        .order_by(day)
    )

    daily_data = connection.execute(
        daily_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 3. Statistics by Site
    # --------------------------------------------------
    site_stmt = (
        select(
            col(Site.id).label("site_id"),
            col(Site.name).label("name"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .join(Site)
        .where(*conditions)
        .group_by(
            col(Site.id),
            col(Site.name),
        )
        .order_by(
            func.count().desc(),
            col(Site.id),
        )
    )

    site_data = connection.execute(
        site_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 4. Top 10 artifacts
    # --------------------------------------------------
    artifact_stmt = (
        select(
            col(Artifact.id).label("artifact_id"),
            col(Artifact.code).label("code"),
            func.count().label("views"),
            func.count(
                distinct(col(VisitLog.user_id))
            ).label("unique_users"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .where(*conditions)
        .group_by(
            col(Artifact.id),
            col(Artifact.code),
        )
        .order_by(
            func.count().desc(),
            col(Artifact.id),
        )
        .limit(10)
    )

    artifact_data = connection.execute(
        artifact_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 5. Statistics by language
    # --------------------------------------------------
    language_stmt = (
        select(
            col(Language.code).label("code"),
            col(Language.name).label("name"),
            func.count().label("views"),
        )
        .select_from(VisitLog)
        .join(Artifact)
        .outerjoin(
            Language,
            col(Language.id) == col(VisitLog.language_id),
        )
        .where(*conditions)
        .group_by(
            col(Language.code),
            col(Language.name),
        )
        .order_by(
            func.count().desc(),
            col(Language.code),
        )
    )

    language_data = connection.execute(
        language_stmt
    ).mappings().all()

    # --------------------------------------------------
    # 6. Register Vietnamese-compatible fonts
    # --------------------------------------------------
    regular_font, bold_font = _register_pdf_fonts()

    # --------------------------------------------------
    # 7. Create PDF styles
    # --------------------------------------------------
    title_style = ParagraphStyle(
        "AnalyticsTitle",
        fontName=bold_font,
        fontSize=18,
        leading=24,
        alignment=TA_CENTER,
        textColor=colors.HexColor("#1F4E78"),
        spaceAfter=6 * mm,
    )

    section_style = ParagraphStyle(
        "AnalyticsSection",
        fontName=bold_font,
        fontSize=12,
        leading=16,
        textColor=colors.HexColor("#1F4E78"),
        spaceBefore=4 * mm,
        spaceAfter=2 * mm,
    )

    header_style = ParagraphStyle(
        "AnalyticsHeader",
        fontName=bold_font,
        fontSize=9,
        leading=12,
        textColor=colors.white,
    )

    cell_style = ParagraphStyle(
        "AnalyticsCell",
        fontName=regular_font,
        fontSize=8,
        leading=11,
    )

    # --------------------------------------------------
    # 8. Helper to create PDF tables
    # --------------------------------------------------
    def build_table(
        headers: list[str],
        rows: list[list[Any]],
        column_widths: list[float],
    ) -> LongTable:
        table_data = [
            [
                Paragraph(escape(header), header_style)
                for header in headers
            ]
        ]

        if rows:
            for row in rows:
                table_data.append(
                    [
                        Paragraph(
                            escape(str(value)),
                            cell_style,
                        )
                        for value in row
                    ]
                )
        else:
            empty_row = [
                Paragraph("Không có dữ liệu", cell_style)
            ]

            empty_row.extend(
                Paragraph("", cell_style)
                for _ in range(len(headers) - 1)
            )

            table_data.append(empty_row)

        table = LongTable(
            table_data,
            colWidths=column_widths,
            repeatRows=1,
            hAlign="LEFT",
        )

        table.setStyle(
            TableStyle(
                [
                    (
                        "BACKGROUND",
                        (0, 0),
                        (-1, 0),
                        colors.HexColor("#1F4E78"),
                    ),
                    (
                        "TEXTCOLOR",
                        (0, 0),
                        (-1, 0),
                        colors.white,
                    ),
                    (
                        "FONTNAME",
                        (0, 0),
                        (-1, 0),
                        bold_font,
                    ),
                    (
                        "FONTNAME",
                        (0, 1),
                        (-1, -1),
                        regular_font,
                    ),
                    (
                        "GRID",
                        (0, 0),
                        (-1, -1),
                        0.4,
                        colors.HexColor("#D9E2F3"),
                    ),
                    (
                        "VALIGN",
                        (0, 0),
                        (-1, -1),
                        "MIDDLE",
                    ),
                    (
                        "LEFTPADDING",
                        (0, 0),
                        (-1, -1),
                        6,
                    ),
                    (
                        "RIGHTPADDING",
                        (0, 0),
                        (-1, -1),
                        6,
                    ),
                    (
                        "TOPPADDING",
                        (0, 0),
                        (-1, -1),
                        6,
                    ),
                    (
                        "BOTTOMPADDING",
                        (0, 0),
                        (-1, -1),
                        6,
                    ),
                ]
            )
        )

        return table

    # --------------------------------------------------
    # 9. Build PDF content
    # --------------------------------------------------
    output = BytesIO()

    document = SimpleDocTemplate(
        output,
        pagesize=landscape(A4),
        rightMargin=12 * mm,
        leftMargin=12 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
        title="Analytics Report",
        author="Smart Heritage",
    )

    story = []

    story.append(
        Paragraph(
            "BÁO CÁO THỐNG KÊ ANALYTICS",
            title_style,
        )
    )

    # Section 1: Overview
    story.append(
        Paragraph("1. Tổng quan", section_style)
    )

    overview_rows = [
        ["Tổng lượt xem", overview_data["views"]],
        ["Người dùng duy nhất", overview_data["unique_users"]],
        ["Hiện vật được xem", overview_data["artifacts_viewed"]],
    ]

    story.append(
        build_table(
            ["Chỉ số", "Giá trị"],
            overview_rows,
            [100 * mm, 50 * mm],
        )
    )

    # Section 2: Daily views
    story.append(
        Paragraph("2. Lượt xem theo ngày", section_style)
    )

    daily_rows = [
        [
            item["date"].isoformat(),
            item["views"],
            item["unique_users"],
        ]
        for item in daily_data
    ]

    story.append(
        build_table(
            ["Ngày", "Lượt xem", "Người dùng duy nhất"],
            daily_rows,
            [90 * mm, 55 * mm, 55 * mm],
        )
    )

    # Section 3: Site statistics
    story.append(
        Paragraph("3. Thống kê theo Site", section_style)
    )

    site_rows = [
        [
            item["name"] or "Không xác định",
            item["views"],
            item["unique_users"],
        ]
        for item in site_data
    ]

    story.append(
        build_table(
            ["Tên Site", "Lượt xem", "Người dùng duy nhất"],
            site_rows,
            [100 * mm, 50 * mm, 50 * mm],
        )
    )

    # Section 4: Top 10 artifacts
    story.append(
        Paragraph("4. Top 10 hiện vật", section_style)
    )

    artifact_rows = [
        [
            item["code"],
            item["views"],
            item["unique_users"],
        ]
        for item in artifact_data
    ]

    story.append(
        build_table(
            ["Mã hiện vật", "Lượt xem", "Người dùng duy nhất"],
            artifact_rows,
            [100 * mm, 50 * mm, 50 * mm],
        )
    )

    # Section 5: Language statistics
    story.append(
        Paragraph("5. Thống kê theo ngôn ngữ", section_style)
    )

    language_rows = [
        [
            item["code"] or "unknown",
            item["name"] or "Không xác định",
            item["views"],
        ]
        for item in language_data
    ]

    story.append(
        build_table(
            ["Mã ngôn ngữ", "Tên ngôn ngữ", "Lượt xem"],
            language_rows,
            [60 * mm, 90 * mm, 50 * mm],
        )
    )

    # --------------------------------------------------
    # 10. Generate and return PDF
    # --------------------------------------------------
    document.build(story)

    output.seek(0)

    return StreamingResponse(
        output,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                'attachment; filename="analytics-report.pdf"'
            )
        },
    )

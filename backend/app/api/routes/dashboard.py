import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import ColumnElement, Date, Float, cast, true
from sqlmodel import SQLModel, col, func, select

from app import crud
from app.api.deps import AdminUser, SessionDep
from app.api.docs import errors
from app.models import (
    Artifact,
    Beacon,
    Feedback,
    FeedbackStatus,
    Language,
    Site,
    VisitLog,
)
from app.services.excel_report import XLSX_MEDIA_TYPE, Sheet, build_workbook

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

# Số ngày tối đa của biểu đồ "lượt xem theo ngày" (tránh trả về quá nhiều dòng)
MAX_DAYS_RANGE = 366
DEFAULT_DAYS_RANGE = 30


# --------------------------------- Schemas --------------------------------------
class InventoryCount(SQLModel):
    total: int
    active: int


class VisitStats(SQLModel):
    total: int
    unique_visitors: int


class RatingStats(SQLModel):
    count: int
    average: float | None = None  # None khi chưa có đánh giá nào


class DashboardSummary(SQLModel):
    sites: InventoryCount
    artifacts: InventoryCount
    beacons: InventoryCount
    visits: VisitStats
    ratings: RatingStats
    from_date: date | None = None
    to_date: date | None = None


class VisitDayCount(SQLModel):
    day: date
    count: int


class VisitsByDay(SQLModel):
    from_date: date
    to_date: date
    total: int
    data: list[VisitDayCount]


class TopArtifact(SQLModel):
    artifact_id: uuid.UUID
    site_id: uuid.UUID
    code: str
    title: str | None = None
    is_active: bool
    visit_count: int
    rating_count: int = 0
    average_rating: float | None = None


class TopArtifacts(SQLModel):
    from_date: date | None = None
    to_date: date | None = None
    data: list[TopArtifact]


class LanguageVisitCount(SQLModel):
    language_id: uuid.UUID | None = None
    code: str | None = None
    name: str | None = None
    count: int


class VisitsByLanguage(SQLModel):
    from_date: date | None = None
    to_date: date | None = None
    total: int
    data: list[LanguageVisitCount]


# ---------------------------------- Bộ lọc ngày ---------------------------------
@dataclass(frozen=True)
class DateRange:
    """Khoảng ngày LỊCH THEO UTC, gồm cả hai đầu (from_date, to_date đều được tính)."""

    from_date: date | None
    to_date: date | None

    @property
    def start(self) -> datetime | None:
        if self.from_date is None:
            return None
        return datetime.combine(self.from_date, time.min, tzinfo=UTC)

    @property
    def end_exclusive(self) -> datetime | None:
        if self.to_date is None:
            return None
        return datetime.combine(self.to_date + timedelta(days=1), time.min, tzinfo=UTC)


def get_date_range(
    from_date: Annotated[
        date | None,
        Query(description="Từ ngày (YYYY-MM-DD, UTC, tính cả ngày này)"),
    ] = None,
    to_date: Annotated[
        date | None,
        Query(description="Đến ngày (YYYY-MM-DD, UTC, tính cả ngày này)"),
    ] = None,
) -> DateRange:
    if from_date and to_date and from_date > to_date:
        raise HTTPException(status_code=422, detail="from_date phải <= to_date")
    if to_date == date.max:
        raise HTTPException(status_code=422, detail="to_date quá lớn")
    return DateRange(from_date=from_date, to_date=to_date)


DateRangeDep = Annotated[DateRange, Depends(get_date_range)]


def _visit_conditions(date_range: DateRange) -> list[ColumnElement[bool]]:
    conditions: list[ColumnElement[bool]] = []
    if date_range.start is not None:
        conditions.append(col(VisitLog.visited_at) >= date_range.start)
    if date_range.end_exclusive is not None:
        conditions.append(col(VisitLog.visited_at) < date_range.end_exclusive)
    return conditions


def _rating_conditions() -> list[ColumnElement[bool]]:
    """Quy tắc đã chốt: rating tính từ mọi feedback trừ `hidden` (kể cả pending)."""
    return [col(Feedback.status) != FeedbackStatus.HIDDEN.value]


def _average(value: Any) -> float | None:
    return None if value is None else round(float(value), 2)


def _count(session: SessionDep, model: Any, *conditions: ColumnElement[bool]) -> int:
    """Đếm bằng COUNT(*) trong SQL (không đếm số dòng của một trang dữ liệu)."""
    return session.exec(
        select(func.count()).select_from(model).where(*conditions)
    ).one()


# ---------------------------------- Endpoints -----------------------------------
@router.get(
    "/summary", response_model=DashboardSummary, responses=errors(401, 403, 422)
)
def read_summary(
    session: SessionDep, _admin: AdminUser, date_range: DateRangeDep
) -> Any:
    """
    Tổng quan hệ thống. **Chỉ Admin**.

    - `sites`, `artifacts`, `beacons`: tổng số hiện có (`total`) và số đang hoạt động
      (`active`, tức `is_active = true`). **Không** phụ thuộc bộ lọc ngày.
    - `visits`: số lượt xem (`total`) và số người xem khác nhau (`unique_visitors`)
      trong khoảng `from_date` - `to_date` (UTC). Bỏ trống = toàn bộ thời gian.
    - `ratings`: số đánh giá và điểm trung bình (1-5, làm tròn 2 chữ số) của mọi
      feedback **trừ `hidden`**. **Không** phụ thuộc bộ lọc ngày.
    """
    conditions = _visit_conditions(date_range)
    rating_count, rating_avg = session.exec(
        select(func.count(), func.avg(cast(col(Feedback.rating), Float))).where(
            *_rating_conditions()
        )
    ).one()
    unique_visitors = session.exec(
        select(func.count(col(VisitLog.user_id).distinct())).where(*conditions)
    ).one()
    return DashboardSummary(
        sites=InventoryCount(
            total=_count(session, Site),
            active=_count(session, Site, col(Site.is_active) == true()),
        ),
        artifacts=InventoryCount(
            total=_count(session, Artifact),
            active=_count(session, Artifact, col(Artifact.is_active) == true()),
        ),
        beacons=InventoryCount(
            total=_count(session, Beacon),
            active=_count(session, Beacon, col(Beacon.is_active) == true()),
        ),
        visits=VisitStats(
            total=_count(session, VisitLog, *conditions),
            unique_visitors=unique_visitors,
        ),
        ratings=RatingStats(count=rating_count, average=_average(rating_avg)),
        from_date=date_range.from_date,
        to_date=date_range.to_date,
    )


@router.get(
    "/visits-by-day", response_model=VisitsByDay, responses=errors(401, 403, 422)
)
def read_visits_by_day(
    session: SessionDep, _admin: AdminUser, date_range: DateRangeDep
) -> Any:
    """
    Lượt xem theo từng ngày (UTC). **Chỉ Admin**.

    Trả **đủ mọi ngày** trong khoảng (ngày không có lượt xem thì `count = 0`) để vẽ biểu đồ.
    Mặc định: `to_date` = hôm nay (UTC), `from_date` = 29 ngày trước `to_date`.
    Khoảng tối đa 366 ngày, vượt quá -> 422.
    """
    to_date = date_range.to_date or datetime.now(UTC).date()
    from_date = date_range.from_date or (
        to_date - timedelta(days=DEFAULT_DAYS_RANGE - 1)
    )
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from_date phải <= to_date")
    if (to_date - from_date).days + 1 > MAX_DAYS_RANGE:
        raise HTTPException(
            status_code=422, detail=f"Khoảng ngày tối đa {MAX_DAYS_RANGE} ngày"
        )

    effective = DateRange(from_date=from_date, to_date=to_date)
    day = cast(col(VisitLog.visited_at), Date)
    rows = session.exec(
        select(day, func.count())
        .where(col(VisitLog.visited_at).is_not(None), *_visit_conditions(effective))
        .group_by(day)
        .order_by(day)
    ).all()
    counts = dict(rows)

    data: list[VisitDayCount] = []
    current = from_date
    while current <= to_date:
        data.append(VisitDayCount(day=current, count=counts.get(current, 0)))
        current += timedelta(days=1)
    return VisitsByDay(
        from_date=from_date,
        to_date=to_date,
        total=sum(item.count for item in data),
        data=data,
    )


@router.get(
    "/top-artifacts", response_model=TopArtifacts, responses=errors(401, 403, 422)
)
def read_top_artifacts(
    session: SessionDep,
    _admin: AdminUser,
    date_range: DateRangeDep,
    limit: Annotated[int, Query(ge=1, le=50, description="Số hiện vật tối đa")] = 10,
    lang: Annotated[
        str | None, Query(description="Mã ngôn ngữ của tiêu đề (vi, en...)")
    ] = None,
) -> Any:
    """
    Hiện vật được xem nhiều nhất. **Chỉ Admin**.

    Xếp theo số lượt xem giảm dần; bằng nhau thì theo mã hiện vật (`code`) rồi `id`
    để thứ tự luôn ổn định. `title` theo `lang`, không có thì dùng ngôn ngữ mặc định,
    rồi bản dịch bất kỳ; hiện vật chưa có bản dịch nào thì `title = null`.
    Hiện vật đã ẩn vẫn được tính (xem cờ `is_active`).
    `rating_count` / `average_rating`: đánh giá của hiện vật, **trừ `hidden`**
    (không phụ thuộc bộ lọc ngày; chưa có đánh giá thì `0` / `null`).
    """
    visit_count = func.count(col(VisitLog.id))
    rows = session.exec(
        select(
            col(Artifact.id),
            col(Artifact.site_id),
            col(Artifact.code),
            visit_count,
        )
        .select_from(VisitLog)
        .join(Artifact, col(Artifact.id) == col(VisitLog.artifact_id))
        .where(*_visit_conditions(date_range))
        .group_by(col(Artifact.id), col(Artifact.site_id), col(Artifact.code))
        .order_by(visit_count.desc(), col(Artifact.code), col(Artifact.id))
        .limit(limit)
    ).all()

    artifact_ids = [row[0] for row in rows]
    # sqlmodel.select chỉ hỗ trợ tối đa 4 cột nên cờ is_active lấy bằng truy vấn riêng
    active_by_id = dict(
        session.exec(
            select(col(Artifact.id), col(Artifact.is_active)).where(
                col(Artifact.id).in_(artifact_ids)
            )
        ).all()
    )
    ratings = {
        artifact_id: (rating_count, rating_avg)
        for artifact_id, rating_count, rating_avg in session.exec(
            select(
                col(Feedback.artifact_id),
                func.count(),
                func.avg(cast(col(Feedback.rating), Float)),
            )
            .where(
                col(Feedback.artifact_id).in_(artifact_ids),
                *_rating_conditions(),
            )
            .group_by(col(Feedback.artifact_id))
        ).all()
    }
    language = crud.resolve_language(session=session, lang_code=lang)
    # một truy vấn chung cho mọi hiện vật trong bảng xếp hạng (không gọi lặp từng dòng)
    translations = crud.pick_translations(
        session=session, artifact_ids=artifact_ids, language=language
    )
    data: list[TopArtifact] = []
    for artifact_id, site_id, code, count in rows:
        translation, _ = translations.get(artifact_id, (None, None))
        data.append(
            TopArtifact(
                artifact_id=artifact_id,
                site_id=site_id,
                code=code,
                title=translation.title if translation else None,
                is_active=active_by_id[artifact_id],
                visit_count=count,
                rating_count=ratings.get(artifact_id, (0, None))[0],
                average_rating=_average(ratings.get(artifact_id, (0, None))[1]),
            )
        )
    return TopArtifacts(
        from_date=date_range.from_date, to_date=date_range.to_date, data=data
    )


@router.get(
    "/visits-by-language",
    response_model=VisitsByLanguage,
    responses=errors(401, 403, 422),
)
def read_visits_by_language(
    session: SessionDep, _admin: AdminUser, date_range: DateRangeDep
) -> Any:
    """
    Thống kê lượt xem theo ngôn ngữ. **Chỉ Admin**.

    Mỗi dòng là một ngôn ngữ có lượt xem (nhiều nhất trước). Lượt xem không ghi ngôn ngữ
    nằm ở dòng có `language_id = null`. Tổng các dòng bằng `total`, và bằng
    `summary.visits.total` với cùng bộ lọc ngày.
    """
    count = func.count(col(VisitLog.id))
    rows = session.exec(
        select(col(VisitLog.language_id), col(Language.code), col(Language.name), count)
        .select_from(VisitLog)
        .outerjoin(Language, col(Language.id) == col(VisitLog.language_id))
        .where(*_visit_conditions(date_range))
        .group_by(col(VisitLog.language_id), col(Language.code), col(Language.name))
        .order_by(count.desc(), col(Language.code))
    ).all()
    data = [
        LanguageVisitCount(language_id=language_id, code=code, name=name, count=total)
        for language_id, code, name, total in rows
    ]
    return VisitsByLanguage(
        from_date=date_range.from_date,
        to_date=date_range.to_date,
        total=sum(item.count for item in data),
        data=data,
    )


@router.get(
    "/export.xlsx",
    response_model=None,
    responses={
        200: {
            "description": "File Excel (.xlsx) gồm 4 sheet: Tổng quan, Lượt xem theo ngày, "
            "Hiện vật nổi bật, Ngôn ngữ",
            "content": {
                XLSX_MEDIA_TYPE: {"schema": {"type": "string", "format": "binary"}}
            },
        },
        **errors(401, 403, 422),
    },
)
def export_report(
    session: SessionDep,
    _admin: AdminUser,
    date_range: DateRangeDep,
    limit: Annotated[
        int, Query(ge=1, le=50, description="Số hiện vật nổi bật tối đa")
    ] = 10,
    lang: Annotated[
        str | None, Query(description="Mã ngôn ngữ của tiêu đề hiện vật (vi, en...)")
    ] = None,
) -> Response:
    """
    Xuất báo cáo thống kê ra **Excel (.xlsx)**. **Chỉ Admin**.

    Dùng đúng bộ lọc ngày và đúng truy vấn của các endpoint dashboard nên số liệu trong file
    **trùng** với `summary`, `visits-by-day`, `top-artifacts` và `visits-by-language`:

    - **Tổng quan**: số Site/Hiện vật/Beacon, tổng lượt xem, số khách xem khác nhau, đánh giá.
    - **Lượt xem theo ngày**: mọi ngày trong khoảng (mặc định 30 ngày gần nhất, tối đa 366).
    - **Hiện vật nổi bật**: top `limit` hiện vật xem nhiều nhất kèm đánh giá.
    - **Ngôn ngữ**: lượt xem theo ngôn ngữ.

    Chưa hỗ trợ xuất PDF.
    """
    summary: DashboardSummary = read_summary(session, _admin, date_range)
    by_day: VisitsByDay = read_visits_by_day(session, _admin, date_range)
    top: TopArtifacts = read_top_artifacts(
        session=session, _admin=_admin, date_range=date_range, limit=limit, lang=lang
    )
    by_language: VisitsByLanguage = read_visits_by_language(session, _admin, date_range)

    now = datetime.now(UTC)
    everything = "Toàn bộ thời gian"
    sheets = [
        Sheet(
            "Tổng quan",
            ["Chỉ số", "Giá trị"],
            [
                ["Từ ngày (UTC)", summary.from_date or everything],
                ["Đến ngày (UTC)", summary.to_date or everything],
                ["Tổng số Site", summary.sites.total],
                ["Site đang hoạt động", summary.sites.active],
                ["Tổng số hiện vật", summary.artifacts.total],
                ["Hiện vật đang hoạt động", summary.artifacts.active],
                ["Tổng số Beacon", summary.beacons.total],
                ["Beacon đang hoạt động", summary.beacons.active],
                ["Tổng lượt xem", summary.visits.total],
                ["Số khách xem khác nhau", summary.visits.unique_visitors],
                ["Số đánh giá (không tính hidden)", summary.ratings.count],
                [
                    "Điểm đánh giá trung bình",
                    summary.ratings.average
                    if summary.ratings.average is not None
                    else "Chưa có đánh giá",
                ],
                ["Thời điểm xuất (UTC)", now],
            ],
        ),
        Sheet(
            "Lượt xem theo ngày",
            ["Ngày (UTC)", "Số lượt xem"],
            [[item.day, item.count] for item in by_day.data],
        ),
        Sheet(
            "Hiện vật nổi bật",
            [
                "Hạng",
                "Mã hiện vật",
                "Tiêu đề",
                "Đang hoạt động",
                "Số lượt xem",
                "Số đánh giá",
                "Điểm trung bình",
            ],
            [
                [
                    rank,
                    item.code,
                    item.title or "(chưa có bản dịch)",
                    "Có" if item.is_active else "Không",
                    item.visit_count,
                    item.rating_count,
                    item.average_rating,
                ]
                for rank, item in enumerate(top.data, start=1)
            ],
        ),
        Sheet(
            "Ngôn ngữ",
            ["Mã ngôn ngữ", "Tên ngôn ngữ", "Số lượt xem"],
            [
                [
                    item.code or "-",
                    item.name or "Không ghi nhận",
                    item.count,
                ]
                for item in by_language.data
            ],
        ),
    ]
    filename = f"smart-heritage-report-{now:%Y%m%d}.xlsx"
    return Response(
        content=build_workbook(sheets),
        media_type=XLSX_MEDIA_TYPE,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
        },
    )

from typing import Any

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import ColumnElement, true
from sqlmodel import col, func, select

from app import crud
from app.api.deps import SessionDep, VisitorUser, get_active_language_or_error
from app.api.docs import errors
from app.core.transactions import acquire_transaction_lock
from app.models import (
    Artifact,
    Beacon,
    Site,
    VisitDetailPublic,
    VisitLog,
    VisitLogCreate,
    VisitLogPublic,
    VisitsDetailPublic,
)

router = APIRouter(prefix="/visits", tags=["visits"])


@router.post(
    "/",
    response_model=VisitLogPublic,
    status_code=status.HTTP_201_CREATED,
    responses={
        **errors(401, 403, 404, 400, 409),
        200: {
            "description": (
                f"Đã có lượt xem hiện vật này trong {crud.VISIT_DEDUP_SECONDS} giây "
                "gần nhất (không tạo bản ghi mới)"
            )
        },
    },
)
def record_visit(
    *,
    session: SessionDep,
    current_user: VisitorUser,
    visit_in: VisitLogCreate,
    response: Response,
) -> Any:
    """
    Ghi **một lượt xem** hiện vật cho người dùng đang đăng nhập.
    **Visitor / Admin** (cần đăng nhập).

    Quy tắc thống nhất với app (BR-05):
    - App chỉ gọi khi **hiện nội dung** hiện vật (vào vùng beacon mới),
      **không** gọi mỗi lần nhận tín hiệu BLE.
    - Server chặn thêm một lớp: cùng người dùng + cùng hiện vật trong
      **300 giây** chỉ tính 1 lượt: trả **200** với bản ghi cũ (không tạo mới);
      lượt mới trả **201**.
    - `beacon_id` (nếu gửi) phải là beacon đang gắn đúng hiện vật này.
    - `language_id` bỏ trống thì lấy ngôn ngữ ưa thích của người dùng / mặc định.
    """
    acquire_transaction_lock(session, f"visit:{current_user.id}:{visit_in.artifact_id}")
    artifact = crud.get_visible_artifact(
        session=session, artifact_id=visit_in.artifact_id
    )
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    if visit_in.beacon_id is not None:
        beacon = session.get(Beacon, visit_in.beacon_id)
        if not beacon or not beacon.is_active:
            raise HTTPException(status_code=404, detail="Beacon not found")
        if beacon.artifact_id != artifact.id or beacon.site_id != artifact.site_id:
            raise HTTPException(
                status_code=400, detail="Beacon không gắn với hiện vật này"
            )

    language_id = visit_in.language_id
    if language_id is not None:
        get_active_language_or_error(session, language_id)
        language = crud.resolve_language(
            session=session, lang_code=None, user=current_user
        )
        language_id = language.id if language else None

    recent = crud.find_recent_visit(
        session=session, user_id=current_user.id, artifact_id=artifact.id
    )
    if recent:
        response.status_code = status.HTTP_200_OK
        return recent

    visit = VisitLog.model_validate(
        visit_in,
        update={
            "user_id": current_user.id,
            "artifact_id": artifact.id,
            "language_id": language_id,
        },
    )
    session.add(visit)
    session.commit()
    session.refresh(visit)
    return visit


@router.get("/me", response_model=VisitsDetailPublic, responses=errors(401, 403))
def read_my_visits(
    session: SessionDep,
    current_user: VisitorUser,
    lang: str | None = Query(default=None, description="Mã ngôn ngữ: vi, en..."),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    """
    Lịch sử tham quan **của tôi** (mới nhất trước, có phân trang).
    **Visitor / Admin** (cần đăng nhập). Chỉ trả dữ liệu của chính người gọi.

    Hiện vật đang bị ẩn (hoặc thuộc Site bị ẩn) không hiện trong lịch sử.
    """
    conditions: list[ColumnElement[bool]] = [
        col(VisitLog.user_id) == current_user.id,
        col(Artifact.is_active) == true(),
        col(Site.is_active) == true(),
    ]
    count = session.exec(
        select(func.count())
        .select_from(VisitLog)
        .join(Artifact, col(Artifact.id) == col(VisitLog.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
    ).one()
    visits = session.exec(
        select(VisitLog, Artifact)
        .select_from(VisitLog)
        .join(Artifact, col(Artifact.id) == col(VisitLog.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(VisitLog.visited_at).desc(), col(VisitLog.id))
        .offset(skip)
        .limit(limit)
    ).all()

    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    summaries = crud.build_artifact_summaries(
        session=session,
        artifacts=[artifact for _, artifact in visits],
        language=language,
    )
    items = []
    for visit, artifact in visits:
        summary = summaries[artifact.id]
        items.append(
            VisitDetailPublic.model_validate(visit, update={"artifact": summary})
        )
    return VisitsDetailPublic(data=items, count=count)

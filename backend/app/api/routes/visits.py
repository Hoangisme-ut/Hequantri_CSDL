from typing import Any

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import ColumnElement, true
from sqlmodel import col, func, select

from app import crud
from app.api.deps import SessionDep, VisitorUser
from app.models import (
    Artifact,
    Beacon,
    Language,
    Site,
    VisitDetailPublic,
    VisitLog,
    VisitLogCreate,
    VisitLogPublic,
    VisitsDetailPublic,
)

router = APIRouter(prefix="/visits", tags=["visits"])

_ERRORS: dict[int | str, dict[str, Any]] = {
    401: {"description": "Thiếu hoặc sai token đăng nhập"},
    403: {"description": "Không đủ quyền"},
}


@router.post(
    "/",
    response_model=VisitLogPublic,
    status_code=status.HTTP_201_CREATED,
    responses={
        **_ERRORS,
        200: {
            "description": (
                f"Đã có lượt xem hiện vật này trong {crud.VISIT_DEDUP_SECONDS} giây "
                "gần nhất (không tạo bản ghi mới)"
            )
        },
        400: {"description": "Beacon không gắn với hiện vật được gửi lên"},
        404: {"description": "Hiện vật / beacon / ngôn ngữ không tồn tại hoặc bị ẩn"},
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
    artifact = crud.get_visible_artifact(
        session=session, artifact_id=visit_in.artifact_id
    )
    if not artifact:
        raise HTTPException(status_code=404, detail="Artifact not found")

    if visit_in.beacon_id is not None:
        beacon = session.get(Beacon, visit_in.beacon_id)
        if not beacon:
            raise HTTPException(status_code=404, detail="Beacon not found")
        if beacon.artifact_id != artifact.id:
            raise HTTPException(
                status_code=400, detail="Beacon không gắn với hiện vật này"
            )

    language_id = visit_in.language_id
    if language_id is not None:
        if not session.get(Language, language_id):
            raise HTTPException(status_code=404, detail="Language not found")
    else:
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


@router.get("/me", response_model=VisitsDetailPublic, responses=_ERRORS)
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
        select(VisitLog)
        .join(Artifact, col(Artifact.id) == col(VisitLog.artifact_id))
        .join(Site, col(Site.id) == col(Artifact.site_id))
        .where(*conditions)
        .order_by(col(VisitLog.visited_at).desc(), col(VisitLog.id))
        .offset(skip)
        .limit(limit)
    ).all()

    language = crud.resolve_language(session=session, lang_code=lang, user=current_user)
    items = []
    for visit in visits:
        artifact = session.get(Artifact, visit.artifact_id)
        if artifact is None:  # không xảy ra: đã join ở trên
            continue
        summary = crud.build_artifact_summary(
            session=session, artifact=artifact, language=language
        )
        items.append(
            VisitDetailPublic.model_validate(visit, update={"artifact": summary})
        )
    return VisitsDetailPublic(data=items, count=count)

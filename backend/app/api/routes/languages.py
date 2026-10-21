import uuid
from typing import Any

from fastapi import APIRouter, HTTPException
from sqlmodel import col, func, select

from app.api.deps import AdminUser, SessionDep
from app.models import (
    Language,
    LanguageCreate,
    LanguagePublic,
    LanguagesPublic,
    LanguageUpdate,
    Message,
)

router = APIRouter(prefix="/languages", tags=["languages"])


def _unset_other_defaults(session: SessionDep, keep_id: uuid.UUID | None) -> None:
    """Chỉ 1 ngôn ngữ is_default: bỏ cờ của các ngôn ngữ khác trước khi đặt cờ mới."""
    for lang in session.exec(select(Language).where(col(Language.is_default))).all():
        if lang.id != keep_id:
            lang.is_default = False
            session.add(lang)
    session.flush()


@router.get("/", response_model=LanguagesPublic)
def read_languages(session: SessionDep) -> Any:
    """
    Danh sách ngôn ngữ đang bật. **Public** (app dùng để cho khách chọn ngôn ngữ).
    """
    statement = select(Language).where(col(Language.is_active)).order_by(Language.code)
    languages = session.exec(statement).all()
    count = session.exec(
        select(func.count()).select_from(Language).where(col(Language.is_active))
    ).one()
    return LanguagesPublic(
        data=[LanguagePublic.model_validate(x) for x in languages], count=count
    )


@router.post("/", response_model=LanguagePublic)
def create_language(
    *, session: SessionDep, admin: AdminUser, language_in: LanguageCreate
) -> Any:
    """
    Thêm ngôn ngữ. **Admin**.
    """
    if session.exec(select(Language).where(Language.code == language_in.code)).first():
        raise HTTPException(status_code=409, detail="Language code already exists")
    if language_in.is_default:
        _unset_other_defaults(session, keep_id=None)
    language = Language.model_validate(language_in)
    session.add(language)
    session.commit()
    session.refresh(language)
    return language


@router.put("/{language_id}", response_model=LanguagePublic)
def update_language(
    *,
    session: SessionDep,
    admin: AdminUser,
    language_id: uuid.UUID,
    language_in: LanguageUpdate,
) -> Any:
    """
    Sửa / bật-tắt / đặt ngôn ngữ mặc định. **Admin**.
    """
    language = session.get(Language, language_id)
    if not language:
        raise HTTPException(status_code=404, detail="Language not found")
    data = language_in.model_dump(exclude_unset=True)
    if "code" in data and data["code"] != language.code:
        if session.exec(select(Language).where(Language.code == data["code"])).first():
            raise HTTPException(status_code=409, detail="Language code already exists")
    if data.get("is_default"):
        _unset_other_defaults(session, keep_id=language.id)
    if data.get("is_default") is False and language.is_default:
        raise HTTPException(
            status_code=400,
            detail="Hãy đặt ngôn ngữ khác làm mặc định thay vì tắt ngôn ngữ mặc định",
        )
    language.sqlmodel_update(data)
    session.add(language)
    session.commit()
    session.refresh(language)
    return language


@router.delete("/{language_id}")
def delete_language(
    session: SessionDep, admin: AdminUser, language_id: uuid.UUID
) -> Message:
    """
    Tắt ngôn ngữ (xóa mềm: is_active = false). **Admin**.
    """
    language = session.get(Language, language_id)
    if not language:
        raise HTTPException(status_code=404, detail="Language not found")
    if language.is_default:
        raise HTTPException(status_code=400, detail="Không thể tắt ngôn ngữ mặc định")
    language.is_active = False
    session.add(language)
    session.commit()
    return Message(message="Language deactivated successfully")

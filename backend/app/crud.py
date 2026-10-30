import uuid
from typing import Any

from sqlmodel import Session, col, select

from app.core.security import get_password_hash, verify_password
from app.models import (
    Artifact,
    ArtifactContentPublic,
    ArtifactTranslation,
    Item,
    ItemCreate,
    Language,
    Media,
    MediaPublic,
    Role,
    Site,
    User,
    UserCreate,
    UserUpdate,
    get_datetime_utc,
)

ROLE_ADMIN = "admin"
ROLE_VISITOR = "visitor"


def get_role_by_name(*, session: Session, name: str) -> Role | None:
    return session.exec(select(Role).where(Role.name == name)).first()


def create_user(*, session: Session, user_create: UserCreate) -> User:
    # [Smart Heritage] user mới tự có role: superuser -> admin, còn lại -> visitor
    role = get_role_by_name(
        session=session,
        name=ROLE_ADMIN if user_create.is_superuser else ROLE_VISITOR,
    )
    db_obj = User.model_validate(
        user_create,
        update={
            "hashed_password": get_password_hash(user_create.password),
            "role_id": role.id if role else None,
        },
    )
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj


def update_user(*, session: Session, db_user: User, user_in: UserUpdate) -> Any:
    user_data = user_in.model_dump(exclude_unset=True)
    extra_data: dict[str, Any] = {}
    if "password" in user_data:
        password = user_data["password"]
        hashed_password = get_password_hash(password)
        extra_data["hashed_password"] = hashed_password
   
    if "is_superuser" in user_data and "role_id" not in user_data:
        role = get_role_by_name(
            session=session,
            name=ROLE_ADMIN if user_data["is_superuser"] else ROLE_VISITOR,
        )
        if role:
            extra_data["role_id"] = role.id
    db_user.sqlmodel_update(user_data, update=extra_data)
    session.add(db_user)
    session.commit()
    session.refresh(db_user)
    return db_user


def get_user_by_email(*, session: Session, email: str) -> User | None:
    statement = select(User).where(User.email == email)
    session_user = session.exec(statement).first()
    return session_user


DUMMY_HASH = "$argon2id$v=19$m=65536,t=3,p=4$MjQyZWE1MzBjYjJlZTI0Yw$YTU4NGM5ZTZmYjE2NzZlZjY0ZWY3ZGRkY2U2OWFjNjk"


def authenticate(*, session: Session, email: str, password: str) -> User | None:
    db_user = get_user_by_email(session=session, email=email)
    if not db_user:
        # Prevent timing attacks by running password verification even when user doesn't exist
        # This ensures the response time is similar whether or not the email exists
        verify_password(password, DUMMY_HASH)
        return None
    verified, updated_password_hash = verify_password(password, db_user.hashed_password)
    if not verified:
        return None
    if updated_password_hash:
        db_user.hashed_password = updated_password_hash
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
    return db_user


def create_item(*, session: Session, item_in: ItemCreate, owner_id: uuid.UUID) -> Item:
    db_item = Item.model_validate(item_in, update={"owner_id": owner_id})
    session.add(db_item)
    session.commit()
    session.refresh(db_item)
    return db_item


# =============================================================================
# [Smart Heritage] Language & nội dung hiện vật theo ngôn ngữ
# =============================================================================
def get_language_by_code(*, session: Session, code: str) -> Language | None:
    return session.exec(
        select(Language).where(Language.code == code, col(Language.is_active))
    ).first()


def get_default_language(*, session: Session) -> Language | None:
    """Ngôn ngữ mặc định (is_default); nếu chưa đặt thì lấy ngôn ngữ active đầu tiên."""
    lang = session.exec(
        select(Language).where(col(Language.is_default), col(Language.is_active))
    ).first()
    if lang:
        return lang
    return session.exec(
        select(Language).where(col(Language.is_active)).order_by(col(Language.code))
    ).first()


def resolve_language(
    *, session: Session, lang_code: str | None, user: User | None = None
) -> Language | None:
    """Chọn ngôn ngữ: ?lang= -> ngôn ngữ ưa thích của user -> ngôn ngữ mặc định."""
    if lang_code:
        lang = get_language_by_code(session=session, code=lang_code)
        if lang:
            return lang
    if user is not None and user.language is not None and user.language.is_active:
        return user.language
    return get_default_language(session=session)


def pick_translation(
    *, session: Session, artifact_id: uuid.UUID, language: Language | None
) -> tuple[ArtifactTranslation | None, Language | None]:
    """Bản dịch theo ngôn ngữ yêu cầu; không có thì dự phòng: mặc định -> bất kỳ."""
    translations = session.exec(
        select(ArtifactTranslation).where(
            ArtifactTranslation.artifact_id == artifact_id
        )
    ).all()
    if not translations:
        return None, None
    by_lang = {t.language_id: t for t in translations}
    candidates: list[Language | None] = [
        language,
        get_default_language(session=session),
    ]
    for cand in candidates:
        if cand is not None and cand.id in by_lang:
            return by_lang[cand.id], session.get(Language, cand.id)
    first = translations[0]
    return first, session.get(Language, first.language_id)


def get_artifact_content(
    *, session: Session, artifact: Artifact, language: Language | None
) -> ArtifactContentPublic:
    """Ghép hiện vật + nội dung đúng ngôn ngữ + media (ảnh dùng chung hoặc đúng ngôn ngữ)."""
    translation, used_lang = pick_translation(
        session=session, artifact_id=artifact.id, language=language
    )
    lang_ids = {x.id for x in (language, used_lang) if x is not None}
    media_stmt = select(Media).where(Media.artifact_id == artifact.id)
    media_list = [
        m
        for m in session.exec(media_stmt.order_by(col(Media.sort_order))).all()
        if m.language_id is None or m.language_id in lang_ids
    ]
    return ArtifactContentPublic.model_validate(
        artifact,
        update={
            "title": translation.title if translation else None,
            "description": translation.description if translation else None,
            "history_content": translation.history_content if translation else None,
            "language_code": used_lang.code if used_lang else None,
            "is_fallback": bool(
                translation
                and language is not None
                and translation.language_id != language.id
            ),
            "media": [MediaPublic.model_validate(m) for m in media_list],
        },
    )


def touch_updated_at(obj: Artifact | ArtifactTranslation) -> None:
    obj.updated_at = get_datetime_utc()


def is_site_active(*, session: Session, site_id: uuid.UUID) -> bool:
    site = session.get(Site, site_id)
    return site is not None and site.is_active


def get_visible_artifact(
    *, session: Session, artifact_id: uuid.UUID
) -> Artifact | None:
    """Hiện vật được phép trả cho khách: đang bật VÀ thuộc Site đang bật."""
    artifact = session.get(Artifact, artifact_id)
    if artifact is None or not artifact.is_active:
        return None
    if not is_site_active(session=session, site_id=artifact.site_id):
        return None
    return artifact

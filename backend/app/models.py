import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import Optional

from pydantic import EmailStr, HttpUrl, field_validator
from sqlalchemy import CheckConstraint, Index, Unicode, UniqueConstraint, text
from sqlmodel import Field, Relationship, SQLModel


def get_datetime_utc() -> datetime:
    return datetime.now(UTC)


# Shared properties
class UserBase(SQLModel):
    email: EmailStr = Field(unique=True, index=True, max_length=255)
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255, sa_type=Unicode(255))


# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str = Field(min_length=8, max_length=128)


class UserRegister(SQLModel):
    email: EmailStr = Field(max_length=255)
    password: str = Field(min_length=8, max_length=128)
    full_name: str | None = Field(default=None, max_length=255)


# Properties to receive via API on update, all are optional
class UserUpdate(SQLModel):
    email: EmailStr | None = Field(default=None, max_length=255)
    is_active: bool | None = None
    is_superuser: bool | None = None
    full_name: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, min_length=8, max_length=128)
    role_id: uuid.UUID | None = None  # [Smart Heritage] admin gán role


class UserUpdateMe(SQLModel):
    full_name: str | None = Field(default=None, max_length=255)
    email: EmailStr | None = Field(default=None, max_length=255)
    language_id: uuid.UUID | None = None  # [Smart Heritage] ngôn ngữ ưa thích


class UpdatePassword(SQLModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


# Database model, database table inferred from class name
class User(UserBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    hashed_password: str
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    # [Smart Heritage] FK mới (nullable để các user cũ trong DB không bị lỗi)
    role_id: uuid.UUID | None = Field(
        default=None, foreign_key="role.id", ondelete="SET NULL"
    )
    language_id: uuid.UUID | None = Field(
        default=None, foreign_key="language.id", ondelete="SET NULL"
    )
    # SQLModel needs Optional forward references for relationships on Python 3.14.
    role: Optional["Role"] = Relationship(back_populates="users")  # noqa: UP037, UP045
    language: Optional["Language"] = Relationship(back_populates="users")  # noqa: UP037, UP045
    items: list[Item] = Relationship(back_populates="owner", cascade_delete=True)
    visit_logs: list[VisitLog] = Relationship(
        back_populates="user", cascade_delete=True
    )
    favorites: list[Favorite] = Relationship(back_populates="user", cascade_delete=True)
    feedbacks: list[Feedback] = Relationship(back_populates="user", cascade_delete=True)


# Properties to return via API, id is always required
class UserPublic(UserBase):
    id: uuid.UUID
    created_at: datetime | None = None
    role_id: uuid.UUID | None = None
    language_id: uuid.UUID | None = None


class UsersPublic(SQLModel):
    data: list[UserPublic]
    count: int


# Shared properties
class ItemBase(SQLModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)


# Properties to receive on item creation
class ItemCreate(ItemBase):
    pass


# Properties to receive on item update
class ItemUpdate(SQLModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=255)


# Database model, database table inferred from class name
class Item(ItemBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    owner_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    owner: User | None = Relationship(back_populates="items")


# Properties to return via API, id is always required
class ItemPublic(ItemBase):
    id: uuid.UUID
    owner_id: uuid.UUID
    created_at: datetime | None = None


class ItemsPublic(SQLModel):
    data: list[ItemPublic]
    count: int


# =============================================================================
# SMART HERITAGE – các bảng mới (khớp với ERD)
# Quy ước giống template: XxxBase -> XxxCreate / XxxUpdate -> Xxx (table) -> XxxPublic
# =============================================================================


class MediaType(StrEnum):
    IMAGE = "image"
    VIDEO = "video"
    AUDIO = "audio"


class FeedbackStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


# ---------------------------------- Role -------------------------------------
class RoleBase(SQLModel):
    name: str = Field(unique=True, index=True, max_length=50)  # admin | visitor
    description: str | None = Field(default=None, max_length=255, sa_type=Unicode(255))


class RoleCreate(RoleBase):
    pass


class Role(RoleBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    users: list[User] = Relationship(back_populates="role")


class RolePublic(RoleBase):
    id: uuid.UUID


# -------------------------------- Language -----------------------------------
class LanguageBase(SQLModel):
    code: str = Field(unique=True, index=True, max_length=10)  # vi, en, ja ...
    name: str = Field(max_length=100, sa_type=Unicode(100))
    is_active: bool = True
    is_default: bool = False  # ngôn ngữ dự phòng khi hiện vật chưa có bản dịch


class LanguageCreate(LanguageBase):
    pass


class LanguageUpdate(SQLModel):
    code: str | None = Field(default=None, max_length=10)
    name: str | None = Field(default=None, max_length=100)
    is_active: bool | None = None
    is_default: bool | None = None


class Language(LanguageBase, table=True):
    # chỉ 1 ngôn ngữ được is_default = 1 (filtered unique index)
    __table_args__ = (
        Index(
            "uq_language_default",
            "is_default",
            unique=True,
            mssql_where=text("is_default = 1"),
            sqlite_where=text("is_default = 1"),
        ),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    users: list["User"] = Relationship(back_populates="language")
    translations: list["ArtifactTranslation"] = Relationship(
        back_populates="language", cascade_delete=True
    )
    media: list["Media"] = Relationship(back_populates="language")
    visit_logs: list["VisitLog"] = Relationship(back_populates="language")


class LanguagePublic(LanguageBase):
    id: uuid.UUID


class LanguagesPublic(SQLModel):
    data: list[LanguagePublic]
    count: int


# ----------------------------------- Site ------------------------------------
class SiteBase(SQLModel):
    name: str = Field(min_length=1, max_length=255, sa_type=Unicode(255))
    description: str | None = Field(
        default=None, max_length=2000, sa_type=Unicode(2000)
    )
    address: str | None = Field(default=None, max_length=500, sa_type=Unicode(500))
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Site name must not be blank")
        return value


class SiteCreate(SiteBase):
    pass


class SiteUpdate(SQLModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    address: str | None = Field(default=None, max_length=500)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not value:
            raise ValueError("Site name must not be blank")
        return value


class Site(SiteBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    updated_at: datetime | None = None
    artifacts: list[Artifact] = Relationship(back_populates="site", cascade_delete=True)
    beacons: list[Beacon] = Relationship(back_populates="site", cascade_delete=True)


class SitePublic(SiteBase):
    id: uuid.UUID
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SitesPublic(SQLModel):
    data: list[SitePublic]
    count: int


# --------------------------------- Artifact ----------------------------------
class ArtifactBase(SQLModel):
    code: str = Field(index=True, max_length=50)  # mã hiện vật (unique theo site)
    era: str | None = Field(
        default=None, max_length=100, sa_type=Unicode(100)
    )  # niên đại
    latitude: float | None = None
    longitude: float | None = None
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool = True


class ArtifactCreate(ArtifactBase):
    site_id: uuid.UUID


class ArtifactUpdate(SQLModel):
    site_id: uuid.UUID | None = None
    code: str | None = Field(default=None, max_length=50)
    era: str | None = Field(default=None, max_length=100)
    latitude: float | None = None
    longitude: float | None = None
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool | None = None


class Artifact(ArtifactBase, table=True):
    __table_args__ = (
        UniqueConstraint("site_id", "code", name="uq_artifact_site_code"),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    site_id: uuid.UUID = Field(
        foreign_key="site.id", nullable=False, ondelete="CASCADE"
    )
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    updated_at: datetime | None = None
    site: Site | None = Relationship(back_populates="artifacts")
    translations: list["ArtifactTranslation"] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    media: list[Media] = Relationship(back_populates="artifact", cascade_delete=True)
    beacon: Optional["Beacon"] = Relationship(back_populates="artifact")  # noqa: UP037, UP045
    visit_logs: list[VisitLog] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    favorites: list["Favorite"] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    feedbacks: list["Feedback"] = Relationship(
        back_populates="artifact", cascade_delete=True
    )


class ArtifactPublic(ArtifactBase):
    id: uuid.UUID
    site_id: uuid.UUID
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ArtifactsPublic(SQLModel):
    data: list[ArtifactPublic]
    count: int


# ----------------------------- ArtifactTranslation ---------------------------
class ArtifactTranslationBase(SQLModel):
    title: str = Field(min_length=1, max_length=255, sa_type=Unicode(255))
    description: str | None = Field(
        default=None, max_length=2000, sa_type=Unicode(2000)
    )
    history_content: str | None = Field(default=None, sa_type=Unicode())  # nội dung dài


class ArtifactTranslationCreate(ArtifactTranslationBase):
    language_id: uuid.UUID


class ArtifactTranslationUpdate(SQLModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    history_content: str | None = None


class ArtifactTranslation(ArtifactTranslationBase, table=True):
    # 1 hiện vật chỉ có 1 bản dịch cho mỗi ngôn ngữ
    __table_args__ = (
        UniqueConstraint("artifact_id", "language_id", name="uq_artifact_language"),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    language_id: uuid.UUID = Field(
        foreign_key="language.id", nullable=False, ondelete="CASCADE"
    )
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    updated_at: datetime | None = None
    artifact: Artifact | None = Relationship(back_populates="translations")
    language: Language | None = Relationship(back_populates="translations")


class ArtifactTranslationPublic(ArtifactTranslationBase):
    id: uuid.UUID
    artifact_id: uuid.UUID
    language_id: uuid.UUID


# ----------------------------------- Media -----------------------------------
class MediaBase(SQLModel):
    media_type: str = Field(default=MediaType.IMAGE, max_length=20)  # MediaType
    url: str = Field(max_length=500)
    caption: str | None = Field(default=None, max_length=255, sa_type=Unicode(255))
    sort_order: int = 0

    @field_validator("media_type")
    @classmethod
    def validate_media_type(cls, value: str) -> str:
        allowed_types = {media_type.value for media_type in MediaType}
        if value not in allowed_types:
            raise ValueError(
                f"media_type must be one of: {', '.join(sorted(allowed_types))}"
            )
        return value


class MediaCreate(MediaBase):
    # audio/video theo ngôn ngữ -> có language_id; ảnh dùng chung -> để None
    language_id: uuid.UUID | None = None

    @field_validator("url")
    @classmethod
    def validate_url(cls, value: str) -> str:
        HttpUrl(value)
        return value


class MediaUpdate(SQLModel):
    media_type: str | None = Field(default=None, max_length=20)
    url: str | None = Field(default=None, max_length=500)
    caption: str | None = Field(default=None, max_length=255)
    sort_order: int | None = None
    language_id: uuid.UUID | None = None

    @field_validator("url")
    @classmethod
    def validate_url(cls, value: str | None) -> str | None:
        if value is not None:
            HttpUrl(value)
        return value

    @field_validator("media_type")
    @classmethod
    def validate_media_type(cls, value: str | None) -> str | None:
        if value is None:
            return value
        allowed_types = {media_type.value for media_type in MediaType}
        if value not in allowed_types:
            raise ValueError(
                f"media_type must be one of: {', '.join(sorted(allowed_types))}"
            )
        return value


class Media(MediaBase, table=True):
    __table_args__ = (
        CheckConstraint(
            "media_type IN ('image', 'video', 'audio')",
            name="ck_media_type",
        ),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    language_id: uuid.UUID | None = Field(
        default=None, foreign_key="language.id", ondelete="SET NULL"
    )
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    updated_at: datetime | None = None
    artifact: Artifact | None = Relationship(back_populates="media")
    language: Language | None = Relationship(back_populates="media")


class MediaPublic(MediaBase):
    id: uuid.UUID
    artifact_id: uuid.UUID
    language_id: uuid.UUID | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


# ----------------------------------- Beacon ----------------------------------
class BeaconBase(SQLModel):
    proximity_uuid: str = Field(max_length=36, index=True)  # iBeacon proximity UUID
    major: int = Field(ge=0, le=65535)
    minor: int = Field(ge=0, le=65535)
    tx_power: int | None = -59  # công suất đo ở 1m (dBm)
    rssi_threshold: int | None = -80  # ngưỡng RSSI để kích hoạt (dBm)
    is_active: bool = True

    @field_validator("proximity_uuid")
    @classmethod
    def validate_proximity_uuid(cls, value: str) -> str:
        try:
            return str(uuid.UUID(value)).upper()
        except ValueError as exc:
            raise ValueError("proximity_uuid must be a valid UUID") from exc


class BeaconCreate(BeaconBase):
    site_id: uuid.UUID
    artifact_id: uuid.UUID | None = None


class BeaconUpdate(SQLModel):
    proximity_uuid: str | None = Field(default=None, max_length=36)
    major: int | None = Field(default=None, ge=0, le=65535)
    minor: int | None = Field(default=None, ge=0, le=65535)
    tx_power: int | None = None
    rssi_threshold: int | None = None
    is_active: bool | None = None
    site_id: uuid.UUID | None = None
    artifact_id: uuid.UUID | None = None
    battery_level: int | None = Field(default=None, ge=0, le=100)

    @field_validator("proximity_uuid")
    @classmethod
    def validate_proximity_uuid(cls, value: str | None) -> str | None:
        if value is None:
            return value
        try:
            return str(uuid.UUID(value)).upper()
        except ValueError as exc:
            raise ValueError("proximity_uuid must be a valid UUID") from exc


class Beacon(BeaconBase, table=True):
    # bộ ba (proximity_uuid, major, minor) định danh duy nhất 1 beacon vật lý
    __table_args__ = (
        CheckConstraint("major BETWEEN 0 AND 65535", name="ck_beacon_major"),
        CheckConstraint("minor BETWEEN 0 AND 65535", name="ck_beacon_minor"),
        UniqueConstraint("proximity_uuid", "major", "minor", name="uq_beacon_identity"),
        # unique chỉ áp dụng cho beacon đã gán hiện vật (cho phép nhiều NULL)
        Index(
            "uq_beacon_artifact_id",
            "artifact_id",
            unique=True,
            mssql_where=text("artifact_id IS NOT NULL"),
            postgresql_where=text("artifact_id IS NOT NULL"),
        ),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    site_id: uuid.UUID = Field(
        foreign_key="site.id", nullable=False, ondelete="CASCADE"
    )
    # mỗi hiện vật gắn tối đa 1 beacon (index unique ở __table_args__).
    # NO ACTION: SQL Server cấm nhiều đường cascade; khi xóa Artifact lẻ,
    # code CRUD phải gỡ beacon (artifact_id = None) trước.
    artifact_id: uuid.UUID | None = Field(default=None, foreign_key="artifact.id")
    battery_level: int | None = None
    last_seen_at: datetime | None = None
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    updated_at: datetime | None = None
    site: Site | None = Relationship(back_populates="beacons")
    artifact: Artifact | None = Relationship(back_populates="beacon")
    visit_logs: list["VisitLog"] = Relationship(back_populates="beacon")


class BeaconPublic(BeaconBase):
    id: uuid.UUID
    site_id: uuid.UUID
    artifact_id: uuid.UUID | None = None
    battery_level: int | None = None
    last_seen_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class BeaconsPublic(SQLModel):
    data: list[BeaconPublic]
    count: int


# ---------------------------------- VisitLog ---------------------------------
class VisitLogCreate(SQLModel):
    artifact_id: uuid.UUID
    beacon_id: uuid.UUID | None = None
    language_id: uuid.UUID | None = None
    rssi: int | None = None
    duration_seconds: int | None = Field(default=None, ge=0)


class VisitLog(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE", index=True
    )
    # NO ACTION (không cascade/set null) để tránh "multiple cascade paths" ở SQL Server
    beacon_id: uuid.UUID | None = Field(default=None, foreign_key="beacon.id")
    language_id: uuid.UUID | None = Field(default=None, foreign_key="language.id")
    visited_at: datetime | None = Field(default_factory=get_datetime_utc, index=True)
    duration_seconds: int | None = None
    rssi: int | None = None
    user: User | None = Relationship(back_populates="visit_logs")
    artifact: Artifact | None = Relationship(back_populates="visit_logs")
    beacon: Beacon | None = Relationship(back_populates="visit_logs")
    language: Language | None = Relationship(back_populates="visit_logs")


class VisitLogPublic(SQLModel):
    id: uuid.UUID
    user_id: uuid.UUID
    artifact_id: uuid.UUID
    beacon_id: uuid.UUID | None = None
    language_id: uuid.UUID | None = None
    visited_at: datetime | None = None
    duration_seconds: int | None = None
    rssi: int | None = None


class VisitLogsPublic(SQLModel):
    data: list[VisitLogPublic]
    count: int


# ---------------------------------- Favorite ---------------------------------
class FavoriteCreate(SQLModel):
    artifact_id: uuid.UUID


class Favorite(SQLModel, table=True):
    # 1 người dùng chỉ yêu thích 1 hiện vật 1 lần
    __table_args__ = (
        UniqueConstraint("user_id", "artifact_id", name="uq_favorite_user_artifact"),
    )
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    user: User | None = Relationship(back_populates="favorites")
    artifact: Artifact | None = Relationship(back_populates="favorites")


class FavoritePublic(SQLModel):
    id: uuid.UUID
    user_id: uuid.UUID
    artifact_id: uuid.UUID
    created_at: datetime | None = None


class FavoritesPublic(SQLModel):
    data: list[FavoritePublic]
    count: int


# ---------------------------------- Feedback ---------------------------------
class FeedbackCreate(SQLModel):
    artifact_id: uuid.UUID
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class FeedbackStatusUpdate(SQLModel):
    status: str = Field(max_length=20)  # FeedbackStatus


class Feedback(SQLModel, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        foreign_key="user.id", nullable=False, ondelete="CASCADE"
    )
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000, sa_type=Unicode(2000))
    status: str = Field(default=FeedbackStatus.PENDING, max_length=20)
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    user: User | None = Relationship(back_populates="feedbacks")
    artifact: Artifact | None = Relationship(back_populates="feedbacks")


class FeedbackPublic(SQLModel):
    id: uuid.UUID
    user_id: uuid.UUID
    artifact_id: uuid.UUID
    rating: int
    comment: str | None = None
    status: str
    created_at: datetime | None = None


class FeedbacksPublic(SQLModel):
    data: list[FeedbackPublic]
    count: int


# ------------------- Schemas dùng cho API nội dung hiện vật -------------------
class ArtifactSummary(SQLModel):
    """Dòng trong danh sách hiện vật: kèm tiêu đề theo ngôn ngữ."""

    id: uuid.UUID
    site_id: uuid.UUID
    code: str
    era: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    cover_image_url: str | None = None
    is_active: bool = True
    title: str | None = None
    language_code: str | None = None  # ngôn ngữ của title
    is_fallback: bool = False  # True nếu title không đúng ngôn ngữ yêu cầu


class ArtifactSummariesPublic(SQLModel):
    data: list[ArtifactSummary]
    count: int


class ArtifactContentPublic(ArtifactPublic):
    """Chi tiết hiện vật + nội dung theo ngôn ngữ + media."""

    title: str | None = None
    description: str | None = None
    history_content: str | None = None
    language_code: str | None = None  # ngôn ngữ của nội dung trả về
    is_fallback: bool = False
    media: list[MediaPublic] = []


class BeaconResolvePublic(SQLModel):
    """Kết quả khi app quét được beacon."""

    beacon: BeaconPublic
    artifact: ArtifactContentPublic


# Generic message
class Message(SQLModel):
    message: str


# JSON payload containing access token
class Token(SQLModel):
    access_token: str
    token_type: str = "bearer"


# Contents of JWT token
class TokenPayload(SQLModel):
    sub: str | None = None


class NewPassword(SQLModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)

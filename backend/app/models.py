import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import Optional

from pydantic import EmailStr
from sqlalchemy import Index, UniqueConstraint, text
from sqlmodel import Field, Relationship, SQLModel


def get_datetime_utc() -> datetime:
    return datetime.now(UTC)


# Shared properties
class UserBase(SQLModel):
    email: EmailStr = Field(unique=True, index=True, max_length=255)
    is_active: bool = True
    is_superuser: bool = False
    full_name: str | None = Field(default=None, max_length=255)


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
    role: Optional["Role"] = Relationship(back_populates="users")
    language: Optional["Language"] = Relationship(back_populates="users")
    items: list[Item] = Relationship(back_populates="owner", cascade_delete=True)
    visit_logs: list[VisitLog] = Relationship(
        back_populates="user", cascade_delete=True
    )
    favorites: list[Favorite] = Relationship(
        back_populates="user", cascade_delete=True
    )
    feedbacks: list[Feedback] = Relationship(
        back_populates="user", cascade_delete=True
    )


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
    description: str | None = Field(default=None, max_length=255)


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
    name: str = Field(max_length=100)
    is_active: bool = True


class LanguageCreate(LanguageBase):
    pass


class LanguageUpdate(SQLModel):
    code: str | None = Field(default=None, max_length=10)
    name: str | None = Field(default=None, max_length=100)
    is_active: bool | None = None


class Language(LanguageBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    users: list[User] = Relationship(back_populates="language")
    translations: list[ArtifactTranslation] = Relationship(
        back_populates="language", cascade_delete=True
    )
    media: list[Media] = Relationship(back_populates="language")
    visit_logs: list[VisitLog] = Relationship(back_populates="language")


class LanguagePublic(LanguageBase):
    id: uuid.UUID


class LanguagesPublic(SQLModel):
    data: list[LanguagePublic]
    count: int


# ----------------------------------- Site ------------------------------------
class SiteBase(SQLModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    address: str | None = Field(default=None, max_length=500)
    latitude: float | None = None
    longitude: float | None = None
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool = True


class SiteCreate(SiteBase):
    pass


class SiteUpdate(SQLModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    address: str | None = Field(default=None, max_length=500)
    latitude: float | None = None
    longitude: float | None = None
    cover_image_url: str | None = Field(default=None, max_length=500)
    is_active: bool | None = None


class Site(SiteBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    artifacts: list[Artifact] = Relationship(
        back_populates="site", cascade_delete=True
    )
    beacons: list[Beacon] = Relationship(back_populates="site", cascade_delete=True)


class SitePublic(SiteBase):
    id: uuid.UUID
    created_at: datetime | None = None


class SitesPublic(SQLModel):
    data: list[SitePublic]
    count: int


# --------------------------------- Artifact ----------------------------------
class ArtifactBase(SQLModel):
    code: str = Field(unique=True, index=True, max_length=50)  # mã hiện vật
    era: str | None = Field(default=None, max_length=100)  # niên đại
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
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    site_id: uuid.UUID = Field(foreign_key="site.id", nullable=False, ondelete="CASCADE")
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    site: Site | None = Relationship(back_populates="artifacts")
    translations: list[ArtifactTranslation] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    media: list[Media] = Relationship(back_populates="artifact", cascade_delete=True)
    beacon: Optional["Beacon"] = Relationship(back_populates="artifact")
    visit_logs: list[VisitLog] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    favorites: list[Favorite] = Relationship(
        back_populates="artifact", cascade_delete=True
    )
    feedbacks: list[Feedback] = Relationship(
        back_populates="artifact", cascade_delete=True
    )


class ArtifactPublic(ArtifactBase):
    id: uuid.UUID
    site_id: uuid.UUID
    created_at: datetime | None = None


class ArtifactsPublic(SQLModel):
    data: list[ArtifactPublic]
    count: int


# ----------------------------- ArtifactTranslation ---------------------------
class ArtifactTranslationBase(SQLModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    history_content: str | None = Field(default=None)  # nội dung dài (text)


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
    caption: str | None = Field(default=None, max_length=255)
    sort_order: int = 0


class MediaCreate(MediaBase):
    # audio/video theo ngôn ngữ -> có language_id; ảnh dùng chung -> để None
    language_id: uuid.UUID | None = None


class MediaUpdate(SQLModel):
    media_type: str | None = Field(default=None, max_length=20)
    url: str | None = Field(default=None, max_length=500)
    caption: str | None = Field(default=None, max_length=255)
    sort_order: int | None = None
    language_id: uuid.UUID | None = None


class Media(MediaBase, table=True):
    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    language_id: uuid.UUID | None = Field(
        default=None, foreign_key="language.id", ondelete="SET NULL"
    )
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    artifact: Artifact | None = Relationship(back_populates="media")
    language: Language | None = Relationship(back_populates="media")


class MediaPublic(MediaBase):
    id: uuid.UUID
    artifact_id: uuid.UUID
    language_id: uuid.UUID | None = None


# ----------------------------------- Beacon ----------------------------------
class BeaconBase(SQLModel):
    proximity_uuid: str = Field(max_length=36, index=True)  # iBeacon proximity UUID
    major: int = Field(ge=0, le=65535)
    minor: int = Field(ge=0, le=65535)
    tx_power: int | None = None  # công suất đo ở 1m (dBm)
    rssi_threshold: int | None = None  # ngưỡng RSSI để kích hoạt (dBm)
    is_active: bool = True


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


class Beacon(BeaconBase, table=True):
    # bộ ba (proximity_uuid, major, minor) định danh duy nhất 1 beacon vật lý
    __table_args__ = (
        UniqueConstraint(
            "proximity_uuid", "major", "minor", name="uq_beacon_identity"
        ),
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
    site_id: uuid.UUID = Field(foreign_key="site.id", nullable=False, ondelete="CASCADE")
    # mỗi hiện vật gắn tối đa 1 beacon (index unique ở __table_args__).
    # NO ACTION: SQL Server cấm nhiều đường cascade; khi xóa Artifact lẻ,
    # code CRUD phải gỡ beacon (artifact_id = None) trước.
    artifact_id: uuid.UUID | None = Field(
        default=None, foreign_key="artifact.id", ondelete="NO ACTION"
    )
    battery_level: int | None = None
    last_seen_at: datetime | None = None
    created_at: datetime | None = Field(default_factory=get_datetime_utc)
    site: Site | None = Relationship(back_populates="beacons")
    artifact: Artifact | None = Relationship(back_populates="beacon")
    visit_logs: list[VisitLog] = Relationship(back_populates="beacon")


class BeaconPublic(BeaconBase):
    id: uuid.UUID
    site_id: uuid.UUID
    artifact_id: uuid.UUID | None = None
    battery_level: int | None = None
    last_seen_at: datetime | None = None


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
    user_id: uuid.UUID = Field(foreign_key="user.id", nullable=False, ondelete="CASCADE")
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE", index=True
    )
    # NO ACTION (không cascade/set null) để tránh "multiple cascade paths" ở SQL Server
    beacon_id: uuid.UUID | None = Field(
        default=None, foreign_key="beacon.id", ondelete="NO ACTION"
    )
    language_id: uuid.UUID | None = Field(
        default=None, foreign_key="language.id", ondelete="NO ACTION"
    )
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
    user_id: uuid.UUID = Field(foreign_key="user.id", nullable=False, ondelete="CASCADE")
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
    user_id: uuid.UUID = Field(foreign_key="user.id", nullable=False, ondelete="CASCADE")
    artifact_id: uuid.UUID = Field(
        foreign_key="artifact.id", nullable=False, ondelete="CASCADE"
    )
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)
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
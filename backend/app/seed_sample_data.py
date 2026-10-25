import logging
import uuid
from dataclasses import dataclass

from sqlmodel import Session, col, select

from app.core.db import engine
from app.models import Artifact, ArtifactTranslation, Beacon, Language, Site

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class SiteSeed:
    id: uuid.UUID
    name: str
    description: str
    address: str
    latitude: float
    longitude: float


@dataclass(frozen=True)
class ArtifactSeed:
    id: uuid.UUID
    site_id: uuid.UUID
    code: str
    era: str
    title_vi: str
    title_en: str
    description_vi: str
    description_en: str


@dataclass(frozen=True)
class BeaconSeed:
    id: uuid.UUID
    site_id: uuid.UUID
    artifact_id: uuid.UUID
    proximity_uuid: str
    major: int
    minor: int


SITE_HOANG_THANH_ID = uuid.UUID("10000000-0000-0000-0000-000000000001")
SITE_VAN_MIEU_ID = uuid.UUID("10000000-0000-0000-0000-000000000002")

ARTIFACT_DOAN_MON_ID = uuid.UUID("20000000-0000-0000-0000-000000000001")
ARTIFACT_KINH_THIEN_ID = uuid.UUID("20000000-0000-0000-0000-000000000002")
ARTIFACT_HAU_LAU_ID = uuid.UUID("20000000-0000-0000-0000-000000000003")
ARTIFACT_KHUE_VAN_CAC_ID = uuid.UUID("20000000-0000-0000-0000-000000000004")
ARTIFACT_BIA_TIEN_SI_ID = uuid.UUID("20000000-0000-0000-0000-000000000005")

SITES = (
    SiteSeed(
        id=SITE_HOANG_THANH_ID,
        name="Hoàng thành Thăng Long",
        description="Khu di tích trung tâm Hoàng thành Thăng Long tại Hà Nội.",
        address="19C Hoàng Diệu, Ba Đình, Hà Nội",
        latitude=21.0353,
        longitude=105.8402,
    ),
    SiteSeed(
        id=SITE_VAN_MIEU_ID,
        name="Văn Miếu – Quốc Tử Giám",
        description="Quần thể di tích về giáo dục và khoa bảng của Việt Nam.",
        address="58 Quốc Tử Giám, Đống Đa, Hà Nội",
        latitude=21.0280,
        longitude=105.8356,
    ),
)

ARTIFACTS = (
    ArtifactSeed(
        id=ARTIFACT_DOAN_MON_ID,
        site_id=SITE_HOANG_THANH_ID,
        code="HTTL-DOAN-MON",
        era="Thời Lê sơ",
        title_vi="Đoan Môn",
        title_en="Doan Mon Gate",
        description_vi="Cổng chính dẫn vào khu vực trung tâm Hoàng thành.",
        description_en="The main gate leading to the central imperial citadel.",
    ),
    ArtifactSeed(
        id=ARTIFACT_KINH_THIEN_ID,
        site_id=SITE_HOANG_THANH_ID,
        code="HTTL-KINH-THIEN",
        era="Thời Lê sơ",
        title_vi="Điện Kính Thiên",
        title_en="Kinh Thien Palace",
        description_vi="Trung tâm thiết triều của Hoàng thành Thăng Long xưa.",
        description_en="The former ceremonial center of the Imperial Citadel.",
    ),
    ArtifactSeed(
        id=ARTIFACT_HAU_LAU_ID,
        site_id=SITE_HOANG_THANH_ID,
        code="HTTL-HAU-LAU",
        era="Thế kỷ XIX",
        title_vi="Hậu Lâu",
        title_en="Hau Lau Pavilion",
        description_vi="Công trình từng là nơi nghỉ của các cung tần mỹ nữ.",
        description_en="A pavilion formerly used by members of the royal household.",
    ),
    ArtifactSeed(
        id=ARTIFACT_KHUE_VAN_CAC_ID,
        site_id=SITE_VAN_MIEU_ID,
        code="VMQT-KHUE-VAN-CAC",
        era="Thời Nguyễn",
        title_vi="Khuê Văn Các",
        title_en="Khue Van Pavilion",
        description_vi="Biểu tượng của Văn Miếu – Quốc Tử Giám và Thủ đô Hà Nội.",
        description_en="An iconic pavilion of the Temple of Literature and Hanoi.",
    ),
    ArtifactSeed(
        id=ARTIFACT_BIA_TIEN_SI_ID,
        site_id=SITE_VAN_MIEU_ID,
        code="VMQT-BIA-TIEN-SI",
        era="Thế kỷ XV–XVIII",
        title_vi="Bia Tiến sĩ",
        title_en="Doctoral Stelae",
        description_vi="Các bia đá ghi danh những người đỗ đại khoa thời phong kiến.",
        description_en="Stone stelae honoring successful royal examination candidates.",
    ),
)

BEACONS = (
    BeaconSeed(
        id=uuid.UUID("30000000-0000-0000-0000-000000000001"),
        site_id=SITE_HOANG_THANH_ID,
        artifact_id=ARTIFACT_DOAN_MON_ID,
        proximity_uuid="FDA50693-A4E2-4FB1-AFCF-C6EB07647825",
        major=1,
        minor=1,
    ),
    BeaconSeed(
        id=uuid.UUID("30000000-0000-0000-0000-000000000002"),
        site_id=SITE_HOANG_THANH_ID,
        artifact_id=ARTIFACT_KINH_THIEN_ID,
        proximity_uuid="FDA50693-A4E2-4FB1-AFCF-C6EB07647825",
        major=1,
        minor=2,
    ),
    BeaconSeed(
        id=uuid.UUID("30000000-0000-0000-0000-000000000003"),
        site_id=SITE_VAN_MIEU_ID,
        artifact_id=ARTIFACT_KHUE_VAN_CAC_ID,
        proximity_uuid="FDA50693-A4E2-4FB1-AFCF-C6EB07647825",
        major=2,
        minor=1,
    ),
)


def _seed_languages(session: Session) -> dict[str, Language]:
    languages: dict[str, Language] = {}
    for code, name in (("vi", "Tiếng Việt"), ("en", "English")):
        language = session.exec(select(Language).where(Language.code == code)).first()
        if language is None:
            language = Language(code=code, name=name)
        else:
            language.name = name
            language.is_active = True
        session.add(language)
        languages[code] = language
    session.flush()

    current_default = session.exec(
        select(Language).where(col(Language.is_default))
    ).first()
    if current_default and current_default.id != languages["vi"].id:
        current_default.is_default = False
        session.add(current_default)
        session.flush()
    languages["vi"].is_default = True
    languages["en"].is_default = False
    session.add(languages["vi"])
    session.add(languages["en"])
    session.flush()
    return languages


def _seed_sites(session: Session) -> None:
    for seed in SITES:
        site = session.get(Site, seed.id)
        values = {
            "name": seed.name,
            "description": seed.description,
            "address": seed.address,
            "latitude": seed.latitude,
            "longitude": seed.longitude,
            "is_active": True,
        }
        if site is None:
            site = Site(
                id=seed.id,
                name=seed.name,
                description=seed.description,
                address=seed.address,
                latitude=seed.latitude,
                longitude=seed.longitude,
                is_active=True,
            )
        else:
            site.sqlmodel_update(values)
        session.add(site)
    session.flush()


def _seed_artifacts_and_translations(
    session: Session, languages: dict[str, Language]
) -> None:
    for seed in ARTIFACTS:
        artifact = session.get(Artifact, seed.id)
        values = {
            "site_id": seed.site_id,
            "code": seed.code,
            "era": seed.era,
            "is_active": True,
        }
        if artifact is None:
            artifact = Artifact(
                id=seed.id,
                site_id=seed.site_id,
                code=seed.code,
                era=seed.era,
                is_active=True,
            )
        else:
            artifact.sqlmodel_update(values)
        session.add(artifact)
        session.flush()

        translations = {
            "vi": (seed.title_vi, seed.description_vi),
            "en": (seed.title_en, seed.description_en),
        }
        for code, (title, description) in translations.items():
            language = languages[code]
            translation = session.exec(
                select(ArtifactTranslation).where(
                    ArtifactTranslation.artifact_id == artifact.id,
                    ArtifactTranslation.language_id == language.id,
                )
            ).first()
            translation_values = {"title": title, "description": description}
            if translation is None:
                translation = ArtifactTranslation(
                    artifact_id=artifact.id,
                    language_id=language.id,
                    title=title,
                    description=description,
                )
            else:
                translation.sqlmodel_update(translation_values)
            session.add(translation)
    session.flush()


def _seed_beacons(session: Session) -> None:
    for seed in BEACONS:
        beacon = session.get(Beacon, seed.id)
        values = {
            "site_id": seed.site_id,
            "artifact_id": seed.artifact_id,
            "proximity_uuid": seed.proximity_uuid,
            "major": seed.major,
            "minor": seed.minor,
            "is_active": True,
        }
        if beacon is None:
            beacon = Beacon(
                id=seed.id,
                site_id=seed.site_id,
                artifact_id=seed.artifact_id,
                proximity_uuid=seed.proximity_uuid,
                major=seed.major,
                minor=seed.minor,
                is_active=True,
            )
        else:
            beacon.sqlmodel_update(values)
        session.add(beacon)
    session.flush()


def seed_sample_data(session: Session) -> None:
    """Create or refresh the deterministic sample data set."""
    languages = _seed_languages(session)
    _seed_sites(session)
    _seed_artifacts_and_translations(session, languages)
    _seed_beacons(session)
    session.commit()


def main() -> None:
    logger.info("Creating sample Smart Heritage data")
    with Session(engine) as session:
        seed_sample_data(session)
    logger.info("Sample data ready: 2 sites, 5 artifacts, 3 beacons, vi/en")


if __name__ == "__main__":
    main()

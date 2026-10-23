import uuid

import pytest
from pydantic import ValidationError

from app.models import BeaconCreate, BeaconUpdate, MediaCreate, MediaUpdate


def test_beacon_create_normalizes_uuid_and_uses_erd_defaults() -> None:
    beacon = BeaconCreate(
        proximity_uuid="fda50693-a4e2-4fb1-afcf-c6eb07647825",
        major=1,
        minor=2,
        site_id=uuid.uuid4(),
    )

    assert beacon.proximity_uuid == "FDA50693-A4E2-4FB1-AFCF-C6EB07647825"
    assert beacon.tx_power == -59
    assert beacon.rssi_threshold == -80


@pytest.mark.parametrize("field", ["major", "minor"])
def test_beacon_create_rejects_out_of_range_identifiers(field: str) -> None:
    data = {
        "proximity_uuid": str(uuid.uuid4()),
        "major": 1,
        "minor": 2,
        "site_id": uuid.uuid4(),
    }
    data[field] = 65536

    with pytest.raises(ValidationError):
        BeaconCreate.model_validate(data)


def test_beacon_create_rejects_invalid_uuid() -> None:
    with pytest.raises(ValidationError):
        BeaconCreate(
            proximity_uuid="not-a-uuid",
            major=1,
            minor=2,
            site_id=uuid.uuid4(),
        )

    with pytest.raises(ValidationError):
        BeaconUpdate(proximity_uuid="not-a-uuid")


def test_media_create_accepts_supported_types() -> None:
    for media_type in ("image", "video", "audio"):
        media = MediaCreate(media_type=media_type, url="https://example.com/file")
        assert media.media_type == media_type


def test_media_create_rejects_unsupported_type() -> None:
    with pytest.raises(ValidationError):
        MediaCreate(media_type="document", url="https://example.com/file.pdf")

    with pytest.raises(ValidationError):
        MediaUpdate(media_type="document")

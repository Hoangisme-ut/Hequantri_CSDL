import uuid
from collections.abc import Generator
from typing import Any
from unittest import TestCase
from unittest.mock import MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlmodel import Session, SQLModel, create_engine, select

from app.api.deps import get_current_user, get_db
from app.api.routes import artifacts, beacons, dashboard, media, visits
from app.core.config import settings
from app.models import (
    Artifact,
    ArtifactCreate,
    ArtifactTranslation,
    ArtifactTranslationBase,
    ArtifactTranslationCreate,
    ArtifactTranslationUpdate,
    ArtifactUpdate,
    Beacon,
    BeaconCreate,
    BeaconUpdate,
    Media,
    MediaCreate,
    MediaUpdate,
    User,
    VisitLogCreate,
)
from app.seed_sample_data import seed_sample_data

INT_MIN = -2147483648
INT_MAX = 2147483647
ID = str(uuid.uuid4())
BEACON = {"site_id": ID, "proximity_uuid": ID, "major": 1, "minor": 2}


def integer_inputs() -> list[
    tuple[type[SQLModel], dict[str, Any], dict[str, tuple[int, int]]]
]:
    signed = (INT_MIN, INT_MAX)
    return [
        (
            VisitLogCreate,
            {"artifact_id": ID},
            {"rssi": signed, "duration_seconds": (0, INT_MAX)},
        ),
        (MediaCreate, {"url": "https://example.com/a"}, {"sort_order": signed}),
        (MediaUpdate, {}, {"sort_order": signed}),
        (
            BeaconCreate,
            BEACON,
            {
                "tx_power": signed,
                "rssi_threshold": signed,
                "major": (0, 65535),
                "minor": (0, 65535),
            },
        ),
        (
            BeaconUpdate,
            {},
            {
                "tx_power": signed,
                "rssi_threshold": signed,
                "major": (0, 65535),
                "minor": (0, 65535),
                "battery_level": (0, 100),
            },
        ),
    ]


class InputModelTests(TestCase):
    def test_codes_and_titles_are_trimmed_and_nonempty(self) -> None:
        cases: list[tuple[type[SQLModel], dict[str, Any], str, int]] = [
            (ArtifactCreate, {"site_id": ID}, "code", 50),
            (ArtifactUpdate, {}, "code", 50),
            (ArtifactTranslationBase, {}, "title", 255),
            (ArtifactTranslationCreate, {"language_id": ID}, "title", 255),
            (ArtifactTranslationUpdate, {}, "title", 255),
        ]
        for model, payload, field, maximum in cases:
            with self.subTest(model=model.__name__):
                for blank in ("", "   ", "\t\n"):
                    with self.assertRaises(ValidationError):
                        model.model_validate({**payload, field: blank})
                for text in ("x", "x" * maximum):
                    result = model.model_validate({**payload, field: f"  {text}\t"})
                    self.assertEqual(getattr(result, field), text)
                with self.assertRaises(ValidationError):
                    model.model_validate({**payload, field: "x" * (maximum + 1)})

    def test_artifact_coordinate_boundaries(self) -> None:
        for model, payload in (
            (ArtifactCreate, {"site_id": ID, "code": "A"}),
            (ArtifactUpdate, {}),
        ):
            for field, maximum in (("latitude", 90), ("longitude", 180)):
                with self.subTest(model=model.__name__, field=field):
                    for value in (-maximum, maximum, 0, None):
                        result = model.model_validate({**payload, field: value})
                        self.assertEqual(getattr(result, field), value)
                    for invalid_value in (
                        -maximum - 0.01,
                        maximum + 0.01,
                        float("nan"),
                        float("inf"),
                    ):
                        with self.assertRaises(ValidationError):
                            model.model_validate({**payload, field: invalid_value})

    def test_media_requires_http_url_with_a_host_and_keeps_plain_string(self) -> None:
        for model in (MediaCreate, MediaUpdate):
            for url in (
                "http://?",
                "http://#fragment",
                "https://",
                "http:///path",
                "http://[invalid]",
                "http://exa mple.com/a",
                "http://example.com:65536/a",
                "ftp://example.com/a",
            ):
                with self.subTest(model=model.__name__, invalid=url):
                    with self.assertRaises(ValidationError):
                        model(url=url)
            for url in (
                "https://example.com/a?x=1#part",
                "http://localhost:8000/a",
                "http://127.0.0.1/a",
                "http://[::1]:8000/a",
                "HTTPS://EXAMPLE.COM/a",
            ):
                with self.subTest(model=model.__name__, valid=url):
                    result = model(url=f"  {url}  ")
                    self.assertIsInstance(result.url, str)
                    self.assertEqual(result.url, url)

    def test_integer_boundaries_match_storage_and_existing_domain_limits(self) -> None:
        for model, payload, fields in integer_inputs():
            for field, (minimum, maximum) in fields.items():
                with self.subTest(model=model.__name__, field=field):
                    for value in (minimum, maximum):
                        result = model.model_validate({**payload, field: value})
                        self.assertEqual(getattr(result, field), value)
                    for value in (minimum - 1, maximum + 1):
                        with self.assertRaises(ValidationError):
                            model.model_validate({**payload, field: value})

    def test_existing_optional_values_and_beacon_defaults_remain_valid(self) -> None:
        self.assertIsNone(VisitLogCreate(artifact_id=uuid.UUID(ID)).duration_seconds)
        self.assertEqual(VisitLogCreate(artifact_id=uuid.UUID(ID), rssi=-62).rssi, -62)
        beacon = BeaconCreate.model_validate(BEACON)
        self.assertEqual(beacon.tx_power, -59)
        self.assertEqual(beacon.rssi_threshold, -80)
        self.assertIsNone(BeaconUpdate(tx_power=None, rssi_threshold=None).tx_power)
        self.assertIsNone(ArtifactUpdate(latitude=None, longitude=None).latitude)
        self.assertIsNone(ArtifactTranslationUpdate(title=None).title)
        self.assertEqual(MediaCreate(url="https://example.com/a").sort_order, 0)

    def test_seed_rows_still_validate_as_input_payloads(self) -> None:
        engine = create_engine("sqlite://")
        try:
            SQLModel.metadata.create_all(engine)
            with Session(engine) as session:
                seed_sample_data(session)
                seed_sample_data(session)
                for table, input_model in (
                    (Artifact, ArtifactCreate),
                    (ArtifactTranslation, ArtifactTranslationBase),
                    (Media, MediaCreate),
                    (Beacon, BeaconCreate),
                ):
                    rows = session.exec(select(table)).all()
                    self.assertTrue(rows)
                    for row in rows:
                        input_model.model_validate(row.model_dump())
        finally:
            engine.dispose()


class InputRouteTests(TestCase):
    def setUp(self) -> None:
        self.session = MagicMock(spec=Session)
        self.session.exec.return_value.all.return_value = []

        def get_session() -> Generator[Session]:
            yield self.session

        admin = User(
            email="admin@example.com", hashed_password="unused", is_superuser=True
        )
        app = FastAPI()
        for router in (
            artifacts.router,
            beacons.router,
            media.router,
            visits.router,
            dashboard.router,
        ):
            app.include_router(router, prefix=settings.API_V1_STR)
        app.dependency_overrides[get_db] = get_session
        app.dependency_overrides[get_current_user] = lambda: admin
        self.client: TestClient = self.enterContext(
            TestClient(app, raise_server_exceptions=False)
        )

    def test_invalid_payloads_return_422_before_database_writes(self) -> None:
        cases = [
            ("POST", "/artifacts/", {"site_id": ID, "code": "   "}),
            ("POST", "/artifacts/", {"site_id": ID, "code": "A", "latitude": 91}),
            ("PUT", f"/artifacts/{ID}", {"longitude": 181}),
            ("PUT", f"/artifacts/{ID}/translations/{ID}", {"title": "   "}),
            ("POST", f"/artifacts/{ID}/media", {"url": "http://?"}),
            ("PUT", f"/artifacts/{ID}/media/{ID}", {"sort_order": INT_MAX + 1}),
            ("POST", "/beacons/", {**BEACON, "tx_power": INT_MIN - 1}),
            ("PUT", f"/beacons/{ID}", {"rssi_threshold": INT_MAX + 1}),
            ("POST", "/visits/", {"artifact_id": ID, "duration_seconds": INT_MAX + 1}),
            ("POST", "/visits/", {"artifact_id": ID, "rssi": INT_MIN - 1}),
        ]
        for method, url, payload in cases:
            with self.subTest(method=method, url=url, payload=payload):
                self.session.reset_mock()
                response = self.client.request(
                    method, f"{settings.API_V1_STR}{url}", json=payload
                )
                self.assertEqual(response.status_code, 422)
                self.session.add.assert_not_called()
                self.session.commit.assert_not_called()
                self.session.flush.assert_not_called()

    def test_default_date_range_underflow_returns_422_without_querying(self) -> None:
        for to_date in ("0001-01-01", "0001-01-29"):
            with self.subTest(to_date=to_date):
                self.session.reset_mock()
                response = self.client.get(
                    f"{settings.API_V1_STR}/dashboard/visits-by-day",
                    params={"to_date": to_date},
                )
                self.assertEqual(response.status_code, 422)
                self.assertEqual(
                    response.json(),
                    {"detail": "Default date range cannot be represented"},
                )
                self.session.exec.assert_not_called()

    def test_minimum_representable_and_explicit_date_ranges_work(self) -> None:
        for params, first, length in (
            ({"to_date": "0001-01-30"}, "0001-01-01", 30),
            ({"from_date": "0001-01-01", "to_date": "0001-01-01"}, "0001-01-01", 1),
            ({"to_date": "2024-12-31"}, "2024-12-02", 30),
        ):
            with self.subTest(params=params):
                response = self.client.get(
                    f"{settings.API_V1_STR}/dashboard/visits-by-day", params=params
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["from_date"], first)
                self.assertEqual(len(response.json()["data"]), length)

    def test_date_range_limit_remains_366_days(self) -> None:
        allowed = self.client.get(
            f"{settings.API_V1_STR}/dashboard/visits-by-day",
            params={"from_date": "2024-01-01", "to_date": "2024-12-31"},
        )
        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(len(allowed.json()["data"]), 366)
        self.session.reset_mock()
        rejected = self.client.get(
            f"{settings.API_V1_STR}/dashboard/visits-by-day",
            params={"from_date": "2024-01-01", "to_date": "2025-01-01"},
        )
        self.assertEqual(rejected.status_code, 422)
        self.session.exec.assert_not_called()

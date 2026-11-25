import uuid
from unittest.mock import MagicMock, patch

import pytest
from fastapi import Response
from sqlmodel import Session

from app import crud
from app.api.routes import visits
from app.models import Artifact, Language, User, VisitLogCreate


@pytest.mark.parametrize(
    ("preferred", "submitted", "expected"),
    [
        ("vi", "en", "en"),
        ("en", "vi", "vi"),
        ("en", "unknown", "en"),
        ("en", None, "en"),
        ("en", 42, "en"),
        (None, "unknown", "vi"),
    ],
)
def test_visit_resolves_code_and_preserves_legacy_fallback(
    preferred: str | None, submitted: object, expected: str
) -> None:
    languages = {
        "vi": Language(code="vi", name="Tiếng Việt", is_default=True),
        "en": Language(code="en", name="English"),
    }
    user = User(email="visitor@example.com", hashed_password="unused")
    if preferred is not None:
        user.language = languages[preferred]
    artifact = Artifact(site_id=uuid.uuid4(), code="VASE")
    session = MagicMock(spec=Session)
    request = VisitLogCreate.model_validate(
        {"artifact_id": artifact.id, "language_code": submitted}
    )

    with (
        patch.object(visits, "acquire_transaction_lock") as lock,
        patch.object(crud, "get_visible_artifact", return_value=artifact),
        patch.object(
            crud,
            "get_language_by_code",
            side_effect=lambda *, session, code: languages.get(code),
        ),
        patch.object(crud, "get_default_language", return_value=languages["vi"]),
        patch.object(crud, "find_recent_visit", return_value=None),
    ):
        visit = visits.record_visit(
            session=session, current_user=user, visit_in=request, response=Response()
        )

    assert visit.language_id == languages[expected].id
    lock.assert_called_once_with(session, f"visit:{user.id}:{artifact.id}")
    session.add.assert_called_once_with(visit)
    session.commit.assert_called_once()

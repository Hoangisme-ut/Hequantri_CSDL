"""Kiểm thử schema, quy tắc trạng thái và ràng buộc của Feedback (theo ERD)."""

import uuid

import pytest
from pydantic import ValidationError

from app import crud
from app.models import (
    Feedback,
    FeedbackCreate,
    FeedbackStatus,
    FeedbackStatusUpdate,
    FeedbackUpdate,
)


def test_feedback_status_values_match_erd() -> None:
    assert {s.value for s in FeedbackStatus} == {"pending", "approved", "hidden"}


def test_feedback_table_has_erd_constraints_and_updated_at() -> None:
    names = {c.name for c in Feedback.__table__.constraints if c.name}  # type: ignore[attr-defined]
    assert {
        "uq_feedback_user_artifact",
        "ck_feedback_rating",
        "ck_feedback_status",
    } <= names
    assert "updated_at" in Feedback.__table__.columns  # type: ignore[attr-defined]


@pytest.mark.parametrize("rating", [1, 2, 3, 4, 5])
def test_feedback_create_accepts_rating_1_to_5(rating: int) -> None:
    assert FeedbackCreate(artifact_id=uuid.uuid4(), rating=rating).rating == rating


@pytest.mark.parametrize("rating", [0, 6, -1, 100])
def test_feedback_create_rejects_rating_out_of_range(rating: int) -> None:
    with pytest.raises(ValidationError):
        FeedbackCreate(artifact_id=uuid.uuid4(), rating=rating)


def test_feedback_comment_is_stripped_and_blank_becomes_none() -> None:
    artifact_id = uuid.uuid4()
    assert (
        FeedbackCreate(artifact_id=artifact_id, rating=3, comment="  hay  ").comment
        == "hay"
    )
    assert (
        FeedbackCreate(artifact_id=artifact_id, rating=3, comment="   ").comment is None
    )
    assert FeedbackCreate(artifact_id=artifact_id, rating=3).comment is None
    with pytest.raises(ValidationError):
        FeedbackCreate(artifact_id=artifact_id, rating=3, comment="x" * 2001)
    assert (
        FeedbackCreate(artifact_id=artifact_id, rating=3, comment="x" * 2000).comment
        == "x" * 2000
    )


def test_feedback_update_requires_a_change_and_non_null_rating() -> None:
    with pytest.raises(ValidationError):
        FeedbackUpdate()
    with pytest.raises(ValidationError):
        FeedbackUpdate(rating=None)
    with pytest.raises(ValidationError):
        FeedbackUpdate(rating=6)
    cleared = FeedbackUpdate(comment=None)
    assert "comment" in cleared.model_fields_set
    assert "rating" not in cleared.model_fields_set
    assert FeedbackUpdate(comment="   ").comment is None
    assert FeedbackUpdate(rating=2).rating == 2


@pytest.mark.parametrize("value", ["approved", "hidden"])
def test_status_update_accepts_only_moderation_values(value: str) -> None:
    assert FeedbackStatusUpdate(status=value).status == value  # type: ignore[arg-type]


@pytest.mark.parametrize("value", ["pending", "rejected", "xyz", "", "Approved"])
def test_status_update_rejects_other_values(value: str) -> None:
    with pytest.raises(ValidationError):
        FeedbackStatusUpdate(status=value)  # type: ignore[arg-type]


def test_initial_status_follows_comment() -> None:
    assert crud.initial_feedback_status("Có bình luận") == FeedbackStatus.PENDING
    assert crud.initial_feedback_status(None) == FeedbackStatus.APPROVED
    assert crud.initial_feedback_status("") == FeedbackStatus.APPROVED


@pytest.mark.parametrize(
    ("current", "old", "new", "expected"),
    [
        ("approved", "a", "b", "pending"),  # sửa comment: approved -> pending
        ("approved", None, "a", "pending"),  # thêm comment mới
        ("approved", "a", "a", "approved"),  # comment không đổi (chỉ đổi rating)
        ("approved", "a", None, "approved"),  # xóa comment: không còn gì để duyệt
        ("approved", None, None, "approved"),
        ("pending", "a", "b", "pending"),
        ("pending", "a", "a", "pending"),
        ("pending", "a", None, "approved"),
        ("hidden", "a", "b", "hidden"),  # hidden giữ nguyên
        ("hidden", "a", None, "hidden"),
        ("hidden", "a", "a", "hidden"),
    ],
)
def test_status_after_edit_rules(
    current: str, old: str | None, new: str | None, expected: str
) -> None:
    assert (
        crud.status_after_feedback_edit(
            current_status=current, old_comment=old, new_comment=new
        )
        == expected
    )

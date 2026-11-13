"""Kiểm thử tài liệu Swagger (OpenAPI) của các API Smart Heritage.

Không gọi DB: chỉ kiểm tra thông tin mô tả mà người dùng Swagger nhìn thấy.
"""

from typing import Any

import pytest

from app.main import OPENAPI_TAGS, app

HERITAGE_TAGS = {
    "languages",
    "sites",
    "artifacts",
    "beacons",
    "favorites",
    "feedbacks",
    "visits",
    "dashboard",
}
BODY_METHODS = {"post", "put", "patch"}


@pytest.fixture(scope="module")
def spec() -> dict[str, Any]:
    app.openapi_schema = None  # luôn dựng lại từ route hiện tại
    return app.openapi()


def _operations(spec: dict[str, Any]) -> list[tuple[str, str, dict[str, Any]]]:
    return [
        (method, path, op)
        for path, item in spec["paths"].items()
        for method, op in item.items()
        if method in {"get", "post", "put", "patch", "delete"}
    ]


def _resolve(spec: dict[str, Any], schema: dict[str, Any]) -> dict[str, Any]:
    ref = schema.get("$ref")
    if ref:
        name = ref.rsplit("/", 1)[-1]
        return spec["components"]["schemas"][name]  # type: ignore[no-any-return]
    return schema


def _body_schema(spec: dict[str, Any], op: dict[str, Any]) -> dict[str, Any] | None:
    content = op.get("requestBody", {}).get("content", {}).get("application/json")
    return _resolve(spec, content["schema"]) if content else None


def test_every_used_tag_is_declared_with_description(spec: dict[str, Any]) -> None:
    declared = {tag["name"]: tag.get("description") for tag in OPENAPI_TAGS}
    used = {tag for _, _, op in _operations(spec) for tag in op.get("tags", [])}
    heritage_used = used & (HERITAGE_TAGS | {"analytics", "feedback", "media"})
    assert HERITAGE_TAGS <= used
    for tag in heritage_used:
        assert declared.get(tag), f"Tag '{tag}' chưa có mô tả trong OPENAPI_TAGS"


def test_heritage_endpoints_have_docstring_description(spec: dict[str, Any]) -> None:
    missing = [
        f"{method.upper()} {path}"
        for method, path, op in _operations(spec)
        if set(op.get("tags", [])) & HERITAGE_TAGS and not op.get("description")
    ]
    assert not missing, f"Endpoint thiếu mô tả: {missing}"


def test_protected_endpoints_document_401_and_403(spec: dict[str, Any]) -> None:
    """Endpoint phân quyền phải ghi rõ cả 401 (thiếu token) và 403 (sai quyền);
    endpoint mô tả "Admin" bắt buộc có 403."""
    problems: list[str] = []
    for method, path, op in _operations(spec):
        if not set(op.get("tags", [])) & HERITAGE_TAGS:
            continue
        responses = op.get("responses", {})
        description = op.get("description", "")
        if "403" in responses and "401" not in responses:
            problems.append(f"{method.upper()} {path}: có 403 nhưng thiếu 401")
        if ("Chỉ Admin" in description or "**Admin**" in description) and (
            "403" not in responses or "401" not in responses
        ):
            problems.append(f"{method.upper()} {path}: mô tả Admin nhưng thiếu 401/403")
    assert not problems, problems


def test_request_bodies_of_new_apis_have_examples(spec: dict[str, Any]) -> None:
    """Mọi body JSON của nhóm API mới đều có ví dụ để thử trên Swagger."""
    checked_tags = {"favorites", "feedbacks", "visits", "languages"}
    missing: list[str] = []
    for method, path, op in _operations(spec):
        if method not in BODY_METHODS or not set(op.get("tags", [])) & checked_tags:
            continue
        schema = _body_schema(spec, op)
        if schema is not None and not schema.get("examples"):
            missing.append(f"{method.upper()} {path} ({schema.get('title')})")
    assert not missing, f"Body chưa có ví dụ: {missing}"


@pytest.mark.parametrize(
    "schema_name",
    ["FeedbackPublic", "VisitLogPublic", "FavoritePublic"],
)
def test_response_models_have_examples(spec: dict[str, Any], schema_name: str) -> None:
    assert spec["components"]["schemas"][schema_name].get("examples")


def test_examples_are_valid_against_their_schema() -> None:
    """Ví dụ mẫu không được sai quy tắc validation (tránh Swagger cho ví dụ lỗi)."""
    from app.models import (
        FeedbackCreate,
        FeedbackStatusUpdate,
        FeedbackUpdate,
        LanguageCreate,
        LanguageUpdate,
        UserUpdate,
        UserUpdateMe,
        VisitLogCreate,
    )

    for model in (
        FeedbackCreate,
        FeedbackUpdate,
        FeedbackStatusUpdate,
        LanguageCreate,
        LanguageUpdate,
        UserUpdate,
        UserUpdateMe,
        VisitLogCreate,
    ):
        for example in model.model_config["json_schema_extra"]["examples"]:  # type: ignore[index]
            model.model_validate(example)

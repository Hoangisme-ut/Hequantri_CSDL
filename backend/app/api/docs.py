"""Mô tả lỗi dùng chung cho Swagger (OpenAPI).

Dùng: `@router.post("/", responses=errors(401, 403, 409))`
"""

from typing import Any

_DESCRIPTIONS: dict[int, str] = {
    400: "Dữ liệu không hợp lệ về nghiệp vụ (ví dụ Beacon và Artifact khác Site)",
    401: "Thiếu hoặc sai token đăng nhập",
    403: "Không đủ quyền (nội dung di sản cần role admin; quản lý người dùng cần superuser)",
    404: "Không tìm thấy hoặc đang bị ẩn",
    409: "Xung đột dữ liệu (trùng mã, Site đang ẩn, hiện vật đang gắn beacon...)",
    422: "Dữ liệu gửi lên sai định dạng",
}


def errors(*codes: int) -> dict[int | str, dict[str, Any]]:
    """Trả về dict `responses` cho các mã lỗi được liệt kê."""
    return {code: {"description": _DESCRIPTIONS[code]} for code in codes}

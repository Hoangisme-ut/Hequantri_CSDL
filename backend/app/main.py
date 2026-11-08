from pathlib import Path

import sentry_sdk
from fastapi import FastAPI
from fastapi.routing import APIRoute
from starlette.middleware.cors import CORSMiddleware

from app.api.main import api_router
from app.core.config import settings

FRONTEND_DIR = Path(__file__).parent / "frontend"


def custom_generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}"


if settings.SENTRY_DSN and settings.FASTAPI_ENV != "development":
    sentry_sdk.init(dsn=str(settings.SENTRY_DSN), enable_tracing=True)

OPENAPI_TAGS = [
    {"name": "login"},
    {"name": "users"},
    {
        "name": "languages",
        "description": "Ngôn ngữ hỗ trợ (vi, en...). Public đọc, admin quản lý.",
    },
    {"name": "sites", "description": "Di tích. Public đọc, admin quản lý."},
    {
        "name": "artifacts",
        "description": "Hiện vật và nội dung theo ngôn ngữ (bản dịch, media). Public đọc, admin quản lý.",
    },
    {"name": "media"},
    {
        "name": "beacons",
        "description": "Beacon iBeacon. App quét gọi `GET /beacons/resolve`; admin quản lý thiết bị.",
    },
    {
        "name": "favorites",
        "description": "Hiện vật yêu thích của người dùng đang đăng nhập.",
    },
    {"name": "feedback"},
    {
        "name": "feedbacks",
        "description": (
            "Đánh giá / phản hồi hiện vật. Visitor gửi và đọc của mình; admin duyệt "
            "(approved) hoặc ẩn (hidden); khách chỉ thấy comment đã duyệt."
        ),
    },
    {
        "name": "visits",
        "description": "Ghi lượt xem và lịch sử tham quan của người dùng đang đăng nhập.",
    },
    {"name": "analytics"},
    {
        "name": "dashboard",
        "description": "Thống kê tổng quan (Site/Artifact/Beacon, lượt xem theo ngày, top hiện vật, theo ngôn ngữ). Chỉ Admin.",
    },
    {"name": "items"},
    {"name": "utils"},
    {"name": "private"},
]

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_tags=OPENAPI_TAGS,
    swagger_ui_parameters={"operationsSorter": "alpha"},
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    generate_unique_id_function=custom_generate_unique_id,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.FRONTEND_HOST],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)
if FRONTEND_DIR.exists():
    app.frontend("/", directory=FRONTEND_DIR)

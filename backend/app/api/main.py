from fastapi import APIRouter

from app.api.routes import (
    artifacts,
    beacons,
    favorites,
    items,
    languages,
    login,
    media,
    private,
    sites,
    users,
    utils,
    visit_logs,
)
from app.core.config import settings

api_router = APIRouter()
api_router.include_router(login.router)
api_router.include_router(users.router)
api_router.include_router(utils.router)
api_router.include_router(items.router)
api_router.include_router(languages.router)
api_router.include_router(sites.router)
api_router.include_router(artifacts.router)
api_router.include_router(media.router)
api_router.include_router(beacons.router)
api_router.include_router(visit_logs.router)
api_router.include_router(favorites.router)


if settings.FASTAPI_ENV == "development":
    api_router.include_router(private.router)
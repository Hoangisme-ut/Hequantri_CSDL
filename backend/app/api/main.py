from fastapi import APIRouter

from app.api.routes import (
    artifacts,
    beacons,
    items,
    languages,
    login,
    private,
    sites,
    users,
    utils,
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
api_router.include_router(beacons.router)


if settings.FASTAPI_ENV == "development":
    api_router.include_router(private.router)

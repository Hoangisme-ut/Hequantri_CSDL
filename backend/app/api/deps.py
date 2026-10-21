from collections.abc import Generator
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jwt.exceptions import InvalidTokenError
from pydantic import ValidationError
from sqlmodel import Session

from app.core import security
from app.core.config import settings
from app.core.db import engine
from app.models import TokenPayload, User

reusable_oauth2 = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/login/access-token"
)


def get_db() -> Generator[Session]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_db)]
TokenDep = Annotated[str, Depends(reusable_oauth2)]


def get_current_user(session: SessionDep, token: TokenDep) -> User:
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[security.ALGORITHM]
        )
        token_data = TokenPayload(**payload)
    except (InvalidTokenError, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )
    user = session.get(User, token_data.sub)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_current_active_superuser(current_user: CurrentUser) -> User:
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=403, detail="The user doesn't have enough privileges"
        )
    return current_user


# =============================================================================
# [Smart Heritage] Phân quyền theo Role (admin / visitor)
# =============================================================================
ROLE_ADMIN = "admin"
ROLE_VISITOR = "visitor"


def get_role_name(user: User) -> str:
    """Tên role của user. User cũ chưa có role: superuser -> admin, còn lại -> visitor."""
    if user.role is not None:
        return user.role.name
    return ROLE_ADMIN if user.is_superuser else ROLE_VISITOR


def is_admin(user: User | None) -> bool:
    return user is not None and get_role_name(user) == ROLE_ADMIN


def require_role(*allowed: str):  # type: ignore[no-untyped-def]
    """Tạo dependency chỉ cho phép các role trong `allowed`.

    Dùng: Depends(require_role("admin")) hoặc các alias AdminUser / VisitorUser.
    """

    def checker(current_user: CurrentUser) -> User:
        if get_role_name(current_user) not in allowed:
            raise HTTPException(
                status_code=403, detail="The user doesn't have enough privileges"
            )
        return current_user

    return checker


# Chỉ admin
AdminUser = Annotated[User, Depends(require_role(ROLE_ADMIN))]
# Du khách đã đăng nhập (admin cũng được gọi để test)
VisitorUser = Annotated[User, Depends(require_role(ROLE_VISITOR, ROLE_ADMIN))]

# Đăng nhập tùy chọn: API công khai nhưng admin được xem thêm dữ liệu đã ẩn
reusable_oauth2_optional = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/login/access-token", auto_error=False
)


def get_optional_user(
    session: SessionDep,
    token: Annotated[str | None, Depends(reusable_oauth2_optional)],
) -> User | None:
    if not token:
        return None
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[security.ALGORITHM]
        )
        token_data = TokenPayload(**payload)
    except (InvalidTokenError, ValidationError):
        return None
    user = session.get(User, token_data.sub)
    if not user or not user.is_active:
        return None
    return user


OptionalUser = Annotated[User | None, Depends(get_optional_user)]

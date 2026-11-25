from typing import Any

from fastapi import APIRouter, Depends, HTTPException

from app import crud
from app.api.deps import (
    SessionDep,
    get_current_active_superuser,
    get_role_or_404,
)
from app.models import UserCreate, UserPublic

router = APIRouter(tags=["private"], prefix="/private")


@router.post(
    "/users/",
    dependencies=[Depends(get_current_active_superuser)],
    response_model=UserPublic,
)
def create_user(user_in: UserCreate, session: SessionDep) -> Any:
    """
    Create a new user. Superuser only.
    """
    if user_in.role_id is not None:
        get_role_or_404(session, user_in.role_id)

    try:
        user = crud.create_user(
            session=session,
            user_create=user_in,
        )
    except crud.InvalidRoleAssignmentError as exc:
        raise HTTPException(
            status_code=409,
            detail=str(exc),
        ) from exc

    return user

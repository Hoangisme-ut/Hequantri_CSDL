from fastapi import APIRouter, Depends
from sqlmodel import select

from app.api.deps import SessionDep, get_current_active_superuser
from app.models import Role, RolePublic

router = APIRouter(prefix="/roles", tags=["roles"])


@router.get(
    "/",
    dependencies=[Depends(get_current_active_superuser)],
    response_model=list[RolePublic],
)
def read_roles(session: SessionDep) -> list[RolePublic]:
    """
    Retrieve supported roles. Superuser only.
    """
    statement = (
        select(Role)
        .where(Role.name.in_(["admin", "visitor"]))
        .order_by(Role.name)
    )
    roles = session.exec(statement).all()
    return [RolePublic.model_validate(role) for role in roles]

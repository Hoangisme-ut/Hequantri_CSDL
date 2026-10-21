from sqlmodel import Session, col, create_engine, select

from app import crud
from app.core.config import settings
from app.models import Language, Role, User, UserCreate

engine = create_engine(str(settings.DATABASE_URL), pool_pre_ping=True)


# make sure all SQLModel models are imported (app.models) before initializing DB
# otherwise, SQLModel might fail to initialize relationships properly
# for more details: https://github.com/fastapi/full-stack-fastapi-template/issues/28

# [Smart Heritage] dữ liệu mặc định, chạy mỗi lần khởi động nhưng chỉ tạo nếu chưa có
DEFAULT_ROLES = [
    ("admin", "Quản trị viên khu di tích"),
    ("visitor", "Du khách dùng ứng dụng di động"),
]
DEFAULT_LANGUAGES = [
    ("vi", "Tiếng Việt"),
    ("en", "English"),
]


def init_db(session: Session) -> None:
    # Tables should be created with Alembic migrations
    # But if you don't want to use migrations, create
    # the tables un-commenting the next lines
    # from sqlmodel import SQLModel

    # This works because the models are already imported and registered from app.models
    # SQLModel.metadata.create_all(engine)

    # --- seed Role ---
    for name, description in DEFAULT_ROLES:
        if not session.exec(select(Role).where(Role.name == name)).first():
            session.add(Role(name=name, description=description))
    # --- seed Language ---
    for code, name in DEFAULT_LANGUAGES:
        if not session.exec(select(Language).where(Language.code == code)).first():
            session.add(Language(code=code, name=name))
    session.commit()
    # --- ngôn ngữ mặc định: nếu chưa có thì đặt tiếng Việt ---
    if not session.exec(select(Language).where(col(Language.is_default))).first():
        vi = session.exec(select(Language).where(Language.code == "vi")).one()
        vi.is_default = True
        session.add(vi)
        session.commit()

    # --- seed superuser (gắn role admin) ---
    admin_role = session.exec(select(Role).where(Role.name == "admin")).one()
    user = session.exec(
        select(User).where(User.email == settings.FIRST_SUPERUSER)
    ).first()
    if not user:
        user_in = UserCreate(
            email=settings.FIRST_SUPERUSER,
            password=settings.FIRST_SUPERUSER_PASSWORD,
            is_superuser=True,
        )
        user = crud.create_user(session=session, user_create=user_in)
    if user.role_id is None:
        user.role_id = admin_role.id
        session.add(user)
        session.commit()
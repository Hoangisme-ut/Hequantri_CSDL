import uuid

import pytest
from fastapi import HTTPException
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, select

from app.api.routes.favorites import create_favorite, delete_favorite, read_favorites
from app.models import Artifact, Favorite, FavoriteCreate, Site, User


@pytest.fixture
def session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as db_session:
        yield db_session


def make_user(session: Session, name: str) -> User:
    user = User(
        email=f"{name}-{uuid.uuid4().hex[:6]}@example.com",
        hashed_password="not-used-in-unit-tests",
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def make_artifact(
    session: Session,
    site: Site | None = None,
    *,
    is_active: bool = True,
) -> Artifact:
    if site is None:
        site = Site(name="Test site")
        session.add(site)
        session.commit()
        session.refresh(site)
    artifact = Artifact(
        site_id=site.id, code=f"ART-{uuid.uuid4().hex[:8]}", is_active=is_active
    )
    session.add(artifact)
    session.commit()
    session.refresh(artifact)
    return artifact


def add(session: Session, user: User, artifact: Artifact):  # type: ignore[no-untyped-def]
    return create_favorite(
        session=session,
        current_user=user,
        favorite_in=FavoriteCreate(artifact_id=artifact.id),
    )


def listing(session: Session, user: User, *, skip: int = 0, limit: int = 100):  # type: ignore[no-untyped-def]
    return read_favorites(session=session, current_user=user, skip=skip, limit=limit)


def test_add_list_and_remove_favorite(session: Session) -> None:
    user = make_user(session, "alice")
    artifact = make_artifact(session)

    created = add(session, user, artifact)
    assert created.user_id == user.id
    assert created.artifact_id == artifact.id
    assert created.created_at is not None

    result = listing(session, user)
    assert result.count == 1
    assert [f.artifact_id for f in result.data] == [artifact.id]

    removed = delete_favorite(
        session=session, current_user=user, artifact_id=artifact.id
    )
    assert removed.message == "Favorite removed successfully"
    assert listing(session, user).count == 0


def test_cannot_create_duplicate_favorite(session: Session) -> None:
    user = make_user(session, "alice")
    artifact = make_artifact(session)
    add(session, user, artifact)

    with pytest.raises(HTTPException) as exc_info:
        add(session, user, artifact)

    assert exc_info.value.status_code == 409
    rows = session.exec(select(Favorite).where(Favorite.user_id == user.id)).all()
    assert len(rows) == 1


def test_different_users_can_favorite_same_artifact(session: Session) -> None:
    alice = make_user(session, "alice")
    bob = make_user(session, "bob")
    artifact = make_artifact(session)

    add(session, alice, artifact)
    add(session, bob, artifact)

    assert listing(session, alice).count == 1
    assert listing(session, bob).count == 1


def test_list_only_returns_own_favorites(session: Session) -> None:
    alice = make_user(session, "alice")
    bob = make_user(session, "bob")
    art_a = make_artifact(session)
    art_b = make_artifact(session)
    add(session, alice, art_a)
    add(session, bob, art_b)

    alice_list = listing(session, alice)
    assert [f.artifact_id for f in alice_list.data] == [art_a.id]
    assert all(f.user_id == alice.id for f in alice_list.data)

    bob_list = listing(session, bob)
    assert [f.artifact_id for f in bob_list.data] == [art_b.id]


def test_cannot_delete_other_users_favorite(session: Session) -> None:
    alice = make_user(session, "alice")
    bob = make_user(session, "bob")
    artifact = make_artifact(session)
    add(session, alice, artifact)

    with pytest.raises(HTTPException) as exc_info:
        delete_favorite(session=session, current_user=bob, artifact_id=artifact.id)

    assert exc_info.value.status_code == 404
    # yêu thích của alice còn nguyên
    assert listing(session, alice).count == 1


def test_delete_missing_favorite_returns_404(session: Session) -> None:
    user = make_user(session, "alice")
    artifact = make_artifact(session)

    with pytest.raises(HTTPException) as exc_info:
        delete_favorite(session=session, current_user=user, artifact_id=artifact.id)
    assert exc_info.value.status_code == 404


def test_cannot_favorite_missing_or_hidden_artifact(session: Session) -> None:
    user = make_user(session, "alice")

    with pytest.raises(HTTPException) as exc_info:
        create_favorite(
            session=session,
            current_user=user,
            favorite_in=FavoriteCreate(artifact_id=uuid.uuid4()),
        )
    assert exc_info.value.status_code == 404

    hidden_artifact = make_artifact(session, is_active=False)
    with pytest.raises(HTTPException) as exc_info:
        add(session, user, hidden_artifact)
    assert exc_info.value.status_code == 404

    hidden_site = Site(name="Hidden", is_active=False)
    session.add(hidden_site)
    session.commit()
    session.refresh(hidden_site)
    under_hidden_site = make_artifact(session, hidden_site)
    with pytest.raises(HTTPException) as exc_info:
        add(session, user, under_hidden_site)
    assert exc_info.value.status_code == 404

    assert listing(session, user).count == 0


def test_hidden_artifact_or_site_is_not_listed_and_comes_back_when_restored(
    session: Session,
) -> None:
    user = make_user(session, "alice")
    site = Site(name="Site")
    session.add(site)
    session.commit()
    session.refresh(site)
    artifact = make_artifact(session, site)
    add(session, user, artifact)

    # ẩn hiện vật
    artifact.is_active = False
    session.add(artifact)
    session.commit()
    assert listing(session, user).count == 0
    artifact.is_active = True
    session.add(artifact)
    session.commit()
    assert listing(session, user).count == 1

    # ẩn Site
    site.is_active = False
    session.add(site)
    session.commit()
    hidden = listing(session, user)
    assert hidden.count == 0
    assert hidden.data == []

    # vẫn bỏ yêu thích được khi hiện vật bị ẩn
    delete_favorite(session=session, current_user=user, artifact_id=artifact.id)
    site.is_active = True
    session.add(site)
    session.commit()
    assert listing(session, user).count == 0


def test_favorites_pagination(session: Session) -> None:
    user = make_user(session, "alice")
    artifacts = [make_artifact(session) for _ in range(3)]
    for artifact in artifacts:
        add(session, user, artifact)

    page = listing(session, user, skip=0, limit=2)
    assert page.count == 3
    assert len(page.data) == 2

    rest = listing(session, user, skip=2, limit=2)
    assert rest.count == 3
    assert len(rest.data) == 1

    seen = {f.artifact_id for f in page.data} | {f.artifact_id for f in rest.data}
    assert seen == {a.id for a in artifacts}
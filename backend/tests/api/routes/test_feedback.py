import uuid

import pytest
from sqlalchemy.exc import IntegrityError

from app.models import Feedback
from tests.utils.heritage import API, create_artifact, create_site, purge_sites


@pytest.fixture
def artifact(client, superuser_token_headers, db):
    site = create_site(client, superuser_token_headers)
    row = create_artifact(client, superuser_token_headers, site["id"])
    yield row
    purge_sites(db, [site["id"]])


@pytest.mark.parametrize("values", [{"rating": 0}, {"status": "invalid"}])
def test_feedback_database_constraints(
    client, db, artifact, normal_user_token_headers, values
):
    user = client.get(f"{API}/users/me", headers=normal_user_token_headers).json()
    row = Feedback(
        user_id=uuid.UUID(user["id"]),
        artifact_id=uuid.UUID(artifact["id"]),
        rating=3,
    )
    for key, value in values.items():
        setattr(row, key, value)
    db.add(row)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()
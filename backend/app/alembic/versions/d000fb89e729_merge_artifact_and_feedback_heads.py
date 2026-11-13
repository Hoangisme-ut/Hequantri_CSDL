"""merge artifact and feedback heads

Revision ID: d000fb89e729
Revises: 9398b7ad0549, f7a8b9c0d1e2
Create Date: 2026-11-13 04:55:01.287894

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel.sql.sqltypes


# revision identifiers, used by Alembic.
revision = 'd000fb89e729'
down_revision = ('9398b7ad0549', 'f7a8b9c0d1e2')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass

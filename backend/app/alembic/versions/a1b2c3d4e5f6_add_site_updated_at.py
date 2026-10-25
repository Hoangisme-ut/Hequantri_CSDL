"""Add Site update timestamp from the ERD.

Revision ID: a1b2c3d4e5f6
Revises: 7d6e9a4b2c1f
Create Date: 2026-10-26 00:00:00.000000

"""

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision = "a1b2c3d4e5f6"
down_revision = "7d6e9a4b2c1f"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "site",
        sa.Column("updated_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("site", "updated_at")

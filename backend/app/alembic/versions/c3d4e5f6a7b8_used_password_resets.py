"""Remember consumed reset tokens without invalidating existing access tokens.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
"""

import sqlalchemy as sa
from alembic import op
from sqlmodel.sql.sqltypes import UTCDateTime

revision = "c3d4e5f6a7b8"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "usedpasswordreset",
        sa.Column("token_digest", sa.String(64), primary_key=True, nullable=False),
        sa.Column("used_at", UTCDateTime(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("usedpasswordreset")

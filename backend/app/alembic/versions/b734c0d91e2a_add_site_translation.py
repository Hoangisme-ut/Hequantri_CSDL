"""Add independent per-language Site translations.

Revision ID: b734c0d91e2a
Revises: a1b2c3d4e5f6
Create Date: 2026-11-04
"""

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

revision = "b734c0d91e2a"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sitetranslation",
        sa.Column("name", sa.Unicode(length=255), nullable=False),
        sa.Column("description", sa.Unicode(length=2000), nullable=True),
        sa.Column("address", sa.Unicode(length=500), nullable=True),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("site_id", sa.Uuid(), nullable=False),
        sa.Column("language_id", sa.Uuid(), nullable=False),
        sa.Column("source_hash", sa.Unicode(length=64), nullable=False),
        sa.Column(
            "translation_source",
            sa.Unicode(length=40),
            server_default="manual",
            nullable=False,
        ),
        sa.Column(
            "is_confirmed", sa.Boolean(), server_default=sa.false(), nullable=False
        ),
        sa.Column("created_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
        sa.Column("updated_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
        sa.ForeignKeyConstraint(["language_id"], ["language.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["site_id"], ["site.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("site_id", "language_id", name="uq_site_language"),
    )


def downgrade() -> None:
    op.drop_table("sitetranslation")

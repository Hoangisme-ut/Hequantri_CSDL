"""Complete Beacon and Media schema from the final ERD.

Revision ID: 7d6e9a4b2c1f
Revises: c3a91f5e7d20
Create Date: 2026-10-23 13:00:00.000000

"""

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision = "7d6e9a4b2c1f"
down_revision = "c3a91f5e7d20"
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column(
        "beacon",
        "tx_power",
        existing_type=sa.Integer(),
        existing_nullable=True,
        server_default=sa.text("-59"),
    )
    op.alter_column(
        "beacon",
        "rssi_threshold",
        existing_type=sa.Integer(),
        existing_nullable=True,
        server_default=sa.text("-80"),
    )
    op.add_column(
        "beacon",
        sa.Column("updated_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    )
    op.create_check_constraint(
        "ck_beacon_major", "beacon", "major BETWEEN 0 AND 65535"
    )
    op.create_check_constraint(
        "ck_beacon_minor", "beacon", "minor BETWEEN 0 AND 65535"
    )

    op.add_column(
        "media",
        sa.Column("updated_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    )
    op.create_check_constraint(
        "ck_media_type", "media", "media_type IN ('image', 'video', 'audio')"
    )


def downgrade():
    op.drop_constraint("ck_media_type", "media", type_="check")
    op.drop_column("media", "updated_at")

    op.drop_constraint("ck_beacon_minor", "beacon", type_="check")
    op.drop_constraint("ck_beacon_major", "beacon", type_="check")
    op.drop_column("beacon", "updated_at")
    op.alter_column(
        "beacon",
        "rssi_threshold",
        existing_type=sa.Integer(),
        existing_nullable=True,
        server_default=None,
    )
    op.alter_column(
        "beacon",
        "tx_power",
        existing_type=sa.Integer(),
        existing_nullable=True,
        server_default=None,
    )

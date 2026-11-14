"""Drop legacy generic Item table."""

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision = "9398b7ad0549"
down_revision = "b734c0d91e2a"
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        """
        IF OBJECT_ID(N'dbo.item', N'U') IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.item WITH (TABLOCKX, HOLDLOCK))
                THROW 50001, 'Cannot drop dbo.item: it contains rows. Back up dbo.item first, then explicitly archive or remove its rows before rerunning the migration.', 1;
            DROP TABLE dbo.item;
        END
        """
    )


def downgrade():
    op.create_table(
        "item",
        sa.Column(
            "title",
            sqlmodel.sql.sqltypes.AutoString(length=255),
            nullable=False,
        ),
        sa.Column(
            "description",
            sqlmodel.sql.sqltypes.AutoString(length=255),
            nullable=True,
        ),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_id"],
            ["user.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

"""nvarchar cho tiếng Việt, Language.is_default, updated_at, Artifact unique theo site

Revision ID: c3a91f5e7d20
Revises: 2af237ad3b09
Create Date: 2026-10-21 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel.sql.sqltypes


# revision identifiers, used by Alembic.
revision = 'c3a91f5e7d20'
down_revision = '2af237ad3b09'
branch_labels = None
depends_on = None


# (bảng, cột, độ dài, cho phép NULL) - các cột có thể chứa tiếng Việt có dấu
NVARCHAR_COLUMNS = [
    ('user', 'full_name', 255, True),
    ('role', 'description', 255, True),
    ('language', 'name', 100, False),
    ('site', 'name', 255, False),
    ('site', 'description', 2000, True),
    ('site', 'address', 500, True),
    ('artifact', 'era', 100, True),
    ('artifacttranslation', 'title', 255, False),
    ('artifacttranslation', 'description', 2000, True),
    ('media', 'caption', 255, True),
    ('feedback', 'comment', 2000, True),
]


def upgrade():
    # 1. VARCHAR -> NVARCHAR (nếu để VARCHAR, tiếng Việt có dấu bị mất dấu)
    for table, column, length, nullable in NVARCHAR_COLUMNS:
        op.alter_column(
            table, column,
            existing_type=sa.String(length=length),
            type_=sa.Unicode(length=length),
            existing_nullable=nullable,
        )
    op.alter_column(
        'artifacttranslation', 'history_content',
        existing_type=sa.String(),
        type_=sa.Unicode(),  # NVARCHAR(max)
        existing_nullable=True,
    )

    # 2. Language.is_default (chỉ 1 ngôn ngữ mặc định: filtered unique index)
    op.add_column(
        'language',
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index(
        'uq_language_default', 'language', ['is_default'],
        unique=True, mssql_where=sa.text('is_default = 1'),
    )
    op.execute("UPDATE language SET is_default = 1 WHERE code = 'vi'")

    # 3. updated_at
    op.add_column('artifact', sa.Column('updated_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True))
    op.add_column('artifacttranslation', sa.Column('updated_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True))

    # 4. Artifact.code: unique theo (site_id, code) thay vì unique toàn bảng
    op.drop_index('ix_artifact_code', table_name='artifact')
    op.create_index('ix_artifact_code', 'artifact', ['code'], unique=False)
    op.create_unique_constraint('uq_artifact_site_code', 'artifact', ['site_id', 'code'])


def downgrade():
    op.drop_constraint('uq_artifact_site_code', 'artifact', type_='unique')
    op.drop_index('ix_artifact_code', table_name='artifact')
    op.create_index('ix_artifact_code', 'artifact', ['code'], unique=True)

    op.drop_column('artifacttranslation', 'updated_at')
    op.drop_column('artifact', 'updated_at')

    op.drop_index('uq_language_default', table_name='language')
    op.drop_column('language', 'is_default', mssql_drop_default=True)

    op.alter_column(
        'artifacttranslation', 'history_content',
        existing_type=sa.Unicode(),
        type_=sa.String(),
        existing_nullable=True,
    )
    for table, column, length, nullable in reversed(NVARCHAR_COLUMNS):
        op.alter_column(
            table, column,
            existing_type=sa.Unicode(length=length),
            type_=sa.String(length=length),
            existing_nullable=nullable,
        )

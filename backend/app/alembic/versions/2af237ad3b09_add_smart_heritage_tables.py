"""Add Smart Heritage tables

Revision ID: 2af237ad3b09
Revises: 475b2d4c150f
Create Date: 2026-10-17 04:23:34.736950

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel.sql.sqltypes


# revision identifiers, used by Alembic.
revision = '2af237ad3b09'
down_revision = '475b2d4c150f'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('language',
    sa.Column('code', sqlmodel.sql.sqltypes.AutoString(length=10), nullable=False),
    sa.Column('name', sqlmodel.sql.sqltypes.AutoString(length=100), nullable=False),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_language_code'), 'language', ['code'], unique=True)
    op.create_table('role',
    sa.Column('name', sqlmodel.sql.sqltypes.AutoString(length=50), nullable=False),
    sa.Column('description', sqlmodel.sql.sqltypes.AutoString(length=255), nullable=True),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_role_name'), 'role', ['name'], unique=True)
    op.create_table('site',
    sa.Column('name', sqlmodel.sql.sqltypes.AutoString(length=255), nullable=False),
    sa.Column('description', sqlmodel.sql.sqltypes.AutoString(length=2000), nullable=True),
    sa.Column('address', sqlmodel.sql.sqltypes.AutoString(length=500), nullable=True),
    sa.Column('latitude', sa.Float(), nullable=True),
    sa.Column('longitude', sa.Float(), nullable=True),
    sa.Column('cover_image_url', sqlmodel.sql.sqltypes.AutoString(length=500), nullable=True),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('artifact',
    sa.Column('code', sqlmodel.sql.sqltypes.AutoString(length=50), nullable=False),
    sa.Column('era', sqlmodel.sql.sqltypes.AutoString(length=100), nullable=True),
    sa.Column('latitude', sa.Float(), nullable=True),
    sa.Column('longitude', sa.Float(), nullable=True),
    sa.Column('cover_image_url', sqlmodel.sql.sqltypes.AutoString(length=500), nullable=True),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('site_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['site_id'], ['site.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_artifact_code'), 'artifact', ['code'], unique=True)
    op.create_table('artifacttranslation',
    sa.Column('title', sqlmodel.sql.sqltypes.AutoString(length=255), nullable=False),
    sa.Column('description', sqlmodel.sql.sqltypes.AutoString(length=2000), nullable=True),
    sa.Column('history_content', sqlmodel.sql.sqltypes.AutoString(), nullable=True),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=False),
    sa.Column('language_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['language_id'], ['language.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('artifact_id', 'language_id', name='uq_artifact_language')
    )
    op.create_table('beacon',
    sa.Column('proximity_uuid', sqlmodel.sql.sqltypes.AutoString(length=36), nullable=False),
    sa.Column('major', sa.Integer(), nullable=False),
    sa.Column('minor', sa.Integer(), nullable=False),
    sa.Column('tx_power', sa.Integer(), nullable=True),
    sa.Column('rssi_threshold', sa.Integer(), nullable=True),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('site_id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=True),
    sa.Column('battery_level', sa.Integer(), nullable=True),
    sa.Column('last_seen_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='NO ACTION'),
    sa.ForeignKeyConstraint(['site_id'], ['site.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('proximity_uuid', 'major', 'minor', name='uq_beacon_identity')
    )
    op.create_index(op.f('ix_beacon_proximity_uuid'), 'beacon', ['proximity_uuid'], unique=False)
    op.create_index('uq_beacon_artifact_id', 'beacon', ['artifact_id'], unique=True, mssql_where=sa.text('artifact_id IS NOT NULL'), postgresql_where=sa.text('artifact_id IS NOT NULL'))
    op.create_table('favorite',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'artifact_id', name='uq_favorite_user_artifact')
    )
    op.create_table('feedback',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=False),
    sa.Column('rating', sa.Integer(), nullable=False),
    sa.Column('comment', sqlmodel.sql.sqltypes.AutoString(length=2000), nullable=True),
    sa.Column('status', sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('media',
    sa.Column('media_type', sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False),
    sa.Column('url', sqlmodel.sql.sqltypes.AutoString(length=500), nullable=False),
    sa.Column('caption', sqlmodel.sql.sqltypes.AutoString(length=255), nullable=True),
    sa.Column('sort_order', sa.Integer(), nullable=False),
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=False),
    sa.Column('language_id', sa.Uuid(), nullable=True),
    sa.Column('created_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['language_id'], ['language.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_table('visitlog',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('artifact_id', sa.Uuid(), nullable=False),
    sa.Column('beacon_id', sa.Uuid(), nullable=True),
    sa.Column('language_id', sa.Uuid(), nullable=True),
    sa.Column('visited_at', sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
    sa.Column('duration_seconds', sa.Integer(), nullable=True),
    sa.Column('rssi', sa.Integer(), nullable=True),
    sa.ForeignKeyConstraint(['artifact_id'], ['artifact.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['beacon_id'], ['beacon.id'], ondelete='NO ACTION'),
    sa.ForeignKeyConstraint(['language_id'], ['language.id'], ondelete='NO ACTION'),
    sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_visitlog_artifact_id'), 'visitlog', ['artifact_id'], unique=False)
    op.create_index(op.f('ix_visitlog_visited_at'), 'visitlog', ['visited_at'], unique=False)

    # Bảng user: chỉ THÊM 2 cột mới (nullable), không đổi cột cũ
    op.add_column('user', sa.Column('role_id', sa.Uuid(), nullable=True))
    op.add_column('user', sa.Column('language_id', sa.Uuid(), nullable=True))
    op.create_foreign_key('fk_user_language_id', 'user', 'language', ['language_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_user_role_id', 'user', 'role', ['role_id'], ['id'], ondelete='SET NULL')


def downgrade():
    op.drop_constraint('fk_user_role_id', 'user', type_='foreignkey')
    op.drop_constraint('fk_user_language_id', 'user', type_='foreignkey')
    op.drop_column('user', 'language_id')
    op.drop_column('user', 'role_id')
    op.drop_index(op.f('ix_visitlog_visited_at'), table_name='visitlog')
    op.drop_index(op.f('ix_visitlog_artifact_id'), table_name='visitlog')
    op.drop_table('visitlog')
    op.drop_table('media')
    op.drop_table('feedback')
    op.drop_table('favorite')
    op.drop_index('uq_beacon_artifact_id', table_name='beacon')
    op.drop_index(op.f('ix_beacon_proximity_uuid'), table_name='beacon')
    op.drop_table('beacon')
    op.drop_table('artifacttranslation')
    op.drop_index(op.f('ix_artifact_code'), table_name='artifact')
    op.drop_table('artifact')
    op.drop_table('site')
    op.drop_index(op.f('ix_role_name'), table_name='role')
    op.drop_table('role')
    op.drop_index(op.f('ix_language_code'), table_name='language')
    op.drop_table('language')
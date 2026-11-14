"""Feedback theo ERD: status pending/approved/hidden, rating 1-5, unique user+artifact, updated_at.

Revision ID: e5f6a7b8c9d0
Revises: a1b2c3d4e5f6
Create Date: 2026-11-05 00:00:00.000000

"""

import logging

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = "e5f6a7b8c9d0"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None

logger = logging.getLogger("alembic.runtime.migration")

# Preserve the existing newest-created_at/id tie-break rule.
DUPLICATE_ROW = """
EXISTS (
    SELECT 1 FROM dbo.feedback AS newer
    WHERE newer.user_id = feedback.user_id
      AND newer.artifact_id = feedback.artifact_id
      AND newer.id <> feedback.id
      AND (
            COALESCE(newer.created_at, '1900-01-01')
                > COALESCE(feedback.created_at, '1900-01-01')
         OR (
            COALESCE(newer.created_at, '1900-01-01')
                = COALESCE(feedback.created_at, '1900-01-01')
            AND newer.id > feedback.id
         )
      )
)
"""


def upgrade() -> None:
    # A deployed version of b2c3 created checks allowing "rejected", not "hidden".
    # Also accept constraints/indexes left by an interrupted execution of this revision.
    for name in ("ck_feedback_rating", "ck_feedback_status"):
        op.execute(
            f"""
            IF EXISTS (
                SELECT 1 FROM sys.check_constraints
                WHERE parent_object_id = OBJECT_ID(N'dbo.feedback')
                  AND name = N'{name}'
            )
                ALTER TABLE dbo.feedback DROP CONSTRAINT [{name}]
            """
        )
    op.execute(
        """
        IF EXISTS (
            SELECT 1 FROM sys.objects
            WHERE parent_object_id = OBJECT_ID(N'dbo.feedback')
              AND name = N'uq_feedback_user_artifact' AND type = 'UQ'
        )
            ALTER TABLE dbo.feedback DROP CONSTRAINT uq_feedback_user_artifact
        ELSE IF EXISTS (
            SELECT 1 FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.feedback')
              AND name = N'uq_feedback_user_artifact'
        )
            DROP INDEX uq_feedback_user_artifact ON dbo.feedback
        """
    )
    op.execute(
        """
        IF COL_LENGTH(N'dbo.feedback', N'updated_at') IS NULL
            ALTER TABLE dbo.feedback ADD updated_at DATETIMEOFFSET NULL
        """
    )
    # No source constraints/FKs are copied. Keep originals, including invalid values,
    # before normalization or deletion; a retry must not overwrite the first backup.
    op.execute(
        """
        IF OBJECT_ID(N'dbo.feedback_migration_backup', N'U') IS NULL
            SELECT TOP (0)
                id, user_id, artifact_id, rating, comment, status, created_at, updated_at
            INTO dbo.feedback_migration_backup FROM dbo.feedback
        """
    )
    connection = op.get_bind()
    backed_up = connection.execute(
        sa.text(
            f"""
            INSERT INTO dbo.feedback_migration_backup
                (id, user_id, artifact_id, rating, comment, status, created_at, updated_at)
            SELECT id, user_id, artifact_id, rating, comment, status, created_at, updated_at
            FROM dbo.feedback AS feedback
            WHERE (rating NOT BETWEEN 1 AND 5
                OR status NOT IN ('pending', 'approved', 'hidden')
                OR {DUPLICATE_ROW})
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.feedback_migration_backup AS archived
                  WHERE archived.id = feedback.id
              )
            """
        )
    ).rowcount
    changed = connection.execute(
        sa.text(
            """
            UPDATE dbo.feedback
            SET status = CASE
                    WHEN status = 'rejected' THEN 'hidden'
                    WHEN status NOT IN ('pending', 'approved', 'hidden') THEN 'pending'
                    ELSE status END,
                rating = CASE WHEN rating < 1 THEN 1 WHEN rating > 5 THEN 5 ELSE rating END
            WHERE rating NOT BETWEEN 1 AND 5
               OR status NOT IN ('pending', 'approved', 'hidden')
            """
        )
    ).rowcount
    deleted = connection.execute(
        sa.text(f"DELETE feedback FROM dbo.feedback AS feedback WHERE {DUPLICATE_ROW}")
    ).rowcount
    logger.info(
        "Feedback migration: backed up %d rows, changed %d rows, deleted %d duplicate rows",
        backed_up,
        changed,
        deleted,
    )
    op.create_check_constraint(
        "ck_feedback_rating", "feedback", "rating BETWEEN 1 AND 5"
    )
    op.create_check_constraint(
        "ck_feedback_status",
        "feedback",
        "status IN ('pending', 'approved', 'hidden')",
    )
    op.create_unique_constraint(
        "uq_feedback_user_artifact", "feedback", ["user_id", "artifact_id"]
    )


def downgrade() -> None:
    # Deliberately retain feedback_migration_backup for manual recovery.
    op.drop_constraint("uq_feedback_user_artifact", "feedback", type_="unique")
    op.drop_constraint("ck_feedback_status", "feedback", type_="check")
    op.drop_constraint("ck_feedback_rating", "feedback", type_="check")
    op.drop_column("feedback", "updated_at")
    # trạng thái cũ của code trước migration này
    op.execute("UPDATE feedback SET status = 'rejected' WHERE status = 'hidden'")

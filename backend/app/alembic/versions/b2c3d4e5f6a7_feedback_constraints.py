"""Validate feedback rating/status without modifying existing rows.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
"""

from alembic import op

revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # WITH CHECK is SQL Server's default: invalid legacy rows stop migration;
    # no rows are silently repaired or removed.
    op.create_check_constraint("ck_feedback_rating", "feedback", "rating BETWEEN 1 AND 5")
    op.create_check_constraint(
        "ck_feedback_status", "feedback", "status IN ('pending', 'approved', 'rejected')"
    )


def downgrade() -> None:
    op.drop_constraint("ck_feedback_status", "feedback", type_="check")
    op.drop_constraint("ck_feedback_rating", "feedback", type_="check")

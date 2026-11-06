"""Merge the feedback and site-translation migration branches.

Revision ID: c8d9e0f1a2b3
Revises: b734c0d91e2a, e5f6a7b8c9d0
Create Date: 2026-11-06

This is a merge-only revision. The schema changes remain in their original
branch revisions; this file only joins the two Alembic histories so that the
repository has one head.
"""

# revision identifiers, used by Alembic.
revision = "c8d9e0f1a2b3"
down_revision = ("b734c0d91e2a", "e5f6a7b8c9d0")
branch_labels = None
depends_on = None


def upgrade() -> None:
    """No schema changes: both parent revisions contain their own changes."""
    pass


def downgrade() -> None:
    """No schema changes to reverse in a merge-only revision."""
    pass

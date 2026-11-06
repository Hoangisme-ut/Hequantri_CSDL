"""Merge the legacy feedback branch with the ERD feedback branch.

Revision ID: f7a8b9c0d1e2
Revises: ab0ca64f8ea9, c8d9e0f1a2b3
Create Date: 2026-11-06

Merge-only revision: both parent histories already contain their schema
changes. Joining them keeps the repository on a single Alembic head after
merging ``origin/main`` into ``fix/backend-improvements``.
"""

# revision identifiers, used by Alembic.
revision = "f7a8b9c0d1e2"
down_revision = ("ab0ca64f8ea9", "c8d9e0f1a2b3")
branch_labels = None
depends_on = None


def upgrade() -> None:
    """No schema changes: both parent revisions contain their own changes."""
    pass


def downgrade() -> None:
    """No schema changes to reverse in a merge-only revision."""
    pass

"""Validate feedback rating/status without modifying existing rows.

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6

.. note::
   Ràng buộc ``ck_feedback_rating`` / ``ck_feedback_status`` giờ do revision
   ERD ``e5f6a7b8c9d0`` tạo (status ``pending/approved/hidden`` + unique
   ``(user_id, artifact_id)`` + ``updated_at``). Revision này được giữ lại để
   các database đã từng chạy nó vẫn có revision id hợp lệ, nhưng không còn
   tạo ràng buộc trùng tên nữa.
"""

revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # No-op: e5f6a7b8c9d0 owns the ERD feedback constraints.
    pass


def downgrade() -> None:
    # No-op: e5f6a7b8c9d0 owns the ERD feedback constraints.
    pass

"""Feedback theo ERD: status pending/approved/hidden, rating 1-5, unique user+artifact, updated_at.

Revision ID: e5f6a7b8c9d0
Revises: a1b2c3d4e5f6
Create Date: 2026-11-05 00:00:00.000000

"""

import sqlalchemy as sa
import sqlmodel.sql.sqltypes
from alembic import op

# revision identifiers, used by Alembic.
revision = "e5f6a7b8c9d0"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Đưa dữ liệu cũ về đúng ERD trước khi thêm ràng buộc
    #    (trạng thái cũ "rejected" -> "hidden"; giá trị lạ -> "pending"; rating kẹp về 1..5)
    op.execute("UPDATE feedback SET status = 'hidden' WHERE status = 'rejected'")
    op.execute(
        "UPDATE feedback SET status = 'pending' "
        "WHERE status NOT IN ('pending', 'approved', 'hidden')"
    )
    op.execute("UPDATE feedback SET rating = 1 WHERE rating < 1")
    op.execute("UPDATE feedback SET rating = 5 WHERE rating > 5")

    # 2. Mỗi (user, artifact) chỉ giữ 1 đánh giá: nếu có trùng thì giữ bản MỚI NHẤT.
    #    (API Feedback chưa tồn tại trước migration này nên bình thường không có dòng trùng.)
    op.execute(
        """
        DELETE FROM feedback
        WHERE EXISTS (
            SELECT 1 FROM feedback AS newer
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
    )

    # 3. Cột + ràng buộc theo ERD
    op.add_column(
        "feedback",
        sa.Column("updated_at", sqlmodel.sql.sqltypes.UTCDateTime(), nullable=True),
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
    op.drop_constraint("uq_feedback_user_artifact", "feedback", type_="unique")
    op.drop_constraint("ck_feedback_status", "feedback", type_="check")
    op.drop_constraint("ck_feedback_rating", "feedback", type_="check")
    op.drop_column("feedback", "updated_at")
    # trạng thái cũ của code trước migration này
    op.execute("UPDATE feedback SET status = 'rejected' WHERE status = 'hidden'")

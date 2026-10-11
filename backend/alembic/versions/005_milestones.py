"""registration status, milestone completion, reminder to milestone link

Revision ID: 005
Revises: 004
Create Date: 2026-10-11
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("registration_status", sa.String(20), nullable=False, server_default="not_started"))
    op.add_column("event_deadlines", sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("reminders", sa.Column("milestone_id", sa.String(36), nullable=True))
    op.create_index("ix_reminders_milestone_id", "reminders", ["milestone_id"])


def downgrade() -> None:
    op.drop_index("ix_reminders_milestone_id", table_name="reminders")
    op.drop_column("reminders", "milestone_id")
    op.drop_column("event_deadlines", "completed_at")
    op.drop_column("events", "registration_status")

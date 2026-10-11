"""per-user timezone and quiet hours

Revision ID: 006
Revises: 005
Create Date: 2026-10-11
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("timezone", sa.String(100), nullable=False, server_default="UTC"))
    op.add_column("users", sa.Column("quiet_hours_enabled", sa.Boolean(), nullable=False, server_default=sa.true()))
    op.add_column("users", sa.Column("quiet_hours_start", sa.SmallInteger(), nullable=True))
    op.add_column("users", sa.Column("quiet_hours_end", sa.SmallInteger(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "quiet_hours_end")
    op.drop_column("users", "quiet_hours_start")
    op.drop_column("users", "quiet_hours_enabled")
    op.drop_column("users", "timezone")

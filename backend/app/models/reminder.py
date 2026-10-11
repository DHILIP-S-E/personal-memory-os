import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Reminder(Base):
    __tablename__ = "reminders"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    reminder_type: Mapped[str] = mapped_column(String(50), nullable=False, default="time")
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    timezone: Mapped[str] = mapped_column(String(100), default="UTC")
    priority: Mapped[str] = mapped_column(String(20), default="medium")
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    alarm_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    notification_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    recurrence_rule: Mapped[str | None] = mapped_column(String(500))
    source: Mapped[str] = mapped_column(String(50), default="manual")
    context_id: Mapped[str | None] = mapped_column(String(36))
    milestone_id: Mapped[str | None] = mapped_column(String(36), index=True)  # the event deadline it belongs to
    # Conditional reminder: only fires if this other reminder is not completed yet.
    depends_on_id: Mapped[str | None] = mapped_column(String(36))
    offsets: Mapped[str | None] = mapped_column(Text)  # JSON array of offset strings e.g. ["-3d","-1h"]
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow
    )

    def to_dict(self) -> dict:
        import json
        return {
            "id": self.id,
            "user_id": self.user_id,
            "title": self.title,
            "description": self.description,
            "reminder_type": self.reminder_type,
            "scheduled_at": self.scheduled_at.isoformat() if self.scheduled_at else None,
            "timezone": self.timezone,
            "priority": self.priority,
            "status": self.status,
            "alarm_enabled": self.alarm_enabled,
            "notification_enabled": self.notification_enabled,
            "recurrence_rule": self.recurrence_rule,
            "source": self.source,
            "context_id": self.context_id,
            "milestone_id": self.milestone_id,
            "depends_on_id": self.depends_on_id,
            "offsets": json.loads(self.offsets) if self.offsets else [],
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

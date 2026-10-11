import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Event(Base):
    __tablename__ = "events"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    event_type: Mapped[str] = mapped_column(String(50), default="custom")
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    timezone: Mapped[str] = mapped_column(String(100), default="UTC")
    location: Mapped[str | None] = mapped_column(String(500))
    is_virtual: Mapped[bool] = mapped_column(Boolean, default=False)
    event_url: Mapped[str | None] = mapped_column(String(1000))
    organizer: Mapped[str | None] = mapped_column(String(500))
    registration_url: Mapped[str | None] = mapped_column(String(1000))
    status: Mapped[str] = mapped_column(String(20), default="upcoming", index=True)
    registration_status: Mapped[str] = mapped_column(String(20), default="not_started")
    summary_id: Mapped[str | None] = mapped_column(String(36))
    photo_count: Mapped[int] = mapped_column(default=0)
    voice_note_count: Mapped[int] = mapped_column(default=0)
    document_count: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow
    )

    deadlines: Mapped[list["EventDeadline"]] = relationship(
        "EventDeadline", back_populates="event", cascade="all, delete-orphan"
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "title": self.title,
            "description": self.description,
            "event_type": self.event_type,
            "start_at": self.start_at.isoformat(),
            "end_at": self.end_at.isoformat() if self.end_at else None,
            "timezone": self.timezone,
            "location": self.location,
            "is_virtual": self.is_virtual,
            "event_url": self.event_url,
            "organizer": self.organizer,
            "registration_url": self.registration_url,
            "registration_status": self.registration_status,
            "status": self.status,
            "summary_id": self.summary_id,
            "photo_count": self.photo_count,
            "voice_note_count": self.voice_note_count,
            "document_count": self.document_count,
            "deadlines": [d.to_dict() for d in self.deadlines],
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }


class EventDeadline(Base):
    __tablename__ = "event_deadlines"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    event_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[str] = mapped_column(String(255), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    deadline_type: Mapped[str] = mapped_column(String(50), default="custom")
    deadline_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="active")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow
    )

    event: Mapped["Event"] = relationship("Event", back_populates="deadlines")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "event_id": self.event_id,
            "user_id": self.user_id,
            "title": self.title,
            "deadline_type": self.deadline_type,
            "deadline_at": self.deadline_at.isoformat(),
            "status": self.status,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "created_at": self.created_at.isoformat(),
        }

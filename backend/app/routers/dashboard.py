"""Dashboard views (spec 4.8): what needs attention today, and what is coming up.

Everything is scoped to the signed-in user. "Today" is the user's own local day."""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user_id
from app.database import get_db
from app.models.capture import Capture
from app.models.event import Event, EventDeadline
from app.models.reminder import Reminder
from app.services import milestones
from app.services.agenda import as_utc, day_bounds
from app.validation import real_timezone

router = APIRouter()
PENDING_REGISTRATION = {"not_started", "planned", "in_progress"}
LIST_CAP = 100


def _tz(timezone_name: str) -> str:
    try:
        return real_timezone(timezone_name)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))


def _brief(reminder: Reminder) -> dict:
    return {
        "id": reminder.id, "title": reminder.title, "scheduled_at": reminder.scheduled_at.isoformat(),
        "priority": reminder.priority, "milestone_id": reminder.milestone_id, "context_id": reminder.context_id,
    }


async def _active_reminders(db: AsyncSession, user_id: str):
    return (await db.execute(
        select(Reminder).where(
            Reminder.user_id == user_id, Reminder.status == "active", Reminder.scheduled_at.is_not(None)
        ).order_by(Reminder.scheduled_at)
    )).scalars().all()


@router.get("/today")
async def dashboard_today(
    timezone_name: str = Query("UTC", alias="timezone"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Overdue (before today), due today, registrations still open, and the latest captures."""
    tz = _tz(timezone_name)
    now = datetime.now(timezone.utc)
    start, end = day_bounds(now, tz)

    reminders = [r for r in await _active_reminders(db, user_id)]
    overdue = [_brief(r) for r in reminders if as_utc(r.scheduled_at) < start]
    today = [_brief(r) for r in reminders if start <= as_utc(r.scheduled_at) < end]

    events = (await db.execute(
        select(Event).options(selectinload(Event.deadlines))
        .where(Event.user_id == user_id, Event.registration_status.in_(PENDING_REGISTRATION))
    )).scalars().all()
    pending = []
    for event in events:
        open_ids = milestones.registration_milestone_ids([d.to_dict() for d in event.deadlines])
        due = sorted(as_utc(d.deadline_at) for d in event.deadlines if d.id in open_ids)
        if due:
            pending.append({
                "event_id": event.id, "title": event.title, "registration_status": event.registration_status,
                "registration_url": event.registration_url, "deadline_at": due[0].isoformat(),
            })
    pending.sort(key=lambda p: p["deadline_at"])

    captures = (await db.execute(
        select(Capture).where(Capture.user_id == user_id).order_by(Capture.created_at.desc()).limit(5)
    )).scalars().all()
    recent = [
        {"id": c.id, "capture_type": c.capture_type, "processing_status": c.processing_status,
         "created_at": c.created_at.isoformat()}
        for c in captures
    ]
    return {
        "timezone": tz,
        "day_start": start.isoformat(), "day_end": end.isoformat(),
        "overdue": overdue[-LIST_CAP:], "today": today[:LIST_CAP],
        "pending_registrations": pending[:LIST_CAP], "recent_captures": recent,
        "counts": {"overdue": len(overdue), "today": len(today), "pending_registrations": len(pending)},
    }


@router.get("/upcoming")
async def dashboard_upcoming(
    days: int = Query(14, ge=1, le=90),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Deadlines and reminders coming up in the next `days` days, soonest first."""
    now = datetime.now(timezone.utc)
    horizon = now + timedelta(days=days)

    deadlines = (await db.execute(
        select(EventDeadline, Event.title)
        .join(Event, Event.id == EventDeadline.event_id)
        .where(EventDeadline.user_id == user_id, EventDeadline.status == milestones.ACTIVE)
        .order_by(EventDeadline.deadline_at)
    )).all()
    milestones_out = [
        {**d.to_dict(), "event_title": title}
        for d, title in deadlines if now <= as_utc(d.deadline_at) <= horizon
    ]
    reminders = [
        _brief(r) for r in await _active_reminders(db, user_id) if now <= as_utc(r.scheduled_at) <= horizon
    ]
    return {"days": days, "milestones": milestones_out[:LIST_CAP], "reminders": reminders[:LIST_CAP]}

"""
Reminder API router — full CRUD, user-scoped.
All routes require a valid Cognito JWT.
"""

import json
import logging
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_id
from app.database import get_db
from app.models.reminder import Reminder
from app.services import scheduling
from app.services import scheduling

router = APIRouter()
logger = logging.getLogger(__name__)
logger = logging.getLogger(__name__)

PRIORITIES = {"high", "medium", "low"}
STATUSES = {"active", "snoozed", "completed", "missed", "cancelled", "overdue"}
MAX_TITLE = 500


def _clean_title(v: str) -> str:
    v = v.strip()
    if not v:
        raise ValueError("Title cannot be empty")
    if len(v) > MAX_TITLE:
        raise ValueError(f"Title is too long (max {MAX_TITLE} characters)")
    return v


def _one_of(allowed: set[str], label: str):
    def check(v: str) -> str:
        if v not in allowed:
            raise ValueError(f"{label} must be one of: {', '.join(sorted(allowed))}")
        return v
    return check


def _real_timezone(v: str) -> str:
    try:
        ZoneInfo(v)
    except (ZoneInfoNotFoundError, ValueError, KeyError):
        raise ValueError("Unknown timezone; use a name like Asia/Kolkata")
    return v


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class ReminderCreate(BaseModel):
    title: str
    description: Optional[str] = None
    reminder_type: str = "time"
    scheduled_at: Optional[datetime] = None
    timezone: str = "UTC"
    priority: str = "medium"
    alarm_enabled: bool = True
    notification_enabled: bool = True
    recurrence_rule: Optional[str] = None
    source: str = "manual"
    context_id: Optional[str] = None
    offsets: Optional[list[str]] = []
    depends_on_id: Optional[str] = None  # conditional: fire only if this one is not done

    @field_validator("title")
    @classmethod
    def _title(cls, v):
        return _clean_title(v)

    @field_validator("priority")
    @classmethod
    def _priority(cls, v):
        return _one_of(PRIORITIES, "Priority")(v)

    @field_validator("timezone")
    @classmethod
    def _timezone(cls, v):
        return _real_timezone(v)


class ReminderUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    priority: Optional[str] = None
    alarm_enabled: Optional[bool] = None

    @field_validator("title")
    @classmethod
    def _title(cls, v):
        return None if v is None else _clean_title(v)

    @field_validator("status")
    @classmethod
    def _status(cls, v):
        return None if v is None else _one_of(STATUSES, "Status")(v)

    @field_validator("priority")
    @classmethod
    def _priority(cls, v):
        return None if v is None else _one_of(PRIORITIES, "Priority")(v)


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_reminder(
    body: ReminderCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if body.depends_on_id:
        await _get_owned(body.depends_on_id, user_id, db)  # 404 if not yours
    now = datetime.utcnow()
    reminder = Reminder(
        id=str(uuid.uuid4()),
        user_id=user_id,
        title=body.title,
        description=body.description,
        reminder_type=body.reminder_type,
        scheduled_at=body.scheduled_at,
        timezone=body.timezone,
        priority=body.priority,
        alarm_enabled=body.alarm_enabled,
        notification_enabled=body.notification_enabled,
        recurrence_rule=body.recurrence_rule,
        source=body.source,
        context_id=body.context_id,
        depends_on_id=body.depends_on_id,
        offsets=json.dumps(body.offsets or []),
        created_at=now,
        updated_at=now,
    )
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    _schedule_cloud_layer(reminder)
    return reminder.to_dict()


@router.get("")
async def list_reminders(
    reminder_status: Optional[str] = None,
    reminder_type: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    query = select(Reminder).where(Reminder.user_id == user_id)
    if reminder_status:
        query = query.where(Reminder.status == reminder_status)
    if reminder_type:
        query = query.where(Reminder.reminder_type == reminder_type)
    query = query.order_by(Reminder.scheduled_at.asc().nulls_last())
    result = await db.execute(query)
    return [r.to_dict() for r in result.scalars().all()]


@router.get("/{reminder_id}")
async def get_reminder(
    reminder_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    return reminder.to_dict()


@router.patch("/{reminder_id}")
async def update_reminder(
    reminder_id: str,
    body: ReminderUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    _cancel_cloud_layer(reminder)  # before edits: cancels the OLD fire times
    if body.title is not None:
        reminder.title = body.title
    if body.description is not None:
        reminder.description = body.description
    if body.status is not None:
        reminder.status = body.status
    if body.scheduled_at is not None:
        reminder.scheduled_at = body.scheduled_at
    if body.priority is not None:
        reminder.priority = body.priority
    if body.alarm_enabled is not None:
        reminder.alarm_enabled = body.alarm_enabled
    reminder.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(reminder)
    _schedule_cloud_layer(reminder)
    return reminder.to_dict()


@router.delete("/{reminder_id}", status_code=status.HTTP_200_OK)
async def delete_reminder(
    reminder_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    _cancel_cloud_layer(reminder)
    await db.delete(reminder)
    await db.commit()
    return {"deleted": reminder_id}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _schedule_cloud_layer(reminder: Reminder) -> None:
    """Cloud layer of the two-layer alarm (R1.5). Best-effort: the device layer
    still fires if this fails, and the failure is logged, never silent."""
    if not reminder.scheduled_at or reminder.status != "active":
        return
    try:
        scheduling.schedule_reminder(
            reminder.id, reminder.user_id, reminder.title, reminder.priority,
            reminder.scheduled_at, json.loads(reminder.offsets or "[]"),
            reminder.depends_on_id, reminder.recurrence_rule, reminder.timezone,
        )
    except Exception:
        logger.exception("Cloud scheduling failed for reminder %s", reminder.id)


def _cancel_cloud_layer(reminder: Reminder) -> None:
    try:
        scheduling.cancel_reminder(
            reminder.id, reminder.scheduled_at, json.loads(reminder.offsets or "[]")
        )
    except Exception:
        logger.exception("Cloud schedule cancel failed for reminder %s", reminder.id)


async def _get_owned(reminder_id: str, user_id: str, db: AsyncSession) -> Reminder:
    result = await db.execute(
        select(Reminder).where(
            Reminder.id == reminder_id, Reminder.user_id == user_id
        )
    )
    reminder = result.scalar_one_or_none()
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")
    return reminder

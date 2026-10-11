"""Notification history: every delivery attempt for the signed-in user (spec 4.6).

A "sent" row means the provider accepted the message. It is not proof the notification
was displayed or read, so the status is reported as recorded and nothing more."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_id
from app.database import get_db
from app.models.delivery import NotificationDelivery
from app.models.reminder import Reminder

router = APIRouter()


@router.get("/history")
async def notification_history(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Newest first, with the reminder's title so the list is readable."""
    rows = (await db.execute(
        select(NotificationDelivery, Reminder.title)
        .outerjoin(Reminder, Reminder.id == NotificationDelivery.reminder_id)
        .where(NotificationDelivery.user_id == user_id)
        .order_by(NotificationDelivery.created_at.desc())
        .limit(limit).offset(offset)
    )).all()
    return {
        "items": [{**d.to_dict(), "reminder_title": title} for d, title in rows],
        "limit": limit,
        "offset": offset,
    }

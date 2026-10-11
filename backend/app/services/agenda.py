"""Where "today" starts and ends for a user. Pure: no I/O.

A day is measured in the user's own timezone and is not always 24 hours long (it is 23 or 25
hours when clocks change), so the bounds come from local midnight, never from "now + 24h"."""

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

UTC = timezone.utc


def day_bounds(now: datetime, tz_name: str) -> tuple[datetime, datetime]:
    """[start, end) of the local day containing `now`, as UTC instants."""
    tz = ZoneInfo(tz_name)
    local = now.astimezone(tz)
    start = datetime.combine(local.date(), time.min, tzinfo=tz)
    end = datetime.combine(local.date() + timedelta(days=1), time.min, tzinfo=tz)
    return start.astimezone(UTC), end.astimezone(UTC)


def as_utc(value: datetime) -> datetime:
    """Databases may hand back naive datetimes; they are stored as UTC."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)

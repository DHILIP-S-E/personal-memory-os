"""Smart reminder policy per event type (spec R2.4). Pure — no I/O."""

from datetime import datetime, timedelta

# Minutes before event start at which to remind, by event type.
_EVENT_OFFSETS = {
    "hackathon": [1440, 60, 30],
    "conference": [1440, 120, 30],
    "workshop": [1440, 60, 15],
    "webinar": [60, 10],
    "meetup": [180, 30],
    "meeting": [30, 10],
    "appointment": [1440, 60],
    "deadline": [4320, 1440, 180],
}
_DEFAULT_OFFSETS = [1440, 30]
_DEADLINE_OFFSETS = [4320, 1440, 180]  # -3d, -1d, -3h


def _label(minutes: int) -> str:
    if minutes % 1440 == 0:
        return f"{minutes // 1440}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"


def build_reminder_policy(
    title: str,
    event_type: str,
    start_at: datetime,
    deadlines: list[tuple],
    now: datetime,
) -> list[dict]:
    """Reminder specs for an event: event-day reminders plus registration /
    submission deadline reminders. Only future instants, sorted by time.

    A deadline is (title, at) or (title, at, milestone_id). The id tags each of its reminders
    so finishing that milestone stops exactly those and no others."""
    out: list[dict] = []
    for minutes in _EVENT_OFFSETS.get(event_type, _DEFAULT_OFFSETS):
        at = start_at - timedelta(minutes=minutes)
        if at > now:
            out.append({
                "title": f"{title} starts in {_label(minutes)}",
                "reminder_type": "time",
                "scheduled_at": at,
                "priority": "medium",
            })
    for dl_title, dl_at, *rest in deadlines:
        milestone_id = rest[0] if rest else None
        for minutes in _DEADLINE_OFFSETS:
            at = dl_at - timedelta(minutes=minutes)
            if at > now:
                out.append({
                    "title": f"{dl_title} due in {_label(minutes)} — {title}",
                    "reminder_type": "deadline",
                    "scheduled_at": at,
                    "priority": "high",
                    "milestone_id": milestone_id,
                })
    return sorted(out, key=lambda r: r["scheduled_at"])

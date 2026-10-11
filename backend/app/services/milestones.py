"""Registration status and milestone rules (spec 4.3 and 4.4). Pure: no I/O.

An event has independent milestones (registration, submission, payment...). Finishing
one stops only the reminders that belong to it, never the others: registering for a
hackathon ends the registration reminders while the submission reminders keep going."""

from typing import Iterable

REGISTRATION_STATES = {
    "not_started", "planned", "in_progress", "registered",
    "waitlisted", "failed", "not_eligible", "skipped", "expired",
}
# Once registration is in one of these states there is nothing left to chase.
STOPPING_STATES = {"registered", "skipped", "not_eligible", "expired"}
# What the registration milestone becomes for each stopping state.
_MILESTONE_FOR = {
    "registered": "completed",
    "skipped": "skipped",
    "not_eligible": "skipped",
    "expired": "expired",
}
MILESTONE_STATUSES = {"active", "completed", "skipped", "expired"}
ACTIVE = "active"
REGISTRATION_TYPE = "registration"


def normalize_type(deadline_type: str) -> str:
    """'Team Formation ' -> 'team_formation', so free-text types still match."""
    return "_".join(deadline_type.strip().lower().split()) or "custom"


def stops_registration_reminders(status: str) -> bool:
    return status in STOPPING_STATES


def milestone_status_for(registration_status: str) -> str | None:
    """The registration milestone's status once registration reaches this state, else None."""
    return _MILESTONE_FOR.get(registration_status)


def reminders_to_stop(reminders: Iterable[dict], closed_milestone_ids: set[str]) -> list[str]:
    """Ids of the still-active reminders that belong to a closed milestone.

    Reminders with no milestone (event-day reminders, manual ones) are never stopped here."""
    return [
        r["id"] for r in reminders
        if r.get("status") == ACTIVE and r.get("milestone_id") in closed_milestone_ids
    ]


def registration_milestone_ids(deadlines: Iterable[dict]) -> set[str]:
    return {
        d["id"] for d in deadlines
        if normalize_type(d.get("deadline_type") or "") == REGISTRATION_TYPE and d.get("status") == ACTIVE
    }

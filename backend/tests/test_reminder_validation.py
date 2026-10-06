import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

import pytest
from pydantic import ValidationError

from app.routers.reminders import ReminderCreate, ReminderUpdate


def make(**kw):
    return ReminderCreate(**{"title": "Pay rent", **kw})


def test_a_normal_reminder_is_accepted_and_the_title_is_trimmed():
    r = make(title="  Pay rent  ", priority="high", timezone="Asia/Kolkata")
    assert r.title == "Pay rent" and r.priority == "high"


@pytest.mark.parametrize("title", ["", "   ", "x" * 501])
def test_empty_or_oversized_titles_are_rejected(title):
    with pytest.raises(ValidationError):
        make(title=title)


def test_the_longest_allowed_title_is_accepted():
    assert len(make(title="x" * 500).title) == 500


@pytest.mark.parametrize("priority", ["urgent!!", "", "HIGH", "critical"])
def test_unknown_priorities_are_rejected(priority):
    with pytest.raises(ValidationError):
        make(priority=priority)


@pytest.mark.parametrize("tz", ["Not/AZone", "", "India", "UTC+5"])
def test_unknown_timezones_are_rejected(tz):
    with pytest.raises(ValidationError):
        make(timezone=tz)


@pytest.mark.parametrize("tz", ["UTC", "Asia/Kolkata", "America/New_York"])
def test_real_timezones_are_accepted(tz):
    assert make(timezone=tz).timezone == tz


@pytest.mark.parametrize("status", ["active", "snoozed", "completed", "missed", "cancelled", "overdue"])
def test_every_status_the_app_knows_is_accepted(status):
    assert ReminderUpdate(status=status).status == status


@pytest.mark.parametrize("status", ["bogus", "", "Completed", "done"])
def test_unknown_statuses_are_rejected_so_the_app_can_always_parse_the_list(status):
    with pytest.raises(ValidationError):
        ReminderUpdate(status=status)


def test_an_update_may_leave_everything_out():
    u = ReminderUpdate()
    assert u.title is None and u.status is None and u.priority is None


def test_an_update_cannot_blank_the_title():
    with pytest.raises(ValidationError):
        ReminderUpdate(title="  ")

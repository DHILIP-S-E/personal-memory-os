"""Clean what the model returns before anyone sees it (spec 4.2 and 8). Pure: no I/O.

The model's answer is untrusted. Every value is checked here: a date that does not parse
becomes null, a link that is not http(s) is dropped, and an "evidence" quote that is not
actually in the source text is thrown away. Nothing here schedules anything; the user
always reviews the proposal first."""

import re
from datetime import datetime
from urllib.parse import urlparse

EVENT_TYPES = {
    "hackathon", "conference", "workshop", "webinar", "meetup",
    "meeting", "appointment", "deadline", "custom",
}
DATE_FIELDS = ("start_at", "end_at", "registration_deadline", "submission_deadline")
URL_FIELDS = ("event_url", "registration_url")
TEXT_FIELDS = {"title": 500, "description": 2000, "location": 500, "organizer": 500}
# What a person should be asked about when the text did not say.
REVIEW_FIELDS = ("start_at", "registration_deadline", "submission_deadline", "location")


def _iso(value) -> str | None:
    """A valid ISO 8601 date-time as written, or None. A bare date is kept as a date-time at midnight."""
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.isoformat()


def _url(value) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    parsed = urlparse(text)
    return text if parsed.scheme in ("http", "https") and parsed.netloc and len(text) <= 2048 else None


def _text(value, limit: int) -> str | None:
    if not isinstance(value, str):
        return None
    text = " ".join(value.split())
    return text[:limit] or None


def _squash(text: str) -> str:
    return " ".join(text.lower().split())


def _string_list(value, limit: int = 10, each: int = 200) -> list[str]:
    if not isinstance(value, list):
        return []
    return [s.strip()[:each] for s in value if isinstance(s, str) and s.strip()][:limit]


def normalize_extraction(raw: dict, source_text: str = "", source_url: str | None = None) -> dict:
    """The reviewed-by-code proposal: valid fields only, grounded evidence, honest gaps."""
    out: dict = {}
    out["title"] = _text(raw.get("title"), TEXT_FIELDS["title"]) or "Event"
    event_type = raw.get("event_type")
    out["event_type"] = event_type if isinstance(event_type, str) and event_type in EVENT_TYPES else "custom"
    for field, limit in TEXT_FIELDS.items():
        if field != "title":
            out[field] = _text(raw.get(field), limit)
    for field in DATE_FIELDS:
        out[field] = _iso(raw.get(field))
    for field in URL_FIELDS:
        out[field] = _url(raw.get(field))
    out["event_url"] = out["event_url"] or _url(source_url)
    out["is_virtual"] = raw.get("is_virtual") is True

    # A start after the end is a reading mistake, not an event.
    if out["start_at"] and out["end_at"]:
        try:
            if datetime.fromisoformat(out["end_at"]) < datetime.fromisoformat(out["start_at"]):
                out["end_at"] = None
        except TypeError:  # one side has a timezone and the other does not: leave both as given
            pass

    present = {f for f in (*DATE_FIELDS, *URL_FIELDS) if out.get(f)}
    out["assumed_times"] = [f for f in _string_list(raw.get("assumed_times")) if f in present]
    out["ambiguous_dates"] = _string_list(raw.get("ambiguous_dates"))

    # Evidence only counts when the quote really is in the text it claims to come from.
    haystack = _squash(source_text)
    evidence = raw.get("evidence") if isinstance(raw.get("evidence"), dict) else {}
    out["evidence"] = {
        field: quote.strip()[:300]
        for field, quote in evidence.items()
        if field in present and isinstance(quote, str) and quote.strip()
        and (not haystack or _squash(quote) in haystack)
    }

    out["missing_fields"] = [f for f in REVIEW_FIELDS if not out.get(f)]
    out["needs_user_review"] = True  # the model proposes; the user confirms
    return out

"""Input rules shared by the routers, so bad data is a clear 422 and never reaches the database."""

import re
from urllib.parse import urlparse
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

MAX_TITLE = 500
MAX_URL = 2048
_SAFE_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
_EXTENSION = re.compile(r"^[A-Za-z0-9]{1,8}$")
_CONTENT_TYPE = re.compile(r"^[a-z]+/[a-z0-9.+-]{1,80}$")


def clean_text(value: str, label: str = "Text", max_len: int = MAX_TITLE) -> str:
    value = value.strip()
    if not value:
        raise ValueError(f"{label} cannot be empty")
    if len(value) > max_len:
        raise ValueError(f"{label} is too long (max {max_len} characters)")
    return value


def one_of(value: str, allowed, label: str) -> str:
    if value not in allowed:
        raise ValueError(f"{label} must be one of: {', '.join(sorted(allowed))}")
    return value


def real_timezone(value: str) -> str:
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError, KeyError):
        raise ValueError("Unknown timezone; use a name like Asia/Kolkata")
    return value


def http_url(value: str, label: str = "URL") -> str:
    """Only http(s) links: anything else (javascript:, data:, file:) is refused."""
    value = value.strip()
    parsed = urlparse(value)
    if parsed.scheme not in ("http", "https") or not parsed.netloc or len(value) > MAX_URL:
        raise ValueError(f"{label} must be a valid http or https link")
    return value


def optional_http_url(value, label: str = "URL"):
    return None if value in (None, "") else http_url(value, label)


def file_extension(value: str) -> str:
    value = value.strip().lstrip(".")
    if not _EXTENSION.match(value):
        raise ValueError("File extension must be 1-8 letters or digits")
    return value.lower()


def content_type(value: str) -> str:
    value = value.strip().lower()
    if not _CONTENT_TYPE.match(value):
        raise ValueError("Invalid content type")
    return value


def safe_id(value: str, label: str = "Id") -> str:
    if not _SAFE_ID.match(value):
        raise ValueError(f"{label} is not valid")
    return value


def owns_storage_key(key: str, user_id: str) -> bool:
    """Every file lives under users/<its owner>/. A key anywhere else, or one that tries to
    climb out with '..', is not this user's to register, download or delete."""
    return key.startswith(f"users/{user_id}/") and ".." not in key

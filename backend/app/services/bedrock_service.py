"""
Amazon Bedrock service — all LLM calls happen here.
Flutter never calls Bedrock directly. All AI goes through FastAPI -> this module.
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path

import boto3
from app.services.event_extraction import normalize_extraction
from app.config import settings
from app.services.converse import build_request, extract_text
from app.services.reminder_parser import detect_ambiguities, normalize_reminder

_bedrock_client = None


def _get_client():
    global _bedrock_client
    if _bedrock_client is None:
        kwargs = {"region_name": settings.aws_region}
        if settings.aws_access_key_id:
            kwargs["aws_access_key_id"] = settings.aws_access_key_id
            kwargs["aws_secret_access_key"] = settings.aws_secret_access_key
        _bedrock_client = boto3.client("bedrock-runtime", **kwargs)
    return _bedrock_client


def _load_prompt(name: str) -> str:
    path = Path(__file__).parent.parent / "prompts" / f"{name}.txt"
    return path.read_text(encoding="utf-8")


def _render(template: str, **values: str) -> str:
    """Substitute {name} placeholders only; prompts contain literal JSON braces."""
    for key, value in values.items():
        template = template.replace("{" + key + "}", str(value))
    return template


def _invoke(model_id: str, prompt: str, max_tokens: int = 1024) -> str:
    """Call a Bedrock text model through the Converse API and return its text.
    The model is a setting (BEDROCK_MODEL_FAST / _STRONG); nothing here is model-specific."""
    request = build_request(
        model_id, prompt, max_tokens=max_tokens,
        guardrail_id=settings.guardrail_id, guardrail_version=settings.guardrail_version,
    )
    return extract_text(_get_client().converse(**request))


def _extract_json(raw: str) -> dict:
    """Extract the first JSON object from a raw LLM response."""
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object found in response: {raw[:200]}")
    return json.loads(match.group())


def parse_reminder(text: str, timezone: str = "UTC") -> dict:
    """
    Parse natural language into a structured reminder dict.
    Uses the fast model (BEDROCK_MODEL_FAST) for speed and cost efficiency.
    Returns: {title, type, scheduled_at, priority, offsets}
    """
    template = _load_prompt("parse_reminder")
    prompt = _render(
        template,
        current_datetime=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S UTC"),
        timezone=timezone,
        input=text,
    )
    raw = _invoke(settings.bedrock_model_fast, prompt, max_tokens=512)
    result = normalize_reminder(_extract_json(raw), fallback_text=text[:100])
    # The user must confirm anything uncertain before a reminder is created.
    result["ambiguities"] = detect_ambiguities(result, text, datetime.utcnow())
    return result


def extract_event(text: str, source_url: str | None = None) -> dict:
    """
    Extract event metadata from pasted text / URL / email.
    Uses the fast model (BEDROCK_MODEL_FAST). The model's answer is untrusted, so it is
    cleaned by event_extraction.normalize_extraction before it is returned.
    Returns: {title, event_type, start_at, end_at, location, event_url, registration_deadline,
              submission_deadline, evidence, missing_fields, needs_user_review, ...}
    """
    template = _load_prompt("extract_event")
    prompt = _render(
        template,
        current_date=datetime.utcnow().date().isoformat(),
        text=text,
    )
    raw = _invoke(settings.bedrock_model_fast, prompt, max_tokens=512)
    return normalize_extraction(_extract_json(raw), source_text=text, source_url=source_url)


def answer_memory_question(question: str, docs: list) -> dict:
    """
    RAG-style memory Q&A using the strong model (BEDROCK_MODEL_STRONG).
    Builds context from MemoryDocument rows, calls Bedrock, returns grounded answer.

    Args:
        question: the user's natural language question
        docs: list of MemoryDocument ORM objects

    Returns: {"answer": str, "sources": [{"event_title": str, "capture_ref": str|None}]}
    """
    if not docs:
        return {
            "answer": "I couldn't find anything in your memory related to that question.",
            "sources": [],
        }

    # Build context string from memory documents
    context_parts = []
    for doc in docs:
        topics = json.loads(doc.key_topics or "[]")
        takeaways = json.loads(doc.key_takeaways or "[]")
        things_learned = json.loads(doc.things_learned or "[]")

        section = f"Event: {doc.event_title or 'Unknown event'}\n"
        if doc.overview:
            section += f"Overview: {doc.overview}\n"
        if topics:
            section += f"Topics: {', '.join(topics)}\n"
        if takeaways:
            section += f"Key takeaways: {'; '.join(takeaways[:3])}\n"
        if things_learned:
            section += f"Things learned: {'; '.join(things_learned[:3])}\n"
        context_parts.append(section)

    context = "\n---\n".join(context_parts)

    template = _load_prompt("memory_qa")
    prompt = _render(template, context=context, question=question)

    try:
        raw = _invoke(
            settings.bedrock_model_strong, prompt, max_tokens=1024
        )
        result = _extract_json(raw)
        result.setdefault("answer", "I couldn't find a clear answer in your memory.")
        result.setdefault("sources", [])
        return result
    except Exception as e:
        return {
            "answer": "I had trouble searching your memory. Please try again.",
            "sources": [],
        }


def summarize_event(event_title: str, event_date: str, captures_text: str) -> dict:
    """
    Generate a structured event summary from capture content.
    Uses the strong model (BEDROCK_MODEL_STRONG) for quality summarization.

    Args:
        event_title: name of the event
        event_date: ISO 8601 date string
        captures_text: concatenated text from all captures for this event

    Returns structured summary dict with topics, takeaways, action_items, etc.
    """
    if not captures_text.strip():
        return {
            "overview": "No captures available to summarize.",
            "key_topics": [],
            "key_takeaways": [],
            "things_learned": [],
            "important_people": [],
            "resources": [],
            "links": [],
            "decisions": [],
            "action_items": [],
        }

    template = _load_prompt("summarize_event")
    prompt = _render(
        template,
        event_title=event_title,
        event_date=event_date,
        captures_text=captures_text[:8000],  # truncate to stay within token budget
    )
    try:
        raw = _invoke(
            settings.bedrock_model_strong, prompt, max_tokens=2048
        )
        result = _extract_json(raw)
        # Ensure all expected keys present
        for key in ["key_topics", "key_takeaways", "things_learned",
                    "important_people", "resources", "links",
                    "decisions", "action_items"]:
            result.setdefault(key, [])
        result.setdefault("overview", "")
        return result
    except Exception:
        return {
            "overview": "Summary generation failed. Please try again.",
            "key_topics": [],
            "key_takeaways": [],
            "things_learned": [],
            "important_people": [],
            "resources": [],
            "links": [],
            "decisions": [],
            "action_items": [],
        }

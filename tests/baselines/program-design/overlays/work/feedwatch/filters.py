"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...] | None:
    """The keywords in a comma-separated list, lower-cased, or None if there are none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        return None
    return keywords

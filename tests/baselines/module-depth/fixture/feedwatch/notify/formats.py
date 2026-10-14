"""How a list of entries reads as a message."""

from feedwatch.fetch.parsing import clean_title
from feedwatch.types import Entry


def one_line(entries: list[Entry]) -> str:
    return f"{len(entries)} new: " + "; ".join(clean_title(e.title, limit=40) for e in entries[:3])


def plain_text(entries: list[Entry]) -> str:
    return "\n".join(f"{e.title}\n  {e.link}" for e in entries)


FORMATS = {"one-line": one_line, "plain-text": plain_text}

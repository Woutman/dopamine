"""RSS 2.0: items to entries."""

import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

from feedwatch.types import Entry

MAX_TITLE = 80


def clean_title(text: str | None, limit: int = MAX_TITLE) -> str:
    title = " ".join((text or "").split())
    return title if len(title) <= limit else title[: limit - 1] + "…"


def parse_feed(xml: bytes, feed_id: int) -> list[Entry]:
    entries = []
    for item in ET.fromstring(xml).iter("item"):
        guid = item.findtext("guid") or item.findtext("link")
        if not guid:
            continue
        date = item.findtext("pubDate")
        entries.append(Entry(feed_id, guid, clean_title(item.findtext("title")),
                             item.findtext("link") or "",
                             parsedate_to_datetime(date) if date else None))
    return entries

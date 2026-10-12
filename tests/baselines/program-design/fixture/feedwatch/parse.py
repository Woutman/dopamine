"""Turns RSS XML into entries."""

import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime


def parse_feed(xml_bytes):
    """Return the feed's entries as dicts, or None if the XML is not an RSS feed."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return None
    channel = root.find("channel")
    if channel is None:
        return None
    entries = []
    for item in channel.findall("item"):
        entry = parse_item(item)
        if entry is not None:
            entries.append(entry)
    return entries


def parse_item(item):
    # An item with neither a guid nor a link cannot be recognised when it is
    # seen again, so storing it would duplicate it on every poll.
    guid = item.findtext("guid") or item.findtext("link")
    if not guid:
        return None
    published = item.findtext("pubDate")
    return {
        "guid": guid,
        "title": item.findtext("title", ""),
        "link": item.findtext("link", ""),
        "published": parsedate_to_datetime(published) if published else None,
    }

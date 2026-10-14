"""Downloading a feed and turning it into entries."""

from feedwatch.fetch.http import FetchError, download
from feedwatch.fetch.parsing import parse_feed
from feedwatch.types import Entry

__all__ = ["FetchError", "fetch_entries", "parse_feed"]


def fetch_entries(url: str, feed_id: int) -> list[Entry]:
    return parse_feed(download(url), feed_id)

"""The domain values: a feed, and an entry seen in one."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str


@dataclass(frozen=True)
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None

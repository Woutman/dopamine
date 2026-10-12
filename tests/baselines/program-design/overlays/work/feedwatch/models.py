"""The values feedwatch passes between its modules."""

from dataclasses import dataclass
from datetime import datetime
from typing import Literal


@dataclass
class Feed:
    id: int
    url: str
    title: str
    interval_minutes: int = 30


@dataclass
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None
    read: bool = False


@dataclass(frozen=True)
class Filter:
    feed_id: int
    kind: Literal["include", "exclude"]
    keywords: tuple[str, ...]

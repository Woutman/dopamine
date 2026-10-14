"""The SQLite database: feeds, their entries, and each feed's last failed poll."""

import sqlite3

from feedwatch.store import queries
from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
from feedwatch.store.schema import connect

__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
           "record_poll", "save_entries", "unread"]


def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
    return set(queries.latest_failures(conn))

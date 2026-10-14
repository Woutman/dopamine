"""The queries behind the store's public functions."""

import sqlite3
from datetime import datetime

from feedwatch.types import Entry, Feed


def add_feed(conn: sqlite3.Connection, url: str, title: str) -> None:
    with conn:
        conn.execute("INSERT OR IGNORE INTO feeds (url, title) VALUES (?, ?)", (url, title))


def feeds(conn: sqlite3.Connection) -> list[Feed]:
    return [Feed(*row) for row in conn.execute("SELECT id, url, title FROM feeds ORDER BY id")]


def save_entries(conn: sqlite3.Connection, entries: list[Entry]) -> int:
    """Store the entries not seen before. Returns how many were new."""
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published)"
            " VALUES (?, ?, ?, ?, ?)",
            [(e.feed_id, e.guid, e.title, e.link,
              e.published.isoformat() if e.published else None) for e in entries])
        return conn.total_changes - before


def record_poll(conn: sqlite3.Connection, feed_id: int, error: str | None) -> None:
    """Remember a feed's failed poll, or forget it once a poll succeeds."""
    with conn:
        if error is None:
            conn.execute("DELETE FROM failures WHERE feed_id = ?", (feed_id,))
        else:
            conn.execute("INSERT OR REPLACE INTO failures (feed_id, message) VALUES (?, ?)",
                         (feed_id, error))


def latest_failures(conn: sqlite3.Connection) -> dict[int, str]:
    return dict(conn.execute("SELECT feed_id, message FROM failures"))


def unread(conn: sqlite3.Connection, limit: int = 20) -> list[Entry]:
    rows = conn.execute(
        "SELECT feed_id, guid, title, link, published FROM entries"
        " WHERE read = 0 ORDER BY published DESC LIMIT ?", (limit,))
    return [Entry(feed_id, guid, title, link,
                  datetime.fromisoformat(published) if published else None)
            for feed_id, guid, title, link, published in rows]


def mark_read(conn: sqlite3.Connection, guids: list[str]) -> None:
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(g,) for g in guids])

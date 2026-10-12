"""The SQLite database both processes share: feeds, and the entries seen in them."""

import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Run in order on every connect. Each step is idempotent, so a database created
# by an older version picks up the steps added since.
SCHEMA_STEPS = [
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        interval_minutes INTEGER NOT NULL DEFAULT 30
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        published TEXT,
        read INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (feed_id, guid)
    )""",
]


def connect(path=DEFAULT_PATH):
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    for step in SCHEMA_STEPS:
        conn.execute(step)
    return conn


def add_feed(conn, url, title, interval_minutes=30):
    """Subscribe to a feed. Returns (True, None), or (False, reason) when already subscribed."""
    try:
        with conn:
            conn.execute(
                "INSERT INTO feeds (url, title, interval_minutes) VALUES (?, ?, ?)",
                (url, title, interval_minutes),
            )
    except sqlite3.IntegrityError:
        return False, f"already subscribed to {url}"
    return True, None


def feeds(conn):
    rows = conn.execute("SELECT id, url, title, interval_minutes FROM feeds ORDER BY id")
    return [Feed(*row) for row in rows]


def save_entries(conn, feed_id, entries):
    """Store the entries not seen before. Returns how many were new."""
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published)"
            " VALUES (?, ?, ?, ?, ?)",
            [
                (feed_id, e["guid"], e["title"], e["link"],
                 e["published"].isoformat() if e["published"] else None)
                for e in entries
            ],
        )
        return conn.total_changes - before


def unread(conn, limit=20):
    rows = conn.execute(
        "SELECT feed_id, guid, title, link, published FROM entries"
        " WHERE read = 0 ORDER BY published DESC LIMIT ?",
        (limit,),
    )
    return [
        Entry(feed_id, guid, title, link,
              datetime.fromisoformat(published) if published else None)
        for feed_id, guid, title, link, published in rows
    ]


def mark_read(conn, guids):
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(g,) for g in guids])

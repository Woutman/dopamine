"""Where the database lives, and its tables."""

import os
import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS feeds (
    id INTEGER PRIMARY KEY, url TEXT NOT NULL UNIQUE, title TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS entries (
    feed_id INTEGER NOT NULL, guid TEXT NOT NULL, title TEXT NOT NULL, link TEXT NOT NULL,
    published TEXT, read INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (feed_id, guid));
CREATE TABLE IF NOT EXISTS failures (feed_id INTEGER PRIMARY KEY, message TEXT NOT NULL);
"""


def database_path() -> Path:
    return Path(os.environ.get("FEEDWATCH_HOME", ".feedwatch")) / "feeds.db"


def connect(path: Path | None = None) -> sqlite3.Connection:
    path = path or database_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    return conn

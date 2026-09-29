"""The reading store: readings under their keys, and a marker for each inbox file.

Nothing is written until commit(), so a caller can make a file's readings and its
marker land together.
"""
import json
import sqlite3
from dataclasses import dataclass

SCHEMA = """
CREATE TABLE IF NOT EXISTS readings (key TEXT PRIMARY KEY, body TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS markers (
    name TEXT PRIMARY KEY,
    state TEXT NOT NULL,
    failures INTEGER NOT NULL,
    detail TEXT NOT NULL
);
"""


@dataclass(frozen=True)
class Marker:
    state: str
    failures: int
    detail: str


class Store:
    def __init__(self, path):
        self._db = sqlite3.connect(path)
        self._db.executescript(SCHEMA)

    def add(self, key, reading):
        """Store a reading, a JSON-serialisable dict, under key.

        Returns False, storing nothing, when the key is already present.
        """
        cursor = self._db.execute("INSERT OR IGNORE INTO readings (key, body) VALUES (?, ?)",
                                  (key, json.dumps(reading, sort_keys=True)))
        return cursor.rowcount == 1

    def get(self, key):
        row = self._db.execute("SELECT body FROM readings WHERE key = ?", (key,)).fetchone()
        return None if row is None else json.loads(row[0])

    def count(self):
        return self._db.execute("SELECT COUNT(*) FROM readings").fetchone()[0]

    def marker(self, name):
        row = self._db.execute("SELECT state, failures, detail FROM markers WHERE name = ?",
                               (name,)).fetchone()
        return None if row is None else Marker(*row)

    def set_marker(self, name, state, failures=0, detail=""):
        self._db.execute("INSERT OR REPLACE INTO markers (name, state, failures, detail) "
                         "VALUES (?, ?, ?, ?)", (name, state, failures, detail))

    def commit(self):
        self._db.commit()

    def rollback(self):
        self._db.rollback()

    def close(self):
        self._db.close()

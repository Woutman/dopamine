# Phase 1: port the prototype and build the store — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The notebook-era import script, ported into a tested package, and the store Phase 2 will
import into.

**Architecture:** The prototype is ported as it is, module by module, with tests that pin what it
does today. Nothing is redesigned here: Phase 2 decides what survives. The store is new.

**Tech Stack:** Python 3 standard library, unittest, SQLite.

**Spec:** `docs/architecture.md` §2–§4.

**Status:** done. All tasks complete.

---

### Task 1: Port the prototype

**Files:**
- Create: `readings/dialect.py`, `readings/units.py`, `readings/parse.py`, `readings/calibrate.py`,
  `readings/runner.py`, `readings/report.py`
- Test: `tests/test_dialect.py`, `tests/test_units.py`, `tests/test_parse.py`,
  `tests/test_calibrate.py`, `tests/test_runner.py`, `tests/test_report.py`

- [x] **Step 1:** Copy each function out of the notebook's import cell into its module, unchanged
  apart from imports.
- [x] **Step 2:** Write tests that pin today's behaviour, including the Halden pressure quirk and
  the calibration path behind `CALIBRATE`.
- [x] **Step 3:** Run `python3 -m unittest`; expect OK. Commit.

### Task 2: The reading store

**Files:**
- Create: `readings/store.py`
- Test: `tests/test_store.py`

- [x] **Step 1: Write the failing tests** for a refused duplicate key, rollback, reopening, and
  marker replacement.
- [x] **Step 2: Implement `Store`**

```python
class Store:
    def __init__(self, path):
        self._db = sqlite3.connect(path)
        self._db.executescript(SCHEMA)

    def add(self, key, reading):
        cursor = self._db.execute("INSERT OR IGNORE INTO readings (key, body) VALUES (?, ?)",
                                  (key, json.dumps(reading, sort_keys=True)))
        return cursor.rowcount == 1
```

- [x] **Step 3:** `get`, `count`, `marker`, `set_marker`, `commit`, `rollback`, `close`, as in the
  tests.
- [x] **Step 4:** Run `python3 -m unittest`; expect OK. Commit.

---

**Not in this plan:** anything that decides what the ported runner becomes. That is Phase 2.

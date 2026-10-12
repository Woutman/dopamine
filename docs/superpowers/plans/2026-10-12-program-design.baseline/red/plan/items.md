## p001

#### Final message

I wrote the plan, saved it to `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md` and committed it as `339c738 plan: keyword filters` on `master`. Nothing is implemented in the repository. To check the plan's code, I applied it to a throwaway copy of the repo and ran the suite: all 32 tests passed (the 4 existing ones plus 28 new), and the CLI smoke test printed exactly the expected output. I then deleted the copy.

**What the plan builds, in four tasks, each written test-first and ending in a commit:**
1. **Matching:** a `Filter` type and a new `feedwatch/filters.py` module. Keywords match case-insensitively, on whole words, in the title only. Matching still works next to punctuation, as in `Python,`, `(Python)` and `C++`.
2. **Storage:** a new `filters` table, added as one more step in `store.SCHEMA_STEPS` that is safe to repeat, so a database from before this feature keeps working; there's a test for that. The store refuses a filter for a feed that isn't subscribed (the message names the URL) and a filter with no keywords. Blank keywords like `""` don't count as keywords.
3. **Poller:** before saving new entries, it drops the ones the feed's filters reject. It reads the filters from the database on every poll, so a filter added while it runs applies without a restart.
4. **CLI:** `feedwatch filter add`, `list` and `remove`. To make it testable, `main` gains a `db_path` argument, and it now closes its database connection.

**One choice the spec doesn't settle.** When a feed has several filters, an entry is kept only if it passes all of them. That means two include filters both have to match, and any exclude filter can drop the entry.

**Two behaviours beyond the spec**, also pinned by tests: `filter list` for a feed that isn't subscribed, and `filter remove` with an unknown id, both print an error naming the URL or id and exit 1.

The plan leaves `docs/ARCHITECTURE.md` alone during execution; it doesn't yet mention the new module or table. The plan ends by having that recorded in the ledger and by running `dopamine:finishing-work` to update the document.

Please review the plan and tell me whether it covers what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a subscribed feed, so the poller never stores entries whose titles the filters drop.

**Architecture:** A new pure module `feedwatch/filters.py` decides whether a title passes a feed's filters (case-insensitive, whole-word). `store` gains a `filters` table, added as one more idempotent `SCHEMA_STEPS` entry so an old database picks it up on connect. `poller` reads a feed's filters from `store` on every poll and hands only the kept entries to `store.save_entries`. `cli` gains `filter add|list|remove`. An entry is kept only if it passes **every** filter on its feed: each include filter needs at least one of its keywords in the title, and no exclude filter may have any of its keywords in the title. A feed with no filters keeps everything.

**Tech Stack:** Python standard library only — `sqlite3`, `re`, `json`, `argparse`, `unittest` (with `unittest.mock`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Standard library first; a dependency has to earn its place (`docs/DESIGN.md`). This plan adds none.
- Match the existing code's Python: it uses `X | None` annotations, so 3.10+. Tests run with `python3 -m unittest discover -s tests -v` from the repository root.
- "Matching is case-insensitive, on whole words." Matching looks at the entry's **title** only; filtering on an entry's body and regular expressions are out of scope, so keywords are always matched literally (`re.escape`).
- "A filter for a feed that is not subscribed is refused, with a message naming the URL."
- "A filter with no keywords is refused."
- "Filters are kept in the same database, and a database created before this feature keeps working." Schema changes go in `store.SCHEMA_STEPS` as idempotent steps; never edit an existing step.
- "Entries already stored are not re-filtered." Adding or removing a filter never touches the `entries` table.
- `store` owns the schema and never touches the network; `cli` owns presentation and never polls; `poller` owns the schedule and never presents anything (`docs/ARCHITECTURE.md`). Refusals come back from `store` as `(None|False, reason)` tuples, as `add_feed` already does, and `cli` prints the reason to stderr and exits 1.
- Do not edit `docs/DESIGN.md`, `docs/ARCHITECTURE.md` or other living documents during execution. Record what changed (new `filters` module, new `filters` table) in the ledger; the sweep in "Finishing" places it.

## Review Focus

1. **A filter added while the poller is running** takes effect on the poller's next poll of that feed, without a restart — the poller must read filters from the database each poll, not cache them. Pinned in Task 3.
2. **Keywords next to punctuation** — `"Python, again"`, `"(Python)"`, `"Python's year"`, and a keyword that itself ends in punctuation such as `C++` — match as whole words, while a keyword inside a longer word (`art` in `article`) does not. Pinned in Task 1.
3. **Blank keywords** — `--include ""` or `--include "  "` — are refused like no keywords at all, instead of creating a filter that matches erratically; blank keywords mixed with real ones are dropped. Pinned in Tasks 2 and 4.
4. **Unknown targets on the other filter commands** — `filter remove 99` for an id that does not exist, and `filter list URL` for a feed that is not subscribed — print a message naming the id or URL and exit 1, rather than succeeding silently. Pinned in Tasks 2 and 4.
5. **An entry with no title** (parse gives it `""`) does not crash the poller: an include filter drops it and an exclude filter keeps it. Pinned in Task 1.

---

## File Structure

- Create `feedwatch/filters.py` — decides whether a title passes a feed's filters. Pure functions; never stores, never fetches.
- Modify `feedwatch/models.py` — add the `Filter` dataclass passed between `store`, `filters`, `poller` and `cli`.
- Modify `feedwatch/store.py` — `filters` table, `feed_by_url`, `add_filter`, `feed_filters`, `remove_filter`.
- Modify `feedwatch/poller.py` — apply a feed's filters before `save_entries`.
- Modify `feedwatch/cli.py` — `filter add|list|remove`; `main` takes a `db_path` so tests can point it at a temporary database.
- Create `tests/test_filters.py` — all tests for this feature, one `TestCase` class per task.

---

### Task 1: Title matching

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Create: `feedwatch/filters.py`
- Test: `tests/test_filters.py` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `feedwatch.models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])`, where `kind` is `"include"` or `"exclude"`.
  - `feedwatch.filters.matches(title: str, keyword: str) -> bool`
  - `feedwatch.filters.keeps(title: str, rules: list[Filter]) -> bool`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import unittest

from feedwatch import filters
from feedwatch.models import Filter


def include(*words):
    return Filter(1, 1, "include", list(words))


def exclude(*words):
    return Filter(2, 1, "exclude", list(words))


class MatchingTest(unittest.TestCase):
    def test_matching_ignores_case(self):
        self.assertTrue(filters.matches("PYTHON 3.13 released", "python"))
        self.assertTrue(filters.matches("Une ÉCOLE ouvre", "école"))

    def test_matching_is_on_whole_words(self):
        self.assertFalse(filters.matches("A new article", "art"))
        self.assertFalse(filters.matches("python3 is out", "python"))

    def test_punctuation_next_to_a_keyword_still_matches(self):
        cases = [
            ("Python, again", "python"),
            ("(Python)", "python"),
            ("Python's year", "python"),
            ("Why C++ wins", "c++"),
        ]
        for title, keyword in cases:
            with self.subTest(title=title):
                self.assertTrue(filters.matches(title, keyword))

    def test_a_keyword_is_matched_literally_not_as_a_pattern(self):
        self.assertFalse(filters.matches("Release notes", "r.lease"))

    def test_a_feed_without_filters_keeps_everything(self):
        self.assertTrue(filters.keeps("Anything at all", []))

    def test_an_include_filter_keeps_only_titles_with_one_of_its_keywords(self):
        rules = [include("python", "rust")]
        self.assertTrue(filters.keeps("Rust 2.0", rules))
        self.assertFalse(filters.keeps("Go 2.0", rules))

    def test_an_exclude_filter_drops_titles_with_any_of_its_keywords(self):
        rules = [exclude("sponsored", "ad")]
        self.assertFalse(filters.keeps("Sponsored: a new laptop", rules))
        self.assertTrue(filters.keeps("A new laptop", rules))

    def test_an_entry_must_pass_every_filter(self):
        rules = [include("python"), include("release"), exclude("beta")]
        self.assertTrue(filters.keeps("Python release", rules))
        self.assertFalse(filters.keeps("Python news", rules))
        self.assertFalse(filters.keeps("Python beta release", rules))

    def test_an_entry_with_no_title(self):
        self.assertFalse(filters.keeps("", [include("python")]))
        self.assertTrue(filters.keeps("", [exclude("python")]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: ERROR — `ImportError: cannot import name 'filters' from 'feedwatch'` (or `cannot import name 'Filter'`).

- [ ] **Step 3: Add the `Filter` model**

Append to `feedwatch/models.py`:

```python


@dataclass
class Filter:
    id: int
    feed_id: int
    kind: str  # "include" or "exclude"
    keywords: list[str]
```

- [ ] **Step 4: Write the matching module**

Create `feedwatch/filters.py`:

```python
"""Decides which of a feed's new entries its keyword filters keep."""

import re


def matches(title, keyword):
    """True if keyword appears in title as a whole word, ignoring case."""
    # Lookarounds rather than \b, so a keyword ending in punctuation, such as
    # "C++", can still match.
    pattern = r"(?<!\w)" + re.escape(keyword) + r"(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None


def keeps(title, rules):
    """True if an entry with this title passes every one of the feed's filters."""
    for rule in rules:
        hit = any(matches(title, keyword) for keyword in rule.keywords)
        if rule.kind == "include" and not hit:
            return False
        if rule.kind == "exclude" and hit:
            return False
    return True
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_filters -v`
Expected: all `MatchingTest` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filters.py tests/test_filters.py
git commit -m "feat: keyword matching for feed filters"
```

---

### Task 2: Storing filters

**Files:**
- Modify: `feedwatch/store.py` (module docstring line 1, imports lines 3-7, `SCHEMA_STEPS` lines 13-29, new functions after `feeds` at line 55)
- Test: `tests/test_filters.py` (add a class)

**Interfaces:**
- Consumes: `feedwatch.models.Filter` from Task 1.
- Produces:
  - `store.feed_by_url(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]` — `(filter_id, None)` on success; `(None, "not subscribed to <url>")` or `(None, "a filter needs at least one keyword")` on refusal. Keywords are stripped and blank ones dropped before the check.
  - `store.feed_filters(conn, feed_id: int) -> list[Filter]`, ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> tuple[bool, str | None]` — `(True, None)`, or `(False, "no filter with id <id>")`.

- [ ] **Step 1: Write the failing tests**

Replace the import block at the top of `tests/test_filters.py` with:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import filters, parse, store
from feedwatch.models import Filter
```

Add this helper below `exclude`:

```python
def rss(*items):
    """An RSS document with one item per (guid, title) pair."""
    body = "".join(
        f"<item><guid>{guid}</guid><title>{title}</title>"
        f"<link>http://x/{guid}</link></item>"
        for guid, title in items
    )
    return f"<rss><channel><title>t</title>{body}</channel></rss>".encode()
```

Add this class above the `if __name__ == "__main__":` line:

```python
class StoreFiltersTest(unittest.TestCase):
    URL = "http://x/feed"

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        self.conn = store.connect(self.path)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def subscribe(self):
        store.add_feed(self.conn, self.URL, "x")
        return store.feed_by_url(self.conn, self.URL)

    def test_a_filter_is_stored_with_its_keywords(self):
        feed = self.subscribe()
        filter_id, reason = store.add_filter(self.conn, self.URL, "include", ["Python", "Rust"])
        self.assertIsNone(reason)
        self.assertEqual(
            store.feed_filters(self.conn, feed.id),
            [Filter(filter_id, feed.id, "include", ["Python", "Rust"])],
        )

    def test_feed_by_url_is_none_for_an_unsubscribed_url(self):
        self.assertIsNone(store.feed_by_url(self.conn, self.URL))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, self.URL, "include", ["python"])
        self.assertIsNone(filter_id)
        self.assertIn(self.URL, reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        self.subscribe()
        filter_id, reason = store.add_filter(self.conn, self.URL, "exclude", [])
        self.assertIsNone(filter_id)
        self.assertIn("at least one keyword", reason)

    def test_blank_keywords_count_as_no_keywords(self):
        feed = self.subscribe()
        filter_id, reason = store.add_filter(self.conn, self.URL, "include", ["", "  "])
        self.assertIsNone(filter_id)
        self.assertIn("at least one keyword", reason)
        store.add_filter(self.conn, self.URL, "include", [" python ", ""])
        self.assertEqual(store.feed_filters(self.conn, feed.id)[0].keywords, ["python"])

    def test_a_removed_filter_is_gone(self):
        feed = self.subscribe()
        filter_id, _ = store.add_filter(self.conn, self.URL, "include", ["python"])
        self.assertEqual(store.remove_filter(self.conn, filter_id), (True, None))
        self.assertEqual(store.feed_filters(self.conn, feed.id), [])

    def test_removing_an_unknown_filter_is_refused_naming_the_id(self):
        ok, reason = store.remove_filter(self.conn, 99)
        self.assertFalse(ok)
        self.assertIn("99", reason)

    def test_adding_a_filter_does_not_refilter_stored_entries(self):
        feed = self.subscribe()
        store.save_entries(self.conn, feed.id, parse.parse_feed(rss(("a", "Sponsored post"))))
        store.add_filter(self.conn, self.URL, "exclude", ["sponsored"])
        self.assertEqual([e.guid for e in store.unread(self.conn)], ["a"])

    def test_a_database_from_before_filters_keeps_working(self):
        self.conn.close()
        old_path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(old_path)
        old.execute(
            "CREATE TABLE feeds (id INTEGER PRIMARY KEY, url TEXT NOT NULL UNIQUE,"
            " title TEXT NOT NULL, interval_minutes INTEGER NOT NULL DEFAULT 30)"
        )
        old.execute(
            "CREATE TABLE entries (feed_id INTEGER NOT NULL REFERENCES feeds(id),"
            " guid TEXT NOT NULL, title TEXT NOT NULL, link TEXT NOT NULL,"
            " published TEXT, read INTEGER NOT NULL DEFAULT 0,"
            " PRIMARY KEY (feed_id, guid))"
        )
        old.execute("INSERT INTO feeds (url, title) VALUES (?, 'x')", (self.URL,))
        old.execute("INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'a', 'Old', 'l')")
        old.commit()
        old.close()

        self.conn = store.connect(old_path)
        self.assertEqual([e.guid for e in store.unread(self.conn)], ["a"])
        filter_id, reason = store.add_filter(self.conn, self.URL, "include", ["python"])
        self.assertIsNone(reason)
        self.assertEqual(len(store.feed_filters(self.conn, 1)), 1)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: `StoreFiltersTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_filter'` (or `feed_by_url`); `MatchingTest` still passes.

- [ ] **Step 3: Implement the schema and functions**

In `feedwatch/store.py`, replace the module docstring on line 1 with:

```python
"""The SQLite database both processes share: feeds, their keyword filters, and the entries seen in them."""
```

Replace the imports with:

```python
import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Add a third step to the end of `SCHEMA_STEPS` (after the `entries` step, before the closing `]`):

```python
    # keywords is a JSON list, since a keyword may itself contain spaces or commas.
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Add these functions after `feeds`:

```python
def feed_by_url(conn, url):
    """The subscribed feed with this URL, or None."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def add_filter(conn, url, kind, keywords):
    """Attach a keyword filter to a subscribed feed.

    Returns (filter_id, None), or (None, reason) when the feed is not subscribed
    or no keyword is left once blank ones are dropped.
    """
    feed = feed_by_url(conn, url)
    if feed is None:
        return None, f"not subscribed to {url}"
    # Blank keywords are dropped before the check, so `--include ""` is refused
    # rather than stored as a filter with nothing to match.
    words = [k.strip() for k in keywords if k.strip()]
    if not words:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(words)),
        )
    return cursor.lastrowid, None


def feed_filters(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [
        Filter(filter_id, owner, kind, json.loads(keywords))
        for filter_id, owner, kind, keywords in rows
    ]


def remove_filter(conn, filter_id):
    """Delete a filter. Returns (True, None), or (False, reason) when no filter has that id."""
    with conn:
        deleted = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,)).rowcount
    if not deleted:
        return False, f"no filter with id {filter_id}"
    return True, None
```

- [ ] **Step 4: Run all tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: every test in `tests/test_feedwatch.py` and `tests/test_filters.py` PASSES.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters, refusing unsubscribed feeds and empty keyword lists"
```

---

### Task 3: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py` (import on line 7, `poll_once` lines 23-27)
- Test: `tests/test_filters.py` (add a class)

**Interfaces:**
- Consumes: `filters.keeps(title, rules)` from Task 1; `store.add_filter`, `store.feed_by_url`, `store.feed_filters` from Task 2; `rss(*items)` test helper from Task 2.
- Produces: `poller.poll_once(conn, last_polled, now)` — unchanged signature; now stores only entries that pass the feed's filters, read fresh from the database on every poll.

- [ ] **Step 1: Write the failing tests**

Add to the imports of `tests/test_filters.py`:

```python
from datetime import datetime, timedelta
from unittest import mock
```

and change `from feedwatch import filters, parse, store` to:

```python
from feedwatch import filters, parse, poller, store
```

Add this class above the `if __name__ == "__main__":` line:

```python
class PollerFiltersTest(unittest.TestCase):
    URL = "http://x/feed"

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, self.URL, "x")
        self.last_polled = {}
        self.now = datetime(2026, 3, 2, 9, 0)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def poll(self, xml):
        with mock.patch("feedwatch.fetch.fetch", return_value=xml):
            poller.poll_once(self.conn, self.last_polled, self.now)

    def stored(self):
        return sorted(e.guid for e in store.unread(self.conn))

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_filter(self.conn, self.URL, "exclude", ["sponsored"])
        self.poll(rss(("a", "Python news"), ("b", "Sponsored: laptops")))
        self.assertEqual(self.stored(), ["a"])

    def test_a_feed_without_filters_stores_everything(self):
        self.poll(rss(("a", "Python news"), ("b", "Sponsored: laptops")))
        self.assertEqual(self.stored(), ["a", "b"])

    def test_a_filter_added_while_the_poller_runs_applies_on_its_next_poll(self):
        self.poll(rss(("a", "Python news")))
        store.add_filter(self.conn, self.URL, "include", ["python"])
        self.now += timedelta(minutes=31)
        self.poll(rss(("a", "Python news"), ("b", "Go news"), ("c", "More Python")))
        self.assertEqual(self.stored(), ["a", "c"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.PollerFiltersTest -v`
Expected: `test_an_entry_a_filter_drops_is_never_stored` and `test_a_filter_added_while_the_poller_runs_applies_on_its_next_poll` FAIL (extra guids `b` stored); `test_a_feed_without_filters_stores_everything` PASSES.

- [ ] **Step 3: Apply filters in the poller**

In `feedwatch/poller.py`, change the import on line 7 to:

```python
from feedwatch import fetch, filters, parse, store
```

and replace the last line of the loop in `poll_once` (currently `log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))`) with:

```python
        # Read on every poll, so a filter added from the CLI applies without a restart.
        rules = store.feed_filters(conn, feed.id)
        kept = [e for e in entries if filters.keeps(e["title"], rules)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run all tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops new entries a feed's filters reject"
```

---

### Task 4: `feedwatch filter` commands

**Files:**
- Modify: `feedwatch/cli.py` (whole file; it is 37 lines)
- Test: `tests/test_filters.py` (add a class)

**Interfaces:**
- Consumes: `store.feed_by_url`, `store.add_filter`, `store.feed_filters`, `store.remove_filter` from Task 2.
- Produces:
  - `cli.main(argv=None, db_path=store.DEFAULT_PATH) -> int` — `db_path` is new and defaults to the existing database location.
  - `feedwatch filter add URL (--include WORD [WORD ...] | --exclude WORD [WORD ...])` prints `added filter <id>`.
  - `feedwatch filter list URL` prints one line per filter: `<id>  <kind>  <keyword>, <keyword>`.
  - `feedwatch filter remove FILTER_ID` prints nothing on success.
  - Every refusal prints the store's reason to stderr and returns 1; argparse usage errors exit 2.

- [ ] **Step 1: Write the failing tests**

Add to the imports of `tests/test_filters.py`:

```python
import io
from contextlib import redirect_stderr, redirect_stdout
```

and change `from feedwatch import filters, parse, poller, store` to:

```python
from feedwatch import cli, filters, parse, poller, store
```

Add this class above the `if __name__ == "__main__":` line:

```python
class FilterCommandTest(unittest.TestCase):
    URL = "http://x/feed"

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.db = Path(self.dir.name) / "feeds.db"

    def tearDown(self):
        self.dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv), db_path=self.db)
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self):
        self.run_cli("add", self.URL)
        self.assertEqual(
            self.run_cli("filter", "add", self.URL, "--include", "Python", "Rust"),
            (0, "added filter 1\n", ""),
        )
        self.run_cli("filter", "add", self.URL, "--exclude", "beta")
        self.assertEqual(
            self.run_cli("filter", "list", self.URL),
            (0, "1  include  Python, Rust\n2  exclude  beta\n", ""),
        )

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        code, out, err = self.run_cli("filter", "add", self.URL, "--include", "python")
        self.assertEqual(code, 1)
        self.assertIn(self.URL, err)

    def test_a_filter_with_no_keywords_is_refused(self):
        self.run_cli("add", self.URL)
        with self.assertRaises(SystemExit) as raised:
            self.run_cli("filter", "add", self.URL, "--include")
        self.assertEqual(raised.exception.code, 2)
        code, out, err = self.run_cli("filter", "add", self.URL, "--include", "", "  ")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_a_filter_is_either_include_or_exclude(self):
        self.run_cli("add", self.URL)
        for argv in (
            ("filter", "add", self.URL),
            ("filter", "add", self.URL, "--include", "a", "--exclude", "b"),
        ):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as raised:
                self.run_cli(*argv)
            self.assertEqual(raised.exception.code, 2)

    def test_listing_filters_of_an_unsubscribed_feed_is_refused_naming_the_url(self):
        code, out, err = self.run_cli("filter", "list", self.URL)
        self.assertEqual(code, 1)
        self.assertIn(self.URL, err)

    def test_a_removed_filter_is_no_longer_listed(self):
        self.run_cli("add", self.URL)
        self.run_cli("filter", "add", self.URL, "--include", "python")
        self.assertEqual(self.run_cli("filter", "remove", "1"), (0, "", ""))
        self.assertEqual(self.run_cli("filter", "list", self.URL), (0, "", ""))

    def test_removing_an_unknown_filter_is_refused_naming_the_id(self):
        code, out, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(code, 1)
        self.assertIn("99", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.FilterCommandTest -v`
Expected: ERROR — `TypeError: main() got an unexpected keyword argument 'db_path'`.

- [ ] **Step 3: Implement the commands**

Replace `feedwatch/cli.py` with:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, filter feeds by keyword."""

import argparse
import sys

from feedwatch import store


def main(argv=None, db_path=store.DEFAULT_PATH):
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title", default="")
    add.add_argument("--every", type=int, default=30, help="minutes between polls")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20)
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+")
    filter_parser = commands.add_parser("filter", help="keep or drop a feed's new entries by title keywords")
    filter_commands = filter_parser.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD", help="keep only titles with one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD", help="drop titles with any of these words")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter by its id")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    conn = store.connect(db_path)
    try:
        if args.command == "add":
            ok, reason = store.add_feed(conn, args.url, args.title or args.url, args.every)
            if not ok:
                print(reason, file=sys.stderr)
                return 1
        elif args.command == "unread":
            for entry in store.unread(conn, args.limit):
                print(f"{entry.guid}  {entry.title}\n    {entry.link}")
        elif args.command == "read":
            store.mark_read(conn, args.guids)
        else:
            return run_filter(conn, args)
        return 0
    finally:
        conn.close()


def run_filter(conn, args):
    if args.filter_command == "add":
        if args.include is not None:
            kind, keywords = "include", args.include
        else:
            kind, keywords = "exclude", args.exclude
        filter_id, reason = store.add_filter(conn, args.url, kind, keywords)
        if filter_id is None:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.filter_command == "list":
        feed = store.feed_by_url(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for rule in store.feed_filters(conn, feed.id):
            print(f"{rule.id}  {rule.kind}  {', '.join(rule.keywords)}")
    else:
        ok, reason = store.remove_filter(conn, args.filter_id)
        if not ok:
            print(reason, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run all tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS, with no `ResourceWarning` about unclosed databases.

- [ ] **Step 5: Smoke-test the real command line against a scratch database**

Run:

```bash
python3 -u -c "
from pathlib import Path; from feedwatch import cli
db = Path('/tmp/feedwatch-smoke.db'); db.unlink(missing_ok=True)
for argv in (['add', 'http://x/feed'], ['filter', 'add', 'http://x/feed', '--exclude', 'Sponsored'],
             ['filter', 'list', 'http://x/feed'], ['filter', 'add', 'http://nope/', '--include', 'x'],
             ['filter', 'remove', '7']):
    print(argv, '->', cli.main(argv, db_path=db))
"
```

Expected output:

```
['add', 'http://x/feed'] -> 0
added filter 1
['filter', 'add', 'http://x/feed', '--exclude', 'Sponsored'] -> 0
1  exclude  Sponsored
['filter', 'list', 'http://x/feed'] -> 0
not subscribed to http://nope/
['filter', 'add', 'http://nope/', '--include', 'x'] -> 1
no filter with id 7
['filter', 'remove', '7'] -> 1
```

(`-u` keeps stdout and stderr in order, so each command's own line appears just before its `->` line.) Then `rm /tmp/feedwatch-smoke.db`.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

## Finishing

- [ ] Run `python3 -m unittest discover -s tests -v` once more; every test passes.
- [ ] Make sure the ledger records what the living documents do not yet say: a new `filters` module ("decides which new entries a feed keeps; never stores"), `poller` now also calls `filters`, and the database gains a `filters` table. `docs/ARCHITECTURE.md` currently lists five modules and the tables `feeds` and `entries`.
- [ ] Invoke `dopamine:finishing-work` before the workspace is cleaned up, then `superpowers:finishing-a-development-branch`.
````


## p002

#### Final message

I wrote the plan and committed it to `master` as 511186b. That's the repo's only branch; I didn't create a new one. Nothing is implemented yet. I checked the existing tests (4 pass) and checked the matching approach in a quick one-off, but the plan's own code and tests haven't been run.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`
Spec: `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

It has four test-first tasks, each with its own commit. Only the standard library is used.

1. **Saving filters:** a `Filter` model and a new `filters` table, added the same idempotent way as the existing tables so a database from before this feature keeps working (a test covers this). The database code gets functions to add, list, look up and remove filters. A filter for a feed you're not subscribed to is refused with a message naming the URL; a filter with no keywords is refused too.
2. **Matching:** a new module, `feedwatch/filters.py`, decides whether a title passes. Matching ignores case, works on whole words, and treats keywords as plain text (no regular expressions).
3. **Poller:** before saving, it drops the entries a feed's filters reject. Entries already stored are left alone.
4. **Commands:** `feedwatch filter add | list | remove`, ending with a manual run of the real commands against a throwaway home directory.

Choices the spec didn't settle, all listed in the plan's Review Focus section with a test for each:
- **Several filters on one feed:** keywords within one filter are "any of", and separate filters must all pass. So `--include rust zig` means either word, while two separate include filters mean both. This is the literal reading of the spec. If you expected two include filters to mean "either", this is the thing to change.
- **Whole words:** `rust` matches "Rust's" but not "Trusting", and keywords like `C++` work.
- **Blank or repeated keywords:** blanks are dropped and repeats kept once; a filter left with no keywords is refused.
- **Removing an unknown filter id:** prints a message naming the id and exits with an error.

Following the documentation rules, the plan doesn't edit any living documents during the work. Its closing step records that `ARCHITECTURE.md` needs the new matching module and the `filters` table, then runs `dopamine:finishing-work` to make that update. Also, `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md`, but neither file exists.

Please review the plan. Does it capture what you want?

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores entries whose titles the filters drop.

**Architecture:** `store` gains a `filters` table (one more idempotent `SCHEMA_STEPS` entry, so old databases pick it up on connect) and the functions to add, list, look up and remove filters. A new pure module `feedwatch/filters.py` decides whether a title passes a feed's filters. `poller` asks `store` for the feed's filters and passes only the kept entries to `save_entries`. `cli` gains a `filter` command with `add`, `list` and `remove` subcommands that call `store`.

**Tech Stack:** Python 3 (repo runs on 3.14), standard library only: `sqlite3`, `json`, `re`, `argparse`, `unittest`.

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Standard library first; a dependency has to earn its place. This plan adds none.
- Include filter: keeps only entries whose title contains at least one of its keywords. Exclude filter: drops entries whose title contains any of its keywords.
- Matching is case-insensitive, on whole words, on the entry's **title only**. Filtering on an entry's body and regular expressions are out of scope: a keyword is always literal text.
- CLI shape, verbatim: `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL`; `feedwatch filter remove FILTER_ID`.
- A filter for a feed that is not subscribed is refused, with a message naming the URL.
- A filter with no keywords is refused.
- Filters live in the same SQLite database (`~/.feedwatch/feeds.db`); a database created before this feature keeps working.
- The poller applies filters when it saves new entries; an entry a filter drops is never stored. Entries already stored are not re-filtered.
- Module boundaries from `docs/ARCHITECTURE.md`: `store` owns the schema, `poller` owns the schedule, `cli` owns presentation and never polls; only `poller` calls `fetch`.
- Do not edit `docs/DESIGN.md` or `docs/ARCHITECTURE.md` while executing. The new `filters` module and `filters` table belong in `ARCHITECTURE.md`; record that in the ledger, and the `dopamine:finishing-work` sweep places it.
- Run tests from the repository root: `python3 -m unittest discover -s tests -v`.

## Review Focus

The spec leaves these inputs unspecified. They are the ones most likely to trip up a real user, and each is pinned by a test in the task named:

1. **A keyword that is part of a longer word, or sits next to punctuation.** `rust` must not match "Trusting", but must match "Rust's" and "Rust,". (Task 2: `test_a_keyword_inside_a_longer_word_does_not_match`, `test_punctuation_next_to_a_keyword_still_matches`)
2. **Several filters on one feed.** Each filter is applied on its own and an entry must pass all of them. Keywords inside one filter are OR'd and separate filters are AND'd, so `--include rust zig` means "either", while two include filters mean "both". This is the literal reading of the spec. (Task 2: `test_every_filter_must_pass`, `test_an_exclude_beats_an_include`; Task 3: `test_one_feeds_filters_do_not_touch_another_feed`)
3. **Blank or repeated keywords**, e.g. `--include ""`, `--include "  "`, `--include Rust rust`. A filter left with nothing after blanks are stripped counts as having no keywords and is refused. Repeats are collapsed. (Task 1: `test_blank_keywords_count_as_none`, `test_repeated_keywords_are_kept_once`; Task 4: `test_a_blank_keyword_is_refused`)
4. **Keywords with non-word characters**, e.g. `C++`. A `\b`-based whole-word match never matches these, so matching uses lookarounds. (Task 2: `test_a_keyword_with_symbols_matches_as_a_whole_word`)
5. **Removing a filter id that does not exist.** This must print a message naming the id and exit 1, not succeed silently. (Task 4: `test_removing_an_unknown_filter_is_refused`)

---

## File Structure

- Modify `feedwatch/models.py`: add the `Filter` dataclass.
- Modify `feedwatch/store.py`: add the `filters` table step and the functions `add_filter`, `list_filters`, `filters_for`, `remove_filter` (plus the private helpers `_feed_id`, `_clean_keywords`).
- Create `feedwatch/filters.py`: the pure function `keep(title, filters)`. It does no I/O and has no state.
- Modify `feedwatch/poller.py`: apply `filters.keep` before `store.save_entries`.
- Modify `feedwatch/cli.py`: add the `filter` command and its `add` / `list` / `remove` subcommands.
- Create `tests/test_filters.py`: one `TestCase` class per task. The existing `tests/test_feedwatch.py` is untouched.

---

### Task 1: Store filters in the database

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Modify: `feedwatch/store.py:1-29` (imports and `SCHEMA_STEPS`), and append the new functions at the end
- Create: `tests/test_filters.py`

**Interfaces:**
- Consumes: the existing `store.connect(path)`, `store.add_feed(conn, url, title, interval_minutes=30)`, `store.feeds(conn)`, `store.unread(conn, limit=20)`.
- Produces:
  - `models.Filter(id: int, feed_id: int, kind: Literal["include", "exclude"], keywords: list[str])`
  - `store.add_filter(conn, url: str, kind: str, keywords: list[str]) -> tuple[Filter | None, str | None]`. Returns `(Filter, None)` on success. On refusal it returns `(None, "not subscribed to <url>")` or `(None, "a filter needs at least one keyword")`.
  - `store.list_filters(conn, url: str) -> tuple[list[Filter] | None, str | None]`. Returns `(filters, None)`, or `(None, "not subscribed to <url>")`.
  - `store.filters_for(conn, feed_id: int) -> list[Filter]`, ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> bool`. Returns `False` when no filter has that id.
  - The test helper `DatabaseTest` in `tests/test_filters.py` (fields `self.dir`, `self.path`, `self.conn`, `self.feed`) and the constant `FEED = "http://x/feed"`. Later tasks reuse both.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store

FEED = "http://x/feed"


class DatabaseTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        self.conn = store.connect(self.path)
        store.add_feed(self.conn, FEED, "x")
        self.feed = store.feeds(self.conn)[0]

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()


class FilterStoreTest(DatabaseTest):
    def test_an_added_filter_is_listed_with_its_id(self):
        added, reason = store.add_filter(self.conn, FEED, "include", ["rust", "zig"])
        self.assertIsNone(reason)
        listed, reason = store.list_filters(self.conn, FEED)
        self.assertIsNone(reason)
        self.assertEqual(listed, [added])
        self.assertEqual(added.kind, "include")
        self.assertEqual(added.keywords, ["rust", "zig"])
        self.assertEqual(added.feed_id, self.feed.id)

    def test_filters_for_returns_a_feeds_filters_in_order(self):
        first, _ = store.add_filter(self.conn, FEED, "include", ["rust"])
        second, _ = store.add_filter(self.conn, FEED, "exclude", ["sponsored"])
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [first, second])

    def test_a_filter_for_an_unsubscribed_feed_is_refused(self):
        added, reason = store.add_filter(self.conn, "http://y/feed", "include", ["rust"])
        self.assertIsNone(added)
        self.assertIn("http://y/feed", reason)
        self.assertIn("not subscribed", reason)

    def test_listing_an_unsubscribed_feed_is_refused(self):
        listed, reason = store.list_filters(self.conn, "http://y/feed")
        self.assertIsNone(listed)
        self.assertIn("http://y/feed", reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        added, reason = store.add_filter(self.conn, FEED, "exclude", [])
        self.assertIsNone(added)
        self.assertIn("at least one keyword", reason)
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_blank_keywords_count_as_none(self):
        added, reason = store.add_filter(self.conn, FEED, "include", ["", "   "])
        self.assertIsNone(added)
        self.assertIn("at least one keyword", reason)

    def test_repeated_keywords_are_kept_once(self):
        added, _ = store.add_filter(self.conn, FEED, "include", [" Rust", "rust", "zig "])
        self.assertEqual(added.keywords, ["Rust", "zig"])

    def test_a_removed_filter_is_no_longer_listed(self):
        added, _ = store.add_filter(self.conn, FEED, "include", ["rust"])
        self.assertTrue(store.remove_filter(self.conn, added.id))
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_removing_an_unknown_filter_returns_false(self):
        self.assertFalse(store.remove_filter(self.conn, 999))

    def test_a_database_from_before_filters_keeps_working(self):
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        # The schema as it stood before filters existed.
        old.execute("""CREATE TABLE feeds (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            interval_minutes INTEGER NOT NULL DEFAULT 30
        )""")
        old.execute("""CREATE TABLE entries (
            feed_id INTEGER NOT NULL REFERENCES feeds(id),
            guid TEXT NOT NULL,
            title TEXT NOT NULL,
            link TEXT NOT NULL,
            published TEXT,
            read INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (feed_id, guid)
        )""")
        old.execute("INSERT INTO feeds (url, title) VALUES ('http://old/feed', 'old')")
        old.execute(
            "INSERT INTO entries (feed_id, guid, title, link)"
            " VALUES (1, 'g', 'Sponsored post', 'http://old/g')"
        )
        old.commit()
        old.close()

        conn = store.connect(path)
        self.addCleanup(conn.close)
        added, reason = store.add_filter(conn, "http://old/feed", "exclude", ["sponsored"])
        self.assertIsNone(reason)
        self.assertEqual(store.filters_for(conn, 1), [added])
        self.assertEqual([e.guid for e in store.unread(conn)], ["g"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: every `FilterStoreTest` test errors with `AttributeError: module 'feedwatch.store' has no attribute 'add_filter'` (or `list_filters` / `filters_for` / `remove_filter`).

- [ ] **Step 3: Add the `Filter` model**

In `feedwatch/models.py`, change the imports to:

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Literal
```

and append:

```python
@dataclass
class Filter:
    id: int
    feed_id: int
    kind: Literal["include", "exclude"]
    keywords: list[str]
```

- [ ] **Step 4: Add the table and the store functions**

In `feedwatch/store.py`, change the module docstring and imports to:

```python
"""The SQLite database both processes share: feeds, the entries seen in them, and their filters."""

import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append a third element to `SCHEMA_STEPS`, after the `entries` step:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Append to the end of `feedwatch/store.py`:

```python
def _feed_id(conn, url):
    row = conn.execute("SELECT id FROM feeds WHERE url = ?", (url,)).fetchone()
    return row[0] if row else None


def _clean_keywords(keywords):
    cleaned, seen = [], set()
    for word in keywords:
        word = word.strip()
        if word and word.casefold() not in seen:
            seen.add(word.casefold())
            cleaned.append(word)
    return cleaned


def add_filter(conn, url, kind, keywords):
    """Attach an include or exclude filter to a subscribed feed.

    Blank keywords are dropped and repeats, compared case-insensitively, are
    kept once. Returns (Filter, None), or (None, reason) when the feed is not
    subscribed or no keyword is left.
    """
    feed_id = _feed_id(conn, url)
    if feed_id is None:
        return None, f"not subscribed to {url}"
    keywords = _clean_keywords(keywords)
    if not keywords:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed_id, kind, json.dumps(keywords)),
        )
    return Filter(cursor.lastrowid, feed_id, kind, keywords), None


def filters_for(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [
        Filter(filter_id, owner, kind, json.loads(keywords))
        for filter_id, owner, kind, keywords in rows
    ]


def list_filters(conn, url):
    """Return (filters, None) for a subscribed feed, or (None, reason) when it is not subscribed."""
    feed_id = _feed_id(conn, url)
    if feed_id is None:
        return None, f"not subscribed to {url}"
    return filters_for(conn, feed_id), None


def remove_filter(conn, filter_id):
    """Delete a filter. Returns False when no filter has that id."""
    with conn:
        return conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,)).rowcount == 1
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all `FilterStoreTest` tests and the 4 existing `FeedwatchTest` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 2: Decide whether a title passes a feed's filters

**Files:**
- Create: `feedwatch/filters.py`
- Modify: `tests/test_filters.py` (add imports, append a test class before the `if __name__` block)

**Interfaces:**
- Consumes: `models.Filter(id, feed_id, kind, keywords)` from Task 1.
- Produces: `filters.keep(title: str, filters: list[Filter]) -> bool`. It returns `True` when the title passes every filter, and `True` for an empty list.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import filters, store
from feedwatch.models import Filter
```

and append, before `if __name__ == "__main__":`:

```python
def include(*words):
    return Filter(1, 1, "include", list(words))


def exclude(*words):
    return Filter(2, 1, "exclude", list(words))


class FilterMatchingTest(unittest.TestCase):
    def test_no_filters_keeps_everything(self):
        self.assertTrue(filters.keep("Anything at all", []))

    def test_an_include_keeps_a_title_with_any_of_its_keywords(self):
        self.assertTrue(filters.keep("Zig 0.12 is out", [include("rust", "zig")]))
        self.assertFalse(filters.keep("Go 1.30 is out", [include("rust", "zig")]))

    def test_an_exclude_drops_a_title_with_any_of_its_keywords(self):
        self.assertFalse(filters.keep("Sponsored: buy this", [exclude("sponsored", "ad")]))
        self.assertTrue(filters.keep("Rust 2.0 released", [exclude("sponsored", "ad")]))

    def test_matching_ignores_case(self):
        self.assertTrue(filters.keep("RUST weekly", [include("rust")]))
        self.assertTrue(filters.keep("rust weekly", [include("Rust")]))
        self.assertTrue(filters.keep("CAFÉ opens", [include("café")]))

    def test_a_keyword_inside_a_longer_word_does_not_match(self):
        self.assertFalse(filters.keep("Trusting your tools", [include("rust")]))
        self.assertTrue(filters.keep("Trusting your tools", [exclude("rust")]))

    def test_punctuation_next_to_a_keyword_still_matches(self):
        self.assertTrue(filters.keep("Why Rust's borrow checker", [include("rust")]))
        self.assertTrue(filters.keep("Rust, Go and Zig", [include("rust")]))
        self.assertTrue(filters.keep("(rust)", [include("rust")]))

    def test_a_keyword_with_symbols_matches_as_a_whole_word(self):
        self.assertTrue(filters.keep("Learning C++ today", [include("C++")]))
        self.assertFalse(filters.keep("Learning C today", [include("C++")]))

    def test_a_keyword_is_literal_text_not_a_pattern(self):
        self.assertFalse(filters.keep("Rust news", [include("r.st")]))

    def test_every_filter_must_pass(self):
        both = [include("rust"), include("async")]
        self.assertTrue(filters.keep("Async Rust in practice", both))
        self.assertFalse(filters.keep("Rust 2.0 released", both))

    def test_an_exclude_beats_an_include(self):
        mixed = [include("rust"), exclude("sponsored")]
        self.assertTrue(filters.keep("Rust 2.0 released", mixed))
        self.assertFalse(filters.keep("Sponsored Rust course", mixed))

    def test_an_empty_title_fails_an_include_and_passes_an_exclude(self):
        self.assertFalse(filters.keep("", [include("rust")]))
        self.assertTrue(filters.keep("", [exclude("rust")]))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: the module fails to import with `ImportError: cannot import name 'filters' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

Create `feedwatch/filters.py`:

```python
"""Decides whether an entry's title passes a feed's keyword filters."""

import re


def _mentions(title, keyword):
    # Lookarounds rather than \b: \b needs a word character beside it, so it
    # never matches at the edges of a keyword like "C++".
    pattern = r"(?<!\w)" + re.escape(keyword) + r"(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None


def keep(title, filters):
    """Return whether a title passes every filter.

    An include filter passes a title that mentions any of its keywords as a
    whole word, ignoring case; an exclude filter passes one that mentions none.
    """
    for f in filters:
        mentioned = any(_mentions(title, word) for word in f.keywords)
        if mentioned != (f.kind == "include"):
            return False
    return True
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/filters.py tests/test_filters.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 3: The poller applies a feed's filters before saving

**Files:**
- Modify: `feedwatch/poller.py:7` (import) and `feedwatch/poller.py:23-27` (the save)
- Modify: `tests/test_filters.py` (add imports, append a test class before the `if __name__` block)

**Interfaces:**
- Consumes: `store.filters_for(conn, feed_id) -> list[Filter]` and `store.add_filter(...)` (Task 1), `filters.keep(title, filters) -> bool` (Task 2), and the existing `poller.poll_once(conn, last_polled, now)` and `store.save_entries(conn, feed_id, entries)`.
- Produces: `poll_once` with the same signature. It now stores only the entries that pass the feed's filters.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import filters, poller, store
from feedwatch.models import Filter
```

and append, before `if __name__ == "__main__":`:

```python
RSS = b"""<rss><channel><title>t</title>
<item><guid>1</guid><title>Rust 2.0 released</title><link>http://x/1</link></item>
<item><guid>2</guid><title>Weekly sponsored roundup</title><link>http://x/2</link></item>
<item><guid>3</guid><title>Trusting your tools</title><link>http://x/3</link></item>
</channel></rss>"""


class FilterPollerTest(DatabaseTest):
    def poll(self):
        with mock.patch.object(poller.fetch, "fetch", return_value=RSS):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))

    def stored(self, feed_id=None):
        feed_id = self.feed.id if feed_id is None else feed_id
        rows = self.conn.execute("SELECT guid FROM entries WHERE feed_id = ?", (feed_id,))
        return {guid for (guid,) in rows}

    def test_a_feed_without_filters_stores_every_entry(self):
        self.poll()
        self.assertEqual(self.stored(), {"1", "2", "3"})

    def test_an_excluded_entry_is_never_stored(self):
        store.add_filter(self.conn, FEED, "exclude", ["sponsored"])
        self.poll()
        self.assertEqual(self.stored(), {"1", "3"})

    def test_only_included_entries_are_stored(self):
        store.add_filter(self.conn, FEED, "include", ["rust"])
        self.poll()
        self.assertEqual(self.stored(), {"1"})

    def test_entries_already_stored_are_not_refiltered(self):
        self.poll()
        store.add_filter(self.conn, FEED, "exclude", ["sponsored"])
        self.poll()
        self.assertEqual(self.stored(), {"1", "2", "3"})

    def test_one_feeds_filters_do_not_touch_another_feed(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        other = store.feeds(self.conn)[1]
        store.add_filter(self.conn, FEED, "include", ["rust"])
        self.poll()
        self.assertEqual(self.stored(), {"1"})
        self.assertEqual(self.stored(other.id), {"1", "2", "3"})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.FilterPollerTest -v`
Expected: `test_an_excluded_entry_is_never_stored`, `test_only_included_entries_are_stored` and `test_one_feeds_filters_do_not_touch_another_feed` FAIL, with sets containing the guids that should have been dropped. The other two PASS already.

- [ ] **Step 3: Write the implementation**

In `feedwatch/poller.py`, change the import line to:

```python
from feedwatch import fetch, filters, parse, store
```

and replace the last line of the loop body in `poll_once`:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        feed_filters = store.filters_for(conn, feed.id)
        kept = [e for e in entries if filters.keep(e["title"], feed_filters)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: `feedwatch filter add | list | remove`

**Files:**
- Modify: `feedwatch/cli.py` (module docstring, parser setup at lines 10-20, dispatch at lines 22-33, and a new `_filter` function)
- Modify: `tests/test_filters.py` (add imports, append a test class before the `if __name__` block)

**Interfaces:**
- Consumes: `store.add_filter`, `store.list_filters`, `store.remove_filter` (Task 1), and the existing `cli.main(argv=None) -> int`.
- Produces: the CLI commands below. Errors go to stderr with exit code 1. Success goes to stdout with exit code 0.
  - `filter add URL --include W [W ...]` / `--exclude W [W ...]` prints `added filter <id>`
  - `filter list URL` prints one line per filter: `<id>  <kind>  <kw1>, <kw2>`
  - `filter remove ID` prints nothing on success. An unknown id gives stderr `no filter with id <id>` and exit 1.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import io
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, filters, poller, store
from feedwatch.models import Filter
```

and append, before `if __name__ == "__main__":`:

```python
class FilterCliTest(DatabaseTest):
    def setUp(self):
        super().setUp()
        connect = store.connect
        patcher = mock.patch.object(store, "connect", lambda: connect(self.path))
        patcher.start()
        self.addCleanup(patcher.stop)

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_an_include_filter_is_added_and_listed(self):
        code, out, _ = self.run_cli("filter", "add", FEED, "--include", "rust", "zig")
        self.assertEqual(code, 0)
        filter_id = store.filters_for(self.conn, self.feed.id)[0].id
        self.assertEqual(out.strip(), f"added filter {filter_id}")
        code, out, _ = self.run_cli("filter", "list", FEED)
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), f"{filter_id}  include  rust, zig")

    def test_an_exclude_filter_is_added(self):
        code, _, _ = self.run_cli("filter", "add", FEED, "--exclude", "sponsored")
        self.assertEqual(code, 0)
        [added] = store.filters_for(self.conn, self.feed.id)
        self.assertEqual((added.kind, added.keywords), ("exclude", ["sponsored"]))

    def test_a_filter_for_an_unsubscribed_feed_is_refused(self):
        code, _, err = self.run_cli("filter", "add", "http://y/feed", "--include", "rust")
        self.assertEqual(code, 1)
        self.assertIn("http://y/feed", err)

    def test_listing_an_unsubscribed_feed_is_refused(self):
        code, _, err = self.run_cli("filter", "list", "http://y/feed")
        self.assertEqual(code, 1)
        self.assertIn("http://y/feed", err)

    def test_a_filter_with_no_keywords_is_refused(self):
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            cli.main(["filter", "add", FEED, "--include"])
        self.assertEqual(raised.exception.code, 2)
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_a_blank_keyword_is_refused(self):
        code, _, err = self.run_cli("filter", "add", FEED, "--include", "  ")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_include_and_exclude_together_are_refused(self):
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            cli.main(["filter", "add", FEED, "--include", "a", "--exclude", "b"])

    def test_a_removed_filter_is_gone(self):
        added, _ = store.add_filter(self.conn, FEED, "include", ["rust"])
        code, _, _ = self.run_cli("filter", "remove", str(added.id))
        self.assertEqual(code, 0)
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_removing_an_unknown_filter_is_refused(self):
        code, _, err = self.run_cli("filter", "remove", "999")
        self.assertEqual(code, 1)
        self.assertIn("no filter with id 999", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.FilterCliTest -v`
Expected: tests fail or error with argparse's `invalid choice: 'filter'` (raised as `SystemExit: 2`). The two `assertRaises(SystemExit)` tests may already pass.

- [ ] **Step 3: Write the implementation**

In `feedwatch/cli.py`, change the module docstring to:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, manage keyword filters."""
```

After the `read` parser lines (`read.add_argument("guids", nargs="+")`) and before `args = parser.parse_args(argv)`, add:

```python
    filter_cmd = commands.add_parser("filter", help="manage a feed's keyword filters")
    filter_commands = filter_cmd.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD",
                      help="keep only entries whose title has one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD",
                      help="drop entries whose title has any of these words")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter")
    filter_remove.add_argument("filter_id", type=int)
```

In the dispatch, insert a branch before the final `else:` so it reads:

```python
    elif args.command == "unread":
        for entry in store.unread(conn, args.limit):
            print(f"{entry.guid}  {entry.title}\n    {entry.link}")
    elif args.command == "filter":
        return _filter(conn, args)
    else:
        store.mark_read(conn, args.guids)
    return 0
```

Add this function between `main` and the `if __name__ == "__main__":` block:

```python
def _filter(conn, args):
    if args.filter_command == "add":
        kind = "include" if args.include is not None else "exclude"
        keywords = args.include if args.include is not None else args.exclude
        added, reason = store.add_filter(conn, args.url, kind, keywords)
        if added is None:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {added.id}")
    elif args.filter_command == "list":
        found, reason = store.list_filters(conn, args.url)
        if found is None:
            print(reason, file=sys.stderr)
            return 1
        for f in found:
            print(f"{f.id}  {f.kind}  {', '.join(f.keywords)}")
    else:
        if not store.remove_filter(conn, args.filter_id):
            print(f"no filter with id {args.filter_id}", file=sys.stderr)
            return 1
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS. That is the 4 `FeedwatchTest` tests plus every class in `tests/test_filters.py`.

- [ ] **Step 5: Smoke-test the real command against a throwaway home**

```bash
export HOME=$(mktemp -d)
python3 -m feedwatch.cli add http://x/feed
python3 -m feedwatch.cli filter add http://x/feed --exclude sponsored ad
python3 -m feedwatch.cli filter list http://x/feed
python3 -m feedwatch.cli filter add http://nope/feed --include rust; echo "exit $?"
python3 -m feedwatch.cli filter remove 1
python3 -m feedwatch.cli filter remove 1; echo "exit $?"
```

Expected, in order: `added filter 1`; `1  exclude  sponsored, ad`; `not subscribed to http://nope/feed` then `exit 1`; nothing; `no filter with id 1` then `exit 1`.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

## After the last task

Record in the ledger that `docs/ARCHITECTURE.md` needs two changes. The assembly gains **filters**, which decides whether a title passes a feed's keyword filters, owns matching and never touches the database; `poller` now calls it. Under "Where state lives", the tables become `feeds`, `entries` and `filters`. Then invoke `dopamine:finishing-work`, which places those changes.
````


## p003

#### Final message

I wrote the implementation plan and committed it as `4d252bb plan: keyword filters` at `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`. No code in the repo was changed. Before writing the plan I built all of its code and tests in a scratch copy: all 34 tests passed (the 4 existing ones plus 30 new). The scratch copy is deleted.

**What the plan builds, in five tasks:**
1. **Matching:** a `Filter` model and a new `feedwatch/filters.py` that checks titles. Matching ignores case and works on whole words. Keywords like "C++" match exactly as typed. A title must get past every filter on its feed.
2. **Storage:** a new `filters` table in the database, added in a way that lets an existing database pick it up when it next opens. New functions `find_feed`, `add_filter`, `filters` and `remove_filter`. A filter is refused if its feed isn't subscribed (the message names the URL) or if it has no keywords; blank keywords count as none.
3. **Commands:** `feedwatch filter add|list|remove`, with the exit codes and output spelled out.
4. **Poller:** before saving new entries it drops the ones a filter rejects. It reads the filters on every poll, so a filter added from the command line applies without restarting the poller.
5. **Close-out:** a quick manual run of the commands. Then the changes `ARCHITECTURE.md` will need (a new `filters` module and a third table) are noted in the run's log of what happened, not written into the document. Last, `dopamine:finishing-work` runs, which updates that document from the log.

**Decisions the spec didn't settle, which you should check:**
- **Several filters on one feed:** a title must pass all of them. I also put this in the log as a decision I made.
- **Blank keywords:** these are dropped, so `--include " "` is refused as a filter with no keywords.
- **`filter list` on a feed that isn't subscribed:** this is refused with the URL in the message, the same as `filter add`.
- **Output:** `filter add` prints `added filter <id>`. `filter list` prints one line per filter as `<id>  <kind>  kw1, kw2`.

**Files listed in `.dopamine/config` that don't exist:** `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md`. The plan doesn't create them.

I didn't run `dopamine:finishing-work` for this planning step. The plan has it run at the end of implementation instead.

Please review the plan and check it captures what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores an entry whose title a filter drops.

**Architecture:** A new pure module `feedwatch/filters.py` decides whether a title gets past a list of filters (case-insensitive, whole-word). `store` gains a `filters` table (added as a new idempotent `SCHEMA_STEPS` entry, so old databases upgrade on connect) and functions to add, list and remove filters. `cli` gains `feedwatch filter add|list|remove`. `poller.poll_once` reads a feed's filters on every poll and passes only the surviving entries to `store.save_entries`. Already-stored entries are never touched.

**Tech Stack:** Python 3 standard library only (`sqlite3`, `json`, `re`, `argparse`), `unittest` for tests.

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Matching is on the entry's **title** only, case-insensitive, on whole words. Not on the body; no regular expressions from the user.
- An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords.
- Commands, exactly: `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL`; `feedwatch filter remove FILTER_ID`.
- A filter for a feed that is not subscribed is refused, with a message naming the URL.
- A filter with no keywords is refused.
- Filters live in the same SQLite database; a database created before this feature keeps working.
- An entry a filter drops is never stored. Entries already stored are not re-filtered.
- Standard library first (DESIGN.md): no new dependencies.
- Module ownership (ARCHITECTURE.md): `store` owns the schema, `poller` owns the schedule, `cli` owns presentation. The new `filters` module owns keyword matching and never touches the database.
- Living documents (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, and the other `living:` entries in `.dopamine/config`) are **not** edited during execution. Record their consequences in the ledger (see "For the ledger" at the end); the closing sweep places them.

## Review Focus

Decisions the spec leaves open, and the inputs most likely to bite a user. Each has a test in the task named.

1. **A filter added while the poller is running** must apply at the next poll, without restarting the poller — the CLI and the poller are separate processes sharing one database. (Task 4: `test_a_filter_added_while_the_poller_runs_applies_at_the_next_poll`.)
2. **Punctuation next to a word** — `"Python's"`, `"(Rust)"`, `"Rust:"`, `"Go, Rust, Zig"` all contain the whole word; `"Pythonic"` and `"Trust"` do not. A naive `title.split()` would miss the first set. (Task 1: `test_punctuation_next_to_a_word_still_bounds_it`, `test_a_keyword_inside_a_longer_word_does_not_match`.)
3. **Blank keywords** — `--include ""` or `--include " "` gets past argparse's `nargs="+"` but is a filter with no keywords and must be refused, not stored as a filter that matches nothing. (Task 2: `test_a_filter_with_no_keywords_is_refused`; Task 3: `test_a_filter_with_no_keywords_is_refused`.)
4. **Several filters on one feed** — a title must get past *every* filter: each include filter must match, and no exclude filter may. (Task 1: `test_a_title_must_get_past_every_filter`, `test_two_include_filters_both_have_to_match`.)
5. **Keywords with regex metacharacters** — `C++`, `C#` must match literally and must not crash; `\b` alone would never match a keyword ending in `+`. (Task 1: `test_keywords_with_symbols_match_literally`.)

---

## File Structure

- Create `feedwatch/filters.py` — pure matching: `mentions(title, keyword)` and `passes(title, feed_filters)`. No I/O.
- Modify `feedwatch/models.py` — add the `Filter` dataclass.
- Modify `feedwatch/store.py` — `filters` table schema step; `find_feed`, `add_filter`, `filters`, `remove_filter`.
- Modify `feedwatch/cli.py` — `filter` subcommand with `add`, `list`, `remove`.
- Modify `feedwatch/poller.py` — apply filters in `poll_once` before `save_entries`.
- Create `tests/test_filters.py`, `tests/test_store_filters.py`, `tests/test_cli_filters.py`, `tests/test_poller_filters.py`. (The existing `tests/test_feedwatch.py` is left as is.)

Run tests from the repository root. The full suite: `python3 -m unittest discover -s tests -v`. One test: `python3 -m unittest tests.test_filters.MentionsTest.test_matching_ignores_case -v`.

Stored shape of a filter: one row per filter in `filters (id, feed_id, kind, keywords)`, `kind` is `'include'` or `'exclude'`, `keywords` is a JSON array of strings as the user typed them (trimmed). Case is folded only at match time.

---

### Task 1: The `Filter` model and keyword matching

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Create: `feedwatch/filters.py`
- Test: `tests/test_filters.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])` — `kind` is `"include"` or `"exclude"`.
  - `feedwatch.filters.mentions(title: str, keyword: str) -> bool`
  - `feedwatch.filters.passes(title: str, feed_filters: list[Filter]) -> bool` — True when the title gets past every filter; `[]` lets everything through.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import unittest

from feedwatch import filters
from feedwatch.models import Filter


def include(*keywords):
    return Filter(1, 1, "include", list(keywords))


def exclude(*keywords):
    return Filter(2, 1, "exclude", list(keywords))


class MentionsTest(unittest.TestCase):
    def test_matching_ignores_case(self):
        self.assertTrue(filters.mentions("Why PYTHON wins", "python"))

    def test_a_keyword_inside_a_longer_word_does_not_match(self):
        self.assertFalse(filters.mentions("Pythonic idioms", "python"))
        self.assertFalse(filters.mentions("Trust issues", "rust"))

    def test_punctuation_next_to_a_word_still_bounds_it(self):
        cases = [
            ("Python's new release", "python"),
            ("(Rust) in 2026", "rust"),
            ("Rust: a review", "rust"),
            ("Go, Rust, Zig", "rust"),
        ]
        for title, keyword in cases:
            with self.subTest(title=title):
                self.assertTrue(filters.mentions(title, keyword))

    def test_keywords_with_symbols_match_literally(self):
        self.assertTrue(filters.mentions("Modern C++ in practice", "c++"))
        self.assertTrue(filters.mentions("What's new in C#", "C#"))
        self.assertFalse(filters.mentions("Modern C in practice", "c++"))

    def test_a_keyword_can_be_a_phrase(self):
        self.assertTrue(filters.mentions("Notes on Machine Learning", "machine learning"))


class PassesTest(unittest.TestCase):
    def test_no_filters_keeps_everything(self):
        self.assertTrue(filters.passes("anything", []))

    def test_include_keeps_a_title_with_any_of_its_keywords(self):
        self.assertTrue(filters.passes("Rust 2.0 released", [include("python", "rust")]))
        self.assertFalse(filters.passes("Zig 1.0 released", [include("python", "rust")]))

    def test_exclude_drops_a_title_with_any_of_its_keywords(self):
        self.assertFalse(filters.passes("Sponsored: buy now", [exclude("sponsored", "ad")]))
        self.assertTrue(filters.passes("Rust 2.0 released", [exclude("sponsored", "ad")]))

    def test_a_title_must_get_past_every_filter(self):
        feed_filters = [include("rust"), exclude("sponsored")]
        self.assertTrue(filters.passes("Rust 2.0 released", feed_filters))
        self.assertFalse(filters.passes("Sponsored: learn Rust", feed_filters))
        self.assertFalse(filters.passes("Zig 1.0 released", feed_filters))

    def test_two_include_filters_both_have_to_match(self):
        feed_filters = [include("rust"), include("release")]
        self.assertTrue(filters.passes("Rust release notes", feed_filters))
        self.assertFalse(filters.passes("Rust tips", feed_filters))

    def test_an_empty_title_fails_an_include_and_passes_an_exclude(self):
        self.assertFalse(filters.passes("", [include("rust")]))
        self.assertTrue(filters.passes("", [exclude("rust")]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: ERROR — `ImportError: cannot import name 'filters' from 'feedwatch'` (or `cannot import name 'Filter'`).

- [ ] **Step 3: Add the `Filter` model**

Append to `feedwatch/models.py`:

```python


@dataclass
class Filter:
    id: int
    feed_id: int
    kind: str  # "include" or "exclude"
    keywords: list[str]
```

- [ ] **Step 4: Write the matching module**

Create `feedwatch/filters.py`:

```python
"""Decides whether an entry's title gets past a feed's keyword filters."""

import re


def mentions(title, keyword):
    """Return True when keyword appears in title as a whole word, ignoring case."""
    # Lookarounds rather than \b: \b needs a word character beside it, so a
    # keyword ending in punctuation, like "C++", would never match.
    pattern = r"(?<!\w)" + re.escape(keyword) + r"(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None


def passes(title, feed_filters):
    """Return True when title gets past every filter in feed_filters.

    An include filter lets title past when it mentions at least one of the
    filter's keywords; an exclude filter when it mentions none of them.
    """
    for feed_filter in feed_filters:
        hit = any(mentions(title, keyword) for keyword in feed_filter.keywords)
        if feed_filter.kind == "include" and not hit:
            return False
        if feed_filter.kind == "exclude" and hit:
            return False
    return True
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_filters -v`
Expected: 11 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filters.py tests/test_filters.py
git commit -m "feat: keyword matching for feed filters"
```

---

### Task 2: Store filters in the database

**Files:**
- Modify: `feedwatch/store.py` (module docstring, imports, `SCHEMA_STEPS`, new functions after `feeds`)
- Test: `tests/test_store_filters.py`

**Interfaces:**
- Consumes: `feedwatch.models.Filter` (Task 1).
- Produces:
  - `store.find_feed(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, feed_url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]` — `(filter_id, None)` on success, `(None, reason)` when refused. Reasons: `"a filter needs at least one keyword"`, `f"not subscribed to {feed_url}"`.
  - `store.filters(conn, feed_id: int) -> list[Filter]` — oldest first.
  - `store.remove_filter(conn, filter_id: int) -> bool` — False when no filter has that id.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_store_filters.py`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store


class StoreFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        self.conn = store.connect(self.path)
        store.add_feed(self.conn, "http://x/feed", "x")
        self.feed = store.find_feed(self.conn, "http://x/feed")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_a_filter_is_stored_and_listed_with_its_id(self):
        filter_id, reason = store.add_filter(self.conn, "http://x/feed", "include", ["Rust", "zig"])
        self.assertIsNone(reason)
        [stored] = store.filters(self.conn, self.feed.id)
        self.assertEqual(
            (stored.id, stored.feed_id, stored.kind, stored.keywords),
            (filter_id, self.feed.id, "include", ["Rust", "zig"]),
        )

    def test_find_feed_returns_none_for_an_unsubscribed_url(self):
        self.assertIsNone(store.find_feed(self.conn, "http://y/feed"))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, "http://y/feed", "include", ["rust"])
        self.assertIsNone(filter_id)
        self.assertIn("http://y/feed", reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        for keywords in [[], [""], ["  ", "\t"]]:
            with self.subTest(keywords=keywords):
                filter_id, reason = store.add_filter(self.conn, "http://x/feed", "exclude", keywords)
                self.assertIsNone(filter_id)
                self.assertIn("keyword", reason)
        self.assertEqual(store.filters(self.conn, self.feed.id), [])

    def test_blank_keywords_are_dropped_and_the_rest_trimmed(self):
        store.add_filter(self.conn, "http://x/feed", "include", [" rust ", ""])
        self.assertEqual(store.filters(self.conn, self.feed.id)[0].keywords, ["rust"])

    def test_removing_a_filter(self):
        filter_id, _ = store.add_filter(self.conn, "http://x/feed", "include", ["rust"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.filters(self.conn, self.feed.id), [])
        self.assertFalse(store.remove_filter(self.conn, filter_id))

    def test_a_database_from_before_filters_keeps_its_entries_and_accepts_filters(self):
        old_path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(old_path)
        for step in store.SCHEMA_STEPS[:2]:
            old.execute(step)
        with old:
            old.execute("INSERT INTO feeds (url, title) VALUES ('http://old/feed', 'old')")
            old.execute(
                "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'g', 'Old entry', 'http://old/g')"
            )
        old.close()

        conn = store.connect(old_path)
        try:
            self.assertEqual([e.guid for e in store.unread(conn)], ["g"])
            filter_id, reason = store.add_filter(conn, "http://old/feed", "exclude", ["old"])
            self.assertIsNone(reason)
            self.assertEqual(len(store.filters(conn, 1)), 1)
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
```

`SCHEMA_STEPS[:2]` is the schema as it was before this feature; the last test builds a database with only those steps, the way an older feedwatch left it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store_filters -v`
Expected: ERROR in `setUp` — `AttributeError: module 'feedwatch.store' has no attribute 'find_feed'`.

- [ ] **Step 3: Implement**

In `feedwatch/store.py`:

Replace the module docstring (it now describes three things):

```python
"""The SQLite database both processes share: feeds, their filters, and the entries seen in them."""
```

Change the imports to:

```python
import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append a third step to `SCHEMA_STEPS`, after the `entries` step. Never edit the existing steps; the schema comment above `SCHEMA_STEPS` already explains why appending keeps older databases working.

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Add these functions between `feeds` and `save_entries`:

```python
def find_feed(conn, url):
    """Return the subscribed feed with this URL, or None."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def add_filter(conn, feed_url, kind, keywords):
    """Attach a filter to a subscribed feed.

    kind is "include" or "exclude". Blank keywords are dropped. Returns
    (filter_id, None), or (None, reason) when the feed is not subscribed or no
    keyword is left.
    """
    keywords = [k.strip() for k in keywords if k.strip()]
    if not keywords:
        return None, "a filter needs at least one keyword"
    feed = find_feed(conn, feed_url)
    if feed is None:
        return None, f"not subscribed to {feed_url}"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(keywords)),
        )
    return cursor.lastrowid, None


def filters(conn, feed_id):
    """Return the feed's filters, oldest first."""
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [Filter(id_, feed_id_, kind, json.loads(keywords))
            for id_, feed_id_, kind, keywords in rows]


def remove_filter(conn, filter_id):
    """Delete a filter. Returns False when no filter has this id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    return cursor.rowcount == 1
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_store_filters tests.test_feedwatch -v`
Expected: 11 tests, OK (7 new, 4 existing).

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 3: The `feedwatch filter` commands

**Files:**
- Modify: `feedwatch/cli.py`
- Test: `tests/test_cli_filters.py`

**Interfaces:**
- Consumes: `store.find_feed`, `store.add_filter`, `store.filters`, `store.remove_filter` (Task 2).
- Produces: `cli.run_filter(conn, args) -> int` (exit code), called from `cli.main`. User-visible output:
  - `filter add` prints `added filter <id>`; refusals go to stderr with exit 1. Missing keywords after `--include`/`--exclude`, or both flags at once, are argparse usage errors (exit 2).
  - `filter list` prints one line per filter: `<id>  <kind>  <kw1>, <kw2>` (two spaces between columns, like `unread`); nothing when the feed has no filters; `not subscribed to <url>` on stderr with exit 1 for an unknown feed.
  - `filter remove` prints nothing on success; `no filter with id <id>` on stderr with exit 1 otherwise.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_cli_filters.py`. `cli.main` opens the default database through `store.connect()`, so the tests patch `store.connect` to hand back a temporary one.

```python
import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from feedwatch import cli, store


class FilterCommandTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")
        patcher = mock.patch("feedwatch.store.connect", return_value=self.conn)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = cli.main(list(argv))
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def test_add_then_list_shows_the_filter_with_its_id(self):
        code, out, _ = self.run_cli("filter", "add", "http://x/feed", "--include", "rust", "zig")
        self.assertEqual((code, out), (0, "added filter 1\n"))
        self.run_cli("filter", "add", "http://x/feed", "--exclude", "sponsored")
        code, out, _ = self.run_cli("filter", "list", "http://x/feed")
        self.assertEqual(code, 0)
        self.assertEqual(out, "1  include  rust, zig\n2  exclude  sponsored\n")

    def test_adding_to_an_unsubscribed_feed_fails_naming_the_url(self):
        code, _, err = self.run_cli("filter", "add", "http://y/feed", "--include", "rust")
        self.assertEqual(code, 1)
        self.assertIn("http://y/feed", err)

    def test_listing_an_unsubscribed_feed_fails_naming_the_url(self):
        code, _, err = self.run_cli("filter", "list", "http://y/feed")
        self.assertEqual(code, 1)
        self.assertIn("http://y/feed", err)

    def test_a_filter_with_no_keywords_is_refused(self):
        code, _, _ = self.run_cli("filter", "add", "http://x/feed", "--include")
        self.assertNotEqual(code, 0)
        code, _, err = self.run_cli("filter", "add", "http://x/feed", "--include", " ")
        self.assertEqual(code, 1)
        self.assertIn("keyword", err)
        self.assertEqual(self.run_cli("filter", "list", "http://x/feed")[1], "")

    def test_include_and_exclude_together_is_refused(self):
        code, _, _ = self.run_cli("filter", "add", "http://x/feed", "--include", "a", "--exclude", "b")
        self.assertNotEqual(code, 0)

    def test_remove_deletes_the_filter(self):
        self.run_cli("filter", "add", "http://x/feed", "--include", "rust")
        self.assertEqual(self.run_cli("filter", "remove", "1")[0], 0)
        self.assertEqual(self.run_cli("filter", "list", "http://x/feed")[1], "")

    def test_removing_an_unknown_id_fails_naming_it(self):
        code, _, err = self.run_cli("filter", "remove", "42")
        self.assertEqual(code, 1)
        self.assertIn("42", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_cli_filters -v`
Expected: FAIL — every test gets exit code 2 from argparse (`invalid choice: 'filter'`), so the assertions on codes and output fail.

- [ ] **Step 3: Implement**

In `feedwatch/cli.py`, replace the module docstring:

```python
"""feedwatch's command line: subscribe, filter feeds, list unread entries, mark them read."""
```

In `main`, after `read.add_argument("guids", nargs="+")` and before `args = parser.parse_args(argv)`, add:

```python
    filter_ = commands.add_parser("filter", help="keep or drop a feed's new entries by title keywords")
    filter_actions = filter_.add_subparsers(dest="action", required=True)
    filter_add = filter_actions.add_parser("add", help="attach a filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD", help="keep only titles with one of these")
    kind.add_argument("--exclude", nargs="+", metavar="WORD", help="drop titles with any of these")
    filter_list = filter_actions.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_actions.add_parser("remove", help="remove a filter")
    filter_remove.add_argument("filter_id", type=int)
```

In the dispatch, add a branch between the `add` branch and the `unread` branch:

```python
    elif args.command == "filter":
        return run_filter(conn, args)
```

Add this function after `main`, before `if __name__ == "__main__":`:

```python
def run_filter(conn, args):
    if args.action == "add":
        kind = "include" if args.include is not None else "exclude"
        filter_id, reason = store.add_filter(conn, args.url, kind, args.include or args.exclude)
        if filter_id is None:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.action == "list":
        feed = store.find_feed(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for feed_filter in store.filters(conn, feed.id):
            print(f"{feed_filter.id}  {feed_filter.kind}  {', '.join(feed_filter.keywords)}")
    elif not store.remove_filter(conn, args.filter_id):
        print(f"no filter with id {args.filter_id}", file=sys.stderr)
        return 1
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_cli_filters -v`
Expected: 7 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/cli.py tests/test_cli_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

### Task 4: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py`
- Test: `tests/test_poller_filters.py`

**Interfaces:**
- Consumes: `store.filters`, `store.add_filter`, `store.find_feed` (Task 2); `filters.passes` (Task 1).
- Produces: no new names. `poll_once(conn, last_polled, now)` keeps its signature; it now stores only entries that get past the feed's filters.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_poller_filters.py`. `fetch.fetch` is patched so no network is used; every feed returns the same three entries.

```python
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path
from unittest import mock

from feedwatch import poller, store

RSS = b"""<rss><channel><title>t</title>
<item><guid>r</guid><title>Rust 2.0 released</title><link>http://x/r</link></item>
<item><guid>z</guid><title>Zig 1.0 released</title><link>http://x/z</link></item>
<item><guid>s</guid><title>Sponsored: learn Rust</title><link>http://x/s</link></item>
</channel></rss>"""


class PollerFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")
        patcher = mock.patch("feedwatch.fetch.fetch", return_value=RSS)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.now = datetime(2026, 3, 2, 9, 0)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def stored_guids(self):
        return sorted(guid for (guid,) in self.conn.execute("SELECT guid FROM entries"))

    def test_without_filters_every_entry_is_stored(self):
        poller.poll_once(self.conn, {}, self.now)
        self.assertEqual(self.stored_guids(), ["r", "s", "z"])

    def test_entries_a_filter_drops_are_never_stored(self):
        store.add_filter(self.conn, "http://x/feed", "include", ["rust"])
        store.add_filter(self.conn, "http://x/feed", "exclude", ["sponsored"])
        poller.poll_once(self.conn, {}, self.now)
        self.assertEqual(self.stored_guids(), ["r"])

    def test_a_filter_added_while_the_poller_runs_applies_at_the_next_poll(self):
        last_polled = {}
        store.add_filter(self.conn, "http://x/feed", "include", ["zig"])
        poller.poll_once(self.conn, last_polled, self.now)
        store.add_filter(self.conn, "http://x/feed", "exclude", ["zig"])
        self.conn.execute("DELETE FROM entries")
        poller.poll_once(self.conn, last_polled, self.now + timedelta(minutes=30))
        self.assertEqual(self.stored_guids(), [])

    def test_entries_already_stored_are_not_refiltered(self):
        last_polled = {}
        poller.poll_once(self.conn, last_polled, self.now)
        store.add_filter(self.conn, "http://x/feed", "include", ["zig"])
        poller.poll_once(self.conn, last_polled, self.now + timedelta(minutes=30))
        self.assertEqual(self.stored_guids(), ["r", "s", "z"])

    def test_filters_on_one_feed_leave_other_feeds_alone(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, "http://x/feed", "include", ["zig"])
        poller.poll_once(self.conn, {}, self.now)
        y = store.find_feed(self.conn, "http://y/feed")
        rows = self.conn.execute("SELECT guid FROM entries WHERE feed_id = ? ORDER BY guid", (y.id,))
        self.assertEqual([guid for (guid,) in rows], ["r", "s", "z"])


if __name__ == "__main__":
    unittest.main()
```

The "next poll" test deletes the entries between polls so that the second poll has something to store: if the poller used the filters it saw first (include `zig`), `z` would come back; with the current filters (include `zig` and exclude `zig`), nothing does.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_poller_filters -v`
Expected: FAILED (failures=2) — `test_entries_a_filter_drops_are_never_stored` and `test_a_filter_added_while_the_poller_runs_applies_at_the_next_poll`, because the poller stores all of `r`, `s`, `z`. The other three already pass; they guard against over-filtering and must stay green.

- [ ] **Step 3: Implement**

In `feedwatch/poller.py`, change the import line to:

```python
from feedwatch import fetch, filters, parse, store
```

Replace the last line of the loop in `poll_once`:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        # Read on every poll, not once at startup, so a filter added from the CLI
        # applies without restarting the poller.
        feed_filters = store.filters(conn, feed.id)
        kept = [e for e in entries if filters.passes(e["title"], feed_filters)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

Name the local `feed_filters`, never `filters`: a local called `filters` would shadow the module.

- [ ] **Step 4: Run the full suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: 34 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 5: Close the work

- [ ] **Step 1: Smoke-test the CLI against a throwaway database**

```bash
python3 - <<'EOF'
import tempfile
from pathlib import Path
from unittest import mock
from feedwatch import cli, store
with tempfile.TemporaryDirectory() as d:
    conn = store.connect(Path(d) / "feeds.db")
    with mock.patch("feedwatch.store.connect", return_value=conn):
        cli.main(["add", "http://x/feed"])
        cli.main(["filter", "add", "http://x/feed", "--include", "rust", "C++"])
        cli.main(["filter", "list", "http://x/feed"])
        print("exit", cli.main(["filter", "add", "http://nope/feed", "--exclude", "ad"]))
EOF
```

Expected output (the stderr line, `not subscribed to ...`, may print first):

```
added filter 1
1  include  rust, C++
not subscribed to http://nope/feed
exit 1
```

- [ ] **Step 2: Record living-document consequences in the ledger** (do not edit the documents)

Add these entries to the ledger for this plan:
- ARCHITECTURE.md "The assembly" gains a fifth module: **filters** — decides whether an entry's title gets past a feed's keyword filters. Owns matching; never touches the database.
- ARCHITECTURE.md "How they talk": `poller` also calls `filters`; `cli` still calls only `store`.
- ARCHITECTURE.md "Where state lives": the database now has a third table, `filters`.
- Ruling: several filters on one feed combine with AND — a title must get past every filter. The spec did not say; this plan chose it.

- [ ] **Step 3: Invoke `dopamine:finishing-work`**

Run the sweep before the workspace is cleaned up, then `superpowers:finishing-a-development-branch`.
````


## p004

#### Final message

I wrote the implementation plan and committed it as `37b1a04` ("plan: keyword filters") on `master`, in `<repo>`. Nothing has been implemented.

**Plan:** `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`

It has four tasks, each test-first with full code and its own commit:
1. **Matching:** a new `Filter` dataclass and a new module `feedwatch/filters.py` that checks a title against a feed's filters.
2. **Storage:** a new `filters` table added as a third schema step, so databases created before this feature upgrade themselves. It adds `feed_by_url`, `add_filter`, `filters_for` and `remove_filter`. A test builds a database with the old schema to prove it keeps working.
3. **Poller:** it reads a feed's filters on every poll and drops filtered entries before saving them.
4. **Commands:** `feedwatch filter add|list|remove`. Refusals print a message and exit 1; wrong usage exits 2.

All new tests go in `tests/test_filters.py`. pytest isn't installed, so the plan uses `python3 -m unittest`. I checked that this command works on the existing tests, and that the regex and command-line parsing behave as the plan assumes.

**Decisions the spec left open (listed in the plan):**
- **Several filters on one feed:** an entry is kept only if it passes every filter. With two include filters, a title must match both. This may not be what a user expects.
- **Keyword cleanup:** keywords are lowercased and extra spaces removed. Blanks are dropped, so `--include ""` counts as no keywords and is refused.
- **Phrases:** a keyword can be a phrase such as `"machine learning"`.
- **Whole words:** "whole word" is defined so that `go` does not match "Google" but `c++` does match "C++ 26". The usual `\b` regex approach would make `c++` never match.
- **Dropped entries aren't remembered:** if a filter is removed while a dropped entry is still in the feed, the next poll stores it.

**Review Focus (each has a test in the task that owns the code):**
- keywords with punctuation at the edge, like `c++` and `c#`
- entries with no title
- blank keywords
- a filter added while the poller is running takes effect on its next poll
- removing a filter id that doesn't exist

**Things to know:**
- `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` as living documents, but neither file exists in this repo. Only `DESIGN.md` and `ARCHITECTURE.md` do.
- The plan adds a new module and a new table, which `ARCHITECTURE.md` will need to reflect. Following the documentation rules, the plan says to record these in the ledger during execution and update the documents in the `dopamine:finishing-work` sweep afterwards, rather than editing them mid-work.
- I didn't run `dopamine:finishing-work` for this planning step. Writing the plan changed no code or system facts, so there was nothing to update. It belongs at the end of executing the plan.

Please review the plan and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores entries whose titles the filters drop.

**Architecture:** A new pure module `feedwatch/filters.py` decides whether a title passes a feed's filters. `store` gains a `filters` table (added as a new idempotent schema step, so old databases pick it up) and functions to add, list and remove filters. `poller` loads a feed's filters on every poll and drops entries before calling `store.save_entries`. `cli` gains `filter add|list|remove`.

**Tech Stack:** Python 3 standard library only (`sqlite3`, `re`, `json`, `argparse`, `unittest`). No pytest in this environment; tests run with `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Matching is case-insensitive, on whole words, against the entry's **title** only. Not the body; no regular expressions from the user.
- `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL`; `feedwatch filter remove FILTER_ID`.
- An entry a filter drops is never stored.
- A filter for a feed that is not subscribed is refused, with a message naming the URL.
- A filter with no keywords is refused.
- Filters live in the same SQLite database; a database created before this feature keeps working.
- Entries already stored are not re-filtered.
- Standard library first (DESIGN.md principle): no new dependencies.
- Comments follow `dopamine:writing-code-comments`: only why, contract or warning.

## Decisions this plan makes where the spec is silent

- **Several filters on one feed compose with AND.** An entry is kept only if it passes every filter: each include filter must match, and no exclude filter may match. This is the spec's per-filter rule applied to each filter in turn.
- **Keywords are normalised on the way in:** whitespace trimmed and collapsed, lowercased, blanks and repeats dropped. `--include ""` therefore counts as "no keywords" and is refused.
- **A keyword may be a phrase** (`"machine learning"`); it matches the words in order with any whitespace between them.
- **Whole word** means the keyword is not preceded or followed by a letter, digit or underscore. So `go` does not match `Google`, and `c++` matches `C++ 26`.
- **A dropped entry is not remembered.** If the filter is later removed and the entry is still in the feed, the next poll stores it as new. Stored entries are never touched (the spec's "not re-filtered").
- **Filters are stored as one row per filter**, keywords as a JSON array in a `TEXT` column.

## Review Focus

1. A keyword with punctuation at its edge (`c++`, `c#`): a reasonable person expects it to match `C++ 26`. A `\b` regex never matches there, so the filter would silently keep everything. Pinned in Task 1.
2. An entry with no title (`<item>` without `<title>`): an include filter drops it and an exclude filter keeps it, without raising. Pinned in Task 1.
3. Blank or whitespace-only keywords (`--include ""`, `--include "  " rust`): blanks are ignored, and a filter left with none is refused like an empty one. Pinned in Task 2.
4. A filter added while the poller is already running applies from its next poll, without a restart, because the poller reads filters on every poll. Pinned in Task 3.
5. Removing a filter id that does not exist (a typo): the user is told and the exit code is 1, rather than a silent success. Pinned in Task 4.

---

## File Structure

- Create `feedwatch/filters.py`: pure matching (`matches`, `keeps`). Knows nothing about SQLite or HTTP.
- Modify `feedwatch/models.py`: add the `Filter` dataclass.
- Modify `feedwatch/store.py`: `filters` schema step, `feed_by_url`, `add_filter`, `filters_for`, `remove_filter`, private `_clean_keywords`.
- Modify `feedwatch/poller.py`: apply filters in `poll_once`.
- Modify `feedwatch/cli.py`: `filter add|list|remove`.
- Create `tests/test_filters.py`: all tests for this feature. The existing `tests/test_feedwatch.py` stays as it is.

Run every test: `python3 -m unittest tests/test_feedwatch.py tests/test_filters.py -v`

---

### Task 1: Matching titles against filters

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Create: `feedwatch/filters.py`
- Create: `tests/test_filters.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])`, where `kind` is `"include"` or `"exclude"`.
  - `feedwatch.filters.matches(title: str, keywords: list[str]) -> bool`
  - `feedwatch.filters.keeps(title: str, filters: list[Filter]) -> bool`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import unittest

from feedwatch import filters
from feedwatch.models import Filter


def include(*keywords):
    return Filter(1, 1, "include", list(keywords))


def exclude(*keywords):
    return Filter(2, 1, "exclude", list(keywords))


class MatchingTest(unittest.TestCase):
    def test_matching_ignores_case(self):
        self.assertTrue(filters.matches("RUST 1.80 released", ["rust"]))

    def test_a_keyword_matches_only_a_whole_word(self):
        self.assertFalse(filters.matches("Trusted builds", ["rust"]))
        self.assertFalse(filters.matches("Google ships a thing", ["go"]))
        self.assertTrue(filters.matches("Why Go, not Rust?", ["go"]))

    def test_a_keyword_with_punctuation_at_its_edge_matches(self):
        self.assertTrue(filters.matches("What's new in C++ 26", ["c++"]))
        self.assertTrue(filters.matches("C# 13 is out", ["c#"]))
        self.assertFalse(filters.matches("cpp news", ["c++"]))

    def test_a_phrase_matches_its_words_across_any_whitespace(self):
        self.assertTrue(filters.matches("New in Machine   Learning", ["machine learning"]))
        self.assertFalse(filters.matches("machine shop learning day", ["machine learning"]))

    def test_any_one_keyword_is_enough(self):
        self.assertTrue(filters.matches("Python 3.14", ["rust", "python"]))


class KeepsTest(unittest.TestCase):
    def test_no_filters_keep_everything(self):
        self.assertTrue(filters.keeps("Anything at all", []))

    def test_an_include_filter_keeps_only_titles_with_one_of_its_keywords(self):
        self.assertTrue(filters.keeps("Rust 1.80 released", [include("rust", "python")]))
        self.assertFalse(filters.keeps("Weekly Go news", [include("rust", "python")]))

    def test_an_exclude_filter_drops_titles_with_any_of_its_keywords(self):
        self.assertFalse(filters.keeps("Sponsored: Rust course", [exclude("sponsored", "ad")]))
        self.assertTrue(filters.keeps("Rust 1.80 released", [exclude("sponsored", "ad")]))

    def test_every_filter_on_a_feed_applies(self):
        both = [include("rust"), exclude("sponsored")]
        self.assertTrue(filters.keeps("Rust 1.80 released", both))
        self.assertFalse(filters.keeps("Sponsored: Rust course", both))
        two_includes = [include("rust"), include("release")]
        self.assertTrue(filters.keeps("Rust release notes", two_includes))
        self.assertFalse(filters.keeps("Rust tips", two_includes))

    def test_an_entry_with_no_title(self):
        self.assertFalse(filters.keeps("", [include("rust")]))
        self.assertTrue(filters.keeps("", [exclude("sponsored")]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -v`
Expected: ERROR, `ImportError: cannot import name 'filters' from 'feedwatch'` (or `cannot import name 'Filter'`).

- [ ] **Step 3: Add the `Filter` model**

Append to `feedwatch/models.py`:

```python
@dataclass
class Filter:
    id: int
    feed_id: int
    kind: str  # "include" or "exclude"
    keywords: list[str]
```

- [ ] **Step 4: Write `feedwatch/filters.py`**

```python
"""Decides which entries a feed's keyword filters keep. Matching is on titles only."""

import re


def _pattern(keyword):
    # Lookarounds rather than \b: \b needs a word character beside it, so it
    # never matches at the edge of a keyword such as "c++" or "c#".
    body = r"\s+".join(re.escape(word) for word in keyword.split())
    return re.compile(rf"(?<!\w){body}(?!\w)", re.IGNORECASE)


def matches(title, keywords):
    """Return True if the title contains any keyword as a whole word, ignoring case."""
    return any(_pattern(keyword).search(title) for keyword in keywords)


def keeps(title, filters):
    """Return True if a title passes every filter: each include matches and no exclude does."""
    for f in filters:
        hit = matches(title, f.keywords)
        if f.kind == "include" and not hit:
            return False
        if f.kind == "exclude" and hit:
            return False
    return True
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests/test_feedwatch.py tests/test_filters.py -v`
Expected: all PASS (4 existing + 10 new).

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filters.py tests/test_filters.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 2: Storing filters

**Files:**
- Modify: `feedwatch/store.py` (module docstring, imports, `SCHEMA_STEPS`, new functions after `feeds`)
- Test: `tests/test_filters.py`

**Interfaces:**
- Consumes: `feedwatch.models.Filter` (Task 1).
- Produces:
  - `store.feed_by_url(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]`. Returns `(filter_id, None)` on success, `(None, reason)` on refusal. Reasons are exactly `f"not subscribed to {url}"` and `"a filter needs at least one keyword"`.
  - `store.filters_for(conn, feed_id: int) -> list[Filter]`, ordered by id, keywords normalised (lowercase, trimmed, whitespace collapsed, no blanks, no repeats, original order).
  - `store.remove_filter(conn, filter_id: int) -> bool`. Returns False when no filter has that id.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import filters, store
from feedwatch.models import Filter
```

Add this class before `if __name__ == "__main__":`:

```python
URL = "http://x/feed"


class StoreFilterTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")
        self.feed = store.feed_by_url(self.conn, URL)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_a_feed_is_found_by_its_url(self):
        self.assertEqual(self.feed.url, URL)
        self.assertIsNone(store.feed_by_url(self.conn, "http://nowhere/feed"))

    def test_an_added_filter_is_listed_with_its_keywords_cleaned(self):
        filter_id, reason = store.add_filter(
            self.conn, URL, "include", ["Rust", " rust ", "Machine   Learning", "  "]
        )
        self.assertIsNone(reason)
        self.assertEqual(
            store.filters_for(self.conn, self.feed.id),
            [Filter(filter_id, self.feed.id, "include", ["rust", "machine learning"])],
        )

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, "http://nowhere/feed", "include", ["rust"])
        self.assertIsNone(filter_id)
        self.assertIn("http://nowhere/feed", reason)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM filters").fetchone()[0], 0)

    def test_a_filter_with_no_keywords_is_refused(self):
        for keywords in ([], [""], ["   ", "\t"]):
            filter_id, reason = store.add_filter(self.conn, URL, "exclude", keywords)
            self.assertIsNone(filter_id)
            self.assertEqual(reason, "a filter needs at least one keyword")
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_filters_belong_to_their_feed(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        other = store.feed_by_url(self.conn, "http://y/feed")
        store.add_filter(self.conn, URL, "include", ["rust"])
        self.assertEqual(store.filters_for(self.conn, other.id), [])

    def test_a_removed_filter_is_gone(self):
        filter_id, _ = store.add_filter(self.conn, URL, "include", ["rust"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])
        self.assertFalse(store.remove_filter(self.conn, filter_id))

    def test_a_database_from_before_filters_keeps_working(self):
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        # The schema as it stood before filters: its first two steps.
        for step in store.SCHEMA_STEPS[:2]:
            old.execute(step)
        old.execute("INSERT INTO feeds (url, title) VALUES (?, 'x')", (URL,))
        old.execute(
            "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'a', 'Old news', 'http://x/a')"
        )
        old.commit()
        old.close()

        conn = store.connect(path)
        try:
            self.assertEqual([e.title for e in store.unread(conn)], ["Old news"])
            filter_id, reason = store.add_filter(conn, URL, "exclude", ["news"])
            self.assertIsNone(reason)
            self.assertEqual(
                store.filters_for(conn, 1), [Filter(filter_id, 1, "exclude", ["news"])]
            )
        finally:
            conn.close()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -k StoreFilterTest -v`
Expected: ERROR in every test, `AttributeError: module 'feedwatch.store' has no attribute 'feed_by_url'`.

- [ ] **Step 3: Extend `feedwatch/store.py`**

Replace the module docstring and imports with:

```python
"""The SQLite database both processes share: feeds, their keyword filters, and the entries seen in them."""

import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append a third step to `SCHEMA_STEPS`, after the `entries` step:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Add after `feeds()`:

```python
def feed_by_url(conn, url):
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def _clean_keywords(keywords):
    cleaned = []
    for keyword in keywords:
        keyword = " ".join(keyword.split()).lower()
        if keyword and keyword not in cleaned:
            cleaned.append(keyword)
    return cleaned


def add_filter(conn, url, kind, keywords):
    """Attach an "include" or "exclude" filter to the feed subscribed at `url`.

    Returns (filter_id, None), or (None, reason) when the feed is not subscribed
    or no keyword is left once blanks are dropped.
    """
    feed = feed_by_url(conn, url)
    if feed is None:
        return None, f"not subscribed to {url}"
    cleaned = _clean_keywords(keywords)
    if not cleaned:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(cleaned)),
        )
    return cursor.lastrowid, None


def filters_for(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [
        Filter(filter_id, feed_id, kind, json.loads(keywords))
        for filter_id, feed_id, kind, keywords in rows
    ]


def remove_filter(conn, filter_id):
    """Delete a filter. Returns False when no filter has that id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    return cursor.rowcount == 1
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests/test_feedwatch.py tests/test_filters.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters, upgrading older databases in place"
```

---

### Task 3: The poller drops filtered entries

**Files:**
- Modify: `feedwatch/poller.py` (import line, `poll_once`)
- Test: `tests/test_filters.py`

**Interfaces:**
- Consumes: `filters.keeps(title, filters)` (Task 1); `store.filters_for(conn, feed_id)`, `store.add_filter(...)`, `store.feed_by_url(...)` (Task 2).
- Produces: `poller.poll_once(conn, last_polled, now)` with an unchanged signature. It now stores only the entries that pass the feed's filters, read fresh on every call.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import fetch, filters, poller, store
from feedwatch.models import Filter
```

Add this class before `if __name__ == "__main__":`:

```python
FEED_XML = b"""<rss><channel><title>t</title>
<item><guid>1</guid><title>Rust 1.80 released</title><link>http://x/1</link></item>
<item><guid>2</guid><title>Weekly Go news</title><link>http://x/2</link></item>
<item><guid>3</guid><title>Sponsored: Rust course</title><link>http://x/3</link></item>
</channel></rss>"""

LATER_XML = FEED_XML.replace(
    b"</channel>",
    b"<item><guid>4</guid><title>Sponsored: Go course</title><link>http://x/4</link></item></channel>",
)


class PollerFilterTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def poll(self, xml):
        with mock.patch.object(fetch, "fetch", return_value=xml):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 12, 0))

    def stored_titles(self):
        return {row[0] for row in self.conn.execute("SELECT title FROM entries")}

    def test_a_feed_without_filters_stores_every_entry(self):
        self.poll(FEED_XML)
        self.assertEqual(
            self.stored_titles(),
            {"Rust 1.80 released", "Weekly Go news", "Sponsored: Rust course"},
        )

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll(FEED_XML)
        self.assertEqual(self.stored_titles(), {"Rust 1.80 released", "Weekly Go news"})

    def test_include_and_exclude_filters_both_apply(self):
        store.add_filter(self.conn, URL, "include", ["rust"])
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll(FEED_XML)
        self.assertEqual(self.stored_titles(), {"Rust 1.80 released"})

    def test_a_filter_added_between_polls_applies_from_the_next_poll(self):
        self.poll(FEED_XML)
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll(LATER_XML)
        self.assertNotIn("Sponsored: Go course", self.stored_titles())

    def test_entries_already_stored_are_not_re_filtered(self):
        self.poll(FEED_XML)
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll(LATER_XML)
        self.assertIn("Sponsored: Rust course", self.stored_titles())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -k PollerFilterTest -v`
Expected: `test_a_feed_without_filters_stores_every_entry` and `test_entries_already_stored_are_not_re_filtered` PASS; the other three FAIL because the sponsored or non-Rust entries are stored.

- [ ] **Step 3: Apply filters in `poll_once`**

In `feedwatch/poller.py`, change the import line to:

```python
from feedwatch import fetch, filters, parse, store
```

Replace the last line of the loop body in `poll_once`:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        # Read on every poll so a filter added from the CLI applies without a restart.
        feed_filters = store.filters_for(conn, feed.id)
        kept = [e for e in entries if filters.keeps(e["title"], feed_filters)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests/test_feedwatch.py tests/test_filters.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: `feedwatch filter add|list|remove`

**Files:**
- Modify: `feedwatch/cli.py` (module docstring, parser setup, dispatch, new `run_filter_command`)
- Test: `tests/test_filters.py`

**Interfaces:**
- Consumes: `store.add_filter`, `store.feed_by_url`, `store.filters_for`, `store.remove_filter` (Task 2).
- Produces: the commands below. Exit code 0 on success, 1 on a refusal (message on stderr), 2 on bad usage (argparse).
  - `filter add URL --include W [W ...]` or `--exclude W [W ...]` (exactly one) prints `added filter <id>`.
  - `filter list URL` prints one line per filter, `<id>  <kind>  <kw>, <kw>`, or `no filters for <URL>`.
  - `filter remove ID` prints nothing on success, and `no filter with id <ID>` on stderr when it is unknown.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import io
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, fetch, filters, poller, store
from feedwatch.models import Filter
```

Add this class before `if __name__ == "__main__":`:

```python
class CliFilterTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(store, "connect", return_value=self.conn), \
                redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self):
        code, out, _ = self.run_cli("filter", "add", URL, "--include", "Rust", "python")
        self.assertEqual((code, out), (0, "added filter 1\n"))
        self.run_cli("filter", "add", URL, "--exclude", "sponsored")
        code, out, _ = self.run_cli("filter", "list", URL)
        self.assertEqual(code, 0)
        self.assertEqual(out, "1  include  rust, python\n2  exclude  sponsored\n")

    def test_a_feed_with_no_filters_says_so(self):
        code, out, _ = self.run_cli("filter", "list", URL)
        self.assertEqual((code, out), (0, f"no filters for {URL}\n"))

    def test_a_filter_for_an_unsubscribed_feed_is_refused(self):
        code, _, err = self.run_cli("filter", "add", "http://nowhere/feed", "--include", "rust")
        self.assertEqual(code, 1)
        self.assertIn("http://nowhere/feed", err)

    def test_listing_an_unsubscribed_feed_is_refused(self):
        code, _, err = self.run_cli("filter", "list", "http://nowhere/feed")
        self.assertEqual(code, 1)
        self.assertIn("http://nowhere/feed", err)

    def test_a_filter_of_blank_keywords_is_refused(self):
        code, _, err = self.run_cli("filter", "add", URL, "--include", "", "  ")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_include_and_exclude_cannot_be_combined_or_both_missing(self):
        with redirect_stderr(io.StringIO()):
            for argv in (
                ["filter", "add", URL, "--include", "a", "--exclude", "b"],
                ["filter", "add", URL],
                ["filter", "add", URL, "--include"],
            ):
                with self.assertRaises(SystemExit) as raised:
                    self.run_cli(*argv)
                self.assertEqual(raised.exception.code, 2)

    def test_a_removed_filter_is_no_longer_listed(self):
        self.run_cli("filter", "add", URL, "--include", "rust")
        code, _, _ = self.run_cli("filter", "remove", "1")
        self.assertEqual(code, 0)
        _, out, _ = self.run_cli("filter", "list", URL)
        self.assertEqual(out, f"no filters for {URL}\n")

    def test_removing_an_unknown_filter_id_is_reported(self):
        code, _, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(code, 1)
        self.assertIn("no filter with id 99", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -k CliFilterTest -v`
Expected: FAIL/ERROR. argparse rejects `filter` as an invalid choice (`SystemExit: 2`); the argparse test passes by accident because every call exits with 2.

- [ ] **Step 3: Add the `filter` commands to `feedwatch/cli.py`**

Replace the module docstring with:

```python
"""feedwatch's command line: subscribe, filter feeds by keyword, list unread entries, mark them read."""
```

In `main`, after the `read` parser lines and before `args = parser.parse_args(argv)`, add:

```python
    filter_parser = commands.add_parser("filter", help="keep or drop a feed's entries by title keywords")
    filter_commands = filter_parser.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD",
                      help="keep only entries whose title has one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD",
                      help="drop entries whose title has any of these words")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter by its id")
    filter_remove.add_argument("filter_id", type=int)
```

In the dispatch, insert a branch before the final `else:` (which handles `read`):

```python
    elif args.command == "filter":
        return run_filter_command(conn, args)
```

Add this function after `main`, before `if __name__ == "__main__":`:

```python
def run_filter_command(conn, args):
    if args.filter_command == "add":
        kind, keywords = ("include", args.include) if args.include else ("exclude", args.exclude)
        filter_id, reason = store.add_filter(conn, args.url, kind, keywords)
        if reason:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.filter_command == "list":
        feed = store.feed_by_url(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        found = store.filters_for(conn, feed.id)
        if not found:
            print(f"no filters for {args.url}")
        for f in found:
            print(f"{f.id}  {f.kind}  {', '.join(f.keywords)}")
    else:
        if not store.remove_filter(conn, args.filter_id):
            print(f"no filter with id {args.filter_id}", file=sys.stderr)
            return 1
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests/test_feedwatch.py tests/test_filters.py -v`
Expected: all PASS.

- [ ] **Step 5: Smoke-test the real command against a throwaway database**

Run:
```bash
HOME=$(mktemp -d) sh -c 'python3 -m feedwatch.cli add http://x/feed &&
  python3 -m feedwatch.cli filter add http://x/feed --include rust "machine learning" &&
  python3 -m feedwatch.cli filter list http://x/feed &&
  python3 -m feedwatch.cli filter add http://nope/feed --exclude ad; echo "exit $?"'
```
Expected:
```
added filter 1
1  include  rust, machine learning
not subscribed to http://nope/feed
exit 1
```

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

## After the last task

Do not edit living documents (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/PROGRAM-DESIGN.md`, `docs/ROADMAP.md`) while executing. Record these facts in the ledger for the sweep to place:

- A new module, `filters`, does pure title matching. `poller` calls it, and nothing else does.
- `store` now has a third table, `filters`, alongside `feeds` and `entries`.
- `cli` has a `filter` command group.
- A filter-dropped entry is not remembered: it is stored if the filter is removed while the entry is still in the feed.

Then invoke `dopamine:finishing-work`.
````


## p005

#### Final message

I wrote the implementation plan and committed it as `9d318b9`. Nothing was implemented in the repository.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`

I applied the plan's code to a throwaway copy of the repo. All 36 tests passed (the 4 existing plus 32 new), and running the real command printed exactly what the plan says it should. I then deleted that copy.

**The four tasks, each written test-first and ending in a commit:**
1. **Store:** a `Filter` model and a new `filters` table, added as a fourth setup step that runs on every connect, so databases created before this feature pick it up. Adds functions to look up a feed by URL and to add, list and remove filters. Adding is refused, with a message, when the feed isn't subscribed (the message names the URL) or when no keywords are left once blank ones are dropped. One test builds a database the old way and checks it still works.
2. **Matching:** a new module, `feedwatch/filtering.py`. Matching is case-insensitive and on whole words, and keywords are treated as plain text, never as patterns. A word counts as whole when no letter or digit touches it on either side, so keywords like `C++` and `node.js` still match.
3. **Poller:** it runs a feed's new entries through its filters before saving them. Tests use a fake download in place of the network and check that dropped entries are never stored and entries already stored are left alone.
4. **CLI:** `feedwatch filter add` (needs exactly one of `--include` or `--exclude`), `filter list` and `filter remove`, plus a smoke test against a throwaway home directory.

**Choices I made where the spec is silent (worth checking in review):**
- When a feed has several filters, an entry is stored only if it passes all of them.
- Blank keywords are dropped, and a filter left with none is refused.
- `filter list` for an unsubscribed URL and `filter remove` with an unknown id both print an error and exit with status 1.
- Keywords are stored as a JSON list in a single column.
- Tests use the standard `unittest` module, because pytest isn't installed here.

**Documentation:** the plan's Documentation section says not to edit the living documents while executing it. Once it is built, `ARCHITECTURE.md` will need to mention the new `filtering` module and `filters` table; that should be noted in the ledger for the end-of-work sweep.

I also ran the end-of-work sweep for this planning step, committed as `b510cf8` with "nothing to drain". It saved a reconstructed ledger at `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters-plan.reconstructed-ledger.md`. `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are listed in `.dopamine/config` but don't exist; I didn't create them.

Plan complete and saved to `docs/superpowers/plans/2026-10-12-keyword-filters.md`. Please review the plan.

#### docs/superpowers/plans/2026-10-12-keyword-filters-plan.reconstructed-ledger.md (added)

````
# Reconstructed ledger — writing the keyword filters plan (2026-10-12)

> Reconstruction, written 2026-10-12 from the conversation that wrote the plan; no superpowers ledger existed for this unit.

- Task: write the implementation plan for `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`; plan only, no implementation.
- Read the spec, `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, every module in `feedwatch/` and `tests/test_feedwatch.py`.
- Found pytest absent; the suite runs as `python3 -m unittest tests.test_feedwatch` (4 tests, OK). The plan uses unittest.
- Decided: filters live in a new `filters` table appended to `store.SCHEMA_STEPS`, keywords stored as a JSON array; matching lives in a new pure module `feedwatch/filtering.py`; an entry must pass every filter on its feed; keyword boundaries are "no word character either side", not `\b`, so keywords like `C++` match.
- Verified the plan's code in a throwaway copy of the repository: 36 tests passed and the CLI smoke test printed the expected output. Nothing was implemented in this repository.
- Committed the plan as `docs/superpowers/plans/2026-10-12-keyword-filters.md`.
- Living-document consequences arise only once the plan is executed (ARCHITECTURE.md's assembly and state sections); the plan's Documentation section hands them to that execution's sweep. Nothing from this unit drains now.
- `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are declared in `.dopamine/config` but do not exist.
````

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed so the poller stores only the new entries whose titles pass them.

**Architecture:** `store` gains a `filters` table (added as a new idempotent schema step, so old databases pick it up on connect) and functions to add, list and remove filters. A new pure module, `feedwatch/filtering.py`, decides whether a title passes a feed's filters (case-insensitive, whole-word). `poller.poll_once` runs a feed's parsed entries through `filtering.apply` before `store.save_entries`, and `cli` gains a `filter` command with `add`, `list` and `remove`.

**Tech Stack:** Python 3.14, standard library only (`sqlite3`, `json`, `re`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Standard library only — no new dependencies (DESIGN.md: "Standard library first; a dependency has to earn its place").
- Matching is on the entry's **title** only, "case-insensitive, on whole words". No regular expressions from the user: keywords are literal text.
- "An entry a filter drops is never stored."
- "A filter for a feed that is not subscribed is refused, with a message naming the URL."
- "A filter with no keywords is refused."
- "Filters are kept in the same database, and a database created before this feature keeps working." — schema changes are appended to `store.SCHEMA_STEPS`; existing steps are never edited.
- "Entries already stored are not re-filtered."
- Module boundaries from ARCHITECTURE.md hold: `store` owns the schema, `poller` is the only caller of `fetch`, `cli` only calls `store`.
- Tests use `unittest` (pytest is not installed). Run the suite with `python3 -m unittest tests.test_feedwatch tests.test_filters -v` from the repository root.

## Review Focus

- A keyword beside punctuation, or containing it: `go` should match "Go, Rust and Zig" and "(Go)" but not "Google" or "going"; `C++` and `node.js` should match literally and never be read as regex syntax. — tested in Task 2.
- An entry with no title (parse yields `""`): an include filter drops it, an exclude filter keeps it, nothing crashes. — tested in Task 2.
- Blank or padded keywords: `--include ""` or `--include "  "` is refused as a filter with no keywords; `" python "` is stored as `python`. — tested in Task 1.
- `filter remove` with an id that does not exist, and `filter list` for a URL that is not subscribed: a message on stderr and exit status 1, not silent success. — tested in Task 4.
- Several filters on one feed: an entry is stored only if it passes every one (include `python` plus exclude `sponsored` keeps "Python 3.14 released" and drops "Sponsored: Python course"). — tested in Tasks 2 and 3.

## Documentation

This plan adds a module (`filtering`) and a table (`filters`), which ARCHITECTURE.md's "The assembly" and "Where state lives" will need to mention, and a capability DESIGN.md's "What it must do" may list. Do not edit the living documents during execution: record these facts in the ledger and let `dopamine:finishing-work` place them when the plan is done.

## File Structure

- Modify `feedwatch/models.py` — add the `Filter` dataclass.
- Modify `feedwatch/store.py` — `filters` schema step; `feed_by_url`, `add_filter`, `filters`, `remove_filter`.
- Create `feedwatch/filtering.py` — pure matching: `passes(title, filters)`, `apply(entries, filters)`. Owns matching; never stores.
- Modify `feedwatch/poller.py` — apply filters in `poll_once` before saving.
- Modify `feedwatch/cli.py` — `filter add|list|remove`.
- Create `tests/test_filters.py` — all new tests (the existing `tests/test_feedwatch.py` stays as it is).

---

### Task 1: Filters in the store

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Modify: `feedwatch/store.py:1-29` (imports, `SCHEMA_STEPS`) and append new functions after `add_feed`
- Test: `tests/test_filters.py` (create)

**Interfaces:**
- Consumes: `store.connect(path)`, `store.add_feed(conn, url, title, interval_minutes=30)`, `store.unread(conn, limit=20)`, `store.SCHEMA_STEPS` (existing).
- Produces:
  - `models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])` — `kind` is `"include"` or `"exclude"`.
  - `store.feed_by_url(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]` — `(filter_id, None)` on success, `(None, reason)` when refused. Reasons: `f"not subscribed to {url}"`, `"a filter needs at least one keyword"`.
  - `store.filters(conn, feed_id: int) -> list[Filter]` — ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> bool` — `False` when no filter has that id.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store

FEED = "http://x/feed"


class StoreFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, FEED, "x")
        self.feed = store.feeds(self.conn)[0]

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_a_filter_is_added_and_listed(self):
        filter_id, reason = store.add_filter(self.conn, FEED, "include", ["python", "rust"])
        self.assertIsNone(reason)
        [f] = store.filters(self.conn, self.feed.id)
        self.assertEqual((f.id, f.feed_id, f.kind, f.keywords),
                         (filter_id, self.feed.id, "include", ["python", "rust"]))

    def test_filters_are_listed_per_feed_in_id_order(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        first, _ = store.add_filter(self.conn, FEED, "include", ["a"])
        store.add_filter(self.conn, "http://y/feed", "include", ["b"])
        second, _ = store.add_filter(self.conn, FEED, "exclude", ["c"])
        self.assertEqual([f.id for f in store.filters(self.conn, self.feed.id)], [first, second])

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, "http://nope/feed", "include", ["a"])
        self.assertIsNone(filter_id)
        self.assertIn("http://nope/feed", reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        filter_id, reason = store.add_filter(self.conn, FEED, "exclude", [])
        self.assertIsNone(filter_id)
        self.assertIn("keyword", reason)

    def test_blank_keywords_count_as_no_keywords(self):
        filter_id, reason = store.add_filter(self.conn, FEED, "include", ["", "   "])
        self.assertIsNone(filter_id)
        self.assertIn("keyword", reason)
        self.assertEqual(store.filters(self.conn, self.feed.id), [])

    def test_keywords_are_stored_without_surrounding_whitespace(self):
        store.add_filter(self.conn, FEED, "include", [" python ", "", "rust"])
        self.assertEqual(store.filters(self.conn, self.feed.id)[0].keywords, ["python", "rust"])

    def test_a_filter_is_removed_by_id(self):
        filter_id, _ = store.add_filter(self.conn, FEED, "include", ["a"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.filters(self.conn, self.feed.id), [])

    def test_removing_an_unknown_filter_reports_it(self):
        self.assertFalse(store.remove_filter(self.conn, 999))

    def test_feed_by_url(self):
        self.assertEqual(store.feed_by_url(self.conn, FEED), self.feed)
        self.assertIsNone(store.feed_by_url(self.conn, "http://nope/feed"))


class OldDatabaseTest(unittest.TestCase):
    def test_a_database_from_before_filters_keeps_working(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "feeds.db"
            old = sqlite3.connect(path)
            for step in store.SCHEMA_STEPS[:2]:
                old.execute(step)
            old.execute("INSERT INTO feeds (url, title) VALUES (?, ?)", (FEED, "x"))
            old.execute(
                "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'g', 'Old entry', '')"
            )
            old.commit()
            old.close()

            conn = store.connect(path)
            try:
                self.assertEqual([e.title for e in store.unread(conn)], ["Old entry"])
                filter_id, reason = store.add_filter(conn, FEED, "exclude", ["old"])
                self.assertIsNone(reason)
                self.assertEqual([f.id for f in store.filters(conn, 1)], [filter_id])
            finally:
                conn.close()


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: errors with `AttributeError: module 'feedwatch.store' has no attribute 'add_filter'` (and `feed_by_url`, `remove_filter`).

- [ ] **Step 3: Add the `Filter` model**

Append to `feedwatch/models.py`:

```python
@dataclass
class Filter:
    id: int
    feed_id: int
    kind: str  # "include" or "exclude"
    keywords: list[str]
```

- [ ] **Step 4: Add the schema step and the store functions**

In `feedwatch/store.py`, change the imports at the top to:

```python
import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append this third element to `SCHEMA_STEPS` (after the `entries` step, inside the list):

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Add these functions after `feeds()`:

```python
def feed_by_url(conn, url):
    """Return the subscribed feed at url, or None."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def add_filter(conn, url, kind, keywords):
    """Attach a keyword filter to a subscribed feed.

    Returns (filter_id, None), or (None, reason) when the feed is not
    subscribed or no keyword is left once blanks are dropped.
    """
    feed = feed_by_url(conn, url)
    if feed is None:
        return None, f"not subscribed to {url}"
    keywords = [k.strip() for k in keywords if k.strip()]
    if not keywords:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(keywords)),
        )
    return cursor.lastrowid, None


def filters(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [Filter(id_, feed_id_, kind, json.loads(keywords))
            for id_, feed_id_, kind, keywords in rows]


def remove_filter(conn, filter_id):
    """Remove a filter. Returns False when no filter has that id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    return cursor.rowcount == 1
```

Update the module docstring on line 1 of `store.py`, which the change makes incomplete:

```python
"""The SQLite database both processes share: feeds, the entries seen in them, and their keyword filters."""
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests PASS (4 existing + 10 new).

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 2: Matching titles against filters

**Files:**
- Create: `feedwatch/filtering.py`
- Test: `tests/test_filters.py` (append a test class)

**Interfaces:**
- Consumes: `models.Filter(id, feed_id, kind, keywords)` from Task 1.
- Produces:
  - `filtering.passes(title: str, filters: list[Filter]) -> bool` — True when the title gets through every filter.
  - `filtering.apply(entries: list[dict], filters: list[Filter]) -> list[dict]` — the entry dicts (as produced by `parse.parse_feed`, with a `"title"` key) that pass, in their original order.

- [ ] **Step 1: Write the failing tests**

Add `from feedwatch import filtering` and `from feedwatch.models import Filter` to the imports at the top of `tests/test_filters.py`, so they read:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import filtering, store
from feedwatch.models import Filter
```

Append before the `if __name__ == "__main__":` line:

```python
def include(*keywords):
    return Filter(1, 1, "include", list(keywords))


def exclude(*keywords):
    return Filter(2, 1, "exclude", list(keywords))


class MatchingTest(unittest.TestCase):
    def test_no_filters_pass_everything(self):
        self.assertTrue(filtering.passes("anything", []))

    def test_include_keeps_a_title_with_any_of_its_keywords(self):
        self.assertTrue(filtering.passes("Rust 2.0 is out", [include("python", "rust")]))
        self.assertFalse(filtering.passes("Zig is out", [include("python", "rust")]))

    def test_exclude_drops_a_title_with_any_of_its_keywords(self):
        self.assertFalse(filtering.passes("Sponsored post", [exclude("ad", "sponsored")]))
        self.assertTrue(filtering.passes("Real post", [exclude("ad", "sponsored")]))

    def test_matching_ignores_case(self):
        self.assertTrue(filtering.passes("PYTHON NEWS", [include("Python")]))
        self.assertTrue(filtering.passes("Le CAFÉ du coin", [include("café")]))

    def test_matching_is_on_whole_words(self):
        self.assertFalse(filtering.passes("Google launches", [include("go")]))
        self.assertFalse(filtering.passes("Going places", [include("go")]))
        self.assertTrue(filtering.passes("Go 1.30 released", [include("go")]))

    def test_punctuation_beside_a_keyword_still_bounds_the_word(self):
        self.assertTrue(filtering.passes("Go, Rust and Zig", [include("go")]))
        self.assertTrue(filtering.passes("Generics (Go)", [include("go")]))

    def test_keywords_are_literal_text_not_patterns(self):
        self.assertTrue(filtering.passes("C++ 26 news", [include("C++")]))
        self.assertFalse(filtering.passes("C news", [include("C++")]))
        self.assertTrue(filtering.passes("node.js 30", [include("node.js")]))
        self.assertFalse(filtering.passes("nodexjs 30", [include("node.js")]))
        self.assertFalse(filtering.passes("a(b", [include("(")]))

    def test_a_keyword_of_several_words_matches_the_phrase(self):
        self.assertTrue(filtering.passes("Machine learning today", [include("machine learning")]))
        self.assertFalse(filtering.passes("Learning machine", [include("machine learning")]))

    def test_an_empty_title_fails_include_and_passes_exclude(self):
        self.assertFalse(filtering.passes("", [include("python")]))
        self.assertTrue(filtering.passes("", [exclude("python")]))

    def test_an_entry_must_pass_every_filter(self):
        rules = [include("python"), exclude("sponsored")]
        self.assertTrue(filtering.passes("Python 3.14 released", rules))
        self.assertFalse(filtering.passes("Sponsored: Python course", rules))
        self.assertFalse(filtering.passes("Rust news", rules))

    def test_apply_keeps_passing_entries_in_order(self):
        entries = [{"guid": "1", "title": "Python a"}, {"guid": "2", "title": "Rust"},
                   {"guid": "3", "title": "Python b"}]
        kept = filtering.apply(entries, [include("python")])
        self.assertEqual([e["guid"] for e in kept], ["1", "3"])
```

Note on `test_keywords_are_literal_text_not_patterns`: the `"("` case checks that a keyword made only of punctuation is escaped rather than compiled as regex syntax (an unescaped `(` raises `re.error`). It does not match `"a(b"` because the whole-word rule needs no word character directly before or after the keyword, and here `a` and `b` touch it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: `ImportError: cannot import name 'filtering' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

Create `feedwatch/filtering.py`:

```python
"""Decides which of a feed's new entries its keyword filters let through."""

import re


def _matcher(keywords):
    alternatives = "|".join(re.escape(k) for k in keywords)
    # Bounded by "no word character either side" rather than \b, which never
    # matches beside a keyword's own punctuation, as in "C++".
    return re.compile(rf"(?<!\w)(?:{alternatives})(?!\w)", re.IGNORECASE)


def passes(title, filters):
    """Return True when an entry titled `title` gets through every one of `filters`.

    An include filter needs at least one of its keywords in the title; an
    exclude filter needs none of them. Matching is case-insensitive, on whole words.
    """
    for f in filters:
        found = _matcher(f.keywords).search(title) is not None
        if f.kind == "include" and not found:
            return False
        if f.kind == "exclude" and found:
            return False
    return True


def apply(entries, filters):
    """Return the entries, as dicts from parse.parse_feed, that pass every filter, in order."""
    return [e for e in entries if passes(e["title"], filters)]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/filtering.py tests/test_filters.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 3: The poller applies a feed's filters

**Files:**
- Modify: `feedwatch/poller.py:7` (import) and `feedwatch/poller.py:23-27` (`poll_once`)
- Test: `tests/test_filters.py` (append a test class)

**Interfaces:**
- Consumes: `store.filters(conn, feed_id) -> list[Filter]`, `store.add_filter(conn, url, kind, keywords)` (Task 1); `filtering.apply(entries, filters) -> list[dict]` (Task 2); existing `poller.poll_once(conn, last_polled: dict, now: datetime)`, `store.save_entries`, `store.unread`.
- Produces: no new names; `poll_once` now stores only entries that pass the feed's filters.

- [ ] **Step 1: Write the failing tests**

Extend the imports at the top of `tests/test_filters.py` so they read:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import filtering, poller, store
from feedwatch.models import Filter
```

Append before the `if __name__ == "__main__":` line:

```python
FEED_XML = b"""<rss><channel><title>t</title>
<item><guid>1</guid><title>Python 3.14 released</title></item>
<item><guid>2</guid><title>Sponsored: Python course</title></item>
<item><guid>3</guid><title>Rust news</title></item>
</channel></rss>"""


class PollerFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, FEED, "x")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def poll(self):
        # A fresh last_polled makes every feed due.
        with mock.patch("feedwatch.fetch.fetch", return_value=FEED_XML):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))

    def stored_guids(self):
        return sorted(e.guid for e in store.unread(self.conn))

    def test_without_filters_every_entry_is_stored(self):
        self.poll()
        self.assertEqual(self.stored_guids(), ["1", "2", "3"])

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_filter(self.conn, FEED, "include", ["python"])
        store.add_filter(self.conn, FEED, "exclude", ["sponsored"])
        self.poll()
        self.assertEqual(self.stored_guids(), ["1"])

    def test_entries_already_stored_are_not_refiltered(self):
        self.poll()
        store.add_filter(self.conn, FEED, "exclude", ["rust"])
        self.poll()
        self.assertEqual(self.stored_guids(), ["1", "2", "3"])

    def test_one_feeds_filters_do_not_touch_another_feed(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, FEED, "include", ["rust"])
        self.poll()
        stored = sorted((e.feed_id, e.guid) for e in store.unread(self.conn))
        self.assertEqual(stored, [(1, "3"), (2, "1"), (2, "2"), (2, "3")])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.PollerFiltersTest -v`
Expected: `test_an_entry_a_filter_drops_is_never_stored` and `test_one_feeds_filters_do_not_touch_another_feed` FAIL (all guids stored); the other two pass already.

- [ ] **Step 3: Apply filters in `poll_once`**

In `feedwatch/poller.py`, change line 7 to:

```python
from feedwatch import fetch, filtering, parse, store
```

and replace the end of the loop body in `poll_once` (the `entries is None` check and the `log.info` line) with:

```python
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        entries = filtering.apply(entries, store.filters(conn, feed.id))
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller stores only entries that pass the feed's filters"
```

---

### Task 4: `feedwatch filter add | list | remove`

**Files:**
- Modify: `feedwatch/cli.py` (whole `main`, module docstring)
- Test: `tests/test_filters.py` (append a test class)

**Interfaces:**
- Consumes: `store.add_filter`, `store.feed_by_url`, `store.filters`, `store.remove_filter` (Task 1); existing `store.connect`, `store.add_feed`.
- Produces: the commands, with this output:
  - `feedwatch filter add URL --include W [W ...]` / `--exclude W [W ...]` → stdout `added filter <id>`, exit 0; refused → reason on stderr, exit 1. Exactly one of `--include`/`--exclude` is required (argparse exits 2 otherwise).
  - `feedwatch filter list URL` → one line per filter, `<id>  <kind>  <kw1>, <kw2>`, exit 0; unsubscribed URL → `not subscribed to <url>` on stderr, exit 1.
  - `feedwatch filter remove ID` → exit 0 silently; unknown id → `no filter with id <id>` on stderr, exit 1.

- [ ] **Step 1: Write the failing tests**

Extend the imports at the top of `tests/test_filters.py` so they read:

```python
import io
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, filtering, poller, store
from feedwatch.models import Filter
```

Append before the `if __name__ == "__main__":` line:

```python
class FilterCommandTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, FEED, "x")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(store, "connect", return_value=self.conn), \
                redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_add_then_list(self):
        code, out, _ = self.run_cli("filter", "add", FEED, "--include", "python", "rust")
        self.assertEqual(code, 0)
        filter_id = int(out.split()[-1])
        code, out, _ = self.run_cli("filter", "add", FEED, "--exclude", "sponsored")
        self.assertEqual(code, 0)
        code, out, _ = self.run_cli("filter", "list", FEED)
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines(), [
            f"{filter_id}  include  python, rust",
            f"{filter_id + 1}  exclude  sponsored",
        ])

    def test_add_for_an_unsubscribed_feed_names_the_url(self):
        code, out, err = self.run_cli("filter", "add", "http://nope/feed", "--include", "a")
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("http://nope/feed", err)

    def test_add_with_only_blank_keywords_is_refused(self):
        code, _, err = self.run_cli("filter", "add", FEED, "--include", "", " ")
        self.assertEqual(code, 1)
        self.assertIn("keyword", err)

    def test_add_needs_exactly_one_of_include_and_exclude(self):
        with redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self.run_cli("filter", "add", FEED)
            with self.assertRaises(SystemExit):
                self.run_cli("filter", "add", FEED, "--include", "a", "--exclude", "b")
            with self.assertRaises(SystemExit):
                self.run_cli("filter", "add", FEED, "--include")

    def test_list_for_an_unsubscribed_feed_names_the_url(self):
        code, out, err = self.run_cli("filter", "list", "http://nope/feed")
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertIn("http://nope/feed", err)

    def test_remove(self):
        filter_id, _ = store.add_filter(self.conn, FEED, "include", ["a"])
        code, _, _ = self.run_cli("filter", "remove", str(filter_id))
        self.assertEqual(code, 0)
        self.assertEqual(store.filters(self.conn, 1), [])

    def test_removing_an_unknown_id_is_reported(self):
        code, _, err = self.run_cli("filter", "remove", "999")
        self.assertEqual(code, 1)
        self.assertIn("999", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.FilterCommandTest -v`
Expected: tests fail or error with argparse's `invalid choice: 'filter'` (raised as `SystemExit: 2`).

- [ ] **Step 3: Write the implementation**

Replace the whole of `feedwatch/cli.py` with:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, filter feeds by keyword."""

import argparse
import sys

from feedwatch import store


def main(argv=None):
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title", default="")
    add.add_argument("--every", type=int, default=30, help="minutes between polls")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20)
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+")
    filter_ = commands.add_parser("filter", help="keep or drop a feed's new entries by title keywords")
    filter_commands = filter_.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD",
                      help="keep only entries whose title has one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD",
                      help="drop entries whose title has any of these words")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    conn = store.connect()
    if args.command == "add":
        ok, reason = store.add_feed(conn, args.url, args.title or args.url, args.every)
        if not ok:
            print(reason, file=sys.stderr)
            return 1
    elif args.command == "unread":
        for entry in store.unread(conn, args.limit):
            print(f"{entry.guid}  {entry.title}\n    {entry.link}")
    elif args.command == "read":
        store.mark_read(conn, args.guids)
    else:
        return filter_command(conn, args)
    return 0


def filter_command(conn, args):
    if args.filter_command == "add":
        if args.include is not None:
            kind, keywords = "include", args.include
        else:
            kind, keywords = "exclude", args.exclude
        filter_id, reason = store.add_filter(conn, args.url, kind, keywords)
        if filter_id is None:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.filter_command == "list":
        feed = store.feed_by_url(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for f in store.filters(conn, feed.id):
            print(f"{f.id}  {f.kind}  {', '.join(f.keywords)}")
    else:
        if not store.remove_filter(conn, args.filter_id):
            print(f"no filter with id {args.filter_id}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests PASS.

- [ ] **Step 5: Smoke-test the real command against a throwaway database**

`store.connect()` defaults to `~/.feedwatch/feeds.db`; point `HOME` at a temporary directory so the smoke test does not touch the user's database:

```bash
export HOME=$(mktemp -d)
python3 -m feedwatch.cli add http://x/feed
python3 -m feedwatch.cli filter add http://x/feed --include python rust
python3 -m feedwatch.cli filter list http://x/feed
python3 -m feedwatch.cli filter add http://nope/feed --exclude ad; echo "exit $?"
python3 -m feedwatch.cli filter remove 1
python3 -m feedwatch.cli filter remove 1; echo "exit $?"
```

Expected, in order: `added filter 1`; `1  include  python, rust`; `not subscribed to http://nope/feed` then `exit 1`; nothing; `no filter with id 1` then `exit 1`.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```
````



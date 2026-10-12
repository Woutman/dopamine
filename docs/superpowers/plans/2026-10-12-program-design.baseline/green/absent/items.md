## p001

#### Final message

I haven't written the plan yet. One question for you first.

`.dopamine/config` lists `docs/PROGRAM-DESIGN.md` as a living document, but the file doesn't exist. That document holds the structural rules a plan copies into its Global Constraints: where code goes, how modules depend on each other, how storage and schema migrations are done. This plan touches all of that. It adds a filters table to the existing database in `feedwatch/store.py`, and older databases have to keep working. It also adds a `filter` command group to `feedwatch/cli.py` and puts the filtering itself into `feedwatch/poller.py`.

Should I run `dopamine:brainstorm-program-design` first to create `docs/PROGRAM-DESIGN.md`, then write the plan from it?

- **Yes:** I'll work through the structural questions with you, record the answers in the document, and then write the plan with those rules in its Global Constraints.
- **No:** I'll write the plan from the spec and the existing code. Global Constraints will say in one line that it was planned without a PROGRAM-DESIGN.md. Then I'll commit it under `docs/superpowers/plans/`.

---
The plan is written and committed (`bf3305a plan: keyword filters`) at `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`. Nothing else in the repo was changed.

As you asked, I planned without `docs/PROGRAM-DESIGN.md`, and one line in Global Constraints says so.

The plan has four tasks, each written test-first and ending in its own commit:
1. **Title matching:** a new `Filter` model and a new pure module `feedwatch/filters.py` with `keeps(title, filters)`. Keywords match case-insensitively, as whole words, literally (so `C++` works and `cat` doesn't match "Category").
2. **Storing filters:** a `filters` table added the same way existing tables are, so databases from before this feature keep working. `store` gains `feed_by_url`, `add_filter`, `filters_for` and `remove_filter`. Filters for unsubscribed feeds are refused, and so are filters with no keywords; blank keywords count as none.
3. **Poller:** before saving, the poller keeps only the entries that pass all of the feed's filters. Entries already stored are not re-filtered.
4. **CLI:** `feedwatch filter add/list/remove`. Refusals print a message to stderr and exit 1.

**Choices I made that the spec doesn't settle:**
- When a feed has several filters, an entry has to pass every one of them. Within a single filter, matching any one keyword is enough.
- Keywords are saved as a JSON array in one column.
- Matching lives in a new `filters` module rather than in `poller`.

**Checked:** I applied every code block from the plan to a scratch copy of the repo and ran the full suite: 36 tests passed. The tests run with `python3 -m unittest discover -s tests -v`; `pytest` isn't installed.

**Docs:** once the plan is carried out, `docs/ARCHITECTURE.md` will be out of date (new `filters` module, new `filters` table, the poller calling `filters`). The plan has executors log that rather than edit the doc, and its Closing section runs `dopamine:finishing-work` to update it at the end.

Please review the plan and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include and exclude keyword filters to a feed. The poller applies them so that a dropped entry is never stored.

**Architecture:** A new pure module `feedwatch/filters.py` decides whether a title passes a list of `Filter` values. `store` gets a `filters` table, added as one more idempotent `SCHEMA_STEPS` entry, plus functions to add, list, look up and remove filters. `poller` reads a feed's filters once per poll and passes on only the entries they keep to `store.save_entries`. `cli` gets a `filter` command group with `add`, `list` and `remove`.

**Tech Stack:** Python 3.14, standard library only (`sqlite3`, `json`, `re`, `argparse`), `unittest`.

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- Planned without `docs/PROGRAM-DESIGN.md`: `.dopamine/config` declares it, but it is absent, and the human chose not to run `dopamine:brainstorm-program-design` first (2026-10-12).
- Standard library only (DESIGN.md: "a dependency has to earn its place"). No regex library and no new packages.
- Module ownership follows ARCHITECTURE.md. Only `store` touches SQL and the schema. Only `cli` prints. Only `poller` fetches. `filters` is pure: no I/O, no SQL, no logging.
- A database created before this feature has to keep working. The new table is added only as a `CREATE TABLE IF NOT EXISTS` step appended to `store.SCHEMA_STEPS`. Existing steps are not edited.
- Matching is case-insensitive and on whole words, against the entry's **title** only. Keywords match literally: no regular expressions are exposed to the user (spec, Out of scope).
- Entries already stored are never re-filtered or deleted.
- Refusal messages: an unsubscribed feed gives `not subscribed to <URL>`. A filter with no keywords gives `a filter needs at least one keyword`. Refusals go to stderr with exit code 1, following the existing `add` command.
- Run tests with `python3 -m unittest discover -s tests -v` from the repo root. `pytest` is not installed.
- Do not edit living documents (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`) during execution. ARCHITECTURE.md will go stale: it gains a `filters` module and a `filters` table, and the poller will call `filters`. Record that in the ledger and let the `dopamine:finishing-work` sweep place it.
- Before writing any code comment, load `dopamine:writing-code-comments`. Comments state a why, a contract or a warning, nothing else.

## Review Focus

1. **A keyword with regex metacharacters** (`C++`, `c.`): it should match literally as a word, not as a pattern, and must not crash. Pinned in Task 1 (`test_regex_characters_in_a_keyword_match_literally`).
2. **A keyword that appears only inside a longer word** (`cat` in "Category"): it should not match, while `cat,` next to punctuation should. Pinned in Task 1.
3. **Blank keywords** (`--include ""` or `"  "`): these should be refused like no keywords at all, not stored as a filter that matches everything or nothing. Pinned in Task 2 (store) and Task 4 (CLI).
4. **`filter list` for an unsubscribed URL and `filter remove` for an unknown id:** each should print a message and exit 1 with no traceback. Pinned in Task 4.
5. **A database file created before this feature, already holding feeds and entries:** it should open, keep its entries and accept filters. Pinned in Task 2 (`test_a_database_from_before_filters_keeps_working`).

---

### Task 1: Title matching

**Files:**
- Modify: `feedwatch/models.py` (append the `Filter` dataclass)
- Create: `feedwatch/filters.py`
- Create: `tests/test_filters.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])`, where `kind` is `"include"` or `"exclude"`.
  - `feedwatch.filters.keeps(title: str, filters: list[Filter]) -> bool`. It returns True when every filter passes the title. An empty list keeps everything. When a feed has several filters, an entry must pass all of them: the keywords inside one filter are ORed, and separate filters are ANDed.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`. The import block already names the modules that later tasks use, so later tasks only append classes to this file.

```python
import io
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, poller, store
from feedwatch.filters import keeps
from feedwatch.models import Filter


def include(*words):
    return Filter(1, 1, "include", list(words))


def exclude(*words):
    return Filter(2, 1, "exclude", list(words))


class KeepsTest(unittest.TestCase):
    def test_no_filters_keeps_everything(self):
        self.assertTrue(keeps("Anything at all", []))

    def test_include_keeps_a_title_with_one_of_its_keywords(self):
        self.assertTrue(keeps("Python 3.14 released", [include("rust", "python")]))

    def test_include_drops_a_title_with_none_of_its_keywords(self):
        self.assertFalse(keeps("Go 1.30 released", [include("rust", "python")]))

    def test_exclude_drops_a_title_with_any_of_its_keywords(self):
        self.assertFalse(keeps("Sponsored: buy now", [exclude("ad", "sponsored")]))

    def test_exclude_keeps_a_title_with_none_of_its_keywords(self):
        self.assertTrue(keeps("Release notes", [exclude("sponsored")]))

    def test_matching_ignores_case(self):
        self.assertTrue(keeps("PYTHON news", [include("Python")]))

    def test_a_keyword_inside_a_longer_word_does_not_match(self):
        self.assertFalse(keeps("Category theory", [include("cat")]))

    def test_a_keyword_next_to_punctuation_matches(self):
        self.assertTrue(keeps("News: cat, dog.", [include("cat")]))

    def test_regex_characters_in_a_keyword_match_literally(self):
        self.assertTrue(keeps("Learning C++ today", [include("c++")]))
        self.assertFalse(keeps("Learning C today", [include("c.")]))

    def test_a_multi_word_keyword_matches_the_phrase(self):
        self.assertTrue(keeps("New machine learning paper", [include("machine learning")]))
        self.assertFalse(keeps("New machine for learning", [include("machine learning")]))

    def test_an_empty_title_fails_include_and_passes_exclude(self):
        self.assertFalse(keeps("", [include("python")]))
        self.assertTrue(keeps("", [exclude("python")]))

    def test_every_filter_must_pass(self):
        filters = [include("python"), exclude("sponsored")]
        self.assertTrue(keeps("Python tips", filters))
        self.assertFalse(keeps("Sponsored Python course", filters))
        self.assertFalse(keeps("Rust tips", filters))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -v`
Expected: ERROR `ModuleNotFoundError: No module named 'feedwatch.filters'`

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

- [ ] **Step 4: Write the matcher**

Create `feedwatch/filters.py`:

```python
"""Decides whether an entry's title passes a feed's keyword filters."""

import re


def keeps(title, filters):
    """Return True if every filter in filters lets title through.

    An include filter passes a title containing at least one of its keywords;
    an exclude filter passes a title containing none of them. Keywords match
    literally, case-insensitively, as whole words.
    """
    return all(_passes(title, f) for f in filters)


def _passes(title, filter_):
    hit = any(_contains_word(title, keyword) for keyword in filter_.keywords)
    return hit if filter_.kind == "include" else not hit


def _contains_word(title, keyword):
    # Lookarounds rather than \b: \b needs a word character on the keyword's
    # side, so a keyword ending in punctuation, such as "C++", would never match.
    pattern = r"(?<!\w)" + re.escape(keyword) + r"(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all `KeepsTest` tests and the existing four tests PASS.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filters.py tests/test_filters.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 2: Storing filters

**Files:**
- Modify: `feedwatch/store.py` (imports; append a step to `SCHEMA_STEPS`; add four functions after `feeds`)
- Test: `tests/test_filters.py` (append `StoreFiltersTest` above the `if __name__` block)

**Interfaces:**
- Consumes: `feedwatch.models.Filter` (Task 1).
- Produces:
  - `store.feed_by_url(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]`. It returns `(filter_id, None)`, or `(None, reason)` where reason is `not subscribed to <url>` or `a filter needs at least one keyword`. Keywords are stripped, and blanks and exact repeats are dropped before the check.
  - `store.filters_for(conn, feed_id: int) -> list[Filter]`, ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> bool`. It returns False when no filter has that id.
  - Table `filters(id INTEGER PRIMARY KEY, feed_id INTEGER NOT NULL REFERENCES feeds(id), kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')), keywords TEXT NOT NULL)`. `keywords` holds a JSON array of strings.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.py`, above `if __name__ == "__main__":`:

```python
OLD_SCHEMA = [
    """CREATE TABLE feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        interval_minutes INTEGER NOT NULL DEFAULT 30
    )""",
    """CREATE TABLE entries (
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        published TEXT,
        read INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (feed_id, guid)
    )""",
]

URL = "http://x/feed"


class StoreFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        self.conn = store.connect(self.path)
        store.add_feed(self.conn, URL, "x")
        self.feed = store.feed_by_url(self.conn, URL)

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_a_feed_is_found_by_its_url(self):
        self.assertEqual(self.feed.url, URL)
        self.assertIsNone(store.feed_by_url(self.conn, "http://nowhere/feed"))

    def test_an_added_filter_is_listed_for_its_feed(self):
        filter_id, reason = store.add_filter(self.conn, URL, "include", ["python", "rust"])
        self.assertIsNone(reason)
        self.assertEqual(
            store.filters_for(self.conn, self.feed.id),
            [Filter(filter_id, self.feed.id, "include", ["python", "rust"])],
        )

    def test_a_filter_for_an_unsubscribed_feed_is_refused(self):
        filter_id, reason = store.add_filter(self.conn, "http://nowhere/feed", "include", ["x"])
        self.assertIsNone(filter_id)
        self.assertIn("http://nowhere/feed", reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        self.assertEqual(
            store.add_filter(self.conn, URL, "exclude", []),
            (None, "a filter needs at least one keyword"),
        )

    def test_blank_keywords_count_as_no_keywords(self):
        filter_id, reason = store.add_filter(self.conn, URL, "exclude", ["", "   "])
        self.assertIsNone(filter_id)
        self.assertEqual(reason, "a filter needs at least one keyword")
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])

    def test_keywords_are_stripped_and_repeats_dropped(self):
        store.add_filter(self.conn, URL, "include", [" python ", "python", "", "rust"])
        [stored] = store.filters_for(self.conn, self.feed.id)
        self.assertEqual(stored.keywords, ["python", "rust"])

    def test_a_removed_filter_is_gone(self):
        filter_id, _ = store.add_filter(self.conn, URL, "include", ["python"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.filters_for(self.conn, self.feed.id), [])
        self.assertFalse(store.remove_filter(self.conn, filter_id))

    def test_a_database_from_before_filters_keeps_working(self):
        old_path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(old_path)
        for step in OLD_SCHEMA:
            old.execute(step)
        old.execute("INSERT INTO feeds (url, title) VALUES (?, ?)", (URL, "x"))
        old.execute(
            "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'a', 'First', 'http://x/a')"
        )
        old.commit()
        old.close()

        conn = store.connect(old_path)
        try:
            self.assertEqual([e.guid for e in store.unread(conn)], ["a"])
            filter_id, reason = store.add_filter(conn, URL, "exclude", ["first"])
            self.assertIsNone(reason)
            self.assertEqual([f.id for f in store.filters_for(conn, 1)], [filter_id])
        finally:
            conn.close()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -v`
Expected: the `StoreFiltersTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'feed_by_url'`. `KeepsTest` still passes.

- [ ] **Step 3: Implement storage**

In `feedwatch/store.py`, change the imports to:

```python
import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append this element to the end of the `SCHEMA_STEPS` list, after the `entries` step:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Add these functions directly after `feeds()`:

```python
def feed_by_url(conn, url):
    """Return the subscribed Feed with this URL, or None."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def add_filter(conn, url, kind, keywords):
    """Attach an "include" or "exclude" filter to a subscribed feed.

    Keywords are stripped, and blanks and repeats are dropped. Returns
    (filter_id, None), or (None, reason) when the feed is not subscribed or
    no keyword remains.
    """
    feed = feed_by_url(conn, url)
    if feed is None:
        return None, f"not subscribed to {url}"
    words = list(dict.fromkeys(k.strip() for k in keywords if k.strip()))
    if not words:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(words)),
        )
    return cursor.lastrowid, None


def filters_for(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [Filter(id_, fid, kind, json.loads(words)) for id_, fid, kind, words in rows]


def remove_filter(conn, filter_id):
    """Delete a filter. Returns False when no filter has that id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    return cursor.rowcount == 1
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 3: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py` (import line; the end of the loop body in `poll_once`)
- Test: `tests/test_filters.py` (append `PollerFiltersTest` above the `if __name__` block)

**Interfaces:**
- Consumes: `filters.keeps(title, filters)` (Task 1); `store.add_filter`, `store.filters_for` (Task 2).
- Produces: `poller.poll_once(conn, last_polled, now)` keeps its signature. It now saves only the entries that the feed's filters keep.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.py`, above `if __name__ == "__main__":`:

```python
FILTER_RSS = b"""<rss><channel><title>t</title>
<item><guid>p</guid><title>Python tips</title><link>http://x/p</link></item>
<item><guid>s</guid><title>Sponsored post</title><link>http://x/s</link></item>
</channel></rss>"""


class PollerFiltersTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def poll(self):
        with mock.patch("feedwatch.fetch.fetch", return_value=FILTER_RSS):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))

    def stored(self, feed_id=1):
        return sorted(e.guid for e in store.unread(self.conn) if e.feed_id == feed_id)

    def test_a_feed_without_filters_stores_every_entry(self):
        self.poll()
        self.assertEqual(self.stored(), ["p", "s"])

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll()
        self.assertEqual(self.stored(), ["p"])

    def test_an_include_filter_stores_only_matching_entries(self):
        store.add_filter(self.conn, URL, "include", ["python"])
        self.poll()
        self.assertEqual(self.stored(), ["p"])

    def test_entries_already_stored_are_not_refiltered(self):
        self.poll()
        store.add_filter(self.conn, URL, "exclude", ["sponsored"])
        self.poll()
        self.assertEqual(self.stored(), ["p", "s"])

    def test_one_feeds_filters_do_not_apply_to_another(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, URL, "include", ["python"])
        self.poll()
        self.assertEqual(self.stored(feed_id=1), ["p"])
        self.assertEqual(self.stored(feed_id=2), ["p", "s"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -v`
Expected: `test_an_entry_a_filter_drops_is_never_stored`, `test_an_include_filter_stores_only_matching_entries` and `test_one_feeds_filters_do_not_apply_to_another` FAIL with `['p', 's'] != ['p']`. The other two already pass.

- [ ] **Step 3: Apply filters in the poller**

In `feedwatch/poller.py`, change the import to:

```python
from feedwatch import fetch, filters, parse, store
```

In `poll_once`, replace the last line of the loop body:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        feed_filters = store.filters_for(conn, feed.id)
        kept = [e for e in entries if filters.keeps(e["title"], feed_filters)]
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

### Task 4: `feedwatch filter` commands

**Files:**
- Modify: `feedwatch/cli.py` (parser setup in `main`; dispatch; new `run_filter` function)
- Test: `tests/test_filters.py` (append `CliFilterTest` above the `if __name__` block)

**Interfaces:**
- Consumes: `store.feed_by_url`, `store.add_filter`, `store.filters_for`, `store.remove_filter` (Task 2).
- Produces: these commands.
  - `feedwatch filter add URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]` prints the new filter id. Exactly one of the two flags is required.
  - `feedwatch filter list URL` prints one line per filter: `<id>  <kind>  <kw1>, <kw2>`.
  - `feedwatch filter remove FILTER_ID`.
  - Each refusal prints its reason to stderr and exits 1.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filters.py`, above `if __name__ == "__main__":`:

```python
class CliFilterTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        path = Path(self.dir.name) / "feeds.db"
        real_connect = store.connect
        self.conns = []

        def connect():
            conn = real_connect(path)
            self.conns.append(conn)
            return conn

        patcher = mock.patch.object(store, "connect", connect)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.run_cli("add", URL)

    def tearDown(self):
        for conn in self.conns:
            conn.close()
        self.dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self):
        code, out, _ = self.run_cli("filter", "add", URL, "--include", "python", "rust")
        self.assertEqual(code, 0)
        filter_id = out.strip()
        code, out, _ = self.run_cli("filter", "list", URL)
        self.assertEqual(code, 0)
        self.assertEqual(out, f"{filter_id}  include  python, rust\n")

    def test_adding_to_an_unsubscribed_feed_names_the_url(self):
        code, _, err = self.run_cli("filter", "add", "http://nowhere/feed", "--exclude", "x")
        self.assertEqual(code, 1)
        self.assertIn("http://nowhere/feed", err)

    def test_a_blank_keyword_is_refused(self):
        code, _, err = self.run_cli("filter", "add", URL, "--include", "")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_include_or_exclude_is_required(self):
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            cli.main(["filter", "add", URL])
        self.assertEqual(raised.exception.code, 2)

    def test_listing_an_unsubscribed_feed_names_the_url(self):
        code, _, err = self.run_cli("filter", "list", "http://nowhere/feed")
        self.assertEqual(code, 1)
        self.assertIn("http://nowhere/feed", err)

    def test_a_removed_filter_is_no_longer_listed(self):
        _, out, _ = self.run_cli("filter", "add", URL, "--exclude", "sponsored")
        code, _, _ = self.run_cli("filter", "remove", out.strip())
        self.assertEqual(code, 0)
        self.assertEqual(self.run_cli("filter", "list", URL)[1], "")

    def test_removing_an_unknown_filter_is_refused(self):
        code, _, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(code, 1)
        self.assertIn("no filter 99", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests/test_filters.py -v`
Expected: the `CliFilterTest` tests fail or error. argparse rejects `filter` with `invalid choice: 'filter'`, so the tests that go through `run_cli` raise `SystemExit: 2`.

- [ ] **Step 3: Add the parsers**

In `feedwatch/cli.py`, update the module docstring to:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, manage filters."""
```

In `main`, insert this after the `read.add_argument("guids", nargs="+")` line and before `args = parser.parse_args(argv)`:

```python
    filter_ = commands.add_parser("filter", help="manage a feed's keyword filters")
    filter_commands = filter_.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach an include or exclude filter")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD")
    kind.add_argument("--exclude", nargs="+", metavar="WORD")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter by its id")
    filter_remove.add_argument("filter_id", type=int)
```

- [ ] **Step 4: Dispatch to `run_filter`**

In `main`, replace the final `else:` branch:

```python
    else:
        store.mark_read(conn, args.guids)
    return 0
```

with:

```python
    elif args.command == "filter":
        return run_filter(conn, args)
    else:
        store.mark_read(conn, args.guids)
    return 0
```

Add this function between `main` and the `if __name__ == "__main__":` block:

```python
def run_filter(conn, args):
    if args.filter_command == "add":
        kind = "include" if args.include is not None else "exclude"
        filter_id, reason = store.add_filter(conn, args.url, kind, args.include or args.exclude)
        if reason:
            print(reason, file=sys.stderr)
            return 1
        print(filter_id)
    elif args.filter_command == "list":
        feed = store.feed_by_url(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for f in store.filters_for(conn, feed.id):
            print(f"{f.id}  {f.kind}  {', '.join(f.keywords)}")
    else:
        if not store.remove_filter(conn, args.filter_id):
            print(f"no filter {args.filter_id}", file=sys.stderr)
            return 1
    return 0
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests PASS.

- [ ] **Step 6: Check the help by hand**

Run: `python3 -m feedwatch.cli filter add --help`
Expected: usage shows `url` and the mutually exclusive `--include WORD [WORD ...] | --exclude WORD [WORD ...]`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

## Closing

When all four tasks are done, the full suite passes, and the branch has been reviewed, invoke `dopamine:finishing-work` before the workspace is cleaned up. The ledger should already record the ARCHITECTURE.md drift described in Global Constraints (the `filters` module, the `filters` table, and the poller calling `filters`) so that the sweep can place it.
````


## p002

#### Final message

I haven't written the plan yet. I need one decision from you first.

`.dopamine/config` lists `docs/PROGRAM-DESIGN.md` as a living document, but the file doesn't exist. That document holds the project's rules for how code is shaped: types, error handling, effects, function signatures, module layout. Every plan copies those rules into its Global Constraints, and they are checked again when the work closes.

**Should I run `dopamine:brainstorm-program-design` first to create `docs/PROGRAM-DESIGN.md`?** You would choose each rule from options I bring, and then I'd write the keyword-filters plan against them.

If you say no, I'll write the plan as usual, add one line to its Global Constraints saying no program-design rules applied, and commit it under `docs/superpowers/plans/`. I'll only write the plan, not implement it.

---
The implementation plan is written and committed at `docs/superpowers/plans/2026-10-12-keyword-filters.md` (commit `beffac0`). Nothing is implemented yet.

You chose not to create `docs/PROGRAM-DESIGN.md` first, so the plan's Global Constraints says in one line that it carries no program-design rules.

**Approach:**
- **Matching:** a new module, `feedwatch/filters.py`, decides whether a title passes a feed's filters. Matching ignores case and works on whole words. It also handles keywords with punctuation such as `c++` and `covid-19`, which a plain word-boundary match would miss.
- **Storage:** filters go in a new `filters` table in the existing database. The table is added the same way the current schema is set up, so a database created before this feature keeps working.
- **Polling:** the poller drops rejected entries before saving them, so they are never stored. Entries already saved are left alone.
- **Commands:** `feedwatch filter add`, `filter list` and `filter remove`, following the existing pattern: a refused command prints the reason and exits with code 1.

**Tasks:**
1. Title matching.
2. Storing filters, including a test that a database from before this feature still works.
3. The poller applies the filters.
4. The `filter` commands.

Before writing the plan, I applied all of its code to a throwaway copy of the repo, and all 28 tests passed there.

**Decisions I made that the spec doesn't settle:**
- When a feed has several filters, an entry is kept only if it passes every one of them.
- A keyword that is empty or only spaces counts as no keyword, so `--include ""` is refused.
- An entry with no title fails an include filter and passes an exclude filter.

These are listed in the plan's Review Focus, and each has a test.

ARCHITECTURE.md will need a `filters` component and the new table once the plan is carried out. The plan says to leave that document alone during the work and update it at the end.

I also ran the end-of-work documentation check for this planning step. It changed no document and is committed as `e6f6e4b`, with a short record of the planning saved next to the plan. `docs/ROADMAP.md` is also listed in `.dopamine/config` but doesn't exist; I didn't create it.

Please review the plan and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters-planning.reconstructed-ledger.md (added)

````
# Keyword filters planning — reconstructed ledger

> Reconstructed 2026-10-12 from the planning conversation. There was no superpowers ledger, because this unit of work was writing the plan, not executing it.

- `docs/PROGRAM-DESIGN.md` is declared in `.dopamine/config` but absent. The human was asked whether to run `dopamine:brainstorm-program-design` first and declined, so the plan copies no program-design rules and says so in its Global Constraints.
- Wrote and committed `docs/superpowers/plans/2026-10-12-keyword-filters.md`. Before writing it into the plan, its code was checked in a throwaway copy of the repo, where all 28 tests passed. No code changed in the repository.
- No living document changed. The ARCHITECTURE.md consequences (a `filters` component and a `filters` table) arise when the plan is executed, and that execution's sweep will place them.
````

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores entries whose titles the filters reject.

**Architecture:** A new pure module `feedwatch/filters.py` decides whether a title passes a feed's filters (case-insensitive, whole-word). `store` gains a `filters` table, added as a new idempotent schema step, plus functions to add, list and remove filters. `poller.poll_once` drops rejected entries before `store.save_entries`. `cli` gains `feedwatch filter add|list|remove`.

**Tech Stack:** Python 3.10+ standard library only (`sqlite3`, `re`, `json`, `argparse`), tests with `unittest`.

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- `docs/PROGRAM-DESIGN.md` is declared in `.dopamine/config` but absent. The human declined to create it first, so this plan copies no program-design rules.
- Standard library only. Add no dependencies (DESIGN.md: "Standard library first; a dependency has to earn its place").
- Matching is on the entry's **title** only. It is case-insensitive and matches **whole words**. Keywords are literal text, never regular expressions, so they go through `re.escape`.
- An include filter keeps only titles that contain at least one of its keywords. An exclude filter drops titles that contain any of its keywords. When a feed has several filters, an entry is stored only if it passes every one of them.
- Schema changes are only **appended** to `store.SCHEMA_STEPS` as `CREATE TABLE IF NOT EXISTS` steps. Never edit or reorder the existing steps: a database created before this feature must keep working.
- Module ownership follows `docs/ARCHITECTURE.md`. Only `store` writes SQL. `filters` owns matching and never stores. `poller` applies filters. `cli` handles presentation and never polls.
- Refusals follow the existing `store.add_feed` convention. A store function returns a reason string instead of raising, and `cli` prints the reason to stderr and returns exit code `1`.
- Entries already stored are never re-filtered. Filtering happens only in `poller.poll_once`, before `save_entries`.
- Do not edit living documents (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`) during execution. Record in the ledger that ARCHITECTURE.md needs updating, for `dopamine:finishing-work` to place. It gains a `filters` component and a `filters` table under "Where state lives".
- Code comments state only a why, a contract or a warning (`dopamine:writing-code-comments`).
- Run tests from the repo root with `python3 -m unittest tests.test_feedwatch -v`.

## Review Focus

1. **A keyword with punctuation** (`c++`, `covid-19`). A user expects it to match as a whole word. `\b` would never match `c++`, so the matcher uses lookarounds. Pinned in Task 1.
2. **A keyword that is empty or whitespace only** (`--include ""`). A user expects it to be refused the same way as a filter with no keywords. If it were stored, the empty pattern would match unpredictably. Pinned in Tasks 2 and 4.
3. **An entry with no title** (`parse` yields `""`). An include filter drops it and an exclude filter keeps it. Pinned in Task 1.
4. **Several filters on one feed.** Every filter must pass, and a filter on one feed never touches another feed. Pinned in Tasks 1 and 3.
5. **An unknown filter id on `remove`, or `list` for a URL that is not subscribed.** A user expects a message that names the id or URL and exit code 1, not silent success. Pinned in Task 4.

---

## File Structure

- Create `feedwatch/filters.py`. It holds the pure matching logic, `keeps(title, filters)` and `contains_word(title, keyword)`.
- Modify `feedwatch/models.py`. Add the `Filter` dataclass.
- Modify `feedwatch/store.py`. Add the `filters` schema step and the functions `find_feed`, `add_filter`, `feed_filters` and `remove_filter`.
- Modify `feedwatch/poller.py`. Apply a feed's filters in `poll_once`.
- Modify `feedwatch/cli.py`. Add the `filter add|list|remove` subcommands.
- Modify `tests/test_feedwatch.py`. Extract a `DatabaseCase` base class and add one test class per task.

---

### Task 1: Title matching

**Files:**
- Modify: `feedwatch/models.py` (append)
- Create: `feedwatch/filters.py`
- Test: `tests/test_feedwatch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])`, a dataclass where `kind` is `"include"` or `"exclude"`.
  - `feedwatch.filters.keeps(title: str, filters: list[Filter]) -> bool`
  - `feedwatch.filters.contains_word(title: str, keyword: str) -> bool`

- [ ] **Step 1: Write the failing tests**

Change the import block at the top of `tests/test_feedwatch.py` to:

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch import filters, parse, store
from feedwatch.models import Filter
```

Insert this immediately above `if __name__ == "__main__":`:

```python
def include(*words):
    return Filter(1, 1, "include", list(words))


def exclude(*words):
    return Filter(2, 1, "exclude", list(words))


class FilterMatchingTest(unittest.TestCase):
    def test_no_filters_keep_everything(self):
        self.assertTrue(filters.keeps("Anything", []))

    def test_include_keeps_only_titles_with_one_of_its_keywords(self):
        only = [include("python", "rust")]
        self.assertTrue(filters.keeps("Rust 2.0 released", only))
        self.assertFalse(filters.keeps("Go 2.0 released", only))

    def test_exclude_drops_titles_with_any_of_its_keywords(self):
        drop = [exclude("sponsored", "advert")]
        self.assertFalse(filters.keeps("Sponsored: a new laptop", drop))
        self.assertTrue(filters.keeps("A new laptop", drop))

    def test_matching_ignores_case(self):
        self.assertTrue(filters.keeps("PYTHON news", [include("Python")]))
        self.assertTrue(filters.keeps("Über alles", [include("über")]))

    def test_a_keyword_inside_a_longer_word_does_not_match(self):
        self.assertFalse(filters.keeps("How to concatenate lists", [include("cat")]))
        self.assertFalse(filters.keeps("Ten cats", [include("cat")]))

    def test_a_keyword_with_punctuation_matches_as_a_whole_word(self):
        self.assertTrue(filters.keeps("Modern C++ tips", [include("c++")]))
        self.assertTrue(filters.keeps("covid-19 update", [include("covid-19")]))
        self.assertFalse(filters.keeps("covid-190 update", [include("covid-19")]))

    def test_a_title_that_is_empty_fails_an_include_and_passes_an_exclude(self):
        self.assertFalse(filters.keeps("", [include("python")]))
        self.assertTrue(filters.keeps("", [exclude("python")]))

    def test_every_filter_on_a_feed_must_pass(self):
        several = [include("python"), include("release"), exclude("beta")]
        self.assertTrue(filters.keeps("Python 3.15 release", several))
        self.assertFalse(filters.keeps("Python 3.15 news", several))
        self.assertFalse(filters.keeps("Python 3.15 beta release", several))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: an import error, `cannot import name 'filters' from 'feedwatch'` (or `cannot import name 'Filter'`).

- [ ] **Step 3: Add the `Filter` dataclass**

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
"""Decides which entries a feed's keyword filters keep. Owns matching; never stores."""

import re


def keeps(title, filters):
    """Return True if every include filter matches the title and no exclude filter does."""
    for f in filters:
        matched = any(contains_word(title, keyword) for keyword in f.keywords)
        if matched != (f.kind == "include"):
            return False
    return True


def contains_word(title, keyword):
    """Return True if keyword occurs in title as a whole word, ignoring case."""
    # Lookarounds rather than \b: \b needs a word character at the keyword's
    # edge, so a keyword such as "c++" would never match.
    pattern = rf"(?<!\w){re.escape(keyword)}(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: all tests pass, the 4 existing ones and the 8 in `FilterMatchingTest`.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filters.py tests/test_feedwatch.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 2: Store filters

**Files:**
- Modify: `feedwatch/store.py` (module docstring, imports, `SCHEMA_STEPS`, new functions)
- Test: `tests/test_feedwatch.py`

**Interfaces:**
- Consumes: `feedwatch.models.Filter` (Task 1).
- Produces:
  - `store.find_feed(conn, url: str) -> Feed | None`
  - `store.add_filter(conn, feed_url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]` returns `(filter_id, None)` on success. It returns `(None, "not subscribed to <url>")` for a feed that is not subscribed, and `(None, "a filter needs at least one keyword")` when no keyword is left after blank ones are dropped. `kind` must be `"include"` or `"exclude"`.
  - `store.feed_filters(conn, feed_id: int) -> list[Filter]`, ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> bool` returns `False` if no filter has that id.
  - A `filters` table with the columns `id`, `feed_id`, `kind` and `keywords`, where `keywords` holds a JSON array of strings.
  - In tests, the `DatabaseCase` base class, which provides `self.dir` and `self.conn`, and the constant `FEED = "http://x/feed"`.

- [ ] **Step 1: Extract the shared database fixture**

In `tests/test_feedwatch.py`, change the import block to the following, which adds `import sqlite3`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import filters, parse, store
from feedwatch.models import Filter
```

Replace the start of `FeedwatchTest`, from `class FeedwatchTest(unittest.TestCase):` through the end of its `tearDown`, with:

```python
class DatabaseCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()


class FeedwatchTest(DatabaseCase):
```

Leave the four existing test methods unchanged underneath it.

- [ ] **Step 2: Write the failing tests**

Insert this immediately above `if __name__ == "__main__":`:

```python
FEED = "http://x/feed"


class StoreFilterTest(DatabaseCase):
    def test_a_filter_is_stored_with_its_kind_and_keywords(self):
        store.add_feed(self.conn, FEED, "x")
        filter_id, reason = store.add_filter(self.conn, FEED, "exclude", ["sponsored", "advert"])
        self.assertIsNone(reason)
        feed = store.find_feed(self.conn, FEED)
        self.assertEqual(
            store.feed_filters(self.conn, feed.id),
            [Filter(filter_id, feed.id, "exclude", ["sponsored", "advert"])],
        )

    def test_a_filter_for_a_feed_not_subscribed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, FEED, "include", ["python"])
        self.assertIsNone(filter_id)
        self.assertIn(FEED, reason)

    def test_a_filter_with_no_keywords_is_refused(self):
        store.add_feed(self.conn, FEED, "x")
        for keywords in ([], ["", "  "]):
            filter_id, reason = store.add_filter(self.conn, FEED, "include", keywords)
            self.assertIsNone(filter_id)
            self.assertIn("at least one keyword", reason)
        self.assertEqual(store.feed_filters(self.conn, store.find_feed(self.conn, FEED).id), [])

    def test_removing_a_filter_reports_whether_it_existed(self):
        store.add_feed(self.conn, FEED, "x")
        filter_id, _ = store.add_filter(self.conn, FEED, "include", ["python"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertFalse(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.feed_filters(self.conn, store.find_feed(self.conn, FEED).id), [])

    def test_a_database_from_before_filters_keeps_working(self):
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        old.execute(store.SCHEMA_STEPS[0])
        old.execute(store.SCHEMA_STEPS[1])
        old.execute("INSERT INTO feeds (url, title) VALUES (?, 'x')", (FEED,))
        old.commit()
        old.close()
        conn = store.connect(path)
        try:
            self.assertEqual([f.url for f in store.feeds(conn)], [FEED])
            filter_id, reason = store.add_filter(conn, FEED, "include", ["python"])
            self.assertIsNone(reason)
            self.assertEqual(store.feed_filters(conn, 1)[0].keywords, ["python"])
        finally:
            conn.close()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: the 5 `StoreFilterTest` tests fail or error with `AttributeError: module 'feedwatch.store' has no attribute 'add_filter'`. All other tests pass.

- [ ] **Step 4: Add the schema step and imports**

In `feedwatch/store.py`, change the module docstring and imports to:

```python
"""The SQLite database both processes share: feeds, their filters, and the entries seen in them."""

import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append this step as the **last** element of `SCHEMA_STEPS`, after the `entries` step:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

- [ ] **Step 5: Add the store functions**

Insert `find_feed` directly after `feeds()`:

```python
def find_feed(conn, url):
    """Return the subscribed feed with this URL, or None."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None
```

Append to the end of `feedwatch/store.py`:

```python


def add_filter(conn, feed_url, kind, keywords):
    """Attach an "include" or "exclude" filter to a subscribed feed.

    Returns (filter_id, None), or (None, reason) when the feed is not
    subscribed or no keyword is left once blank ones are dropped.
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


def feed_filters(conn, feed_id):
    rows = conn.execute(
        "SELECT id, feed_id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id",
        (feed_id,),
    )
    return [Filter(id_, feed_id_, kind, json.loads(keywords))
            for id_, feed_id_, kind, keywords in rows]


def remove_filter(conn, filter_id):
    """Delete a filter. Returns False if no filter has that id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    return cursor.rowcount == 1
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: all 17 tests pass.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/store.py tests/test_feedwatch.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 3: Poller applies filters

**Files:**
- Modify: `feedwatch/poller.py` (import line, `poll_once`)
- Test: `tests/test_feedwatch.py`

**Interfaces:**
- Consumes: `filters.keeps(title, filters) -> bool` (Task 1). `store.feed_filters(conn, feed_id) -> list[Filter]` and `store.add_filter(...)` (Task 2). The `DatabaseCase` test base and `FEED` (Task 2).
- Produces: `poller.poll_once(conn, last_polled, now)`, whose signature is unchanged. It now stores only the entries that pass the feed's filters.

- [ ] **Step 1: Write the failing tests**

Extend the imports at the top of `tests/test_feedwatch.py` to:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import filters, parse, poller, store
from feedwatch.models import Filter
```

Insert this immediately above `if __name__ == "__main__":`:

```python
TWO_ITEMS = b"""<rss><channel><title>t</title>
<item><guid>p</guid><title>Python release</title></item>
<item><guid>g</guid><title>Go release</title></item>
</channel></rss>"""


class PollerFilterTest(DatabaseCase):
    def poll(self):
        with mock.patch("feedwatch.fetch.fetch", return_value=TWO_ITEMS):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))

    def stored(self):
        return sorted(self.conn.execute("SELECT feed_id, guid FROM entries"))

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_feed(self.conn, FEED, "x")
        store.add_filter(self.conn, FEED, "include", ["python"])
        self.poll()
        self.assertEqual(self.stored(), [(1, "p")])

    def test_entries_already_stored_are_not_refiltered(self):
        store.add_feed(self.conn, FEED, "x")
        self.poll()
        store.add_filter(self.conn, FEED, "exclude", ["python"])
        self.poll()
        self.assertEqual(self.stored(), [(1, "g"), (1, "p")])

    def test_a_filter_applies_only_to_its_own_feed(self):
        store.add_feed(self.conn, FEED, "x")
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, FEED, "exclude", ["go"])
        self.poll()
        self.assertEqual(self.stored(), [(1, "p"), (2, "g"), (2, "p")])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: `test_an_entry_a_filter_drops_is_never_stored` and `test_a_filter_applies_only_to_its_own_feed` FAIL, because the dropped entries are stored. `test_entries_already_stored_are_not_refiltered` already passes, since nothing deletes stored entries, and it stays as a guard.

- [ ] **Step 3: Apply filters in `poll_once`**

In `feedwatch/poller.py`, change the import to:

```python
from feedwatch import fetch, filters, parse, store
```

Replace the last line of the loop body in `poll_once`,

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        feed_filters = store.feed_filters(conn, feed.id)
        kept = [e for e in entries if filters.keeps(e["title"], feed_filters)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: all 20 tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_feedwatch.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: `feedwatch filter` commands

**Files:**
- Modify: `feedwatch/cli.py` (module docstring, `main`, new `run_filter`)
- Test: `tests/test_feedwatch.py`

**Interfaces:**
- Consumes: `store.find_feed`, `store.add_filter`, `store.feed_filters` and `store.remove_filter` (Task 2). The `DatabaseCase` test base and `FEED` (Task 2).
- Produces the following commands. Each exits with code `0` on success and `1` on a refusal, and argparse usage errors exit with `2`.
  - `feedwatch filter add URL (--include WORD [WORD ...] | --exclude WORD [WORD ...])` prints `added filter <id>`.
  - `feedwatch filter list URL` prints one line per filter: `<id>  <kind>  <keywords separated by spaces>`.
  - `feedwatch filter remove FILTER_ID` prints nothing on success. For an unknown id it prints `no filter with id <id>` to stderr.

- [ ] **Step 1: Write the failing tests**

Extend the imports at the top of `tests/test_feedwatch.py` to:

```python
import contextlib
import io
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, filters, parse, poller, store
from feedwatch.models import Filter
```

Insert this immediately above `if __name__ == "__main__":`:

```python
class CliFilterTest(DatabaseCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("feedwatch.store.connect", return_value=self.conn), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self):
        store.add_feed(self.conn, FEED, "x")
        self.assertEqual(self.run_cli("filter", "add", FEED, "--include", "python", "rust"),
                         (0, "added filter 1\n", ""))
        self.run_cli("filter", "add", FEED, "--exclude", "beta")
        self.assertEqual(self.run_cli("filter", "list", FEED),
                         (0, "1  include  python rust\n2  exclude  beta\n", ""))

    def test_a_filter_for_a_feed_not_subscribed_is_refused_naming_the_url(self):
        code, out, err = self.run_cli("filter", "add", FEED, "--include", "python")
        self.assertEqual((code, out), (1, ""))
        self.assertIn(FEED, err)

    def test_a_filter_with_only_blank_keywords_is_refused(self):
        store.add_feed(self.conn, FEED, "x")
        code, _, err = self.run_cli("filter", "add", FEED, "--include", "")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_a_filter_with_no_keywords_is_a_usage_error(self):
        store.add_feed(self.conn, FEED, "x")
        with self.assertRaises(SystemExit) as raised:
            self.run_cli("filter", "add", FEED, "--include")
        self.assertEqual(raised.exception.code, 2)

    def test_include_and_exclude_together_is_a_usage_error(self):
        store.add_feed(self.conn, FEED, "x")
        with self.assertRaises(SystemExit) as raised:
            self.run_cli("filter", "add", FEED, "--include", "a", "--exclude", "b")
        self.assertEqual(raised.exception.code, 2)

    def test_a_removed_filter_is_no_longer_listed(self):
        store.add_feed(self.conn, FEED, "x")
        self.run_cli("filter", "add", FEED, "--include", "python")
        self.assertEqual(self.run_cli("filter", "remove", "1"), (0, "", ""))
        self.assertEqual(self.run_cli("filter", "list", FEED), (0, "", ""))

    def test_removing_an_unknown_filter_names_its_id(self):
        self.assertEqual(self.run_cli("filter", "remove", "99"),
                         (1, "", "no filter with id 99\n"))

    def test_listing_filters_of_a_feed_not_subscribed_names_the_url(self):
        self.assertEqual(self.run_cli("filter", "list", FEED),
                         (1, "", f"not subscribed to {FEED}\n"))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: the `CliFilterTest` tests error with `SystemExit: 2`, because argparse reports `invalid choice: 'filter'`. All other tests pass.

- [ ] **Step 3: Add the subcommands**

In `feedwatch/cli.py`, change the module docstring to:

```python
"""feedwatch's command line: subscribe, filter feeds, list unread entries, mark them read."""
```

In `main`, directly after `read.add_argument("guids", nargs="+")`, add:

```python
    flt = commands.add_parser("filter", help="keep or drop a feed's entries by title keyword")
    flt_commands = flt.add_subparsers(dest="filter_command", required=True)
    flt_add = flt_commands.add_parser("add", help="attach a filter to a feed")
    flt_add.add_argument("url")
    kind = flt_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD",
                      help="keep only entries whose title has one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD",
                      help="drop entries whose title has any of these words")
    flt_list = flt_commands.add_parser("list", help="list a feed's filters with their ids")
    flt_list.add_argument("url")
    flt_remove = flt_commands.add_parser("remove", help="remove a filter")
    flt_remove.add_argument("filter_id", type=int)
```

Replace the tail of `main`,

```python
    else:
        store.mark_read(conn, args.guids)
    return 0
```

with the following. The `else` still handles `read`.

```python
    elif args.command == "filter":
        return run_filter(conn, args)
    else:
        store.mark_read(conn, args.guids)
    return 0


def run_filter(conn, args):
    if args.filter_command == "add":
        kind, keywords = ("include", args.include) if args.include else ("exclude", args.exclude)
        filter_id, reason = store.add_filter(conn, args.url, kind, keywords)
        if reason:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.filter_command == "list":
        feed = store.find_feed(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for f in store.feed_filters(conn, feed.id):
            print(f"{f.id}  {f.kind}  {' '.join(f.keywords)}")
    elif not store.remove_filter(conn, args.filter_id):
        print(f"no filter with id {args.filter_id}", file=sys.stderr)
        return 1
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch -v`
Expected: all 28 tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/cli.py tests/test_feedwatch.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

## Spec coverage

| Spec requirement | Task |
|---|---|
| An include filter keeps titles with at least one keyword, and an exclude filter drops titles with any | 1 |
| Matching is case-insensitive, on whole words | 1 |
| `filter add` / `list` / `remove` | 4 |
| The poller applies filters when it saves, and a dropped entry is never stored | 3 |
| A filter for a feed that is not subscribed is refused, naming the URL | 2, 4 |
| A filter with no keywords is refused | 2, 4 |
| Filters live in the same database, and an old database keeps working | 2 |
| Entries already stored are not re-filtered | 3 |
| Out of scope: entry body, regular expressions | Global Constraints: title only, `re.escape` |
````


## p003

#### Final message

I haven't written the keyword-filters plan yet. I need one decision from you first.

`.dopamine/config` lists `docs/PROGRAM-DESIGN.md` as a living document, but the file doesn't exist in the repo. That document sets the structural rules a plan copies into its Global Constraints: where new code goes, how modules depend on each other, and how storage and schema migrations are handled. This feature hits several of those questions. It adds a filters table to the same database, has to keep databases created before the feature working, adds a `filter` subcommand group to the CLI, and adds filtering to the poller's save step.

Should I first run the `dopamine:brainstorm-program-design` recipe with you to write `docs/PROGRAM-DESIGN.md`, and then write the plan against it?

- **Yes:** we settle the program-design rules together first, then I write the plan and commit it under `docs/superpowers/plans/`.
- **No:** I write the plan as usual from the spec and the existing `feedwatch/` code, with one line in Global Constraints saying no program design existed. Then I commit it.

So far I've read the spec (`docs/superpowers/specs/2026-03-02-keyword-filters-design.md`) and the config. Nothing has been written or committed.

---
The keyword-filters plan is written and committed at `docs/superpowers/plans/2026-10-12-keyword-filters.md`. As you asked, it was planned without a program design. Global Constraints says in one line that `docs/PROGRAM-DESIGN.md` is declared in the config but missing and that you declined to write it first, so the plan follows the existing code and `docs/ARCHITECTURE.md`. Nothing has been implemented.

**The plan has four test-first tasks:**
1. **Store:** `feedwatch/models.py` gets a `Filter` model, and `feedwatch/store.py` gets a `filters` table plus `find_feed`, `add_filter`, `feed_filters` and `remove_filter`. The table is added as a new idempotent schema step, so databases created before the feature keep working; a test covers that.
2. **Matching:** a new pure module, `feedwatch/keywords.py`, with `passes(filters, title)`. Matching ignores case, works on whole words and treats keywords as plain text. A keyword ending in punctuation, such as `c++`, still matches.
3. **Poller:** entries are dropped before they are saved. Entries already stored are never re-filtered.
4. **Commands:** `filter add`, `filter list` and `filter remove` in `feedwatch/cli.py`, with refusals going to stderr with exit code 1. `main` also takes an optional `conn` so the tests can use a temporary database.

All new tests go in `tests/test_filters.py`. The Review Focus section adds tests for five likely trouble spots:
- keywords containing punctuation or regex characters
- keywords that are empty or only spaces
- removing a filter id that doesn't exist
- listing filters for a feed you aren't subscribed to
- several filters on one feed, or filters on another feed

I ran every code block in the plan in a scratch copy of the repo: all 33 tests pass, and each task's "fails first" expectation matches what actually happens.

**One decision for you to confirm:** the spec doesn't say how filters combine when a feed has several. The plan keeps an entry only if every filter keeps it, so two include filters both have to match. If you meant two include filters to mean "either word", that changes one function in Task 2 (`passes` in `feedwatch/keywords.py`) and one test there.

I also ran the end-of-work wrap-up (`dopamine:finishing-work`). It added a record of this planning session at `docs/superpowers/plans/2026-10-12-keyword-filters-planning.reconstructed-ledger.md` and committed it as "sweep: … nothing to drain", with the documents' line counts in the commit message. No living document was changed. `docs/ARCHITECTURE.md` will need the new `keywords` module and `filters` table once the plan is carried out, and the plan leaves that update to the wrap-up after execution.

Please review the plan and tell me whether it captures what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters-planning.reconstructed-ledger.md (added)

````
# Keyword filters planning — reconstructed ledger

Reconstructed on 2026-10-12 from the planning conversation. There was no superpowers ledger because this unit of work only wrote the plan.

- Wrote `docs/superpowers/plans/2026-10-12-keyword-filters.md` from `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`.
- `.dopamine/config` lists `docs/PROGRAM-DESIGN.md`, but the file is absent. I asked the human whether to run `dopamine:brainstorm-program-design` first; they declined, and the plan's Global Constraints says so.
- A plan-level reading the spec leaves open: when a feed has several filters, an entry is kept only if every filter keeps it.
- No code changed. Pending for the execution sweep: `docs/ARCHITECTURE.md` will need the `keywords` module and the `filters` table once the plan lands.
- Before committing, I ran every code block in the plan in a scratch copy: 33 tests passed.
````

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a subscribed feed, so the poller stores only the new entries whose titles get past them.

**Architecture:** `store` gains a `filters` table, added as a new idempotent schema step, and functions to add, list and remove filters. A new pure module, `keywords`, decides whether a title gets past a feed's filters. `poller` reads the feed's filters from `store` and drops entries before `store.save_entries`. `cli` gains a `filter` command group (`add`, `list`, `remove`) that calls `store` only.

**Tech Stack:** Python 3 standard library (`sqlite3`, `re`, `json`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

- No program design: `.dopamine/config` lists `docs/PROGRAM-DESIGN.md`, but the file does not exist. The human declined to write it first, so this plan follows the existing code and `docs/ARCHITECTURE.md`.
- Use only the standard library ("Standard library first; a dependency has to earn its place" — `docs/DESIGN.md`).
- Module boundaries follow `docs/ARCHITECTURE.md`:
  - `store` owns the schema and never touches the network.
  - `cli` calls `store` only.
  - `poller` calls `fetch`, `parse`, `store` and the new `keywords`.
  - `keywords` is pure: it does no I/O and has no `store` import.
- Schema changes are new idempotent steps appended to `store.SCHEMA_STEPS`. Existing steps are never edited, so "a database created before this feature keeps working."
- Matching is "case-insensitive, on whole words", on the entry's **title** only. Keywords are literal text, never regular expressions (out of scope per the spec).
- An include filter keeps only entries whose title contains at least one of its keywords. An exclude filter drops entries whose title contains any of its keywords.
- When a feed has several filters, an entry is kept only if **every** filter keeps it. The spec defines each filter as dropping entries and does not say how filters combine; this is the reading that follows from that.
- "An entry a filter drops is never stored." "Entries already stored are not re-filtered": adding a filter never deletes or changes stored entries.
- Refusals print one line to stderr and return exit code 1, as `feedwatch add` already does. A refused filter for an unsubscribed feed names the URL.
- Tests use `unittest`; pytest is not installed. Run the suite with `python3 -m unittest tests.test_feedwatch tests.test_filters -v` from the repo root. `discover` does not work because `tests/` has no `__init__.py`.
- `docs/ARCHITECTURE.md` will be out of date once this lands: it does not mention the `keywords` module or the `filters` table. Do not edit it during execution. Record it in the ledger, and the `dopamine:finishing-work` sweep will place it.

## Review Focus

1. **Keywords with punctuation or regex characters** (`c++`, `.net`, `a.b`). `c++` must match "Why C++ is hard", and `a.b` must not match "axb". A plain `\b…\b` pattern never matches a keyword that ends in punctuation. The test is in Task 2.
2. **Blank keywords** (`--include ""` or `--include "  "`). argparse's `nargs="+"` accepts these, but they must be refused as "a filter with no keywords". Tests are in Tasks 1 and 4.
3. **Removing an unknown filter id.** `filter remove 99` must say no such filter exists and exit 1, not succeed silently. Tests are in Tasks 1 and 4.
4. **Listing filters for an unsubscribed URL** must be refused with a message naming the URL, the same way adding is, not print an empty list. The test is in Task 4.
5. **Several filters on one feed, and filters on another feed.** An include filter and an exclude filter on the same feed must both apply. A filter on feed A must not affect feed B. Tests are in Tasks 1 and 3.

---

## File Structure

- Modify `feedwatch/models.py`: add the `Filter` dataclass.
- Modify `feedwatch/store.py`: add the `filters` schema step and `find_feed`, `add_filter`, `feed_filters` and `remove_filter`.
- Create `feedwatch/keywords.py`: `passes(filters, title)`, the matching rule and nothing else.
- Modify `feedwatch/poller.py`: filter parsed entries before saving them.
- Modify `feedwatch/cli.py`: the `filter add|list|remove` commands, and an optional `conn` parameter on `main` so tests can pass in a temporary database.
- Create `tests/test_filters.py`: all tests for this feature. `tests/test_feedwatch.py` is left unchanged.

---

### Task 1: Filters in the store

**Files:**
- Modify: `feedwatch/models.py` (append after `Entry`)
- Modify: `feedwatch/store.py:1-29` (docstring, imports, `SCHEMA_STEPS`) and append new functions after `feeds` (line 55)
- Test: `tests/test_filters.py` (create)

**Interfaces:**
- Consumes: the existing `store.connect(path)`, `store.add_feed(conn, url, title)` and `store.SCHEMA_STEPS`.
- Produces:
  - `models.Filter(id: int, feed_id: int, kind: str, keywords: list[str])`, where `kind` is `"include"` or `"exclude"`.
  - `store.find_feed(conn, url) -> Feed | None`
  - `store.add_filter(conn, feed_url: str, kind: str, keywords: list[str]) -> tuple[int | None, str | None]`, which returns `(filter_id, None)` or `(None, reason)`.
  - `store.feed_filters(conn, feed_id: int) -> list[Filter]`, ordered by id.
  - `store.remove_filter(conn, filter_id: int) -> bool`, which returns `False` when no filter has that id.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store


class TempDatabase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")
        self.feed = store.find_feed(self.conn, "http://x/feed")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()


class StoreFilterTest(TempDatabase):
    def test_a_filter_is_kept_with_its_keywords(self):
        filter_id, reason = store.add_filter(self.conn, "http://x/feed", "include", ["python", "rust"])
        self.assertIsNone(reason)
        [saved] = store.feed_filters(self.conn, self.feed.id)
        self.assertEqual(
            (saved.id, saved.feed_id, saved.kind, saved.keywords),
            (filter_id, self.feed.id, "include", ["python", "rust"]),
        )

    def test_a_feed_that_is_not_subscribed_is_unknown(self):
        self.assertIsNone(store.find_feed(self.conn, "http://nowhere/feed"))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self):
        filter_id, reason = store.add_filter(self.conn, "http://nowhere/feed", "exclude", ["x"])
        self.assertIsNone(filter_id)
        self.assertIn("http://nowhere/feed", reason)

    def test_a_filter_with_only_blank_keywords_is_refused(self):
        filter_id, reason = store.add_filter(self.conn, "http://x/feed", "include", ["", "  "])
        self.assertIsNone(filter_id)
        self.assertIn("keyword", reason)
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [])

    def test_blank_keywords_are_dropped_from_a_filter_that_has_others(self):
        store.add_filter(self.conn, "http://x/feed", "include", [" python ", ""])
        self.assertEqual(store.feed_filters(self.conn, self.feed.id)[0].keywords, ["python"])

    def test_a_feeds_filters_do_not_include_another_feeds(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, "http://y/feed", "exclude", ["rust"])
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [])

    def test_removing_a_filter_reports_whether_it_existed(self):
        filter_id, _ = store.add_filter(self.conn, "http://x/feed", "include", ["python"])
        self.assertTrue(store.remove_filter(self.conn, filter_id))
        self.assertFalse(store.remove_filter(self.conn, filter_id))
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [])

    def test_a_database_from_before_filters_gains_them(self):
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        for step in store.SCHEMA_STEPS[:2]:  # feeds and entries: the schema before filters
            old.execute(step)
        old.execute("INSERT INTO feeds (url, title) VALUES ('http://x/old', 'old')")
        old.commit()
        old.close()

        conn = store.connect(path)
        self.addCleanup(conn.close)
        filter_id, reason = store.add_filter(conn, "http://x/old", "exclude", ["rust"])
        self.assertIsNone(reason)
        feed = store.find_feed(conn, "http://x/old")
        self.assertEqual([f.id for f in store.feed_filters(conn, feed.id)], [filter_id])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: every test errors with `AttributeError: module 'feedwatch.store' has no attribute 'find_feed'` (raised in `setUp`).

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

In `feedwatch/store.py`, replace the module docstring and the imports with:

```python
"""The SQLite database both processes share: feeds, the entries seen in them, and the feeds' keyword filters."""

import json
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed, Filter
```

Append this step to the end of the `SCHEMA_STEPS` list, after the `entries` step:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Insert after `feeds(conn)`:

```python
def find_feed(conn, url):
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    return Feed(*row) if row else None


def add_filter(conn, feed_url, kind, keywords):
    """Attach a filter to a subscribed feed.

    Returns (filter_id, None), or (None, reason) when the feed is not subscribed
    or no keyword is left once blank ones are dropped.
    """
    feed = find_feed(conn, feed_url)
    if feed is None:
        return None, f"not subscribed to {feed_url}"
    keywords = [k.strip() for k in keywords if k.strip()]
    if not keywords:
        return None, "a filter needs at least one keyword"
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed.id, kind, json.dumps(keywords)),
        )
    return cursor.lastrowid, None


def feed_filters(conn, feed_id):
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
        return conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,)).rowcount == 1
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests pass: the 4 existing ones and the 8 new ones.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 2: The matching rule

**Files:**
- Create: `feedwatch/keywords.py`
- Test: `tests/test_filters.py` (add a test class)

**Interfaces:**
- Consumes: `models.Filter(id, feed_id, kind, keywords)` from Task 1.
- Produces: `keywords.passes(filters: list[Filter], title: str) -> bool`. It returns True when every filter keeps the title, and True for an empty list.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import keywords, store
from feedwatch.models import Filter
```

Add this class before the `if __name__ == "__main__":` line:

```python
def include(*words):
    return Filter(1, 1, "include", list(words))


def exclude(*words):
    return Filter(2, 1, "exclude", list(words))


class MatchingTest(unittest.TestCase):
    def test_no_filters_keep_everything(self):
        self.assertTrue(keywords.passes([], "Anything at all"))

    def test_include_keeps_a_title_with_any_of_its_keywords(self):
        self.assertTrue(keywords.passes([include("python", "rust")], "Rust 2.0 is out"))
        self.assertFalse(keywords.passes([include("python", "rust")], "Go 2.0 is out"))

    def test_exclude_drops_a_title_with_any_of_its_keywords(self):
        self.assertFalse(keywords.passes([exclude("sponsored", "ad")], "Sponsored: buy now"))
        self.assertTrue(keywords.passes([exclude("sponsored", "ad")], "A real post"))

    def test_matching_ignores_case(self):
        self.assertTrue(keywords.passes([include("PYTHON")], "python tips"))
        self.assertTrue(keywords.passes([include("über")], "ÜBER alles"))

    def test_matching_is_on_whole_words(self):
        self.assertFalse(keywords.passes([include("cat")], "Category theory"))
        self.assertTrue(keywords.passes([include("cat")], "My cat, again"))

    def test_a_keyword_ending_in_punctuation_still_matches(self):
        self.assertTrue(keywords.passes([include("c++")], "Why C++ is hard"))
        self.assertTrue(keywords.passes([include(".net")], "News from .NET land"))

    def test_keywords_are_literal_text_not_patterns(self):
        self.assertFalse(keywords.passes([include("a.b")], "axb"))
        self.assertTrue(keywords.passes([include("a.b")], "see a.b now"))

    def test_every_filter_must_keep_the_title(self):
        filters = [include("python"), exclude("rust")]
        self.assertTrue(keywords.passes(filters, "Python 3.15 released"))
        self.assertFalse(keywords.passes(filters, "Python and Rust"))
        self.assertFalse(keywords.passes(filters, "Go news"))

    def test_an_empty_title_fails_an_include_filter(self):
        self.assertFalse(keywords.passes([include("python")], ""))
        self.assertTrue(keywords.passes([exclude("python")], ""))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: an import error: `ImportError: cannot import name 'keywords' from 'feedwatch'`.

- [ ] **Step 3: Write the module**

Create `feedwatch/keywords.py`:

```python
"""Decides whether an entry's title gets past a feed's keyword filters."""

import re


def passes(filters, title):
    """True when every filter keeps the title; no filters keep everything."""
    return all(_keeps(filter_, title) for filter_ in filters)


def _keeps(filter_, title):
    found = any(_contains_word(title, keyword) for keyword in filter_.keywords)
    return found if filter_.kind == "include" else not found


def _contains_word(title, keyword):
    # Lookarounds rather than \b: \b needs a word character on the keyword's
    # side, so a keyword ending in punctuation, such as "c++", would never match.
    pattern = rf"(?<!\w){re.escape(keyword)}(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/keywords.py tests/test_filters.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 3: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py:7` (import) and `:27` (the save)
- Test: `tests/test_filters.py` (add a test class)

**Interfaces:**
- Consumes: `store.feed_filters(conn, feed_id)` and `store.add_filter(...)` from Task 1, `keywords.passes(filters, title)` from Task 2, and the existing `poller.poll_once(conn, last_polled, now)`.
- Produces: no new names. `poll_once` stores only the entries that pass the feed's filters.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import keywords, poller, store
from feedwatch.models import Filter
```

Add this before the `if __name__ == "__main__":` line:

```python
THREE_ENTRIES = b"""<rss><channel><title>t</title>
<item><guid>1</guid><title>Python 3.15 released</title><link>http://x/1</link></item>
<item><guid>2</guid><title>Rust news</title><link>http://x/2</link></item>
<item><guid>3</guid><title>Python and Rust</title><link>http://x/3</link></item>
</channel></rss>"""


class PollerFilterTest(TempDatabase):
    def poll(self):
        with mock.patch("feedwatch.fetch.fetch", return_value=THREE_ENTRIES):
            poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))

    def stored_titles(self, feed_id):
        rows = self.conn.execute(
            "SELECT title FROM entries WHERE feed_id = ? ORDER BY guid", (feed_id,)
        )
        return [title for (title,) in rows]

    def test_a_feed_without_filters_stores_every_entry(self):
        self.poll()
        self.assertEqual(
            self.stored_titles(self.feed.id),
            ["Python 3.15 released", "Rust news", "Python and Rust"],
        )

    def test_an_entry_a_filter_drops_is_never_stored(self):
        store.add_filter(self.conn, "http://x/feed", "exclude", ["rust"])
        self.poll()
        self.assertEqual(self.stored_titles(self.feed.id), ["Python 3.15 released"])

    def test_include_and_exclude_on_one_feed_both_apply(self):
        store.add_filter(self.conn, "http://x/feed", "include", ["python"])
        store.add_filter(self.conn, "http://x/feed", "exclude", ["rust"])
        self.poll()
        self.assertEqual(self.stored_titles(self.feed.id), ["Python 3.15 released"])

    def test_a_filter_on_one_feed_leaves_another_alone(self):
        store.add_feed(self.conn, "http://y/feed", "y")
        other = store.find_feed(self.conn, "http://y/feed")
        store.add_filter(self.conn, "http://x/feed", "exclude", ["rust"])
        self.poll()
        self.assertEqual(len(self.stored_titles(other.id)), 3)

    def test_entries_stored_before_a_filter_is_added_stay(self):
        self.poll()
        store.add_filter(self.conn, "http://x/feed", "exclude", ["rust"])
        self.poll()
        self.assertEqual(len(self.stored_titles(self.feed.id)), 3)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: `test_an_entry_a_filter_drops_is_never_stored` and `test_include_and_exclude_on_one_feed_both_apply` fail because the Rust entries were stored. The other three pass already, since they pin behaviour that has to survive the change.

- [ ] **Step 3: Filter before saving**

In `feedwatch/poller.py`, change the import line to:

```python
from feedwatch import fetch, keywords, parse, store
```

Replace the last line of the loop in `poll_once`:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        filters = store.feed_filters(conn, feed.id)
        kept = [entry for entry in entries if keywords.passes(filters, entry["title"])]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_feedwatch tests.test_filters -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: The `filter` commands

**Files:**
- Modify: `feedwatch/cli.py` (docstring; `main` signature, parser and dispatch; new `run_filter`)
- Test: `tests/test_filters.py` (add a test class)

**Interfaces:**
- Consumes: `store.find_feed`, `store.add_filter`, `store.feed_filters` and `store.remove_filter` from Task 1.
- Produces:
  - `cli.main(argv=None, conn=None) -> int`. When `conn` is None, `main` opens the default database as before.
  - These command forms:
    - `feedwatch filter add URL (--include WORD [WORD ...] | --exclude WORD [WORD ...])` prints `added filter <id>`.
    - `feedwatch filter list URL` prints one `<id>  <kind>  <kw1>, <kw2>` line per filter.
    - `feedwatch filter remove FILTER_ID` prints nothing on success.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the imports to:

```python
import contextlib
import io
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, keywords, poller, store
from feedwatch.models import Filter
```

Add this before the `if __name__ == "__main__":` line:

```python
class FilterCommandTest(TempDatabase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.main(list(argv), conn=self.conn)
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self):
        code, out, _ = self.run_cli("filter", "add", "http://x/feed", "--include", "python", "rust")
        self.assertEqual((code, out), (0, "added filter 1\n"))
        code, out, _ = self.run_cli("filter", "list", "http://x/feed")
        self.assertEqual((code, out), (0, "1  include  python, rust\n"))

    def test_adding_a_filter_to_an_unsubscribed_feed_is_refused(self):
        code, _, err = self.run_cli("filter", "add", "http://nowhere/feed", "--exclude", "x")
        self.assertEqual(code, 1)
        self.assertIn("http://nowhere/feed", err)

    def test_a_filter_of_blank_keywords_is_refused(self):
        code, _, err = self.run_cli("filter", "add", "http://x/feed", "--include", "", "  ")
        self.assertEqual(code, 1)
        self.assertIn("keyword", err)

    def test_a_filter_must_be_include_or_exclude(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            cli.main(["filter", "add", "http://x/feed"], conn=self.conn)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            cli.main(
                ["filter", "add", "http://x/feed", "--include", "a", "--exclude", "b"],
                conn=self.conn,
            )

    def test_listing_an_unsubscribed_feed_is_refused_naming_the_url(self):
        code, out, err = self.run_cli("filter", "list", "http://nowhere/feed")
        self.assertEqual((code, out), (1, ""))
        self.assertIn("http://nowhere/feed", err)

    def test_a_removed_filter_is_no_longer_listed(self):
        self.run_cli("filter", "add", "http://x/feed", "--exclude", "rust")
        code, _, _ = self.run_cli("filter", "remove", "1")
        self.assertEqual(code, 0)
        self.assertEqual(self.run_cli("filter", "list", "http://x/feed")[1], "")

    def test_removing_an_unknown_filter_is_refused(self):
        code, _, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(code, 1)
        self.assertIn("99", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: the `FilterCommandTest` tests error with `TypeError: main() got an unexpected keyword argument 'conn'`.

- [ ] **Step 3: Add the commands**

Replace `feedwatch/cli.py` with:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, and manage keyword filters."""

import argparse
import sys

from feedwatch import store


def main(argv=None, conn=None):
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
    filter_ = commands.add_parser("filter", help="manage a feed's keyword filters")
    filter_commands = filter_.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="keep or drop new entries by title keywords")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD")
    kind.add_argument("--exclude", nargs="+", metavar="WORD")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    if conn is None:
        conn = store.connect()
    if args.command == "add":
        ok, reason = store.add_feed(conn, args.url, args.title or args.url, args.every)
        if not ok:
            print(reason, file=sys.stderr)
            return 1
    elif args.command == "unread":
        for entry in store.unread(conn, args.limit):
            print(f"{entry.guid}  {entry.title}\n    {entry.link}")
    elif args.command == "filter":
        return run_filter(conn, args)
    else:
        store.mark_read(conn, args.guids)
    return 0


def run_filter(conn, args):
    if args.filter_command == "add":
        kind = "include" if args.include is not None else "exclude"
        filter_id, reason = store.add_filter(conn, args.url, kind, args.include or args.exclude)
        if reason:
            print(reason, file=sys.stderr)
            return 1
        print(f"added filter {filter_id}")
    elif args.filter_command == "list":
        feed = store.find_feed(conn, args.url)
        if feed is None:
            print(f"not subscribed to {args.url}", file=sys.stderr)
            return 1
        for filter_ in store.feed_filters(conn, feed.id):
            print(f"{filter_.id}  {filter_.kind}  {', '.join(filter_.keywords)}")
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
Expected: all tests pass.

- [ ] **Step 5: Smoke-test the real command line**

Run each command with `HOME` pointed at a temporary directory, so the real `~/.feedwatch` is untouched:

```bash
export HOME=$(mktemp -d)
python3 -m feedwatch.cli add http://x/feed
python3 -m feedwatch.cli filter add http://x/feed --include python rust   # added filter 1
python3 -m feedwatch.cli filter list http://x/feed                       # 1  include  python, rust
python3 -m feedwatch.cli filter add http://nowhere --exclude x; echo $?  # not subscribed to http://nowhere, then 1
python3 -m feedwatch.cli filter remove 1; echo $?                        # 0
python3 -m feedwatch.cli filter remove 1; echo $?                        # no filter with id 1, then 1
```

Expected: the output shown in each comment.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: filter add, list and remove commands"
```
````



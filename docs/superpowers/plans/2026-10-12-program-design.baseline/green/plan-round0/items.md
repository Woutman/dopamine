## p001

#### Final message

Plan complete and saved to `docs/superpowers/plans/2026-10-12-keyword-filters.md`, committed as `9754f24 plan: keyword filters` on `master` in <repo>. Nothing was implemented.

**The four tasks:**
1. **Filter value and matching.** A new `feedwatch/errors.py` with `FeedwatchError` and the three refusals. A frozen `Filter` dataclass in `models.py`. A new logic module `feedwatch/keywords.py` whose one public function is `keeps(filters, title) -> bool`: keywords are matched case-insensitively, as whole words, and literally (no regular expressions).
2. **Store.** A `filters` table appended to `SCHEMA_STEPS` with `IF NOT EXISTS`, plus `add_filter(conn, feed_url, *, mode, keywords)`, `feed_filters(conn, feed_url)` and `remove_filter(conn, filter_id)`. These refuse an unsubscribed URL (the message names the URL), a filter with no keywords, and an unknown filter id. One test builds a database from before this feature and checks it still works.
3. **Poller.** `poll_once` drops entries that `keeps` rejects before it saves them. It gains a keyword-only `fetch_feed` parameter so the tests don't need the network. Entries already stored are not re-filtered.
4. **CLI.** `feedwatch filter add|list|remove`. `main` gains a `db_path` parameter, and any `FeedwatchError` prints its message and exits 1.

**Program design:** every rule in `docs/PROGRAM-DESIGN.md` applies to this feature. Each one is copied into Global Constraints with its check, and Task 4 ends with a step that checks the added lines against them. The document already settles every structural choice this feature needs, so I had nothing to ask the human.

**Decisions worth a look when reviewing:**
- **Several filters on one feed:** I read the spec as "an entry is stored only if every filter keeps it". So two include filters on one feed both have to match. This is stated in Global Constraints and pinned by a test.
- **Existing code is left alone:** some existing code doesn't follow the program-design rules: `add_feed` returns `(ok, reason)`, `parse` returns dicts, and `Feed`/`Entry` aren't frozen. The plan doesn't change any of it; the rules are checked only on added lines. Because `parse` still hands over dicts, `keeps` takes the title string rather than an entry dict.
- **Filter mode:** `mode` is a `Literal["include", "exclude"]` field rather than an Enum, so `Filter` is the only new domain type.

**Review Focus** (each has a test in the task that owns the code): keywords like `C++` and `node.js` are taken literally; punctuation next to a word still counts as a word edge, but `rust` doesn't match inside `trust`; blank keywords are refused; multiple filters combine as above; removing an unknown filter or listing an unsubscribed feed is refused.

**Verification:** I ran all the plan's code in a scratch clone. The 25 new tests and the 4 existing ones (29 in total) pass, and the clone has been deleted.

I didn't run `dopamine:finishing-work`. Its sweep belongs at the end of executing the plan, not after writing it.

Please review the plan. Does it capture what you want?

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores entries whose titles the filters drop.

**Architecture:** A new frozen `Filter` value in `models.py`; a new pure logic module `feedwatch/keywords.py` whose one public function, `keeps`, decides whether a title gets past a feed's filters; three new `store` functions over a new `filters` table appended to `SCHEMA_STEPS`; `poller.poll_once` drops entries `keeps` rejects before `save_entries`; `cli` gains `filter add|list|remove`. Refusals are `FeedwatchError` subclasses from a new `feedwatch/errors.py`, caught only in `cli`.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `re`, `json`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

**Run all tests:** `python3 -m unittest discover -s tests -v` from the repository root.

## Global Constraints

From the spec:

- Matching is case-insensitive, on whole words, against the entry's **title** only. Not the body; no regular expressions (keywords are matched literally).
- Filters are applied when the poller saves new entries. An entry a filter drops is never stored. Entries already stored are not re-filtered.
- A filter for a feed that is not subscribed is refused, with a message naming the URL. A filter with no keywords is refused.
- Filters live in the same database, and a database created before this feature keeps working.
- Reading of the spec this plan commits to: each of a feed's filters applies on its own, so an entry is stored only if **every** filter keeps it (an include and an exclude both apply; two include filters both have to match).

From `docs/PROGRAM-DESIGN.md` (every rule applies to the lines this plan adds; each is followed by its check):

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects.** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout.** Split by responsibility, not technical layer; files that change together live together. Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan meets them, and what it deliberately leaves alone:

- `feedwatch/errors.py` does not exist yet; Task 1 creates it. Existing code that predates the rules (`store.add_feed`'s `(ok, reason)` pair, `parse` returning dicts and `None`, unfrozen `Feed`/`Entry`, `fetch.FetchError`) is **not** refactored — out of scope; the checks are judged over added lines only.
- `parse` still hands the poller dicts, so the new matching function takes the title **string**, never an entry dict. The poller (existing function) reads `e["title"]` from the dicts it already handles.
- The filter's mode is a `Literal["include", "exclude"]` field, not a new `Enum`, so the only new domain type is the frozen `Filter`.
- `poll_once` gains a keyword-only `fetch_feed` parameter and `cli.main` a `db_path` parameter, so tests pass in a fake fetcher and a temporary database instead of mocking.
- Nothing new is added to `poller`'s threading; no executor is introduced.

## Review Focus

1. A keyword containing regex metacharacters (`C++`, `node.js`) is matched literally: no crash on `C++`, and `node.js` does not match `nodexjs`. Pinned in Task 1.
2. Punctuation next to a keyword in the title (`Python,`, `Python's`, `(Python)`, `Python-based`) still counts as a whole-word match, while `rust` does not match inside `trust`. Pinned in Task 1.
3. A blank or whitespace-only keyword (`--include ""`, `--include " "`) is refused as "no keywords" instead of creating a filter that matches nothing; surrounding spaces on real keywords are stripped. Pinned in Tasks 2 and 4.
4. Several filters on one feed combine: an include plus an exclude both apply, and two include filters both have to match. Pinned in Task 1.
5. `filter remove` with an id that does not exist, and `filter list` for an unsubscribed URL, are refused with a message and exit status 1, not silent success. Pinned in Tasks 2 and 4.

---

## File Structure

- Create `feedwatch/errors.py`: `FeedwatchError` and the three refusals this feature raises.
- Modify `feedwatch/models.py`: add the frozen `Filter` dataclass.
- Create `feedwatch/keywords.py`: logic module; one public function `keeps` deciding whether a title gets past a feed's filters.
- Modify `feedwatch/store.py`: append the `filters` table to `SCHEMA_STEPS`; add `add_filter`, `feed_filters`, `remove_filter` and a private `_feed_id`.
- Modify `feedwatch/poller.py`: inject `fetch_feed`; filter parsed entries before saving.
- Modify `feedwatch/cli.py`: `filter add|list|remove`; injectable `db_path`; catch `FeedwatchError`.
- Create `tests/test_keyword_filters.py`: all tests for this feature, one class per task.

---

### Task 1: Filter value and keyword matching

**Files:**
- Create: `feedwatch/errors.py`
- Modify: `feedwatch/models.py` (append after `Entry`, add one import)
- Create: `feedwatch/keywords.py`
- Test: `tests/test_keyword_filters.py` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `feedwatch.errors.FeedwatchError(Exception)`, and its subclasses `NotSubscribedError`, `EmptyFilterError`, `UnknownFilterError`.
  - `feedwatch.models.Filter` — `@dataclass(frozen=True)` with fields `id: int`, `feed_id: int`, `mode: Literal["include", "exclude"]`, `keywords: tuple[str, ...]`.
  - `feedwatch.keywords.keeps(filters: Sequence[Filter], title: str) -> bool` — `True` when every filter lets the title through; `True` for no filters.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_keyword_filters.py`:

```python
import unittest

from feedwatch import keywords
from feedwatch.models import Filter


def include(*words: str) -> Filter:
    return Filter(1, 1, "include", words)


def exclude(*words: str) -> Filter:
    return Filter(2, 1, "exclude", words)


class KeepsTest(unittest.TestCase):
    def test_no_filters_keep_everything(self) -> None:
        self.assertTrue(keywords.keeps([], "Anything at all"))

    def test_include_keeps_only_titles_with_one_of_its_keywords(self) -> None:
        self.assertTrue(keywords.keeps([include("rust", "python")], "Python 3.14 released"))
        self.assertFalse(keywords.keeps([include("rust", "python")], "Release notes"))

    def test_exclude_drops_titles_with_any_of_its_keywords(self) -> None:
        self.assertFalse(keywords.keeps([exclude("job", "sponsored")], "SPONSORED: buy now"))
        self.assertTrue(keywords.keeps([exclude("job", "sponsored")], "Daily news"))

    def test_matching_ignores_case_beyond_ascii(self) -> None:
        self.assertTrue(keywords.keeps([include("ölpreis")], "ÖLPREIS steigt"))

    def test_a_keyword_inside_a_longer_word_does_not_match(self) -> None:
        self.assertFalse(keywords.keeps([include("rust")], "Why I trust my compiler"))

    def test_punctuation_next_to_a_keyword_still_counts_as_a_word_edge(self) -> None:
        for title in ["Python, again", "Python's future", "(Python) notes", "Python-based tools"]:
            with self.subTest(title=title):
                self.assertTrue(keywords.keeps([include("python")], title))

    def test_keywords_are_literal_not_patterns(self) -> None:
        self.assertTrue(keywords.keeps([include("C++")], "C++ 26 ships"))
        self.assertTrue(keywords.keeps([include("node.js")], "What's new in Node.js"))
        self.assertFalse(keywords.keeps([include("node.js")], "nodexjs is not it"))

    def test_a_keyword_of_several_words_matches_them_together(self) -> None:
        self.assertTrue(keywords.keeps([include("machine learning")], "Machine learning for all"))
        self.assertFalse(keywords.keeps([include("machine learning")], "Learning a machine"))

    def test_an_empty_title_fails_an_include_and_passes_an_exclude(self) -> None:
        self.assertFalse(keywords.keeps([include("python")], ""))
        self.assertTrue(keywords.keeps([exclude("python")], ""))

    def test_every_filter_on_a_feed_must_keep_the_entry(self) -> None:
        both = [include("python"), exclude("job")]
        self.assertTrue(keywords.keeps(both, "Python tips"))
        self.assertFalse(keywords.keeps(both, "Python job board"))
        two_includes = [include("python"), Filter(3, 1, "include", ("rust",))]
        self.assertFalse(keywords.keeps(two_includes, "Python tips"))
        self.assertTrue(keywords.keeps(two_includes, "Python and Rust compared"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: ERROR — `ImportError: cannot import name 'keywords' from 'feedwatch'`.

- [ ] **Step 3: Create `feedwatch/errors.py`**

```python
"""The failures feedwatch reports. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Something feedwatch was asked to do could not be done."""


class NotSubscribedError(FeedwatchError):
    """A command named a feed URL with no subscription."""


class EmptyFilterError(FeedwatchError):
    """A filter was given no keywords."""


class UnknownFilterError(FeedwatchError):
    """A command named a filter id that does not exist."""
```

- [ ] **Step 4: Add `Filter` to `feedwatch/models.py`**

Add `from typing import Literal` below `from datetime import datetime`, and append at the end of the file:

```python


@dataclass(frozen=True)
class Filter:
    """Keywords that decide which of a feed's new entries are stored."""

    id: int
    feed_id: int
    mode: Literal["include", "exclude"]
    keywords: tuple[str, ...]
```

Leave `Feed` and `Entry` as they are.

- [ ] **Step 5: Create `feedwatch/keywords.py`**

```python
"""Decides whether an entry's title gets past a feed's keyword filters."""

import re
from collections.abc import Sequence

from feedwatch.models import Filter


def keeps(filters: Sequence[Filter], title: str) -> bool:
    """Return whether every one of the filters lets an entry with this title through.

    An include filter lets a title through when it contains at least one of the
    filter's keywords, an exclude filter when it contains none. Keywords match
    whole words, ignoring case, and are taken literally.
    """
    return all(_mentions(f.keywords, title) == (f.mode == "include") for f in filters)


def _mentions(keywords: Sequence[str], title: str) -> bool:
    # Not \b: a keyword ending in punctuation, such as "C++", has no word
    # boundary after it when a space follows.
    return any(
        re.search(rf"(?<!\w){re.escape(k)}(?!\w)", title, re.IGNORECASE) for k in keywords
    )
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all 14 tests PASS (10 new, 4 existing).

- [ ] **Step 7: Commit**

```bash
git add feedwatch/errors.py feedwatch/models.py feedwatch/keywords.py tests/test_keyword_filters.py
git commit -m "feat: keyword filter value and whole-word title matching"
```

---

### Task 2: Store filters in the database

**Files:**
- Modify: `feedwatch/store.py` (imports; `SCHEMA_STEPS` gains a third step; four functions appended)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `Filter`, `NotSubscribedError`, `EmptyFilterError`, `UnknownFilterError` from Task 1.
- Produces:
  - `store.add_filter(conn: sqlite3.Connection, feed_url: str, *, mode: Literal["include", "exclude"], keywords: Sequence[str]) -> Filter` — strips each keyword, drops blank ones; raises `NotSubscribedError` (message `not subscribed to <url>`) or `EmptyFilterError` (message `a filter needs at least one keyword`).
  - `store.feed_filters(conn: sqlite3.Connection, feed_url: str) -> list[Filter]` — oldest first; raises `NotSubscribedError`.
  - `store.remove_filter(conn: sqlite3.Connection, filter_id: int) -> None` — raises `UnknownFilterError` (message `no filter with id <id>`).

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, replace the import block at the top with:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import keywords, store
from feedwatch.errors import EmptyFilterError, NotSubscribedError, UnknownFilterError
from feedwatch.models import Filter

FEED = "http://x/feed"
```

Then add, after `KeepsTest` and before `if __name__ == "__main__":`:

```python
class DatabaseTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        self.conn = store.connect(self.path)
        store.add_feed(self.conn, FEED, "x")

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()


class StoreFiltersTest(DatabaseTest):
    def test_an_added_filter_is_listed_with_its_keywords_stripped(self) -> None:
        added = store.add_filter(self.conn, FEED, mode="include", keywords=[" python ", "rust"])
        self.assertEqual(added.mode, "include")
        self.assertEqual(added.keywords, ("python", "rust"))
        self.assertEqual(store.feed_filters(self.conn, FEED), [added])

    def test_a_keyword_with_a_space_survives_the_round_trip(self) -> None:
        store.add_filter(self.conn, FEED, mode="exclude", keywords=["machine learning"])
        self.assertEqual(store.feed_filters(self.conn, FEED)[0].keywords, ("machine learning",))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        with self.assertRaisesRegex(NotSubscribedError, "http://nope/feed"):
            store.add_filter(self.conn, "http://nope/feed", mode="include", keywords=["python"])

    def test_listing_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        with self.assertRaisesRegex(NotSubscribedError, "http://nope/feed"):
            store.feed_filters(self.conn, "http://nope/feed")

    def test_a_filter_with_no_keywords_is_refused_and_not_stored(self) -> None:
        for given in [[], [""], ["  ", "\t"]]:
            with self.subTest(keywords=given), self.assertRaises(EmptyFilterError):
                store.add_filter(self.conn, FEED, mode="include", keywords=given)
        self.assertEqual(store.feed_filters(self.conn, FEED), [])

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        added = store.add_filter(self.conn, FEED, mode="include", keywords=["python"])
        store.remove_filter(self.conn, added.id)
        self.assertEqual(store.feed_filters(self.conn, FEED), [])

    def test_removing_a_filter_that_does_not_exist_is_refused(self) -> None:
        with self.assertRaisesRegex(UnknownFilterError, "99"):
            store.remove_filter(self.conn, 99)

    def test_a_database_from_before_filters_keeps_working(self) -> None:
        old_path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(old_path)
        for step in store.SCHEMA_STEPS[:2]:
            old.execute(step)
        with old:
            old.execute("INSERT INTO feeds (url, title) VALUES (?, ?)", (FEED, "x"))
            old.execute(
                "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'a', 'Old', 'http://x/a')"
            )
        old.close()
        conn = store.connect(old_path)
        self.addCleanup(conn.close)
        store.add_filter(conn, FEED, mode="exclude", keywords=["old"])
        self.assertEqual([e.title for e in store.unread(conn)], ["Old"])
```

(The last test builds a pre-feature database from the first two schema steps, so it uses `sqlite3` directly; that is test code, outside the Effects check, which covers the package.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: the eight `StoreFiltersTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_filter'`; `KeepsTest` still passes.

- [ ] **Step 3: Update `store.py`'s imports**

Replace:

```python
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.models import Entry, Feed
```

with:

```python
import json
import sqlite3
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path
from typing import Literal

from feedwatch.errors import EmptyFilterError, NotSubscribedError, UnknownFilterError
from feedwatch.models import Entry, Feed, Filter
```

- [ ] **Step 4: Append the `filters` table to `SCHEMA_STEPS`**

Add a third element after the `entries` step, inside the list, without touching the first two:

```python
    # keywords holds a JSON list, since a keyword may itself contain spaces.
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        mode TEXT NOT NULL CHECK (mode IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

- [ ] **Step 5: Append the filter functions at the end of `store.py`**

```python


def add_filter(
    conn: sqlite3.Connection,
    feed_url: str,
    *,
    mode: Literal["include", "exclude"],
    keywords: Sequence[str],
) -> Filter:
    """Attach a keyword filter to a subscribed feed and return it with its new id.

    Surrounding whitespace is stripped from each keyword and blank ones are dropped.
    Raises NotSubscribedError when feed_url is not subscribed, and EmptyFilterError
    when no keyword is left.
    """
    feed_id = _feed_id(conn, feed_url)
    cleaned = tuple(k.strip() for k in keywords if k.strip())
    if not cleaned:
        raise EmptyFilterError("a filter needs at least one keyword")
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, mode, keywords) VALUES (?, ?, ?)",
            (feed_id, mode, json.dumps(cleaned)),
        )
    return Filter(cursor.lastrowid, feed_id, mode, cleaned)


def feed_filters(conn: sqlite3.Connection, feed_url: str) -> list[Filter]:
    """Return a feed's filters, oldest first. Raises NotSubscribedError when feed_url is not subscribed."""
    feed_id = _feed_id(conn, feed_url)
    rows = conn.execute(
        "SELECT id, mode, keywords FROM filters WHERE feed_id = ? ORDER BY id", (feed_id,)
    )
    return [
        Filter(filter_id, feed_id, mode, tuple(json.loads(words)))
        for filter_id, mode, words in rows
    ]


def remove_filter(conn: sqlite3.Connection, filter_id: int) -> None:
    """Delete a filter. Raises UnknownFilterError when no filter has filter_id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    if cursor.rowcount == 0:
        raise UnknownFilterError(f"no filter with id {filter_id}")


def _feed_id(conn: sqlite3.Connection, feed_url: str) -> int:
    row = conn.execute("SELECT id FROM feeds WHERE url = ?", (feed_url,)).fetchone()
    if row is None:
        raise NotSubscribedError(f"not subscribed to {feed_url}")
    return row[0]
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all 22 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/store.py tests/test_keyword_filters.py
git commit -m "feat: store keyword filters in a new filters table"
```

---

### Task 3: The poller applies a feed's filters

**Files:**
- Modify: `feedwatch/poller.py` (imports; `poll_once` signature and its last line)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `keywords.keeps` (Task 1); `store.feed_filters`, `store.add_filter` (Task 2).
- Produces: `poller.poll_once(conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch)` — the existing three positional parameters are unchanged; `fetch_feed` lets a test supply the XML without the network.

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, change `from feedwatch import keywords, store` to `from feedwatch import keywords, poller, store`, add `from datetime import datetime, timedelta` after `import unittest`, and add below `FEED = "http://x/feed"`:

```python

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>Python tips</title><link>http://x/a</link>
<pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>
<item><guid>b</guid><title>Sponsored: buy now</title><link>http://x/b</link>
<pubDate>Mon, 02 Mar 2026 08:00:00 +0000</pubDate></item>
</channel></rss>"""
```

Then add after `StoreFiltersTest`:

```python
class PollerFiltersTest(DatabaseTest):
    def setUp(self) -> None:
        super().setUp()
        self.last_polled: dict[int, datetime] = {}

    def poll(self, now: datetime) -> None:
        poller.poll_once(self.conn, self.last_polled, now, fetch_feed=lambda url: RSS)

    def test_an_entry_a_filter_drops_is_never_stored(self) -> None:
        store.add_filter(self.conn, FEED, mode="exclude", keywords=["sponsored"])
        self.poll(datetime(2026, 3, 2, 10, 0))
        self.assertEqual([e.title for e in store.unread(self.conn)], ["Python tips"])

    def test_entries_already_stored_are_not_refiltered(self) -> None:
        self.poll(datetime(2026, 3, 2, 10, 0))
        store.add_filter(self.conn, FEED, mode="exclude", keywords=["sponsored"])
        self.poll(datetime(2026, 3, 2, 10, 0) + timedelta(minutes=31))
        self.assertEqual(
            [e.title for e in store.unread(self.conn)], ["Python tips", "Sponsored: buy now"]
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters.PollerFiltersTest -v`
Expected: both ERROR with `TypeError: poll_once() got an unexpected keyword argument 'fetch_feed'`.

- [ ] **Step 3: Change `feedwatch/poller.py`**

Add `from collections.abc import Callable` after `import time`, and change the package import to:

```python
from feedwatch import fetch, keywords, parse, store
```

Change the signature of `poll_once` to:

```python
def poll_once(
    conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch
):
```

Inside it, replace `xml = fetch.fetch(feed.url)` with `xml = fetch_feed(feed.url)`, and replace its last line,

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        feed_filters = store.feed_filters(conn, feed.url)
        kept = [e for e in entries if keywords.keeps(feed_filters, e["title"])]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

Leave `main` and the `except fetch.FetchError` handler as they are.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all 24 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_keyword_filters.py
git commit -m "feat: poller drops entries a feed's keyword filters reject"
```

---

### Task 4: `feedwatch filter add|list|remove`

**Files:**
- Modify: `feedwatch/cli.py` (whole file shown below)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `store.add_filter`, `store.feed_filters`, `store.remove_filter` (Task 2); `FeedwatchError` (Task 1).
- Produces: `cli.main(argv=None, db_path: Path = store.DEFAULT_PATH) -> int` and the commands
  - `feedwatch filter add FEED_URL (--include WORD [WORD ...] | --exclude WORD [WORD ...])` → prints `added filter <id>`
  - `feedwatch filter list FEED_URL` → one line per filter: `<id>  <mode>  <kw1>, <kw2>`
  - `feedwatch filter remove FILTER_ID`
  - Any `FeedwatchError` → its message on stderr, exit status 1.

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, add `import contextlib` and `import io` at the top of the imports, and change `from feedwatch import keywords, poller, store` to `from feedwatch import cli, keywords, poller, store`. Then add after `PollerFiltersTest`:

```python
class FilterCommandTest(DatabaseTest):
    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = cli.main(list(argv), db_path=self.path)
        return status, out.getvalue(), err.getvalue()

    def test_add_list_and_remove_a_filter(self) -> None:
        status, out, _ = self.run_cli("filter", "add", FEED, "--include", "python", "rust")
        self.assertEqual((status, out), (0, "added filter 1\n"))
        status, out, _ = self.run_cli("filter", "list", FEED)
        self.assertEqual((status, out), (0, "1  include  python, rust\n"))
        self.assertEqual(self.run_cli("filter", "remove", "1")[0], 0)
        self.assertEqual(self.run_cli("filter", "list", FEED), (0, "", ""))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        status, _, err = self.run_cli("filter", "add", "http://nope/feed", "--exclude", "job")
        self.assertEqual(status, 1)
        self.assertIn("http://nope/feed", err)

    def test_a_blank_keyword_is_refused(self) -> None:
        status, _, err = self.run_cli("filter", "add", FEED, "--include", " ")
        self.assertEqual(status, 1)
        self.assertIn("at least one keyword", err)

    def test_removing_an_unknown_filter_is_refused(self) -> None:
        status, _, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(status, 1)
        self.assertIn("no filter with id 99", err)

    def test_a_filter_needs_exactly_one_of_include_and_exclude(self) -> None:
        for argv in [
            ("filter", "add", FEED),
            ("filter", "add", FEED, "--include", "a", "--exclude", "b"),
        ]:
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.run_cli(*argv)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters.FilterCommandTest -v`
Expected: ERROR with `TypeError: main() got an unexpected keyword argument 'db_path'`.

- [ ] **Step 3: Replace `feedwatch/cli.py` with**

```python
"""feedwatch's command line: subscribe, filter, list unread entries, mark them read."""

import argparse
import sys
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError


def main(argv=None, db_path: Path = store.DEFAULT_PATH):
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
    filters = commands.add_parser("filter", help="manage a feed's keyword filters")
    filter_commands = filters.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    mode = filter_add.add_mutually_exclusive_group(required=True)
    mode.add_argument("--include", nargs="+", metavar="WORD", help="keep only titles with one of these")
    mode.add_argument("--exclude", nargs="+", metavar="WORD", help="drop titles with any of these")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter")
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
        elif args.filter_command == "add":
            added = store.add_filter(
                conn,
                args.url,
                mode="include" if args.include else "exclude",
                keywords=args.include or args.exclude,
            )
            print(f"added filter {added.id}")
        elif args.filter_command == "list":
            for f in store.feed_filters(conn, args.url):
                print(f"{f.id}  {f.mode}  {', '.join(f.keywords)}")
        else:
            store.remove_filter(conn, args.filter_id)
    except FeedwatchError as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

The `add`, `unread` and `read` branches behave exactly as before; only the `read` branch changes from `else` to an explicit `elif`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all 29 tests PASS.

- [ ] **Step 5: Check the added lines against PROGRAM-DESIGN.md**

Run: `git diff master...HEAD -- feedwatch/ | grep '^+' | grep -nE 'sqlite3|conn\.|urllib|threading|asyncio|multiprocessing|^\+\s*except|^\+\s*raise|^\+def |^\+    def |^\+from feedwatch|^\+import'`
Expected: `sqlite3`/`conn.` only in `store.py`; the only added `except` is `except FeedwatchError` in `cli.py`; every added `raise` is a `FeedwatchError` subclass; every added `def` is annotated and has `*` before any third parameter; `keywords.py` and `store.py` import only `models`/`errors` from the package. Fix any line that breaks a rule before committing.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_keyword_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```
````


## p002

#### Final message

I've written the plan and committed it as `5114e3d` ("plan: keyword filters") on `master`. I didn't create a branch because you asked for the commit here. Nothing is implemented, and the four existing tests still pass. I also applied the plan's code to a throwaway copy of the repo, where all 33 tests passed (the 4 existing ones plus 29 new).

Plan: `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`

It has five tasks:
1. **Store:** add `feedwatch/errors.py` with `FeedwatchError` and three failures: `FeedNotSubscribed`, `EmptyFilter` and `FilterNotFound`. Add a frozen `Filter` dataclass to `models.py`. Append a new `filters` table step to `SCHEMA_STEPS`, and add `store.add_filter`, `store.filters` and `store.remove_filter`. A test checks that a database created before this feature keeps working.
2. **Matching:** a new pure module, `feedwatch/filtering.py`, with one public function, `passes(filters, title) -> bool`. Matching is on whole words, ignores case, and treats keywords literally (no regular expressions).
3. **Poller:** `poll_once` looks up the feed's filters and saves only the entries that pass. It also takes the fetcher as a keyword-only `fetch_feed` parameter so the test can supply the feed instead of mocking the network.
4. **CLI:** `feedwatch filter add/list/remove`. `main` gains a keyword-only `db_path` parameter so tests can point it at a temporary database. A refused command prints one line to stderr and exits with status 1.
5. **Sweep:** run `dopamine:finishing-work`. The things `ARCHITECTURE.md` and `DESIGN.md` will then be missing go in the ledger rather than being edited during the work.

Global Constraints copies each rule from `PROGRAM-DESIGN.md` with its check. `PROGRAM-DESIGN.md` left no structural choice open, so the plan didn't need a decision from you.

Two choices need your review:
- **Old code that breaks the rules isn't fixed.** `parse` still returns dicts, `add_feed` still returns `(ok, reason)`, and `FetchError` isn't a `FeedwatchError`. As a result, the one new line in `poll_once` still reads a title out of a parse dict. That passes the Types check but goes against the wording of the Types rule. Converting `parse` to dataclasses would be a separate change.
- **The rule checks cover `feedwatch/` only.** The tests import `poller` and `cli` and close connections, as the existing test file already does.

Please review the plan and confirm it captures what you want before anything is implemented.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed so the poller never stores entries whose titles a filter drops.

**Architecture:** Filters are a new `filters` table owned by `store`, read back as a frozen `Filter` dataclass. A new pure logic module, `feedwatch/filtering.py`, decides whether a title passes a list of filters. `poller.poll_once` asks `store` for a feed's filters and passes only the entries `filtering` keeps to `store.save_entries`. `cli` gains a `filter` command with `add`, `list` and `remove`.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `json`, `re`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

From the spec, verbatim where it gives values:

- Commands: `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL` lists a feed's filters with their ids; `feedwatch filter remove FILTER_ID`.
- An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. Matching is case-insensitive, on whole words. Each filter on a feed applies, so an entry is stored only if it passes all of them.
- An entry a filter drops is never stored. Entries already stored are not re-filtered.
- A filter for a feed that is not subscribed is refused, with a message naming the URL. A filter with no keywords is refused.
- Filters are kept in the same database, and a database created before this feature keeps working.
- Out of scope: filtering on an entry's body; regular expressions. Keywords are matched literally, never as patterns.

From `docs/PROGRAM-DESIGN.md`. Each rule's check is judged over the added lines under `feedwatch/`. Tests follow the existing `tests/test_feedwatch.py`: they import `poller` and `cli` and close the connections they open.

- **Types:** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors:** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects:** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules (inherited default). Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures:** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout:** Split by responsibility, not technical layer; files that change together live together (inherited default). Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules:** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency:** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence:** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

Scope of the rules here: code this plan does not add is not retrofitted. `parse.parse_feed` still returns dicts, `store.add_feed` still returns `(ok, reason)`, `fetch.FetchError` is not yet a `FeedwatchError`, and `Feed`/`Entry` stay unfrozen. The one added line that reads a parse dict is the title lookup in the existing `poller.poll_once`. `filtering.passes` takes the title as a `str`, so no added function takes a dict.

## Review Focus

- **Keywords holding punctuation or regex metacharacters** (`C++`, `node.js`): matched literally and as whole words, never as a pattern. `node.js` must not match `nodexjs`. Test: Task 2.
- **A keyword inside a longer word, or beside punctuation:** `art` does not match "A party", but `python` matches "(Python), again". Test: Task 2.
- **Blank keywords** (`--include ""` or `"  "`): refused the same way as no keywords. Test: Tasks 1 and 4.
- **An unknown filter id, or an unsubscribed URL, given to `list` or `remove`:** a one-line error on stderr and exit status 1, with no traceback. Test: Task 4.
- **Several filters on one feed** (an include plus an exclude, or two includes): an entry is kept only if it passes every one. Test: Task 2.

---

## File Structure

- Create `feedwatch/errors.py` holding `FeedwatchError` and the three failures this feature raises.
- Modify `feedwatch/models.py` to add the frozen `Filter` dataclass.
- Modify `feedwatch/store.py` to add the `filters` schema step plus `add_filter`, `filters` and `remove_filter`.
- Create `feedwatch/filtering.py`, a pure logic module with one public function, `passes`.
- Modify `feedwatch/poller.py` so that `poll_once` applies filters and takes its fetcher as an injectable keyword parameter.
- Modify `feedwatch/cli.py` to add the `filter` command and an injectable `db_path`.
- Create the tests `tests/test_store_filters.py`, `tests/test_filtering.py`, `tests/test_poller_filters.py` and `tests/test_cli_filters.py`.

Run every test with `python3 -m unittest discover -s tests` from the repository root.

---

### Task 1: Filters in the store

**Files:**
- Create: `feedwatch/errors.py`
- Modify: `feedwatch/models.py`
- Modify: `feedwatch/store.py:1-29` (imports, `SCHEMA_STEPS`), and append functions at the end
- Test: `tests/test_store_filters.py`

**Interfaces:**
- Consumes: `store.connect(path)`, `store.add_feed(conn, url, title)`, `store.SCHEMA_STEPS` (existing).
- Produces:
  - `feedwatch.errors`: `FeedwatchError(Exception)`, `FeedNotSubscribed(FeedwatchError)`, `EmptyFilter(FeedwatchError)`, `FilterNotFound(FeedwatchError)`.
  - `feedwatch.models.Filter`: `@dataclass(frozen=True)` with fields `id: int`, `feed_id: int`, `kind: Literal["include", "exclude"]`, `keywords: tuple[str, ...]`.
  - `store.add_filter(conn: sqlite3.Connection, feed_url: str, *, kind: Literal["include", "exclude"], keywords: list[str]) -> Filter`. It raises `EmptyFilter` when no non-blank keyword is left after stripping, and `FeedNotSubscribed` when no feed has that URL. The message is `not subscribed to {feed_url}`.
  - `store.filters(conn: sqlite3.Connection, feed_url: str) -> list[Filter]`, oldest first. It raises `FeedNotSubscribed`.
  - `store.remove_filter(conn: sqlite3.Connection, filter_id: int) -> None`. It raises `FilterNotFound` with the message `no filter with id {filter_id}`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_store_filters.py`:

```python
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from feedwatch import store
from feedwatch.errors import EmptyFilter, FeedNotSubscribed, FilterNotFound
from feedwatch.models import Filter

URL = "http://x/feed"


class StoreFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def test_an_added_filter_is_listed_for_its_feed(self) -> None:
        added = store.add_filter(self.conn, URL, kind="include", keywords=["python", "rust"])
        self.assertEqual(added, Filter(added.id, added.feed_id, "include", ("python", "rust")))
        self.assertEqual(store.filters(self.conn, URL), [added])

    def test_filters_belong_to_one_feed(self) -> None:
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, URL, kind="exclude", keywords=["ads"])
        self.assertEqual(store.filters(self.conn, "http://y/feed"), [])

    def test_blank_keywords_are_dropped(self) -> None:
        added = store.add_filter(self.conn, URL, kind="exclude", keywords=[" ads ", "", "  "])
        self.assertEqual(added.keywords, ("ads",))

    def test_a_filter_with_no_keywords_is_refused(self) -> None:
        for keywords in ([], ["", "   "]):
            with self.subTest(keywords=keywords):
                with self.assertRaises(EmptyFilter):
                    store.add_filter(self.conn, URL, kind="include", keywords=keywords)
        self.assertEqual(store.filters(self.conn, URL), [])

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        with self.assertRaises(FeedNotSubscribed) as caught:
            store.add_filter(self.conn, "http://nope/feed", kind="include", keywords=["a"])
        self.assertIn("http://nope/feed", str(caught.exception))

    def test_listing_an_unsubscribed_feed_is_refused(self) -> None:
        with self.assertRaises(FeedNotSubscribed):
            store.filters(self.conn, "http://nope/feed")

    def test_a_removed_filter_is_gone(self) -> None:
        added = store.add_filter(self.conn, URL, kind="include", keywords=["python"])
        store.remove_filter(self.conn, added.id)
        self.assertEqual(store.filters(self.conn, URL), [])

    def test_removing_an_unknown_filter_is_refused(self) -> None:
        with self.assertRaises(FilterNotFound) as caught:
            store.remove_filter(self.conn, 99)
        self.assertIn("99", str(caught.exception))

    def test_a_database_from_before_filters_gains_them(self) -> None:
        path = Path(self.dir.name) / "old.db"
        with mock.patch.object(store, "SCHEMA_STEPS", store.SCHEMA_STEPS[:2]):
            old = store.connect(path)
        store.add_feed(old, URL, "x")
        old.close()
        conn = store.connect(path)
        self.addCleanup(conn.close)
        store.add_filter(conn, URL, kind="include", keywords=["python"])
        self.assertEqual(len(store.filters(conn, URL)), 1)
        self.assertEqual([feed.url for feed in store.feeds(conn)], [URL])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store_filters -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.errors'`

- [ ] **Step 3: Create `feedwatch/errors.py`**

```python
"""The failures feedwatch raises. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class FeedNotSubscribed(FeedwatchError):
    """A feed URL was given that is not subscribed."""


class EmptyFilter(FeedwatchError):
    """A filter was given no keywords."""


class FilterNotFound(FeedwatchError):
    """No filter has the given id."""
```

- [ ] **Step 4: Add `Filter` to `feedwatch/models.py`**

Change the imports at the top to:

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Literal
```

Append at the end of the file:

```python
@dataclass(frozen=True)
class Filter:
    """A feed's keyword filter. Include keeps titles with a keyword; exclude drops them."""

    id: int
    feed_id: int
    kind: Literal["include", "exclude"]
    keywords: tuple[str, ...]
```

- [ ] **Step 5: Add the schema step and the store functions to `feedwatch/store.py`**

Replace the imports (lines 3-7) with:

```python
import json
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Literal

from feedwatch.errors import EmptyFilter, FeedNotSubscribed, FilterNotFound
from feedwatch.models import Entry, Feed, Filter
```

Append a third element to `SCHEMA_STEPS`, after the `entries` step and before the closing `]`. Leave the two existing steps as they are.

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Append at the end of the file:

```python
def add_filter(
    conn: sqlite3.Connection,
    feed_url: str,
    *,
    kind: Literal["include", "exclude"],
    keywords: list[str],
) -> Filter:
    """Attach a filter to the feed at ``feed_url`` and return it.

    Blank keywords are dropped. Raises EmptyFilter when none remain, and
    FeedNotSubscribed when no feed has that URL.
    """
    cleaned = tuple(word.strip() for word in keywords if word.strip())
    if not cleaned:
        raise EmptyFilter("a filter needs at least one keyword")
    feed_id = _feed_id(conn, feed_url)
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed_id, kind, json.dumps(cleaned)),
        )
    return Filter(cursor.lastrowid, feed_id, kind, cleaned)


def filters(conn: sqlite3.Connection, feed_url: str) -> list[Filter]:
    """Return the filters on the feed at ``feed_url``, oldest first.

    Raises FeedNotSubscribed when no feed has that URL.
    """
    feed_id = _feed_id(conn, feed_url)
    rows = conn.execute(
        "SELECT id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id", (feed_id,)
    )
    return [
        Filter(filter_id, feed_id, kind, tuple(json.loads(keywords)))
        for filter_id, kind, keywords in rows
    ]


def remove_filter(conn: sqlite3.Connection, filter_id: int) -> None:
    """Delete a filter. Raises FilterNotFound when no filter has ``filter_id``."""
    with conn:
        deleted = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,)).rowcount
    if deleted == 0:
        raise FilterNotFound(f"no filter with id {filter_id}")


def _feed_id(conn: sqlite3.Connection, feed_url: str) -> int:
    row = conn.execute("SELECT id FROM feeds WHERE url = ?", (feed_url,)).fetchone()
    if row is None:
        raise FeedNotSubscribed(f"not subscribed to {feed_url}")
    return row[0]
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests pass, both the new `test_store_filters` tests and the four in `test_feedwatch`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/errors.py feedwatch/models.py feedwatch/store.py tests/test_store_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 2: Deciding whether a title passes

**Files:**
- Create: `feedwatch/filtering.py`
- Test: `tests/test_filtering.py`

**Interfaces:**
- Consumes: `feedwatch.models.Filter` (Task 1).
- Produces: `filtering.passes(filters: list[Filter], title: str) -> bool`. It returns True when the title passes every filter, and True for an empty list.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filtering.py`:

```python
import unittest

from feedwatch.filtering import passes
from feedwatch.models import Filter


def include(*keywords: str) -> Filter:
    return Filter(1, 1, "include", keywords)


def exclude(*keywords: str) -> Filter:
    return Filter(2, 1, "exclude", keywords)


class PassesTest(unittest.TestCase):
    def test_no_filters_pass_everything(self) -> None:
        self.assertTrue(passes([], "Anything at all"))

    def test_include_keeps_a_title_with_any_of_its_keywords(self) -> None:
        self.assertTrue(passes([include("python", "rust")], "Rust 2.0 released"))
        self.assertFalse(passes([include("python", "rust")], "Go 2.0 released"))

    def test_exclude_drops_a_title_with_any_of_its_keywords(self) -> None:
        self.assertFalse(passes([exclude("sponsored", "ad")], "Sponsored: a new laptop"))
        self.assertTrue(passes([exclude("sponsored", "ad")], "A new laptop"))

    def test_matching_ignores_case(self) -> None:
        self.assertTrue(passes([include("PYTHON")], "python tips"))
        self.assertTrue(passes([include("über")], "ÜBER alles"))

    def test_a_keyword_inside_a_longer_word_does_not_match(self) -> None:
        self.assertFalse(passes([include("art")], "A party"))
        self.assertTrue(passes([exclude("art")], "A party"))

    def test_a_keyword_beside_punctuation_matches(self) -> None:
        self.assertTrue(passes([include("python")], "(Python), again"))

    def test_keywords_are_literal_not_patterns(self) -> None:
        self.assertTrue(passes([include("C++")], "Why C++ is hard"))
        self.assertTrue(passes([include("node.js")], "node.js 22 is out"))
        self.assertFalse(passes([include("node.js")], "nodexjs 22 is out"))

    def test_a_title_must_pass_every_filter(self) -> None:
        both = [include("python"), exclude("sponsored")]
        self.assertTrue(passes(both, "Python tips"))
        self.assertFalse(passes(both, "Sponsored Python tips"))
        self.assertFalse(passes(both, "Rust tips"))
        two_includes = [include("python"), include("tips")]
        self.assertTrue(passes(two_includes, "Python tips"))
        self.assertFalse(passes(two_includes, "Python news"))

    def test_an_empty_title_passes_only_exclude_filters(self) -> None:
        self.assertTrue(passes([exclude("ads")], ""))
        self.assertFalse(passes([include("python")], ""))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filtering -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.filtering'`

- [ ] **Step 3: Create `feedwatch/filtering.py`**

```python
"""Decides which entry titles a feed's keyword filters let through."""

import re

from feedwatch.models import Filter


def passes(filters: list[Filter], title: str) -> bool:
    """Whether ``title`` passes every filter in ``filters``.

    An include filter passes a title holding at least one of its keywords, and
    an exclude filter passes a title holding none. Keywords match literally, as
    whole words, ignoring case.
    """
    for keyword_filter in filters:
        matched = any(_holds(title, word) for word in keyword_filter.keywords)
        if matched != (keyword_filter.kind == "include"):
            return False
    return True


def _holds(title: str, keyword: str) -> bool:
    # Lookarounds rather than \b, so that a keyword starting or ending in
    # punctuation, such as "C++", still matches as a whole word.
    pattern = r"(?<!\w)" + re.escape(keyword) + r"(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/filtering.py tests/test_filtering.py
git commit -m "feat: match entry titles against keyword filters"
```

---

### Task 3: The poller stores only what the filters keep

**Files:**
- Modify: `feedwatch/poller.py:1-27` (imports and `poll_once`)
- Test: `tests/test_poller_filters.py`

**Interfaces:**
- Consumes: `store.add_filter(conn, feed_url, *, kind, keywords)` and `store.filters(conn, feed_url)` from Task 1, and `filtering.passes(filters, title)` from Task 2.
- Produces: `poller.poll_once(conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch) -> None`. The existing positional parameters are unchanged, so `main` keeps calling it as before.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_poller_filters.py`:

```python
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

from feedwatch import poller, store

URL = "http://x/feed"
RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>Python news</title><link>http://x/a</link>
<pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>
<item><guid>b</guid><title>Sponsored: a laptop</title><link>http://x/b</link>
<pubDate>Mon, 02 Mar 2026 10:00:00 +0000</pubDate></item>
</channel></rss>"""
NOW = datetime(2026, 3, 2, 12, 0)


def serve(url: str) -> bytes:
    return RSS


class PollerFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, URL, "x")

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def stored_titles(self) -> list[str]:
        return sorted(entry.title for entry in store.unread(self.conn, 10))

    def test_a_feed_without_filters_stores_every_entry(self) -> None:
        poller.poll_once(self.conn, {}, NOW, fetch_feed=serve)
        self.assertEqual(self.stored_titles(), ["Python news", "Sponsored: a laptop"])

    def test_an_entry_a_filter_drops_is_never_stored(self) -> None:
        store.add_filter(self.conn, URL, kind="exclude", keywords=["sponsored"])
        poller.poll_once(self.conn, {}, NOW, fetch_feed=serve)
        self.assertEqual(self.stored_titles(), ["Python news"])

    def test_entries_already_stored_are_not_refiltered(self) -> None:
        last_polled: dict[int, datetime] = {}
        poller.poll_once(self.conn, last_polled, NOW, fetch_feed=serve)
        store.add_filter(self.conn, URL, kind="include", keywords=["rust"])
        poller.poll_once(self.conn, last_polled, NOW + timedelta(hours=1), fetch_feed=serve)
        self.assertEqual(self.stored_titles(), ["Python news", "Sponsored: a laptop"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_poller_filters -v`
Expected: ERROR or FAIL with `TypeError: poll_once() got an unexpected keyword argument 'fetch_feed'`

- [ ] **Step 3: Change `feedwatch/poller.py`**

Replace the imports and `poll_once` (lines 3-27) with the code below. `main` and everything after it stay as they are.

```python
import logging
import time
from collections.abc import Callable
from datetime import datetime, timedelta

from feedwatch import fetch, filtering, parse, store

log = logging.getLogger("feedwatch.poller")


def poll_once(conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch):
    for feed in store.feeds(conn):
        previous = last_polled.get(feed.id)
        if previous is not None and now - previous < timedelta(minutes=feed.interval_minutes):
            continue
        last_polled[feed.id] = now
        try:
            xml = fetch_feed(feed.url)
        except fetch.FetchError as exc:
            log.warning("skipping %s: %s", feed.url, exc)
            continue
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        feed_filters = store.filters(conn, feed.url)
        kept = [entry for entry in entries if filtering.passes(feed_filters, entry["title"])]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: The `filter` command

**Files:**
- Modify: `feedwatch/cli.py` (the whole of `main` and the imports)
- Test: `tests/test_cli_filters.py`

**Interfaces:**
- Consumes: `store.add_filter`, `store.filters` and `store.remove_filter` from Task 1, and `feedwatch.errors.FeedwatchError`.
- Produces: `cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int`. Its output:
  - `filter add` prints the new filter's id.
  - `filter list` prints one line per filter, `{id}  {kind}  {keywords joined by spaces}`.
  - `filter remove` prints nothing.
  - A `FeedwatchError` prints its message on stderr and returns 1.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_cli_filters.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import dataclass
from pathlib import Path

from feedwatch import cli

URL = "http://x/feed"


@dataclass(frozen=True)
class Result:
    status: int
    out: str
    err: str


class FilterCommandTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.db = Path(self.dir.name) / "feeds.db"
        self.assertEqual(self.run_cli("add", URL).status, 0)

    def tearDown(self) -> None:
        self.dir.cleanup()

    def run_cli(self, *argv: str) -> Result:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = cli.main(list(argv), db_path=self.db)
        return Result(status, out.getvalue(), err.getvalue())

    def test_an_added_filter_is_listed_with_its_id(self) -> None:
        added = self.run_cli("filter", "add", URL, "--include", "python", "rust")
        self.assertEqual(added.status, 0)
        filter_id = added.out.strip()
        listed = self.run_cli("filter", "list", URL)
        self.assertEqual(listed.out, f"{filter_id}  include  python rust\n")

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        filter_id = self.run_cli("filter", "add", URL, "--exclude", "ads").out.strip()
        self.assertEqual(self.run_cli("filter", "remove", filter_id).status, 0)
        self.assertEqual(self.run_cli("filter", "list", URL).out, "")

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        result = self.run_cli("filter", "add", "http://nope/feed", "--include", "a")
        self.assertEqual(result.status, 1)
        self.assertIn("http://nope/feed", result.err)

    def test_blank_keywords_are_refused(self) -> None:
        result = self.run_cli("filter", "add", URL, "--include", "", "  ")
        self.assertEqual(result.status, 1)
        self.assertIn("keyword", result.err)

    def test_a_flag_with_no_keywords_is_refused(self) -> None:
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            cli.main(["filter", "add", URL, "--include"], db_path=self.db)
        self.assertEqual(caught.exception.code, 2)

    def test_add_needs_exactly_one_of_include_and_exclude(self) -> None:
        for argv in (["filter", "add", URL],
                     ["filter", "add", URL, "--include", "a", "--exclude", "b"]):
            with self.subTest(argv=argv):
                with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    cli.main(argv, db_path=self.db)

    def test_removing_an_unknown_filter_is_a_one_line_error(self) -> None:
        result = self.run_cli("filter", "remove", "99")
        self.assertEqual((result.status, result.err), (1, "no filter with id 99\n"))

    def test_listing_an_unsubscribed_feed_is_a_one_line_error(self) -> None:
        result = self.run_cli("filter", "list", "http://nope/feed")
        self.assertEqual((result.status, result.err), (1, "not subscribed to http://nope/feed\n"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_cli_filters -v`
Expected: ERROR in `setUp`, `TypeError: main() got an unexpected keyword argument 'db_path'`

- [ ] **Step 3: Replace the imports and `main` in `feedwatch/cli.py`**

Replace everything from `import argparse` down to and including `return 0`. Keep the module docstring, but extend its summary to name filters, and keep the `if __name__ == "__main__":` block as it is.

```python
"""feedwatch's command line: subscribe, filter feeds, list unread entries, mark them read."""

import argparse
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError


def main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
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
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument("--include", nargs="+", metavar="WORD",
                      help="keep only entries whose title has one of these words")
    kind.add_argument("--exclude", nargs="+", metavar="WORD",
                      help="drop entries whose title has any of these words")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters and their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter by id")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    with closing(store.connect(db_path)) as conn:
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
            try:
                if args.filter_command == "add":
                    added = store.add_filter(
                        conn,
                        args.url,
                        kind="include" if args.include is not None else "exclude",
                        keywords=args.include if args.include is not None else args.exclude,
                    )
                    print(added.id)
                elif args.filter_command == "list":
                    for keyword_filter in store.filters(conn, args.url):
                        print(f"{keyword_filter.id}  {keyword_filter.kind}"
                              f"  {' '.join(keyword_filter.keywords)}")
                else:
                    store.remove_filter(conn, args.filter_id)
            except FeedwatchError as exc:
                print(exc, file=sys.stderr)
                return 1
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: all tests pass.

- [ ] **Step 5: Check the added lines against PROGRAM-DESIGN's checks**

Run: `git diff BASE...HEAD -- feedwatch/ | grep '^+' | grep -nE 'sqlite3|conn\.|urllib|threading|asyncio|multiprocessing|^\+\s*except|^\+\s*raise|^\+import|^\+from'`

Expected:
- `sqlite3` and `conn.` appear only in `store.py`. `cli.py` passes `conn` into `store` and nothing more, and its `closing(...)` closes the connection without a `conn.` call.
- The only `except` outside `store.py` is the one in `cli.py`, and no `except` is added inside `store.py`.
- Every `raise` raises an `errors` class.
- `errors.py` and `models.py` import nothing from `feedwatch`.
- `filtering.py` imports only `models`, and `store.py` imports only `models` and `errors` from the package.

`BASE` is the commit Task 1 started from (`git merge-base HEAD master` when working on a branch).

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_cli_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

### Task 5: Finish the work

- [ ] **Step 1: Run the sweep**

Load `dopamine:finishing-work` and follow it before the workspace is cleaned up. Its ledger should carry what the living documents now lag behind:
- `ARCHITECTURE.md` still names only the tables `feeds` and `entries`, while there is now a `filters` table.
- `ARCHITECTURE.md`'s "How they talk" section does not mention `poller` calling the new `filtering` logic module.
- `DESIGN.md`'s "What it must do" does not mention keyword filters.

Do not edit those documents during Tasks 1-4. Record each of these in the ledger, and let the sweep place them.
````


## p003

#### Final message

I wrote the plan, saved it to `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-2/docs/superpowers/plans/2026-10-12-keyword-filters.md` and committed it as `339c738 plan: keyword filters` on `master`. Nothing is implemented in the repository. To check the plan's code, I applied it to a throwaway copy of the repo and ran the suite: all 32 tests passed (the 4 existing ones plus 28 new), and the CLI smoke test printed exactly the expected output. I then deleted the copy.

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


## p004

#### Final message

I wrote the implementation plan and committed it as `4d252bb plan: keyword filters` at `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-4/docs/superpowers/plans/2026-10-12-keyword-filters.md`. No code in the repo was changed. Before writing the plan I built all of its code and tests in a scratch copy: all 34 tests passed (the 4 existing ones plus 30 new). The scratch copy is deleted.

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


## p005

#### Final message

I wrote the implementation plan and committed it as `9d318b9`. Nothing was implemented in the repository.

Plan: `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-5/docs/superpowers/plans/2026-10-12-keyword-filters.md`

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

I also ran the end-of-work sweep for this planning step, committed as `b510cf8` with "nothing to drain". It saved a reconstructed ledger at `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-5/docs/superpowers/plans/2026-10-12-keyword-filters-plan.reconstructed-ledger.md`. `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are listed in `.dopamine/config` but don't exist; I didn't create them.

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


## p006

#### Final message

I wrote the plan and committed it to `master` as 511186b. That's the repo's only branch; I didn't create a new one. Nothing is implemented yet. I checked the existing tests (4 pass) and checked the matching approach in a quick one-off, but the plan's own code and tests haven't been run.

Plan: `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-3/docs/superpowers/plans/2026-10-12-keyword-filters.md`
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


## p007

#### Final message

I wrote the implementation plan and committed it as `8f53eff` ("plan: keyword filters"). Nothing is implemented in the repository. To check the plan's code, I applied it to a scratch copy of the repo: the 4 existing tests and the 32 new ones all pass, and the plan's program-design grep checks come back clean.

The plan is at `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`. It has five tasks:

1. **Matching:** a frozen `Filter` dataclass in `models.py`, and a new module `feedwatch/filtering.py` with one public function, `keeps(filters, title) -> bool`. A keyword matches regardless of case, as a whole word, and literally, so "C++" works and "node.js" is not treated as a pattern.
2. **Storage:** a new `feedwatch/errors.py` holding `FeedwatchError` and three failures (feed not subscribed, filter with no keywords, unknown filter id). A new `filters` table is added at the end of `SCHEMA_STEPS`, and `store` gets `add_filter`, `feed_filters` and `remove_filter`. Blank keywords are dropped, and a filter left with none is refused.
3. **Poller:** `poll_once` takes a `fetch_feed` parameter so tests can pass in fake feed XML, and it drops filtered entries before saving. An entry is stored only if every filter on its own feed keeps it. Entries already stored are not re-filtered.
4. **Command line:** `filter add | list | remove`. Any of these failures prints a one-line message and exits with 1, and `main` takes a `db_path` so tests can point it at a temporary database.
5. **Final checks:** run the whole suite, run the program-design grep checks over the added lines, then the `dopamine:finishing-work` sweep. The sweep is where `ARCHITECTURE.md` will learn about the new `filters` table, since no living document is edited during execution.

Every rule from `PROGRAM-DESIGN.md` is copied, with its check, into Global Constraints. The design document didn't leave any structural choice open, so I had no question for you. The plan does state how it reads the rules where the existing code already breaks them:
- **Left alone:** `add_feed`'s `(ok, reason)` return, `parse` returning dicts, and the unfrozen `Feed`/`Entry` are not refactored.
- **`poll_once`'s `conn` stays unannotated:** annotating it would mean importing `sqlite3` into `poller.py`, which the Effects rule forbids.
- **Tests may use `sqlite3` directly:** I read the Effects rule as covering the `feedwatch` package, so a test can build a database as it was before this feature.

Checking against the rules caught one problem in my draft: a `conn.close()` in `cli.py` broke the Effects rule, so I removed it before committing.

The plan's Review Focus names the five cases most likely to go wrong, and each one has a test in the task that owns it:
- a keyword next to punctuation, or inside a longer word;
- keywords containing characters that mean something in a regular expression;
- blank keywords;
- several filters on one feed, and filters on another feed;
- a wrong id, URL or flag at the command line.

I didn't run the finishing-work sweep for writing the plan, since nothing was executed. It is Task 5, to run when the plan is carried out.

The plan is ready for you to review.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores an entry a filter drops.

**Architecture:** A frozen `Filter` dataclass in `models.py`; a new `filters` table appended to `store.SCHEMA_STEPS`, read and written by three new `store` functions; one new pure logic module, `feedwatch/filtering.py`, whose single public function `keeps(filters, title)` decides from a title alone; `poller.poll_once` looks up a feed's filters and drops entries before `store.save_entries`; `cli` gains `filter add|list|remove`. Failures are new `FeedwatchError` subclasses in a new `feedwatch/errors.py`, caught only in `cli`.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `json`, `re`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

From the spec:
- An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. Matching is case-insensitive, on whole words.
- Commands: `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL` lists a feed's filters with their ids; `feedwatch filter remove FILTER_ID`.
- The poller applies a feed's filters when it saves new entries. An entry a filter drops is never stored. Several filters on one feed: an entry is stored only if no filter drops it.
- A filter for a feed that is not subscribed is refused, with a message naming the URL. A filter with no keywords is refused (blank keywords count as none).
- Filters live in the same database; a database created before this feature keeps working. Entries already stored are not re-filtered.
- Out of scope: filtering on an entry's body; regular expressions (keywords match literally).

From `docs/PROGRAM-DESIGN.md` (each rule judged by its check, over added lines):
- **Python 3.11, standard library.**
- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value. *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them. *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects.** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class. *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type. *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout.** Split by responsibility, not technical layer. Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`. *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer. *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function. (`filtering.py` has one: `keeps`.)
- **Concurrency.** The poller is one thread. *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited. *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan reads those rules where existing code already departs from them:
- Existing departures (`store.add_feed`'s `(ok, reason)`, `parse` returning dicts, the unfrozen `Feed`/`Entry`, unannotated existing defs) are left alone; this plan does not refactor them.
- `poll_once` and `cli.main` are existing defs that gain one keyword-only parameter each. The new parameter is annotated; `poll_once`'s existing `conn` stays unannotated, because annotating it would import `sqlite3` into `poller.py`.
- `filtering.keeps` takes a title string, not an entry dict, so no added function handles parse's dicts; `poll_once` passes `e["title"]` in.
- The Effects rule governs the `feedwatch` package. A test may use `sqlite3` directly to build a database as it was before this feature.

Documentation: do not edit `docs/*.md` during execution. Facts with living-document consequence (the new `filters` table, the `errors` and `filtering` modules, the `filter` commands) go in the ledger; Task 5's sweep places them.

## Review Focus

1. A keyword next to punctuation or inside a longer word: `rust` matches "Rust, Go and Zig" and "(rust)" but not "Rusty" or "trust". Pinned in Task 1.
2. Keywords holding characters that mean something in a regular expression: `C++` matches "Learn C++ today", `node.js` does not match "nodexjs". Pinned in Task 1.
3. Blank keywords (`--include ""`, `--include " "`) are refused like no keywords, not stored as a filter that matches nothing. Pinned in Tasks 2 and 4.
4. Several filters on one feed, and filters on another feed: an entry is stored only if every filter of *its own* feed keeps it. Pinned in Tasks 1 and 3.
5. A wrong id or URL at the command line (`filter remove 99`, `filter list` on an unsubscribed URL, both or neither of `--include`/`--exclude`) gives a one-line message and a non-zero exit, never a traceback. Pinned in Task 4.

---

## File Structure

- Create `feedwatch/errors.py` — `FeedwatchError` and the three failures this feature raises.
- Create `feedwatch/filtering.py` — the pure keep/drop decision for a title (logic module, one public function).
- Modify `feedwatch/models.py` — add `FilterKind` and the frozen `Filter`.
- Modify `feedwatch/store.py` — append the `filters` schema step; add `add_filter`, `feed_filters`, `remove_filter`, private `_feed_id`.
- Modify `feedwatch/poller.py` — `poll_once` takes `fetch_feed` and applies filters before saving.
- Modify `feedwatch/cli.py` — `filter add|list|remove`; catch `FeedwatchError`; `main` takes `db_path`.
- Create `tests/test_keyword_filters.py` — one `TestCase` per task.

Run the whole suite with `python3 -m unittest discover -s tests -v` from the repository root.

---

### Task 1: The `Filter` value and the keep/drop decision

**Files:**
- Modify: `feedwatch/models.py`
- Create: `feedwatch/filtering.py`
- Test: `tests/test_keyword_filters.py` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.FilterKind = Literal["include", "exclude"]`
  - `feedwatch.models.Filter` — `@dataclass(frozen=True)` with fields `id: int`, `feed_id: int`, `kind: FilterKind`, `keywords: tuple[str, ...]`
  - `feedwatch.filtering.keeps(filters: Sequence[Filter], title: str) -> bool` — `True` when no filter drops the title.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_keyword_filters.py`:

```python
import unittest

from feedwatch.filtering import keeps
from feedwatch.models import Filter


def include(*keywords: str) -> Filter:
    return Filter(id=1, feed_id=1, kind="include", keywords=keywords)


def exclude(*keywords: str) -> Filter:
    return Filter(id=2, feed_id=1, kind="exclude", keywords=keywords)


class MatchingTest(unittest.TestCase):
    def test_no_filters_keep_everything(self) -> None:
        self.assertTrue(keeps([], "Anything at all"))

    def test_an_include_filter_keeps_only_titles_naming_a_keyword(self) -> None:
        self.assertTrue(keeps([include("rust", "zig")], "Zig 0.13 released"))
        self.assertFalse(keeps([include("rust", "zig")], "Go 1.23 released"))

    def test_an_exclude_filter_drops_titles_naming_any_keyword(self) -> None:
        self.assertFalse(keeps([exclude("sponsored", "ad")], "Sponsored: a new laptop"))
        self.assertTrue(keeps([exclude("sponsored", "ad")], "Rust 1.80 released"))

    def test_matching_ignores_case(self) -> None:
        self.assertTrue(keeps([include("rust")], "RUST weekly"))
        self.assertFalse(keeps([exclude("Sponsored")], "sponsored post"))

    def test_a_keyword_matches_only_a_whole_word(self) -> None:
        self.assertFalse(keeps([include("rust")], "Rusty tools you can trust"))
        self.assertTrue(keeps([include("rust")], "Rust, Go and Zig"))
        self.assertTrue(keeps([include("rust")], "Why (rust) matters"))
        self.assertTrue(keeps([include("rust")], "rust"))

    def test_a_keyword_matches_literally_not_as_a_pattern(self) -> None:
        self.assertTrue(keeps([include("C++")], "Learn C++ today"))
        self.assertTrue(keeps([include("node.js")], "node.js 22 is out"))
        self.assertFalse(keeps([include("node.js")], "nodexjs is not node"))

    def test_an_entry_is_kept_only_if_every_filter_keeps_it(self) -> None:
        both = [include("rust"), exclude("sponsored")]
        self.assertTrue(keeps(both, "Rust 1.80 released"))
        self.assertFalse(keeps(both, "Sponsored: Rust jobs"))
        self.assertFalse(keeps(both, "Go 1.23 released"))

    def test_an_include_filter_drops_an_empty_title(self) -> None:
        self.assertFalse(keeps([include("rust")], ""))
        self.assertTrue(keeps([exclude("ad")], ""))

    def test_a_filter_is_immutable(self) -> None:
        with self.assertRaises(AttributeError):
            include("rust").kind = "exclude"


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.filtering'`.

- [ ] **Step 3: Add `FilterKind` and `Filter` to `feedwatch/models.py`**

Add `from typing import Literal` beside the existing imports, and append:

```python
FilterKind = Literal["include", "exclude"]


@dataclass(frozen=True)
class Filter:
    """A feed's keyword filter, matched against entry titles.

    An include filter keeps only titles naming one of its keywords; an exclude
    filter drops titles naming any of them.
    """

    id: int
    feed_id: int
    kind: FilterKind
    keywords: tuple[str, ...]
```

- [ ] **Step 4: Create `feedwatch/filtering.py`**

```python
"""Decides from an entry's title whether a feed's keyword filters keep it."""

import re
from collections.abc import Sequence

from feedwatch.models import Filter


def keeps(filters: Sequence[Filter], title: str) -> bool:
    """Return whether no filter drops an entry with this title.

    A keyword matches case-insensitively, as a whole word, and literally.
    """
    for rule in filters:
        mentioned = _mentions_any(rule.keywords, title)
        if rule.kind == "include" and not mentioned:
            return False
        if rule.kind == "exclude" and mentioned:
            return False
    return True


def _mentions_any(keywords: Sequence[str], title: str) -> bool:
    return any(_whole_word(keyword).search(title) for keyword in keywords)


def _whole_word(keyword: str) -> re.Pattern[str]:
    # Lookarounds rather than \b: \b needs a word character at the keyword's
    # edge, so a keyword ending in punctuation, like "C++", would never match.
    return re.compile(rf"(?<!\w){re.escape(keyword)}(?!\w)", re.IGNORECASE)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: all `MatchingTest` tests PASS.

- [ ] **Step 6: Run the whole suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/models.py feedwatch/filtering.py tests/test_keyword_filters.py
git commit -m "feat: Filter value and whole-word keyword matching"
```

---

### Task 2: Storing filters, and the errors they raise

**Files:**
- Create: `feedwatch/errors.py`
- Modify: `feedwatch/store.py` (imports at top; `SCHEMA_STEPS` at lines 13-29; new functions appended at the end)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `feedwatch.models.Filter`, `feedwatch.models.FilterKind` (Task 1).
- Produces:
  - `feedwatch.errors.FeedwatchError(Exception)`, and its subclasses `NotSubscribedError`, `EmptyFilterError`, `UnknownFilterError`; each takes one message string.
  - `store.add_filter(conn, feed_url: str, *, kind: FilterKind, keywords: Sequence[str]) -> Filter` — strips keywords and drops blank ones; raises `EmptyFilterError` when none are left, `NotSubscribedError("not subscribed to <url>")` when no feed has that URL.
  - `store.feed_filters(conn, feed_url: str) -> list[Filter]` — oldest first; raises `NotSubscribedError` for an unknown URL.
  - `store.remove_filter(conn, filter_id: int) -> None` — raises `UnknownFilterError("no filter with id <n>")` when there is no such filter.

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, extend the imports at the top to:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store
from feedwatch.errors import (
    EmptyFilterError,
    FeedwatchError,
    NotSubscribedError,
    UnknownFilterError,
)
from feedwatch.filtering import keeps
from feedwatch.models import Filter
```

and add this class above the `if __name__ == "__main__":` line:

```python
FEED = "http://x/feed"


class StoreFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        self.addCleanup(self.conn.close)
        store.add_feed(self.conn, FEED, "x")

    def test_an_added_filter_is_listed_with_its_id(self) -> None:
        added = store.add_filter(self.conn, FEED, kind="exclude", keywords=["sponsored", "ad"])
        self.assertEqual(store.feed_filters(self.conn, FEED), [added])
        self.assertEqual(added.kind, "exclude")
        self.assertEqual(added.keywords, ("sponsored", "ad"))
        self.assertIsInstance(added.id, int)

    def test_a_feed_lists_only_its_own_filters_oldest_first(self) -> None:
        store.add_feed(self.conn, "http://y/feed", "y")
        first = store.add_filter(self.conn, FEED, kind="include", keywords=["rust"])
        store.add_filter(self.conn, "http://y/feed", kind="include", keywords=["go"])
        second = store.add_filter(self.conn, FEED, kind="exclude", keywords=["ad"])
        self.assertEqual(store.feed_filters(self.conn, FEED), [first, second])

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        with self.assertRaises(NotSubscribedError) as caught:
            store.add_filter(self.conn, "http://nope/feed", kind="include", keywords=["rust"])
        self.assertIn("http://nope/feed", str(caught.exception))
        with self.assertRaises(NotSubscribedError):
            store.feed_filters(self.conn, "http://nope/feed")

    def test_a_filter_with_no_keywords_is_refused(self) -> None:
        for keywords in ([], [""], ["  ", ""]):
            with self.subTest(keywords=keywords), self.assertRaises(EmptyFilterError):
                store.add_filter(self.conn, FEED, kind="include", keywords=keywords)
        self.assertEqual(store.feed_filters(self.conn, FEED), [])

    def test_keywords_are_trimmed_and_blank_ones_dropped(self) -> None:
        added = store.add_filter(self.conn, FEED, kind="include", keywords=[" rust ", "", "zig"])
        self.assertEqual(added.keywords, ("rust", "zig"))
        self.assertEqual(store.feed_filters(self.conn, FEED)[0].keywords, ("rust", "zig"))

    def test_a_removed_filter_is_gone(self) -> None:
        added = store.add_filter(self.conn, FEED, kind="include", keywords=["rust"])
        store.remove_filter(self.conn, added.id)
        self.assertEqual(store.feed_filters(self.conn, FEED), [])

    def test_removing_an_unknown_filter_is_refused_naming_the_id(self) -> None:
        with self.assertRaises(UnknownFilterError) as caught:
            store.remove_filter(self.conn, 99)
        self.assertIn("99", str(caught.exception))

    def test_every_refusal_is_a_feedwatch_error(self) -> None:
        for error in (NotSubscribedError, EmptyFilterError, UnknownFilterError):
            self.assertTrue(issubclass(error, FeedwatchError))

    def test_a_database_from_before_filters_gains_them(self) -> None:
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        for step in store.SCHEMA_STEPS[:2]:
            old.execute(step)
        old.execute("INSERT INTO feeds (url, title) VALUES (?, ?)", (FEED, "x"))
        old.commit()
        old.close()

        conn = store.connect(path)
        self.addCleanup(conn.close)
        self.assertEqual([feed.url for feed in store.feeds(conn)], [FEED])
        added = store.add_filter(conn, FEED, kind="include", keywords=["rust"])
        self.assertEqual(store.feed_filters(conn, FEED), [added])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.errors'`.

- [ ] **Step 3: Create `feedwatch/errors.py`**

```python
"""The failures feedwatch reports to the person using it."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises; only poller and cli catch it."""


class NotSubscribedError(FeedwatchError):
    """A feed URL was named that no subscription has."""


class EmptyFilterError(FeedwatchError):
    """A filter was given no keywords, or only blank ones."""


class UnknownFilterError(FeedwatchError):
    """A filter id was named that no filter has."""
```

- [ ] **Step 4: Append the schema step and the filter functions to `feedwatch/store.py`**

Change the imports at the top of `store.py` to:

```python
import json
import sqlite3
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path

from feedwatch.errors import EmptyFilterError, NotSubscribedError, UnknownFilterError
from feedwatch.models import Entry, Feed, Filter, FilterKind
```

Append one step to the end of `SCHEMA_STEPS`, after the `entries` step, leaving both existing steps unchanged:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

Append to the end of the file:

```python
def add_filter(
    conn: sqlite3.Connection, feed_url: str, *, kind: FilterKind, keywords: Sequence[str]
) -> Filter:
    """Attach a keyword filter to a subscribed feed and return it.

    Keywords are trimmed and blank ones dropped. Raises EmptyFilterError when
    none are left, and NotSubscribedError when no feed has feed_url.
    """
    kept = tuple(keyword.strip() for keyword in keywords if keyword.strip())
    if not kept:
        raise EmptyFilterError("a filter needs at least one keyword")
    feed_id = _feed_id(conn, feed_url)
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed_id, kind, json.dumps(kept)),
        )
    return Filter(cursor.lastrowid, feed_id, kind, kept)


def feed_filters(conn: sqlite3.Connection, feed_url: str) -> list[Filter]:
    """Return the filters attached to the feed at feed_url, oldest first.

    Raises NotSubscribedError when no feed has feed_url.
    """
    feed_id = _feed_id(conn, feed_url)
    rows = conn.execute(
        "SELECT id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id", (feed_id,)
    )
    return [
        Filter(filter_id, feed_id, kind, tuple(json.loads(keywords)))
        for filter_id, kind, keywords in rows
    ]


def remove_filter(conn: sqlite3.Connection, filter_id: int) -> None:
    """Delete a filter. Raises UnknownFilterError when no filter has filter_id."""
    with conn:
        deleted = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,)).rowcount
    if deleted == 0:
        raise UnknownFilterError(f"no filter with id {filter_id}")


def _feed_id(conn: sqlite3.Connection, feed_url: str) -> int:
    row = conn.execute("SELECT id FROM feeds WHERE url = ?", (feed_url,)).fetchone()
    if row is None:
        raise NotSubscribedError(f"not subscribed to {feed_url}")
    return row[0]
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_keyword_filters -v`
Expected: all `MatchingTest` and `StoreFilterTest` tests PASS.

- [ ] **Step 6: Run the whole suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS, including the four existing tests in `tests/test_feedwatch.py`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/errors.py feedwatch/store.py tests/test_keyword_filters.py
git commit -m "feat: store keyword filters in a new filters table"
```

---

### Task 3: The poller drops filtered entries before saving

**Files:**
- Modify: `feedwatch/poller.py:1-27` (imports and `poll_once`)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `store.feed_filters(conn, feed_url) -> list[Filter]` (Task 2); `filtering.keeps(filters, title) -> bool` (Task 1).
- Produces: `poller.poll_once(conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch) -> None`. `main` keeps calling it without `fetch_feed`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, add `from datetime import datetime` to the standard-library imports and change `from feedwatch import store` to `from feedwatch import poller, store`. Add this above the `if __name__ == "__main__":` line:

```python
RSS = b"""<rss><channel><title>t</title>
<item><guid>rust</guid><title>Rust 1.80 released</title><link>http://x/rust</link></item>
<item><guid>ad</guid><title>Sponsored: Rust jobs</title><link>http://x/ad</link></item>
<item><guid>go</guid><title>Go 1.23 released</title><link>http://x/go</link></item>
</channel></rss>"""

NOW = datetime(2026, 3, 2, 9, 0)


class PollerFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        self.addCleanup(self.conn.close)
        store.add_feed(self.conn, FEED, "x")

    def poll(self) -> None:
        poller.poll_once(self.conn, {}, NOW, fetch_feed=lambda url: RSS)

    def stored_guids(self) -> set[str]:
        return {entry.guid for entry in store.unread(self.conn, 100)}

    def test_without_filters_every_entry_is_stored(self) -> None:
        self.poll()
        self.assertEqual(self.stored_guids(), {"rust", "ad", "go"})

    def test_an_entry_an_exclude_filter_drops_is_never_stored(self) -> None:
        store.add_filter(self.conn, FEED, kind="exclude", keywords=["sponsored"])
        self.poll()
        self.assertEqual(self.stored_guids(), {"rust", "go"})

    def test_an_include_filter_stores_only_matching_entries(self) -> None:
        store.add_filter(self.conn, FEED, kind="include", keywords=["rust"])
        self.poll()
        self.assertEqual(self.stored_guids(), {"rust", "ad"})

    def test_every_filter_of_the_feed_applies(self) -> None:
        store.add_filter(self.conn, FEED, kind="include", keywords=["rust"])
        store.add_filter(self.conn, FEED, kind="exclude", keywords=["sponsored"])
        self.poll()
        self.assertEqual(self.stored_guids(), {"rust"})

    def test_a_filter_leaves_other_feeds_alone(self) -> None:
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, FEED, kind="include", keywords=["go"])
        self.poll()
        stored = {(entry.feed_id, entry.guid) for entry in store.unread(self.conn, 100)}
        feed_ids = {feed.url: feed.id for feed in store.feeds(self.conn)}
        self.assertEqual(
            {guid for feed_id, guid in stored if feed_id == feed_ids["http://y/feed"]},
            {"rust", "ad", "go"},
        )
        self.assertEqual(
            {guid for feed_id, guid in stored if feed_id == feed_ids[FEED]}, {"go"}
        )

    def test_entries_already_stored_are_not_refiltered(self) -> None:
        self.poll()
        store.add_filter(self.conn, FEED, kind="exclude", keywords=["sponsored"])
        self.poll()
        self.assertEqual(self.stored_guids(), {"rust", "ad", "go"})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters.PollerFilterTest -v`
Expected: ERROR — `TypeError: poll_once() got an unexpected keyword argument 'fetch_feed'`.

- [ ] **Step 3: Change `poll_once` in `feedwatch/poller.py`**

Change the imports to:

```python
import logging
import time
from collections.abc import Callable
from datetime import datetime, timedelta

from feedwatch import fetch, filtering, parse, store
```

Replace `poll_once` (lines 12-27) with:

```python
def poll_once(
    conn, last_polled, now, *, fetch_feed: Callable[[str], bytes] = fetch.fetch
) -> None:
    for feed in store.feeds(conn):
        previous = last_polled.get(feed.id)
        if previous is not None and now - previous < timedelta(minutes=feed.interval_minutes):
            continue
        last_polled[feed.id] = now
        try:
            xml = fetch_feed(feed.url)
        except fetch.FetchError as exc:
            log.warning("skipping %s: %s", feed.url, exc)
            continue
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        rules = store.feed_filters(conn, feed.url)
        kept = [entry for entry in entries if filtering.keeps(rules, entry["title"])]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

`main` is unchanged: `poll_once(conn, last_polled, datetime.now())` still uses the real `fetch.fetch`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_keyword_filters.PollerFilterTest -v`
Expected: all PASS.

- [ ] **Step 5: Run the whole suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/poller.py tests/test_keyword_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: `feedwatch filter add | list | remove`

**Files:**
- Modify: `feedwatch/cli.py` (whole `main`, lines 1-33)
- Test: `tests/test_keyword_filters.py`

**Interfaces:**
- Consumes: `store.add_filter`, `store.feed_filters`, `store.remove_filter` (Task 2); `feedwatch.errors.FeedwatchError` (Task 2).
- Produces: `cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int`. Exit 0 on success; 1 with the error's message on stderr for any `FeedwatchError`; argparse's exit 2 for malformed commands.
  - `filter add` prints `added filter <id>`.
  - `filter list` prints one line per filter: `<id>  <kind>  <keyword>, <keyword>`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_keyword_filters.py`, add `import io` and `from contextlib import redirect_stderr, redirect_stdout` to the standard-library imports, and change `from feedwatch import poller, store` to `from feedwatch import cli, poller, store`. Add this above the `if __name__ == "__main__":` line:

```python
class CliFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.db_path = Path(self.dir.name) / "feeds.db"
        self.run_cli("add", FEED)

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv), db_path=self.db_path)
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self) -> None:
        code, out, _ = self.run_cli("filter", "add", FEED, "--exclude", "sponsored", "ad")
        self.assertEqual(code, 0)
        filter_id = out.split()[-1]
        self.assertEqual(out, f"added filter {filter_id}\n")
        code, out, _ = self.run_cli("filter", "list", FEED)
        self.assertEqual(code, 0)
        self.assertEqual(out, f"{filter_id}  exclude  sponsored, ad\n")

    def test_include_filters_are_listed_as_include(self) -> None:
        self.run_cli("filter", "add", FEED, "--include", "rust")
        _, out, _ = self.run_cli("filter", "list", FEED)
        self.assertIn("  include  rust", out)

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        _, out, _ = self.run_cli("filter", "add", FEED, "--include", "rust")
        code, _, _ = self.run_cli("filter", "remove", out.split()[-1])
        self.assertEqual(code, 0)
        self.assertEqual(self.run_cli("filter", "list", FEED)[1], "")

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        code, out, err = self.run_cli("filter", "add", "http://nope/feed", "--include", "rust")
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertEqual(err, "not subscribed to http://nope/feed\n")

    def test_listing_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        code, _, err = self.run_cli("filter", "list", "http://nope/feed")
        self.assertEqual(code, 1)
        self.assertIn("http://nope/feed", err)

    def test_blank_keywords_are_refused(self) -> None:
        code, _, err = self.run_cli("filter", "add", FEED, "--include", "", " ")
        self.assertEqual(code, 1)
        self.assertIn("keyword", err)
        self.assertEqual(self.run_cli("filter", "list", FEED)[1], "")

    def test_removing_an_unknown_filter_is_refused_naming_the_id(self) -> None:
        code, _, err = self.run_cli("filter", "remove", "99")
        self.assertEqual(code, 1)
        self.assertEqual(err, "no filter with id 99\n")

    def test_a_filter_needs_exactly_one_of_include_and_exclude(self) -> None:
        for argv in (
            ("filter", "add", FEED),
            ("filter", "add", FEED, "--include", "a", "--exclude", "b"),
            ("filter", "add", FEED, "--include"),
        ):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as caught:
                self.run_cli(*argv)
            self.assertEqual(caught.exception.code, 2)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_keyword_filters.CliFilterTest -v`
Expected: ERROR — `TypeError: main() got an unexpected keyword argument 'db_path'`.

- [ ] **Step 3: Rewrite `main` in `feedwatch/cli.py`**

Replace lines 1-33 (module docstring, imports and `main`) with:

```python
"""feedwatch's command line: subscribe, filter feeds, list unread entries, mark them read."""

import argparse
import sys
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError


def main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
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
    filter_parser = commands.add_parser(
        "filter", help="keep or drop a feed's new entries by words in their titles"
    )
    filter_commands = filter_parser.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kind = filter_add.add_mutually_exclusive_group(required=True)
    kind.add_argument(
        "--include", nargs="+", metavar="WORD",
        help="keep only entries whose title has one of these words",
    )
    kind.add_argument(
        "--exclude", nargs="+", metavar="WORD",
        help="drop entries whose title has any of these words",
    )
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
        elif args.filter_command == "add":
            if args.include is not None:
                added = store.add_filter(conn, args.url, kind="include", keywords=args.include)
            else:
                added = store.add_filter(conn, args.url, kind="exclude", keywords=args.exclude)
            print(f"added filter {added.id}")
        elif args.filter_command == "list":
            for rule in store.feed_filters(conn, args.url):
                print(f"{rule.id}  {rule.kind}  {', '.join(rule.keywords)}")
        else:
            store.remove_filter(conn, args.filter_id)
    except FeedwatchError as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0
```

Do not add a `conn.close()` here: the Effects check allows no `conn.` outside `store.py`, and the process exits right after `main` returns.

The `if __name__ == "__main__":` block at the end of the file stays as it is.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_keyword_filters.CliFilterTest -v`
Expected: all PASS.

- [ ] **Step 5: Run the whole suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_keyword_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

---

### Task 5: Check the branch against the program design and sweep

**Files:** none new; the sweep may touch the living documents listed in `.dopamine/config`.

- [ ] **Step 1: Run the whole suite**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS.

- [ ] **Step 2: Run the mechanical program-design checks over the added lines**

Run each from the repository root, with `<base>` the commit this plan started from:

```bash
git diff <base>...HEAD -- feedwatch | grep '^+' | grep -nE 'threading\.Thread|asyncio|multiprocessing|urllib'
git diff <base>...HEAD -- feedwatch ':!feedwatch/store.py' | grep '^+' | grep -nE 'sqlite3|conn\.'
git diff <base>...HEAD -- feedwatch ':!feedwatch/poller.py' ':!feedwatch/cli.py' | grep '^+' | grep -nE '^\+\s*except'
git diff <base>...HEAD -- feedwatch | grep '^+' | grep -nE 'import .*(cli|poller)'
```

Expected: no output from any of them. Then read every added `def` in `git diff <base>...HEAD -- feedwatch` and confirm it is fully annotated and has `*` before any third parameter, and that every added `raise` raises a `FeedwatchError` subclass.

- [ ] **Step 3: Sweep**

Load `dopamine:finishing-work` and follow it. Expected living-document consequences to drain from the ledger: `ARCHITECTURE.md`'s "Where state lives" names the tables `feeds` and `entries` and now also needs `filters`; the new `errors` and `filtering` modules and the `filter` commands, wherever `dopamine:routing-documentation-updates` places them.
````


## p008

#### Final message

I wrote the plan and committed it on `master` as `2d4b5bb plan: keyword filters`. Nothing is implemented. Before writing it out, I tried every task's code in a throwaway copy of the repo: all 30 tests pass, with no unclosed-connection warnings.

Plan file: `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`

**The four tasks:**
1. **Storage and errors.** A new `feedwatch/errors.py` holds `FeedwatchError` and the three failures: not subscribed, no keywords, unknown filter id. A frozen `Filter` and `FilterKind` go in `models.py`. A new `filters` table is added as an extra step at the end of `SCHEMA_STEPS`. `store` gets `feed_by_url`, `add_filter`, `feed_filters` and `remove_filter`. A test checks that a database created before this feature keeps working.
2. **Matching.** A new `feedwatch/filtering.py` has one pure function, `keeps(filters, title)`. It ignores case and matches whole words only, and it still matches keywords like "c++" that a plain `\b` regex would miss.
3. **Poller.** `poll_once` drops the entries filters reject before saving. Its download function becomes a parameter, so the tests need no network.
4. **CLI.** `filter add | list | remove`. `main` now takes the database path, so the tests don't touch `~/.feedwatch`.

**PROGRAM-DESIGN.md rules:** each rule and its check is copied into Global Constraints. None of them left a structural choice open, so I didn't need to stop and ask you anything.

**Decision for you:** the existing code already breaks some of those rules. `parse` returns dicts and `None`, `add_feed` returns an `(ok, reason)` pair, `Feed` and `Entry` aren't frozen, and `FetchError` isn't a `FeedwatchError`. The plan leaves all of that alone and says so, and only requires the new code to pass the checks. Bringing the old code in line would be a separate job.

**Review Focus:** five risky inputs the spec doesn't spell out, each pinned by a test in the task that owns it:
- several filters on one feed (an entry must pass all of them);
- punctuation next to a word, and accented letters in different case;
- a keyword inside a longer word ("cat" in "Category" doesn't match);
- blank keywords (`--include ""` is refused);
- removing a filter id that doesn't exist (refused, exit code 1).

**Two other choices:**
- No task edits the living documents, even though `ARCHITECTURE.md` lists the database tables and will need the new one. The cleanup step after the plan runs (`dopamine:finishing-work`) adds it from the run's record.
- I didn't run `dopamine:finishing-work` now, because nothing has been executed yet and there's nothing to carry into the documents. It belongs after the plan runs.

Plan complete and saved to `docs/superpowers/plans/2026-10-12-keyword-filters.md`. Please review the plan. Does it capture what you want?

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller stores only the new entries whose titles get past them.

**Architecture:** Filters are a new frozen `Filter` value in `models.py`, kept in a new `filters` table that `store` owns (appended to `SCHEMA_STEPS`, so old databases pick it up on connect). The matching rule is one pure function, `filtering.keeps(filters, title)`, in a new logic module. `poller` asks `store` for a feed's filters and drops entries before `save_entries`. `cli` gets a `filter` command group with `add`, `list` and `remove`. Failures are new `FeedwatchError` subclasses in a new `errors.py`, which `cli` catches.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `json`, `re`, `argparse`, `enum.StrEnum`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

From the spec:

- Matching is case-insensitive, on whole words, against the entry's **title only**. Filtering on an entry's body and regular expressions are out of scope.
- An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. With several filters on one feed, an entry must pass every one of them.
- An entry a filter drops is never stored. Entries already stored are not re-filtered.
- A filter for a feed that is not subscribed is refused, with a message naming the URL. A filter with no keywords is refused.
- Filters live in the same database, and a database created before this feature keeps working.

From `docs/PROGRAM-DESIGN.md`. Every rule applies to the added lines in `feedwatch/`; each is judged by its check at close.

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`; database rows and argv are turned into them in the module that reads them. *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed; no function returns `None`, `False` or an `(ok, reason)` pair to signal failure; only `poller` and `cli` catch them. *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects.** Only `store` touches the database and only `fetch` the network; logic between them is pure functions; `store` is module functions taking `conn` first, with no class wrapping the connection. Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type. *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated. This plan also applies it to the two existing `def`s whose signatures it changes (`poller.poll_once`, `cli.main`), and to the test methods.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`. *Check:* no added import of `cli` or `poller` (the test file excepted); no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not an `ARCHITECTURE.md` component hides real work behind one or two public functions; no pass-through layer. *Check:* a new module other than a component has at most two public functions, types aside (`filtering.py` has one, `keeps`; `errors.py` has none); no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows: a new table is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited. *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS`; no existing step changes.

Out of this plan's scope: existing code that predates these rules — `parse.parse_feed` returning dicts and `None`, `store.add_feed` returning `(ok, reason)`, the non-frozen `Feed` and `Entry`, `fetch.FetchError` not being a `FeedwatchError` — stays as it is. New code meets the checks above where it touches it: `filtering.keeps` takes a title string rather than an entry dict.

Living documents (`ARCHITECTURE.md` lists the tables in "Where state lives") are not edited during execution; the finishing-work sweep places that from the ledger.

Run the tests with `python3 -m unittest discover -s tests -v` from the repository root. There is no pytest.

## Review Focus

1. **Two or more filters on one feed** — an include and an exclude, or two includes: the entry must pass every filter. Pinned in Task 2 (`test_an_entry_must_pass_every_filter_on_its_feed`) and Task 3 (`test_entries_a_filter_drops_are_not_stored`).
2. **Punctuation next to a word, keywords that contain punctuation, non-ASCII case** — "Python's", "(Python)", "C++", "node.js", "ÉCOLE": these are whole-word matches. A plain `\b` regex would miss "c++". Pinned in Task 2 (`test_punctuation_next_to_a_word_does_not_hide_it`, `test_a_keyword_with_punctuation_matches_as_a_whole_word`, `test_matching_ignores_case`).
3. **A keyword inside a longer word** — "cat" in "Category" is not a match, for include or for exclude. Pinned in Task 2 (`test_part_of_a_word_does_not_match`).
4. **Blank keywords** — `--include ""` or `--include "  "` gets past argparse's `nargs="+"`, but it is still a filter with no keywords and is refused. A blank keyword among real ones is dropped rather than stored. Pinned in Task 1 (`test_a_filter_without_keywords_is_refused`, `test_blank_keywords_are_dropped_and_the_rest_trimmed`) and Task 4 (`test_a_filter_whose_keywords_are_all_blank_is_refused`).
5. **Removing a filter id that does not exist** — a typo must not exit 0. It is refused with a message naming the id, exit 1. Pinned in Task 1 (`test_removing_an_unknown_filter_is_refused_by_id`) and Task 4 (`test_removing_an_unknown_filter_is_refused_naming_the_id`).

---

## File Structure

- Create `feedwatch/errors.py`: `FeedwatchError` and the three failures this feature raises.
- Modify `feedwatch/models.py`: add `FilterKind` and the frozen `Filter`.
- Modify `feedwatch/store.py`: add the `filters` schema step, the `Connection` alias, and `feed_by_url`, `add_filter`, `feed_filters`, `remove_filter`.
- Create `feedwatch/filtering.py`: `keeps`, the matching rule, pure.
- Modify `feedwatch/poller.py`: `poll_once` drops filtered entries before saving, and takes its downloader as a parameter so tests need no network.
- Modify `feedwatch/cli.py`: the `filter add|list|remove` commands, and `main` takes the database path so tests do not touch `~/.feedwatch`.
- Create `tests/test_filters.py`: one test class per task. `tests/test_feedwatch.py` is unchanged and must keep passing.

---

### Task 1: Errors, the Filter model, and filter storage

**Files:**
- Create: `feedwatch/errors.py`
- Modify: `feedwatch/models.py`
- Modify: `feedwatch/store.py`
- Test: `tests/test_filters.py` (create)

**Interfaces:**
- Consumes: `store.connect(path)`, `store.add_feed(conn, url, title)`, `store.unread(conn, limit)`, `store.SCHEMA_STEPS` (existing).
- Produces:
  - `errors.FeedwatchError(Exception)`, `errors.NotSubscribedError`, `errors.EmptyFilterError`, `errors.UnknownFilterError` (all subclasses of `FeedwatchError`).
  - `models.FilterKind(StrEnum)` with `INCLUDE = "include"`, `EXCLUDE = "exclude"`.
  - `models.Filter`, `@dataclass(frozen=True)`, with fields `id: int`, `feed_id: int`, `kind: FilterKind`, `keywords: tuple[str, ...]`.
  - `store.Connection` (alias of `sqlite3.Connection`, for annotations outside `store`).
  - `store.feed_by_url(conn: Connection, url: str) -> Feed`, which raises `NotSubscribedError` with the URL in its message.
  - `store.add_filter(conn: Connection, feed_id: int, *, kind: FilterKind, keywords: Sequence[str]) -> Filter`, which strips each keyword, drops blank ones, and raises `EmptyFilterError` when none are left.
  - `store.feed_filters(conn: Connection, feed_id: int) -> list[Filter]`, in id order.
  - `store.remove_filter(conn: Connection, filter_id: int) -> None`, which raises `UnknownFilterError` with the id in its message.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
"""Keyword filters: storage, matching, the poller and the command line."""

import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store
from feedwatch.errors import EmptyFilterError, NotSubscribedError, UnknownFilterError
from feedwatch.models import Filter, FilterKind

FEED_URL = "http://x/feed"


class FilterStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, FEED_URL, "x")
        self.feed = store.feed_by_url(self.conn, FEED_URL)

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def test_a_filter_is_stored_and_listed_with_its_feed(self) -> None:
        added = store.add_filter(
            self.conn, self.feed.id, kind=FilterKind.INCLUDE, keywords=["python", "rust"]
        )
        self.assertEqual(
            added, Filter(added.id, self.feed.id, FilterKind.INCLUDE, ("python", "rust"))
        )
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [added])

    def test_an_unsubscribed_url_is_refused_by_name(self) -> None:
        with self.assertRaises(NotSubscribedError) as caught:
            store.feed_by_url(self.conn, "http://y/feed")
        self.assertIn("http://y/feed", str(caught.exception))

    def test_a_filter_without_keywords_is_refused(self) -> None:
        for keywords in ([], [""], ["  ", "\t"]):
            with self.subTest(keywords=keywords), self.assertRaises(EmptyFilterError):
                store.add_filter(
                    self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=keywords
                )
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [])

    def test_blank_keywords_are_dropped_and_the_rest_trimmed(self) -> None:
        added = store.add_filter(
            self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=[" sale ", "", "  "]
        )
        self.assertEqual(added.keywords, ("sale",))

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        added = store.add_filter(
            self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=["sale"]
        )
        store.remove_filter(self.conn, added.id)
        self.assertEqual(store.feed_filters(self.conn, self.feed.id), [])

    def test_removing_an_unknown_filter_is_refused_by_id(self) -> None:
        with self.assertRaises(UnknownFilterError) as caught:
            store.remove_filter(self.conn, 99)
        self.assertIn("99", str(caught.exception))

    def test_a_database_from_before_filters_keeps_working(self) -> None:
        path = Path(self.dir.name) / "old.db"
        old = sqlite3.connect(path)
        for step in store.SCHEMA_STEPS[:2]:
            old.execute(step)
        old.execute("INSERT INTO feeds (url, title) VALUES (?, ?)", (FEED_URL, "x"))
        old.execute(
            "INSERT INTO entries (feed_id, guid, title, link) VALUES (1, 'a', 'Old', 'http://x/a')"
        )
        old.commit()
        old.close()
        conn = store.connect(path)
        try:
            feed = store.feed_by_url(conn, FEED_URL)
            self.assertEqual([e.guid for e in store.unread(conn)], ["a"])
            added = store.add_filter(conn, feed.id, kind=FilterKind.INCLUDE, keywords=["python"])
            self.assertEqual(store.feed_filters(conn, feed.id), [added])
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.errors'`.

- [ ] **Step 3: Create `feedwatch/errors.py`**

```python
"""The failures feedwatch raises on purpose."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises; poller and cli catch it."""


class NotSubscribedError(FeedwatchError):
    """A command named a feed URL that is not subscribed."""


class EmptyFilterError(FeedwatchError):
    """A filter was given no keyword that is not blank."""


class UnknownFilterError(FeedwatchError):
    """A command named a filter id that does not exist."""
```

- [ ] **Step 4: Add `FilterKind` and `Filter` to `feedwatch/models.py`**

Add `from enum import StrEnum` below `from datetime import datetime`, and append at the end of the file:

```python


class FilterKind(StrEnum):
    INCLUDE = "include"
    EXCLUDE = "exclude"


@dataclass(frozen=True)
class Filter:
    id: int
    feed_id: int
    kind: FilterKind
    keywords: tuple[str, ...]
```

- [ ] **Step 5: Add filter storage to `feedwatch/store.py`**

Replace the import block at the top with:

```python
import json
import sqlite3
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path

from feedwatch.errors import EmptyFilterError, NotSubscribedError, UnknownFilterError
from feedwatch.models import Entry, Feed, Filter, FilterKind
```

Below `DEFAULT_PATH = ...`, add:

```python

Connection = sqlite3.Connection
```

Append a third step to `SCHEMA_STEPS`, after the `entries` step. Leave the two existing steps byte-for-byte unchanged:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL,
        keywords TEXT NOT NULL
    )""",
```

Append at the end of the file:

```python


def feed_by_url(conn: Connection, url: str) -> Feed:
    """Return the subscribed feed at `url`; raises NotSubscribedError if there is none."""
    row = conn.execute(
        "SELECT id, url, title, interval_minutes FROM feeds WHERE url = ?", (url,)
    ).fetchone()
    if row is None:
        raise NotSubscribedError(f"not subscribed to {url}")
    return Feed(*row)


def add_filter(
    conn: Connection, feed_id: int, *, kind: FilterKind, keywords: Sequence[str]
) -> Filter:
    """Attach a filter to a feed and return it, its keywords trimmed and blank ones dropped.

    Raises EmptyFilterError when no keyword is left.
    """
    kept = tuple(k.strip() for k in keywords if k.strip())
    if not kept:
        raise EmptyFilterError("a filter needs at least one keyword")
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed_id, kind.value, json.dumps(kept)),
        )
    return Filter(cursor.lastrowid, feed_id, kind, kept)


def feed_filters(conn: Connection, feed_id: int) -> list[Filter]:
    rows = conn.execute(
        "SELECT id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id", (feed_id,)
    )
    return [
        Filter(filter_id, feed_id, FilterKind(kind), tuple(json.loads(keywords)))
        for filter_id, kind, keywords in rows
    ]


def remove_filter(conn: Connection, filter_id: int) -> None:
    """Delete a filter; raises UnknownFilterError if no filter has that id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    if cursor.rowcount == 0:
        raise UnknownFilterError(f"no filter with id {filter_id}")
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: PASS. 7 tests in `FilterStoreTest` and the 4 existing ones in `tests/test_feedwatch.py`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/errors.py feedwatch/models.py feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 2: The matching rule

**Files:**
- Create: `feedwatch/filtering.py`
- Test: `tests/test_filters.py` (modify)

**Interfaces:**
- Consumes: `models.Filter`, `models.FilterKind` (Task 1).
- Produces: `filtering.keeps(filters: Iterable[Filter], title: str) -> bool`. It is pure, and it is the module's only public function.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the line `from feedwatch import store` to:

```python
from feedwatch import filtering, store
```

Below `FEED_URL = "http://x/feed"`, add:

```python


def include(*keywords: str) -> Filter:
    return Filter(1, 1, FilterKind.INCLUDE, keywords)


def exclude(*keywords: str) -> Filter:
    return Filter(2, 1, FilterKind.EXCLUDE, keywords)
```

Add this class above `if __name__ == "__main__":`:

```python
class KeepsTest(unittest.TestCase):
    def test_no_filters_keep_everything(self) -> None:
        self.assertTrue(filtering.keeps([], "Anything at all"))

    def test_an_include_filter_keeps_only_titles_with_one_of_its_keywords(self) -> None:
        self.assertTrue(filtering.keeps([include("python", "rust")], "Rust 2.0 released"))
        self.assertFalse(filtering.keeps([include("python", "rust")], "Go 2.0 released"))

    def test_an_exclude_filter_drops_titles_with_any_of_its_keywords(self) -> None:
        self.assertFalse(filtering.keeps([exclude("sale", "sponsored")], "Sponsored: a laptop"))
        self.assertTrue(filtering.keeps([exclude("sale", "sponsored")], "A new laptop"))

    def test_matching_ignores_case(self) -> None:
        self.assertTrue(filtering.keeps([include("python")], "PYTHON 3.14 is out"))
        self.assertTrue(filtering.keeps([include("École")], "l'école rouvre"))

    def test_part_of_a_word_does_not_match(self) -> None:
        self.assertFalse(filtering.keeps([include("cat")], "Category theory"))
        self.assertTrue(filtering.keeps([exclude("ad")], "Adding filters"))

    def test_punctuation_next_to_a_word_does_not_hide_it(self) -> None:
        for title in ("Python, again", "(Python)", "Python's new parser", "python-dev news"):
            with self.subTest(title=title):
                self.assertTrue(filtering.keeps([include("python")], title))

    def test_a_keyword_with_punctuation_matches_as_a_whole_word(self) -> None:
        self.assertTrue(filtering.keeps([include("c++")], "What's new in C++ 26"))
        self.assertTrue(filtering.keeps([include("node.js")], "Node.js 24 is out"))
        self.assertFalse(filtering.keeps([include("node.js")], "nodexjs 24 is out"))

    def test_an_entry_must_pass_every_filter_on_its_feed(self) -> None:
        filters = [include("python"), exclude("sponsored")]
        self.assertTrue(filtering.keeps(filters, "Python tips"))
        self.assertFalse(filtering.keeps(filters, "Sponsored Python course"))
        self.assertFalse(filtering.keeps(filters, "Rust tips"))
        self.assertFalse(filtering.keeps([include("python"), include("rust")], "Python tips"))

    def test_an_empty_title_fails_an_include_filter_and_passes_an_exclude_filter(self) -> None:
        self.assertFalse(filtering.keeps([include("python")], ""))
        self.assertTrue(filtering.keeps([exclude("python")], ""))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters -v`
Expected: ERROR, `ImportError: cannot import name 'filtering' from 'feedwatch'`.

- [ ] **Step 3: Create `feedwatch/filtering.py`**

```python
"""Decides whether an entry's title gets past its feed's keyword filters."""

import re
from collections.abc import Iterable

from feedwatch.models import Filter, FilterKind


def keeps(filters: Iterable[Filter], title: str) -> bool:
    """Whether a title passes every filter: each include filter matches one of its
    keywords in it, and no exclude filter matches any. Case-insensitive, whole words."""
    folded = title.casefold()
    for f in filters:
        matched = any(_has_word(folded, keyword) for keyword in f.keywords)
        if matched != (f.kind is FilterKind.INCLUDE):
            return False
    return True


def _has_word(folded_title: str, keyword: str) -> bool:
    # Lookarounds rather than \b: \b needs a word character at each end, so a
    # keyword such as "c++" would never match.
    pattern = rf"(?<!\w){re.escape(keyword.casefold())}(?!\w)"
    return re.search(pattern, folded_title) is not None
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: PASS. 20 tests.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/filtering.py tests/test_filters.py
git commit -m "feat: match keyword filters against entry titles"
```

---

### Task 3: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py`
- Test: `tests/test_filters.py` (modify)

**Interfaces:**
- Consumes: `store.feed_filters`, `store.add_filter`, `store.feed_by_url`, `store.Connection` (Task 1); `filtering.keeps` (Task 2).
- Produces: `poller.poll_once(conn: store.Connection, last_polled: dict[int, datetime], *, now: datetime, download: Callable[[str], bytes] = fetch.fetch) -> None`. `now` becomes keyword-only, and `poller.main` is updated to match.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the line `from feedwatch import filtering, store` to:

```python
from feedwatch import filtering, poller, store
```

Add `from datetime import datetime` to the standard-library imports. Below `FEED_URL = "http://x/feed"`, add:

```python

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>Python tips</title><link>http://x/a</link></item>
<item><guid>b</guid><title>Sponsored: Python course</title><link>http://x/b</link></item>
<item><guid>c</guid><title>Rust tips</title><link>http://x/c</link></item>
</channel></rss>"""
```

Add this class above `if __name__ == "__main__":`:

```python
class PollerFilterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, FEED_URL, "x")
        self.feed = store.feed_by_url(self.conn, FEED_URL)

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def poll(self) -> None:
        poller.poll_once(self.conn, {}, now=datetime(2026, 3, 2, 9, 0), download=lambda url: RSS)

    def stored_guids(self, feed_id: int) -> list[str]:
        return sorted(e.guid for e in store.unread(self.conn, 100) if e.feed_id == feed_id)

    def test_a_feed_without_filters_stores_every_entry(self) -> None:
        self.poll()
        self.assertEqual(self.stored_guids(self.feed.id), ["a", "b", "c"])

    def test_entries_a_filter_drops_are_not_stored(self) -> None:
        store.add_filter(self.conn, self.feed.id, kind=FilterKind.INCLUDE, keywords=["python"])
        store.add_filter(self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=["sponsored"])
        self.poll()
        self.assertEqual(self.stored_guids(self.feed.id), ["a"])

    def test_entries_already_stored_are_not_refiltered(self) -> None:
        self.poll()
        store.add_filter(self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=["rust"])
        self.poll()
        self.assertEqual(self.stored_guids(self.feed.id), ["a", "b", "c"])

    def test_a_feeds_filters_leave_other_feeds_alone(self) -> None:
        store.add_feed(self.conn, "http://y/feed", "y")
        other = store.feed_by_url(self.conn, "http://y/feed")
        store.add_filter(self.conn, self.feed.id, kind=FilterKind.EXCLUDE, keywords=["tips"])
        self.poll()
        self.assertEqual(self.stored_guids(self.feed.id), ["b"])
        self.assertEqual(self.stored_guids(other.id), ["a", "b", "c"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.PollerFilterTest -v`
Expected: 4 ERRORs, `TypeError: poll_once() got an unexpected keyword argument 'download'`.

- [ ] **Step 3: Apply filters in `feedwatch/poller.py`**

Replace the imports and `poll_once` with:

```python
import logging
import time
from collections.abc import Callable
from datetime import datetime, timedelta

from feedwatch import fetch, filtering, parse, store

log = logging.getLogger("feedwatch.poller")


def poll_once(
    conn: store.Connection,
    last_polled: dict[int, datetime],
    *,
    now: datetime,
    download: Callable[[str], bytes] = fetch.fetch,
) -> None:
    for feed in store.feeds(conn):
        previous = last_polled.get(feed.id)
        if previous is not None and now - previous < timedelta(minutes=feed.interval_minutes):
            continue
        last_polled[feed.id] = now
        try:
            xml = download(feed.url)
        except fetch.FetchError as exc:
            log.warning("skipping %s: %s", feed.url, exc)
            continue
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        filters = store.feed_filters(conn, feed.id)
        kept = [e for e in entries if filtering.keeps(filters, e["title"])]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

In `main`, change the call to:

```python
        poll_once(conn, last_polled, now=datetime.now())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: PASS. 24 tests.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: The `filter` commands

**Files:**
- Modify: `feedwatch/cli.py`
- Test: `tests/test_filters.py` (modify)

**Interfaces:**
- Consumes: `store.feed_by_url`, `store.add_filter`, `store.feed_filters`, `store.remove_filter`, `errors.FeedwatchError`, `models.FilterKind` (Task 1).
- Produces: `cli.main(argv: list[str] | None = None, path: Path = store.DEFAULT_PATH) -> int`. The commands and their output are:
  - `feedwatch filter add URL --include|--exclude WORD [WORD ...]` prints `added filter <id>`.
  - `feedwatch filter list URL` prints one line per filter, `<id>  <include|exclude>  <kw>, <kw>`.
  - `feedwatch filter remove ID` prints nothing.
  - Any `FeedwatchError` goes to stderr, exit 1. A usage error is argparse's exit 2.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, change the line `from feedwatch import filtering, poller, store` to:

```python
from feedwatch import cli, filtering, poller, store
```

Add `import io` and `from contextlib import redirect_stderr, redirect_stdout` to the standard-library imports, keeping them sorted. Add this class above `if __name__ == "__main__":`:

```python
class FilterCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "feeds.db"
        conn = store.connect(self.path)
        store.add_feed(conn, FEED_URL, "x")
        conn.close()

    def tearDown(self) -> None:
        self.dir.cleanup()

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv), self.path)
        return code, out.getvalue(), err.getvalue()

    def test_a_filter_is_added_listed_and_removed(self) -> None:
        self.assertEqual(
            self.run_cli("filter", "add", FEED_URL, "--include", "python", "rust"),
            (0, "added filter 1\n", ""),
        )
        self.assertEqual(
            self.run_cli("filter", "add", FEED_URL, "--exclude", "sale"),
            (0, "added filter 2\n", ""),
        )
        self.assertEqual(
            self.run_cli("filter", "list", FEED_URL),
            (0, "1  include  python, rust\n2  exclude  sale\n", ""),
        )
        self.assertEqual(self.run_cli("filter", "remove", "1"), (0, "", ""))
        self.assertEqual(self.run_cli("filter", "list", FEED_URL), (0, "2  exclude  sale\n", ""))

    def test_a_filter_for_an_unsubscribed_feed_is_refused_naming_the_url(self) -> None:
        for argv in (("filter", "add", "http://y/feed", "--include", "python"),
                     ("filter", "list", "http://y/feed")):
            with self.subTest(argv=argv):
                code, out, err = self.run_cli(*argv)
                self.assertEqual((code, out), (1, ""))
                self.assertIn("http://y/feed", err)

    def test_a_filter_whose_keywords_are_all_blank_is_refused(self) -> None:
        code, _, err = self.run_cli("filter", "add", FEED_URL, "--include", "", "  ")
        self.assertEqual(code, 1)
        self.assertIn("keyword", err)
        self.assertEqual(self.run_cli("filter", "list", FEED_URL), (0, "", ""))

    def test_a_filter_needs_exactly_one_of_include_and_exclude_with_words(self) -> None:
        for argv in (("filter", "add", FEED_URL, "--include"),
                     ("filter", "add", FEED_URL),
                     ("filter", "add", FEED_URL, "--include", "a", "--exclude", "b")):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as caught:
                self.run_cli(*argv)
            self.assertEqual(caught.exception.code, 2)

    def test_removing_an_unknown_filter_is_refused_naming_the_id(self) -> None:
        code, out, err = self.run_cli("filter", "remove", "99")
        self.assertEqual((code, out), (1, ""))
        self.assertIn("99", err)

    def test_the_existing_commands_still_work(self) -> None:
        self.assertEqual(self.run_cli("unread"), (0, "", ""))
        code, _, err = self.run_cli("add", FEED_URL)
        self.assertEqual(code, 1)
        self.assertIn("already subscribed", err)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_filters.FilterCliTest -v`
Expected: ERRORs, `TypeError: main() takes from 0 to 1 positional arguments but 2 were given`.

- [ ] **Step 3: Add the commands to `feedwatch/cli.py`**

Replace the whole file with:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read, filter feeds."""

import argparse
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import FilterKind


def main(argv: list[str] | None = None, path: Path = store.DEFAULT_PATH) -> int:
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
    filters = commands.add_parser("filter", help="keep or drop a feed's new entries by title")
    filter_commands = filters.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="attach a keyword filter to a feed")
    filter_add.add_argument("url")
    kinds = filter_add.add_mutually_exclusive_group(required=True)
    kinds.add_argument("--include", nargs="+", metavar="WORD", help="keep titles with one of these")
    kinds.add_argument("--exclude", nargs="+", metavar="WORD", help="drop titles with any of these")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter by id")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    with closing(store.connect(path)) as conn:
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
            elif args.filter_command == "add":
                feed = store.feed_by_url(conn, args.url)
                if args.include is not None:
                    kind, keywords = FilterKind.INCLUDE, args.include
                else:
                    kind, keywords = FilterKind.EXCLUDE, args.exclude
                added = store.add_filter(conn, feed.id, kind=kind, keywords=keywords)
                print(f"added filter {added.id}")
            elif args.filter_command == "list":
                feed = store.feed_by_url(conn, args.url)
                for f in store.feed_filters(conn, feed.id):
                    print(f"{f.id}  {f.kind}  {', '.join(f.keywords)}")
            else:
                store.remove_filter(conn, args.filter_id)
        except FeedwatchError as exc:
            print(exc, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`closing(...)` closes the connection without an added `conn.` call outside `store`, which is what the Effects check asks for.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest discover -s tests -v`
Expected: PASS. 30 tests, and no unclosed-connection warnings.

- [ ] **Step 5: Check the added lines against PROGRAM-DESIGN.md**

Run: `git diff -U0 $(git merge-base HEAD master)... -- feedwatch/ | grep -E '^\+\+\+ |^\+.*(sqlite3|conn\.|urllib|threading|asyncio|multiprocessing|except|return None|return False)'`

Expected: under `feedwatch/store.py`, the `Connection = sqlite3.Connection` line and the `conn.execute` lines; under `feedwatch/cli.py`, `except FeedwatchError as exc:`; under `feedwatch/filtering.py`, the predicate's `return False`. Any other match breaks a Global Constraint and must be fixed before committing.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: filter add, list and remove commands"
```
````


## p009

#### Final message

I wrote the implementation plan and committed it as `6ae819c plan: keyword filters`. Nothing is implemented in the repository. Before writing the plan I built every step's code in a scratch copy, and all 32 tests passed there (the 4 existing ones and 28 new ones).

Plan: `<repo>/docs/superpowers/plans/2026-10-12-keyword-filters.md`

**Tasks:**
1. **The filter type and matching.** A frozen `KeywordFilter` goes in `models.py`. A new `feedwatch/filtering.py` has one public function, `keeps(title, filters) -> bool`. It matches case-insensitively and on whole words, and still works when a keyword sits next to punctuation or ends in it, like `C++`.
2. **Storage and errors.** A new `feedwatch/errors.py` holds `FeedwatchError` and the three errors this feature raises. A `filters` table is added as a new last step in `SCHEMA_STEPS`, and `store` gets `add_filter`, `filters` and `remove_filter`. One test checks that a database built by the old version still works.
3. **The poller.** It reads each feed's filters on every poll and saves only the entries they keep, so entries already stored are never re-filtered. The test points the poller at a real `file://` feed, so nothing is mocked.
4. **The CLI.** Adds `filter add | list | remove`. `main` gains a `db_path` parameter so the tests can use a temporary database. Errors print one line and exit with status 1. The task ends with grep checks against `PROGRAM-DESIGN.md` and a note for the post-execution documentation sweep.

**Program-design rules:**
- I copied every rule that applies, with its check, into Global Constraints. The concurrency rule doesn't apply because the feature adds no threads.
- None of the structural choices was left open by `PROGRAM-DESIGN.md`, so I had no question for you.
- Some existing code doesn't follow the rules: `Feed` and `Entry` aren't frozen, `parse` returns dicts, and `add_feed` returns an `(ok, reason)` pair. The plan leaves that code alone and holds only the new lines to the rules.
- That's why `keeps` takes the entry's title as a string rather than the dict `parse` returns. It's also why "include"/"exclude" is a plain `Literal` type and not an `Enum`: the Types rule's check says every new domain type is a frozen dataclass, which an `Enum` isn't.

**Choices I made where the spec is silent:**
- Several filters on one feed: an entry is stored only if every filter keeps it.
- Blank keywords are dropped and repeated ones stored once. A filter left with no keywords is refused.
- `filter list` on a feed you're not subscribed to is refused, the same way `filter add` is.
- Removing a filter id that doesn't exist is refused with a message.

**Documentation:** `ARCHITECTURE.md` lists only the `feeds` and `entries` tables. The plan's last step adds the new `filters` table to the execution ledger for the sweep to place, and leaves the document itself unedited.

Please review the plan and check it covers what you want.

#### docs/superpowers/plans/2026-10-12-keyword-filters.md (added)

````
# Keyword Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user attach include/exclude keyword filters to a feed, so the poller never stores entries whose titles a filter drops.

**Architecture:** A new `filters` table, appended to `store.SCHEMA_STEPS`, holds each filter as a `KeywordFilter` value. A new pure module, `feedwatch/filtering.py`, decides from an entry's title whether every filter of its feed lets it through. `poller.poll_once` reads the feed's filters on every poll and saves only the entries that pass. `cli` gains `filter add | list | remove`. Failures are raised as `FeedwatchError` subclasses from a new `feedwatch/errors.py` and caught only in `cli`.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `re`, `json`, `argparse`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`

## Global Constraints

From the spec, verbatim where it gives values:

- An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. Matching is case-insensitive, on whole words.
- Commands: `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]`; `feedwatch filter list FEED_URL` (lists filters with their ids); `feedwatch filter remove FILTER_ID`.
- An entry a filter drops is never stored. Entries already stored are not re-filtered.
- A filter for a feed that is not subscribed is refused, with a message naming the URL. A filter with no keywords is refused.
- Filters live in the same database; a database created before this feature keeps working.
- Out of scope: filtering on an entry's body; regular expressions. A keyword is literal text: it is passed through `re.escape`, never compiled as a pattern.
- Several filters on one feed combine: an entry is stored only if every filter keeps it. This is what the spec's per-filter rules mean together; it is not a choice the plan adds.

From `docs/PROGRAM-DESIGN.md` (Python 3.11, standard library). Each rule applies to the lines this plan adds; the code that already exists does not follow all of them (`Feed` and `Entry` are not frozen, `parse` returns dicts, `store.add_feed` returns `(ok, reason)`, `fetch.FetchError` is not a `FeedwatchError`), and this plan leaves that code as it is.

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`; past the module that reads XML, rows or argv, nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
  *Here:* `KeywordFilter` is a frozen dataclass in `models.py`; `FilterKind` is a `Literal` alias, not a new type. `filtering.keeps` takes the entry's `title: str`, not the dict `parse` returns.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
  *Here:* `feedwatch/errors.py` does not exist yet; Task 2 creates it. `filtering.keeps` returning `False` is a predicate's answer.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class. Inherited default: dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
  *Here:* `cli` closes its connection with `contextlib.closing`, not `conn.close()`. `cli.main` takes the database path as a parameter so tests need no mock. The poller test fetches a real `file://` URL, so `fetch` is not mocked either.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated. This includes test methods and test helpers (`-> None`).
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`. Inherited default: split by responsibility, not technical layer.
  *Check:* no added import of `cli` or `poller` inside the package (tests import them); no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
  *Here:* `filtering.py` has one public function, `keeps`; `errors.py` holds only types.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

The Concurrency rule does not apply: nothing here adds threads or executors.

Tests run from the repository root with `python3 -m unittest discover -s tests -v`.

## Review Focus

1. **A keyword next to punctuation, or ending in it** (`"Python, again"`, `"(Python)"`, `--include C++`): a user expects it to match. A plain `\b…\b` pattern never matches `C++`, because `\b` needs a word character on one side. Pinned in Task 1.
2. **Several filters on one feed** (an include and an exclude, or two includes): a user expects an entry to be stored only when every filter keeps it. Pinned in Task 1.
3. **Blank or repeated keywords** (`--include ""`, `--include " "`, `--include python python`): blank keywords are dropped, and a filter left with none is refused as having no keywords, rather than being stored and matching nothing. Repeats are stored once. Pinned in Tasks 2 and 4.
4. **An unknown filter id, or listing an unsubscribed feed** (`filter remove 99`, `filter list http://nope/feed`): a user expects a one-line message and exit status 1, not a traceback or a silent success. Pinned in Tasks 2 and 4.
5. **A filter added while the poller is running**: it takes effect at that feed's next poll without a restart, and the entries already stored stay. Pinned in Task 3.

---

## File Structure

- Create `feedwatch/errors.py`: `FeedwatchError` and the three failures this feature raises. Types only.
- Create `feedwatch/filtering.py`: whether an entry's title passes a feed's filters. Pure; imports only `models`.
- Modify `feedwatch/models.py`: add `FilterKind` and the frozen `KeywordFilter`.
- Modify `feedwatch/store.py`: append the `filters` table step; add `add_filter`, `filters`, `remove_filter` and the private `_feed_id`.
- Modify `feedwatch/poller.py`: filter parsed entries before `save_entries`.
- Modify `feedwatch/cli.py`: the `filter` subcommand, a `db_path` parameter on `main`, and catching `FeedwatchError`.
- Create `tests/test_filters.py`: every test for this feature, one class per task. `tests/test_feedwatch.py` is not changed.

---

### Task 1: The filter value and the matching logic

**Files:**
- Modify: `feedwatch/models.py`
- Create: `feedwatch/filtering.py`
- Create: `tests/test_filters.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.FilterKind = Literal["include", "exclude"]`
  - `feedwatch.models.KeywordFilter`: `@dataclass(frozen=True)` with fields `id: int`, `feed_id: int`, `kind: FilterKind`, `keywords: tuple[str, ...]`
  - `feedwatch.filtering.keeps(title: str, filters: Sequence[KeywordFilter]) -> bool`: `True` when every filter lets an entry with this title through; `True` for an empty `filters`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_filters.py`:

```python
import unittest

from feedwatch import filtering
from feedwatch.models import KeywordFilter


def include(*keywords: str) -> KeywordFilter:
    return KeywordFilter(1, 1, "include", keywords)


def exclude(*keywords: str) -> KeywordFilter:
    return KeywordFilter(2, 1, "exclude", keywords)


class FilteringTest(unittest.TestCase):
    def test_an_include_filter_keeps_only_titles_with_one_of_its_keywords(self) -> None:
        only_python = [include("python", "rust")]
        self.assertTrue(filtering.keeps("Rust 2.0 released", only_python))
        self.assertFalse(filtering.keeps("Go 2.0 released", only_python))

    def test_an_exclude_filter_drops_titles_with_any_of_its_keywords(self) -> None:
        no_ads = [exclude("sponsored", "ad")]
        self.assertFalse(filtering.keeps("Sponsored: a new laptop", no_ads))
        self.assertTrue(filtering.keeps("A new laptop", no_ads))

    def test_matching_ignores_case(self) -> None:
        self.assertTrue(filtering.keeps("PYTHON 4 ANNOUNCED", [include("Python")]))

    def test_a_keyword_inside_a_longer_word_does_not_match(self) -> None:
        self.assertFalse(filtering.keeps("A category of its own", [include("cat")]))
        self.assertTrue(filtering.keeps("A category of its own", [exclude("cat")]))

    def test_a_feed_with_no_filters_keeps_everything(self) -> None:
        self.assertTrue(filtering.keeps("Anything at all", []))

    def test_a_keyword_next_to_punctuation_still_matches(self) -> None:
        self.assertTrue(filtering.keeps("Python, again", [include("python")]))
        self.assertTrue(filtering.keeps("(Python)", [include("python")]))
        self.assertTrue(filtering.keeps("Why C++ still matters", [include("C++")]))
        self.assertFalse(filtering.keeps("Why C still matters", [include("C++")]))

    def test_an_entry_is_kept_only_when_every_filter_keeps_it(self) -> None:
        both = [include("python"), exclude("sponsored")]
        self.assertTrue(filtering.keeps("Python tips", both))
        self.assertFalse(filtering.keeps("Sponsored Python tips", both))
        self.assertFalse(filtering.keeps("Rust tips", both))

    def test_an_empty_title_fails_an_include_filter_and_passes_an_exclude_filter(self) -> None:
        self.assertFalse(filtering.keeps("", [include("python")]))
        self.assertTrue(filtering.keeps("", [exclude("python")]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -v`
Expected: `test_filters` errors with `ImportError: cannot import name 'filtering' from 'feedwatch'`; the four tests in `test_feedwatch` pass.

- [ ] **Step 3: Add the filter value to `feedwatch/models.py`**

Add `from typing import Literal` below `from datetime import datetime`, and append to the end of the file:

```python
FilterKind = Literal["include", "exclude"]


@dataclass(frozen=True)
class KeywordFilter:
    id: int
    feed_id: int
    kind: FilterKind
    keywords: tuple[str, ...]
```

- [ ] **Step 4: Write `feedwatch/filtering.py`**

```python
"""Decides whether an entry's title gets past a feed's keyword filters."""

import re
from collections.abc import Sequence

from feedwatch.models import KeywordFilter


def keeps(title: str, filters: Sequence[KeywordFilter]) -> bool:
    """Whether every one of the filters lets an entry with this title through."""
    return all(_passes(title, keyword_filter) for keyword_filter in filters)


def _passes(title: str, keyword_filter: KeywordFilter) -> bool:
    hit = any(_contains_word(title, keyword) for keyword in keyword_filter.keywords)
    return hit if keyword_filter.kind == "include" else not hit


def _contains_word(title: str, keyword: str) -> bool:
    # Lookarounds rather than \b: \b needs a word character on one side, so a
    # keyword that ends in punctuation, such as "C++", would never match.
    pattern = rf"(?<!\w){re.escape(keyword)}(?!\w)"
    return re.search(pattern, title, re.IGNORECASE) is not None
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 12 tests, all OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/filtering.py tests/test_filters.py
git commit -m "feat: keyword filter value and title matching"
```

---

### Task 2: Storing filters, and the errors they raise

**Files:**
- Create: `feedwatch/errors.py`
- Modify: `feedwatch/store.py` (imports at lines 3-7; `SCHEMA_STEPS` at lines 13-29; new functions at the end)
- Modify: `tests/test_filters.py`

**Interfaces:**
- Consumes: `KeywordFilter`, `FilterKind` from Task 1.
- Produces:
  - `feedwatch.errors.FeedwatchError(Exception)`
  - `feedwatch.errors.FeedNotSubscribedError(url: str)`: message `not subscribed to <url>`; attribute `url`
  - `feedwatch.errors.EmptyFilterError()`: message `a filter needs at least one keyword`
  - `feedwatch.errors.FilterNotFoundError(filter_id: int)`: message `no filter with id <filter_id>`; attribute `filter_id`
  - `store.add_filter(conn: sqlite3.Connection, feed_url: str, *, kind: FilterKind, keywords: Sequence[str]) -> KeywordFilter`: strips keywords, drops blank and repeated ones; raises `EmptyFilterError` if none is left, then `FeedNotSubscribedError` if no feed has `feed_url`.
  - `store.filters(conn: sqlite3.Connection, feed_url: str) -> list[KeywordFilter]`: oldest first; raises `FeedNotSubscribedError`.
  - `store.remove_filter(conn: sqlite3.Connection, filter_id: int) -> None`: raises `FilterNotFoundError`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest import mock

from feedwatch import filtering, store
from feedwatch.errors import EmptyFilterError, FeedNotSubscribedError, FilterNotFoundError
from feedwatch.models import KeywordFilter
```

Then add this class after `FilteringTest`, above `if __name__ == "__main__":`:

```python
class StoreFiltersTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def test_an_added_filter_is_listed_for_its_feed(self) -> None:
        added = store.add_filter(
            self.conn, "http://x/feed", kind="exclude", keywords=["ad", "sponsored"]
        )
        self.assertEqual(store.filters(self.conn, "http://x/feed"), [added])
        self.assertEqual(added.kind, "exclude")
        self.assertEqual(added.keywords, ("ad", "sponsored"))

    def test_a_filter_belongs_to_one_feed(self) -> None:
        store.add_feed(self.conn, "http://y/feed", "y")
        store.add_filter(self.conn, "http://x/feed", kind="include", keywords=["python"])
        self.assertEqual(store.filters(self.conn, "http://y/feed"), [])

    def test_a_filter_for_a_feed_that_is_not_subscribed_is_refused(self) -> None:
        with self.assertRaises(FeedNotSubscribedError) as caught:
            store.add_filter(
                self.conn, "http://nope/feed", kind="include", keywords=["python"]
            )
        self.assertIn("http://nope/feed", str(caught.exception))

    def test_listing_the_filters_of_a_feed_that_is_not_subscribed_is_refused(self) -> None:
        with self.assertRaises(FeedNotSubscribedError):
            store.filters(self.conn, "http://nope/feed")

    def test_a_filter_with_no_keywords_is_refused(self) -> None:
        for keywords in ([], [""], ["  ", ""]):
            with self.subTest(keywords=keywords), self.assertRaises(EmptyFilterError):
                store.add_filter(
                    self.conn, "http://x/feed", kind="include", keywords=keywords
                )
        self.assertEqual(store.filters(self.conn, "http://x/feed"), [])

    def test_blank_and_repeated_keywords_are_dropped(self) -> None:
        added = store.add_filter(
            self.conn, "http://x/feed", kind="include",
            keywords=[" python ", "", "python", "rust"],
        )
        self.assertEqual(added.keywords, ("python", "rust"))

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        added = store.add_filter(
            self.conn, "http://x/feed", kind="include", keywords=["python"]
        )
        store.remove_filter(self.conn, added.id)
        self.assertEqual(store.filters(self.conn, "http://x/feed"), [])

    def test_removing_a_filter_that_does_not_exist_is_refused(self) -> None:
        with self.assertRaises(FilterNotFoundError) as caught:
            store.remove_filter(self.conn, 99)
        self.assertIn("99", str(caught.exception))

    def test_a_database_created_before_filters_keeps_working(self) -> None:
        old_path = Path(self.dir.name) / "old.db"
        with mock.patch.object(store, "SCHEMA_STEPS", store.SCHEMA_STEPS[:2]):
            with closing(store.connect(old_path)) as old:
                store.add_feed(old, "http://x/feed", "x")
                store.save_entries(old, 1, [
                    {"guid": "a", "title": "First", "link": "http://x/a", "published": None},
                ])
        with closing(store.connect(old_path)) as upgraded:
            self.assertEqual([e.guid for e in store.unread(upgraded)], ["a"])
            store.add_filter(upgraded, "http://x/feed", kind="include", keywords=["x"])
            self.assertEqual(len(store.filters(upgraded, "http://x/feed")), 1)
```

The last test builds the database an older feedwatch would have built, by running only the two steps that version had.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -v`
Expected: `test_filters` errors with `ModuleNotFoundError: No module named 'feedwatch.errors'`.

- [ ] **Step 3: Write `feedwatch/errors.py`**

```python
"""The failures feedwatch raises. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class FeedNotSubscribedError(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"not subscribed to {url}")
        self.url = url


class EmptyFilterError(FeedwatchError):
    def __init__(self) -> None:
        super().__init__("a filter needs at least one keyword")


class FilterNotFoundError(FeedwatchError):
    def __init__(self, filter_id: int) -> None:
        super().__init__(f"no filter with id {filter_id}")
        self.filter_id = filter_id
```

- [ ] **Step 4: Add the filters table and functions to `feedwatch/store.py`**

Replace the imports (lines 3-7) with:

```python
import json
import sqlite3
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path

from feedwatch.errors import EmptyFilterError, FeedNotSubscribedError, FilterNotFoundError
from feedwatch.models import Entry, Feed, FilterKind, KeywordFilter
```

Append a third step to `SCHEMA_STEPS`, after the `entries` step and before the closing `]`. Do not edit the two existing steps:

```python
    """CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds(id),
        kind TEXT NOT NULL CHECK (kind IN ('include', 'exclude')),
        keywords TEXT NOT NULL
    )""",
```

`keywords` holds a JSON array, so a keyword containing a space survives the round trip.

Append to the end of the file:

```python
def add_filter(
    conn: sqlite3.Connection, feed_url: str, *, kind: FilterKind, keywords: Sequence[str]
) -> KeywordFilter:
    """Attach a keyword filter to a subscribed feed and return it.

    Blank and repeated keywords are dropped. Raises EmptyFilterError when none
    is left, and FeedNotSubscribedError when no feed has this URL.
    """
    words = tuple(dict.fromkeys(k.strip() for k in keywords if k.strip()))
    if not words:
        raise EmptyFilterError()
    feed_id = _feed_id(conn, feed_url)
    with conn:
        cursor = conn.execute(
            "INSERT INTO filters (feed_id, kind, keywords) VALUES (?, ?, ?)",
            (feed_id, kind, json.dumps(words)),
        )
    return KeywordFilter(cursor.lastrowid, feed_id, kind, words)


def filters(conn: sqlite3.Connection, feed_url: str) -> list[KeywordFilter]:
    """A feed's filters, oldest first. Raises FeedNotSubscribedError when no feed has this URL."""
    feed_id = _feed_id(conn, feed_url)
    rows = conn.execute(
        "SELECT id, kind, keywords FROM filters WHERE feed_id = ? ORDER BY id", (feed_id,)
    )
    return [
        KeywordFilter(filter_id, feed_id, kind, tuple(json.loads(keywords)))
        for filter_id, kind, keywords in rows
    ]


def remove_filter(conn: sqlite3.Connection, filter_id: int) -> None:
    """Delete a filter. Raises FilterNotFoundError when there is none with this id."""
    with conn:
        cursor = conn.execute("DELETE FROM filters WHERE id = ?", (filter_id,))
    if cursor.rowcount == 0:
        raise FilterNotFoundError(filter_id)


def _feed_id(conn: sqlite3.Connection, url: str) -> int:
    row = conn.execute("SELECT id FROM feeds WHERE url = ?", (url,)).fetchone()
    if row is None:
        raise FeedNotSubscribedError(url)
    return row[0]
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 21 tests, all OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/errors.py feedwatch/store.py tests/test_filters.py
git commit -m "feat: store keyword filters per feed"
```

---

### Task 3: The poller applies filters

**Files:**
- Modify: `feedwatch/poller.py:7` (import) and `feedwatch/poller.py:27` (the save)
- Modify: `tests/test_filters.py`

**Interfaces:**
- Consumes: `store.filters(conn, feed_url) -> list[KeywordFilter]` and `store.add_filter(...)` from Task 2; `filtering.keeps(title, filters) -> bool` from Task 1.
- Produces: no new names. `poller.poll_once(conn, last_polled, now)` keeps its signature; it now saves only the entries every one of the feed's filters keeps.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import filtering, poller, store
from feedwatch.errors import EmptyFilterError, FeedNotSubscribedError, FilterNotFoundError
from feedwatch.models import KeywordFilter
```

Then add after `StoreFiltersTest`, above `if __name__ == "__main__":`:

```python
def rss(*titles: str) -> bytes:
    items = "".join(
        f"<item><guid>{title}</guid><title>{title}</title><link>http://x/{title}</link></item>"
        for title in titles
    )
    return f"<rss><channel><title>t</title>{items}</channel></rss>".encode()


class PollerFiltersTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        self.feed_file = Path(self.dir.name) / "feed.xml"
        self.url = self.feed_file.as_uri()
        store.add_feed(self.conn, self.url, "x")

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def poll(self, *titles: str) -> list[str]:
        self.feed_file.write_bytes(rss(*titles))
        poller.poll_once(self.conn, {}, datetime(2026, 3, 2, 9, 0))
        return sorted(e.title for e in store.unread(self.conn))

    def test_a_feed_without_filters_stores_every_entry(self) -> None:
        self.assertEqual(self.poll("Python", "Rust"), ["Python", "Rust"])

    def test_an_include_filter_stores_only_matching_entries(self) -> None:
        store.add_filter(self.conn, self.url, kind="include", keywords=["python"])
        self.assertEqual(self.poll("Python news", "Rust news"), ["Python news"])

    def test_an_exclude_filter_never_stores_matching_entries(self) -> None:
        store.add_filter(self.conn, self.url, kind="exclude", keywords=["sponsored"])
        self.assertEqual(self.poll("Sponsored post", "Real post"), ["Real post"])

    def test_a_new_filter_applies_from_the_next_poll_and_spares_stored_entries(self) -> None:
        self.poll("Sponsored old")
        store.add_filter(self.conn, self.url, kind="exclude", keywords=["sponsored"])
        self.assertEqual(
            self.poll("Sponsored old", "Sponsored new", "Real new"),
            ["Real new", "Sponsored old"],
        )
```

The feed is a `file://` URL, which `fetch` downloads like any other, so the test exercises the real poll without mocking the network. Each `poll` passes a fresh `last_polled`, so the interval never skips the feed.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -v`
Expected: `test_an_include_filter_stores_only_matching_entries`, `test_an_exclude_filter_never_stores_matching_entries` and `test_a_new_filter_applies_from_the_next_poll_and_spares_stored_entries` FAIL with list mismatches (the filtered-out titles are present); `test_a_feed_without_filters_stores_every_entry` passes.

- [ ] **Step 3: Filter before saving in `feedwatch/poller.py`**

Change line 7 to:

```python
from feedwatch import fetch, filtering, parse, store
```

Replace line 27:

```python
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))
```

with:

```python
        feed_filters = store.filters(conn, feed.url)
        kept = [e for e in entries if filtering.keeps(e["title"], feed_filters)]
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, kept))
```

Filters are read on every poll, so one added while the poller runs applies from that feed's next poll. Only new entries pass through here, so stored entries are never re-filtered.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 25 tests, all OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_filters.py
git commit -m "feat: poller drops entries a feed's filters reject"
```

---

### Task 4: The `filter` command

**Files:**
- Modify: `feedwatch/cli.py` (whole file; it is 37 lines)
- Modify: `tests/test_filters.py`

**Interfaces:**
- Consumes: `store.add_filter`, `store.filters`, `store.remove_filter` and `FeedwatchError` from Task 2.
- Produces: `cli.main(argv: list[str] | None = None, db_path: Path = store.DEFAULT_PATH) -> int`. Output: `filter add` prints `added filter <id>`; `filter list` prints one line per filter, `<id>  <kind>  <keyword>, <keyword>`; `filter remove` prints nothing. A `FeedwatchError` prints its message to stderr and returns 1.

- [ ] **Step 1: Write the failing tests**

In `tests/test_filters.py`, replace the import block at the top with:

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
from unittest import mock

from feedwatch import cli, filtering, poller, store
from feedwatch.errors import EmptyFilterError, FeedNotSubscribedError, FilterNotFoundError
from feedwatch.models import KeywordFilter
```

Then add after `PollerFiltersTest`, above `if __name__ == "__main__":`:

```python
class CliFiltersTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.dir.name) / "feeds.db"
        self.run_cli("add", "http://x/feed")

    def tearDown(self) -> None:
        self.dir.cleanup()

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cli.main(list(argv), db_path=self.db_path)
        return code, out.getvalue(), err.getvalue()

    def test_an_added_filter_is_listed_with_its_id(self) -> None:
        self.assertEqual(
            self.run_cli("filter", "add", "http://x/feed", "--include", "python", "rust"),
            (0, "added filter 1\n", ""),
        )
        self.assertEqual(
            self.run_cli("filter", "list", "http://x/feed"),
            (0, "1  include  python, rust\n", ""),
        )

    def test_a_filter_for_a_feed_that_is_not_subscribed_names_the_url(self) -> None:
        code, _, err = self.run_cli("filter", "add", "http://nope/feed", "--exclude", "ad")
        self.assertEqual(code, 1)
        self.assertIn("http://nope/feed", err)

    def test_a_filter_with_only_blank_keywords_is_refused(self) -> None:
        code, _, err = self.run_cli("filter", "add", "http://x/feed", "--include", "", " ")
        self.assertEqual(code, 1)
        self.assertIn("at least one keyword", err)

    def test_a_filter_needs_include_or_exclude(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            self.run_cli("filter", "add", "http://x/feed")
        self.assertEqual(caught.exception.code, 2)

    def test_a_removed_filter_is_no_longer_listed(self) -> None:
        self.run_cli("filter", "add", "http://x/feed", "--exclude", "ad")
        self.assertEqual(self.run_cli("filter", "remove", "1"), (0, "", ""))
        self.assertEqual(self.run_cli("filter", "list", "http://x/feed"), (0, "", ""))

    def test_removing_an_unknown_filter_is_refused(self) -> None:
        self.assertEqual(
            self.run_cli("filter", "remove", "99"), (1, "", "no filter with id 99\n")
        )

    def test_listing_the_filters_of_a_feed_that_is_not_subscribed_is_refused(self) -> None:
        self.assertEqual(
            self.run_cli("filter", "list", "http://nope/feed"),
            (1, "", "not subscribed to http://nope/feed\n"),
        )
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -v`
Expected: every `CliFiltersTest` test errors in `setUp` with `TypeError: main() got an unexpected keyword argument 'db_path'`.

- [ ] **Step 3: Rewrite `feedwatch/cli.py`**

The existing `add`, `unread` and `read` commands behave as before; `read` moves from the final `else` to its own `elif` so `filter` can follow.

```python
"""feedwatch's command line: subscribe, filter, list unread entries, mark them read."""

import argparse
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError


def main(argv: list[str] | None = None, db_path: Path = store.DEFAULT_PATH) -> int:
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
    filter_parser = commands.add_parser("filter", help="manage a feed's keyword filters")
    filter_commands = filter_parser.add_subparsers(dest="filter_command", required=True)
    filter_add = filter_commands.add_parser("add", help="keep or drop entries by title keywords")
    filter_add.add_argument("url")
    words = filter_add.add_mutually_exclusive_group(required=True)
    words.add_argument("--include", nargs="+", metavar="WORD")
    words.add_argument("--exclude", nargs="+", metavar="WORD")
    filter_list = filter_commands.add_parser("list", help="list a feed's filters with their ids")
    filter_list.add_argument("url")
    filter_remove = filter_commands.add_parser("remove", help="remove a filter")
    filter_remove.add_argument("filter_id", type=int)
    args = parser.parse_args(argv)

    with closing(store.connect(db_path)) as conn:
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
            elif args.filter_command == "add":
                kind = "include" if args.include else "exclude"
                added = store.add_filter(
                    conn, args.url, kind=kind, keywords=args.include or args.exclude
                )
                print(f"added filter {added.id}")
            elif args.filter_command == "list":
                for keyword_filter in store.filters(conn, args.url):
                    keywords = ", ".join(keyword_filter.keywords)
                    print(f"{keyword_filter.id}  {keyword_filter.kind}  {keywords}")
            else:
                store.remove_filter(conn, args.filter_id)
        except FeedwatchError as exc:
            print(exc, file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the whole suite, with unclosed connections as errors**

Run: `python3 -W error::ResourceWarning -m unittest discover -s tests -v`
Expected: 32 tests, all OK.

- [ ] **Step 5: Check the added lines against `PROGRAM-DESIGN.md`**

`BASE` is the commit that added this plan, which comes before every task's commit. Run each and confirm the stated result:

- `BASE=$(git log --format=%H -1 -- docs/superpowers/plans/2026-10-12-keyword-filters.md)`
- `git diff $BASE -U0 -- feedwatch ':!feedwatch/store.py' | grep '^+' | grep -E 'sqlite3|conn\.'` prints nothing.
- `git diff $BASE -U0 -- feedwatch | grep '^+' | grep -E 'urllib|threading|asyncio|multiprocessing'` prints nothing.
- `grep -nE '^def [a-z]' feedwatch/filtering.py` prints exactly one function, `keeps`.
- `grep -n import feedwatch/errors.py feedwatch/filtering.py` shows no import from `feedwatch` except `feedwatch.models` in `filtering.py`.
- `git diff $BASE -- feedwatch/store.py` shows the first two `SCHEMA_STEPS` entries unchanged and the `filters` step appended after them.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_filters.py
git commit -m "feat: feedwatch filter add, list and remove"
```

- [ ] **Step 7: Record for the sweep**

Do not edit any living document. Add to the execution ledger: `ARCHITECTURE.md`'s "Where state lives" names the tables `feeds` and `entries`; the database now also has `filters`, owned by `store`. Then invoke `dopamine:finishing-work` before the workspace is cleaned up.
````


## p010

#### Final message

I wrote the implementation plan and committed it as `37b1a04` ("plan: keyword filters") on `master`, in `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-1`. Nothing has been implemented.

**Plan:** `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/plan/runs/P0-1/docs/superpowers/plans/2026-10-12-keyword-filters.md`

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



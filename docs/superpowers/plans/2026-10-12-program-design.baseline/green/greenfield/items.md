## p001

#### Final message

The feedwatch v1 implementation plan is written and committed on `master` as 7109cba (`docs/superpowers/plans/2026-10-12-feedwatch-v1.md`). Per the instructions, nothing is implemented in the repo.

**How the plan is laid out:** six test-first tasks, one per component in `docs/ARCHITECTURE.md`:
1. **parse** turns RSS XML into entries.
2. **fetch** downloads a feed. Its tests run against a local `http.server`, so they need no network.
3. **store** creates the database and handles subscriptions. Schema changes go through a numbered migration list, so an existing database keeps working.
4. **store** adds entries, lists unread ones and marks them read.
5. **poller** runs the polling loop.
6. **cli** adds `add`, `unread` and `read`, plus `pyproject.toml` and an end-to-end check against a locally served feed.

It uses only the standard library. Tests use `unittest`, because pytest isn't installed here and the design says dependencies have to earn their place.

**How it was checked:** I ran all the plan's code in a scratch directory. I then rebuilt the code from the plan's own text, applying Task 4's edits as written, and all 57 tests passed. The end-to-end run with both the CLI and the poller worked. To show the busy-timeout test really guards against "database is locked", I confirmed it fails with the timeout set to 0.

**Calls the plan makes where the spec says nothing.** These are listed in the plan, and any of them can be changed before execution:
- RSS means `<rss><channel>`. An RSS 1.0 (`rdf:RDF`) feed is treated as not RSS, logged and skipped.
- `read` is all or nothing. If any guid is unknown, it names every unknown one and marks nothing. A guid found in more than one feed is marked read in all of them.
- An entry with no date, or one that can't be read, is sorted by when it was first stored. An item with neither a guid nor a link is skipped.
- A failed poll still counts as a poll, so the feed waits for its next interval.
- `add` refuses URLs that aren't http or https. `--every` and `--limit` must be at least 1.
- `unread` prints one tab-separated line per entry: guid, local time, feed, title. Refusals exit with status 1; malformed arguments exit with status 2.
- The poller re-reads the feed list at least once a minute, so a feed added while it runs is picked up without a restart.

**XML safety:** a security hook suggested `defusedxml`. The plan keeps the standard XML parser and adds two tests showing it rejects entity-expansion bombs and external entities on this Python (expat 2.7.4). It tells the implementer to stop and report, rather than add a dependency, if those tests ever fail.

**Before executing:**
- `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` as living documents, but neither exists. I didn't create them.
- `python3 -m venv` fails on this machine because `ensurepip` is missing, so the plan's end-to-end step installs with `uv`.
- I didn't run the `finishing-work` sweep, because only a plan was written and no code changed. It belongs at the end of execution.

Plan complete and saved to `docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Please review the plan. Does it capture what you want?

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller (`python -m feedwatch.poller`) that stores new RSS entries in SQLite, and a `feedwatch` command line with `add`, `unread` and `read`.

**Architecture:** One Python package, `feedwatch`, with one module per component in `docs/ARCHITECTURE.md`: `fetch` (HTTP), `parse` (RSS XML to `Entry` values), `store` (the SQLite file and its schema), `poller` (the schedule loop) and `cli` (argparse commands). `poller` calls `fetch`, `parse` and `store`. `cli` calls only `store`. The two processes share `~/.feedwatch/feeds.db`, which runs in WAL mode with a busy timeout so that one process's write does not fail the other.

**Tech Stack:** Python 3.11+ standard library only (`urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`). Tests use `unittest`, run with `python3 -m unittest`. Packaging uses `pyproject.toml` with setuptools, which is needed only at build time.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Also read `docs/DESIGN.md` and `docs/ARCHITECTURE.md`; the spec builds on them.

## Global Constraints

- Standard library first. A runtime dependency has to earn its place, and v1 has none (`dependencies = []`).
- Component boundaries, from `docs/ARCHITECTURE.md`: **fetch** owns HTTP and never parses. **parse** owns the format and never stores. **store** owns the schema and never touches the network. **poller** owns the schedule and never presents anything. **cli** owns presentation and never polls. Only `poller` imports `feedwatch.fetch`. `store` may import `parse.Entry` for type hints only.
- The database is the single file `~/.feedwatch/feeds.db`, with tables `feeds` and `entries`. The schema changes only by appending to `store.MIGRATIONS`, and an existing database has to keep working.
- `feedwatch add URL [--title TITLE] [--every MINUTES]` uses an interval that "defaults to 30 minutes". If the URL is already subscribed, the command is refused "with a message naming the URL".
- `feedwatch unread [--limit N]` lists unread entries "newest first, 20 unless set otherwise".
- `feedwatch read GUID [GUID ...]`: "A guid that is not stored is refused, with a message naming it."
- "An entry is identified by its feed and its guid, or its link when it has no guid."
- "A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled." A database error stops the poller.
- Out of scope: Atom feeds; importing or exporting subscription lists.
- Every datetime inside the program is timezone-aware. The database stores UTC ISO 8601 text with seconds precision.

### Decisions this plan makes where the spec is silent

- **RSS means `<rss><channel>`.** That covers RSS 0.91, 0.92 and 2.0. An RSS 1.0 (`<rdf:RDF>`) document is treated as "not an RSS feed" and logged.
- **The display time is the entry's `pubDate`.** When an entry has no `pubDate`, or one that cannot be parsed, the time the poller first stored it is used. "Newest first" sorts on that time.
- **An item with neither a guid nor a link is skipped**, because nothing identifies it.
- **`read` is all or nothing.** If any guid is unknown, every unknown guid is named and nothing is marked. A guid that appears in several feeds is marked read in all of them.
- **`unread` prints one tab-separated line per entry**: `guid`, local time `YYYY-MM-DD HH:MM`, feed title (or the URL when untitled), entry title (or the link, or `(untitled)`). It prints nothing when there are no unread entries. `read` and `add` print nothing when they succeed.
- **Refusals exit with status 1** and print `feedwatch: <reason>` to stderr. Malformed arguments exit with status 2, using argparse's own message.
- **A failed poll counts as a poll.** Its `last_polled_at` is updated, and that is what "skipped until its next interval" means.

## Review Focus

These are the inputs the spec implies but does not spell out, most likely first. Each one has a test in the task that owns the code.

1. **A feed added with `feedwatch add` while the poller is already running** should be polled within a minute, without a restart. Both processes writing at once should not crash either of them with "database is locked". Tests: Task 3 `test_waits_for_another_writer_instead_of_failing`; Task 5 `test_sleep_is_capped_so_new_feeds_are_noticed`.
2. **The first run on a machine with no `~/.feedwatch/` directory** should create the directory, not fail. Test: Task 3 `test_creates_missing_directory`.
3. **Items without a guid and link, or with a missing or garbled `pubDate`**, should never crash the poller or lose the feed's other entries. Undated entries still sort sensibly. Tests: Task 1 `test_reads_items_in_document_order`; Task 4 `test_undated_entry_sorts_by_when_it_was_seen`.
4. **`feedwatch read` given a mix of known and unknown guids** should name every unknown guid and mark nothing, so the user can retry the whole command. Tests: Task 4 and Task 6 `test_unknown_guid_is_refused_naming_it_and_nothing_is_marked`.
5. **`feedwatch add example.com/feed.xml` (no scheme), or `--every 0` or `--limit 0`**, should be refused at the command line. Accepting them would leave a feed that fails every poll forever, or an empty listing. Tests: Task 6 `test_url_without_http_scheme_is_refused`, `test_interval_must_be_a_positive_whole_number`, `test_limit_must_be_a_positive_whole_number`.

## File Structure

```
pyproject.toml            package metadata, `feedwatch` console script (Task 6)
feedwatch/__init__.py     empty package marker (Task 1)
feedwatch/parse.py        Entry, ParseError, parse_feed (Task 1)
feedwatch/fetch.py        FetchError, fetch (Task 2)
feedwatch/store.py        Store, Feed, StoredEntry, errors, MIGRATIONS (Tasks 3, 4)
feedwatch/poller.py       poll_feed, poll_due, seconds_until_next, run, main (Task 5)
feedwatch/cli.py          main, format_entry (Task 6)
feedwatch/__main__.py     `python3 -m feedwatch` runs the CLI (Task 6)
tests/__init__.py         makes tests a package for unittest discovery (Task 1)
tests/test_parse.py       (Task 1)
tests/test_fetch.py       (Task 2)
tests/test_store.py       (Tasks 3, 4)
tests/test_poller.py      (Task 5)
tests/test_cli.py         (Task 6)
```

Run every command from the repository root. To run the whole suite: `python3 -m unittest -v`.

---

### Task 1: parse — RSS XML to entries

**Files:**
- Create: `feedwatch/__init__.py` (empty)
- Create: `tests/__init__.py` (empty)
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.parse.Entry`: a frozen dataclass `Entry(key: str, title: str | None, link: str | None, published_at: datetime | None)`. `key` is the guid, or the link when there is no guid. `published_at` is aware UTC.
  - `feedwatch.parse.ParseError(Exception)`.
  - `feedwatch.parse.parse_feed(xml: bytes) -> list[Entry]`. It raises `ParseError` when the document is not RSS.

- [ ] **Step 1: Create the empty package markers**

```bash
mkdir -p feedwatch tests
touch feedwatch/__init__.py tests/__init__.py
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import UTC, datetime

from feedwatch.parse import Entry, ParseError, parse_feed

FEED = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Example</title>
  <item><title>First</title><link>https://example.com/1</link>
        <guid>id-1</guid><pubDate>Sun, 01 Mar 2026 12:00:00 +0100</pubDate></item>
  <item><title>No guid</title><link>https://example.com/2</link></item>
  <item><title>Neither guid nor link</title></item>
  <item><title>Bad date</title><guid> id-3 </guid><pubDate>yesterday-ish</pubDate></item>
  <item><guid>id-4</guid><pubDate>Sun, 01 Mar 2026 12:00:00 -0000</pubDate></item>
</channel></rss>"""


class ParseFeedTest(unittest.TestCase):
    def test_reads_items_in_document_order(self):
        self.assertEqual(
            parse_feed(FEED),
            [
                Entry("id-1", "First", "https://example.com/1",
                      datetime(2026, 3, 1, 11, 0, tzinfo=UTC)),
                Entry("https://example.com/2", "No guid", "https://example.com/2", None),
                Entry("id-3", "Bad date", None, None),
                Entry("id-4", None, None, datetime(2026, 3, 1, 12, 0, tzinfo=UTC)),
            ],
        )

    def test_channel_without_items_is_empty(self):
        self.assertEqual(parse_feed(b"<rss><channel><title>t</title></channel></rss>"), [])

    def test_malformed_xml_is_refused(self):
        with self.assertRaises(ParseError):
            parse_feed(b"<rss><channel>")

    def test_html_page_is_refused(self):
        with self.assertRaises(ParseError):
            parse_feed(b"<html><body>Not found</body></html>")

    def test_atom_feed_is_refused(self):
        with self.assertRaises(ParseError):
            parse_feed(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>t</title></feed>')

    def test_rss_without_channel_is_refused(self):
        with self.assertRaises(ParseError):
            parse_feed(b"<rss version='2.0'/>")

    def test_empty_body_is_refused(self):
        with self.assertRaises(ParseError):
            parse_feed(b"")

    def test_entity_expansion_bomb_is_refused(self):
        entities = "".join(
            f'<!ENTITY {chr(98 + i)} "{("&" + chr(97 + i) + ";") * 10}">' for i in range(9)
        )
        bomb = (
            f'<?xml version="1.0"?><!DOCTYPE rss [<!ENTITY a "aaaaaaaaaa">{entities}]>'
            "<rss><channel><item><title>&j;</title><guid>x</guid></item></channel></rss>"
        ).encode()
        with self.assertRaises(ParseError):
            parse_feed(bomb)

    def test_external_entity_is_not_resolved(self):
        xxe = (
            b'<?xml version="1.0"?><!DOCTYPE rss [<!ENTITY x SYSTEM "file:///etc/passwd">]>'
            b"<rss><channel><item><title>&x;</title><guid>x</guid></item></channel></rss>"
        )
        with self.assertRaises(ParseError):
            parse_feed(xxe)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_parse -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.parse'`

- [ ] **Step 4: Write the implementation**

`feedwatch/parse.py`:

```python
"""Turn RSS feed XML into entries."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime


class ParseError(Exception):
    """The document is not well-formed XML, or not an RSS feed."""


@dataclass(frozen=True)
class Entry:
    """One item of a feed.

    ``key`` identifies the item within its feed: its guid, or its link when it
    has no guid. ``published_at`` is timezone-aware UTC, or None when the item
    has no readable pubDate.
    """

    key: str
    title: str | None
    link: str | None
    published_at: datetime | None


def parse_feed(xml: bytes) -> list[Entry]:
    """Return the items of an RSS feed in document order.

    Items with neither a guid nor a link are left out: nothing identifies them,
    so they could not be stored once. Raises ParseError when ``xml`` is not an
    RSS feed.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ParseError(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel") if root.tag == "rss" else None
    if channel is None:
        raise ParseError(f"not an RSS feed: root element is <{root.tag}>")
    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        key = _text(item, "guid") or link
        if key is None:
            continue
        entries.append(Entry(key, _text(item, "title"), link, _published(item)))
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    value = item.findtext(tag)
    if value is None:
        return None
    return value.strip() or None


def _published(item: ET.Element) -> datetime | None:
    raw = _text(item, "pubDate")
    if raw is None:
        return None
    try:
        parsed = parsedate_to_datetime(raw)
    except (TypeError, ValueError, IndexError):
        return None
    if parsed.tzinfo is None:
        # parsedate_to_datetime returns "-0000" (UTC, origin unknown) as naive.
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_parse -v`
Expected: `Ran 9 tests` … `OK`

`xml.etree.ElementTree` is safe for untrusted feeds here without `defusedxml`. Expat 2.4.1 and later refuses entity-amplification bombs, and ElementTree never fetches external entities. The last two tests pin both behaviours. If either fails, the Python build is linked against an old system expat: stop and report it, and do not add a dependency.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/__init__.py tests/__init__.py feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS feeds into entries"
```

---

### Task 2: fetch — download a feed

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.fetch.FetchError(Exception)`.
  - `feedwatch.fetch.fetch(url: str, timeout: float = 30.0) -> bytes`. It raises `FetchError` for a bad URL, a network error, a timeout or an HTTP error status. It never raises anything else for those cases.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py` serves pages from a local `http.server`, so the tests need no network:

```python
import socket
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from unittest import mock

from feedwatch.fetch import FetchError, fetch


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/feed.xml":
            body = b"<rss/>"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, *args):
        pass


class FetchTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), _Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        # A proxy configured in the environment must not intercept the local test server.
        patcher = mock.patch.dict("os.environ", {"no_proxy": "*", "NO_PROXY": "*"})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_returns_body(self):
        self.assertEqual(fetch(f"{self.base}/feed.xml"), b"<rss/>")

    def test_http_error_status_raises(self):
        with self.assertRaises(FetchError):
            fetch(f"{self.base}/missing")

    def test_refused_connection_raises(self):
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        with self.assertRaises(FetchError):
            fetch(f"http://127.0.0.1:{port}/feed.xml", timeout=2)

    def test_malformed_url_raises(self):
        with self.assertRaises(FetchError):
            fetch("not a url")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.fetch'`

- [ ] **Step 3: Write the implementation**

`feedwatch/fetch.py`:

```python
"""Download a feed's XML."""

from __future__ import annotations

import http.client
import urllib.error
import urllib.request

USER_AGENT = "feedwatch/0.1"


class FetchError(Exception):
    """The feed could not be downloaded."""


def fetch(url: str, timeout: float = 30.0) -> bytes:
    """Return the body served at ``url``.

    Raises FetchError for any failure to get a successful response: a bad URL,
    a network error, a timeout, or an HTTP error status.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        exc.close()
        raise FetchError(f"HTTP {exc.code} {exc.reason}") from exc
    except (OSError, ValueError, http.client.HTTPException) as exc:
        raise FetchError(str(exc)) from exc
```

`HTTPError` is caught first so that its response is closed. Otherwise Python 3.13+ emits a `ResourceWarning`. `ValueError` covers malformed URLs, which `Request` rejects. `http.client.HTTPException` covers truncated responses, which are not `OSError`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_fetch -v`
Expected: `Ran 4 tests` … `OK`, with no `ResourceWarning`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feed XML over HTTP"
```

---

### Task 3: store — database, schema migrations and feeds

**Files:**
- Create: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: nothing at runtime.
- Produces:
  - `DEFAULT_DB_PATH: Path` = `~/.feedwatch/feeds.db`; `DEFAULT_INTERVAL_MINUTES = 30`.
  - `MIGRATIONS: list[tuple[str, ...]]`. The schema version is `len(MIGRATIONS)`, recorded in `PRAGMA user_version`.
  - `DuplicateFeedError(Exception)`, with attribute `.url` and a message that contains the URL.
  - A frozen dataclass `Feed(id: int, url: str, title: str | None, interval_minutes: int, last_polled_at: datetime | None)`, with method `next_poll_at() -> datetime | None` (None means never polled, so due now).
  - `Store`:
    - `Store.open(path: Path = DEFAULT_DB_PATH) -> Store` (a classmethod).
    - `Store(conn: sqlite3.Connection)`.
    - `close()`. `Store` is also a context manager.
    - `add_feed(url: str, title: str | None = None, interval_minutes: int = 30) -> Feed`.
    - `feeds() -> list[Feed]`, ordered by id.
    - `due_feeds(now: datetime) -> list[Feed]`.
    - `mark_polled(feed_id: int, now: datetime) -> None`.

- [ ] **Step 1: Write the failing tests**

`tests/test_store.py`:

```python
import sqlite3
import tempfile
import threading
import unittest
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch.store import MIGRATIONS, DuplicateFeedError, Feed, Store

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class StoreTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / "feeds.db"
        self.store = Store.open(self.path)
        self.addCleanup(self.store.close)


class OpenTest(StoreTestCase):
    def test_creates_missing_directory(self):
        nested = self.path.parent / "not" / "yet" / "feeds.db"
        with Store.open(nested):
            pass
        self.assertTrue(nested.exists())

    def test_new_database_is_at_latest_schema_version(self):
        with closing(sqlite3.connect(self.path)) as conn:
            (version,) = conn.execute("PRAGMA user_version").fetchone()
        self.assertEqual(version, len(MIGRATIONS))

    def test_reopening_keeps_existing_data(self):
        self.store.add_feed("https://example.com/feed.xml")
        self.store.close()
        with Store.open(self.path) as reopened:
            self.assertEqual([f.url for f in reopened.feeds()], ["https://example.com/feed.xml"])

    def test_waits_for_another_writer_instead_of_failing(self):
        other = sqlite3.connect(self.path, check_same_thread=False)
        self.addCleanup(other.close)
        other.execute("BEGIN IMMEDIATE")
        release = threading.Timer(0.5, other.commit)
        release.start()
        self.store.add_feed("https://example.com/feed.xml")
        release.join()
        self.assertEqual(len(self.store.feeds()), 1)


class FeedsTest(StoreTestCase):
    def test_add_feed_defaults(self):
        feed = self.store.add_feed("https://example.com/feed.xml")
        self.assertEqual(feed, Feed(feed.id, "https://example.com/feed.xml", None, 30, None))
        self.assertEqual(self.store.feeds(), [feed])

    def test_add_feed_with_title_and_interval(self):
        feed = self.store.add_feed("https://example.com/feed.xml", "Example", 5)
        self.assertEqual((feed.title, feed.interval_minutes), ("Example", 5))

    def test_duplicate_url_is_refused_naming_it(self):
        self.store.add_feed("https://example.com/feed.xml")
        with self.assertRaises(DuplicateFeedError) as caught:
            self.store.add_feed("https://example.com/feed.xml", "Again")
        self.assertIn("https://example.com/feed.xml", str(caught.exception))
        self.assertEqual(len(self.store.feeds()), 1)

    def test_never_polled_feed_is_due(self):
        feed = self.store.add_feed("https://example.com/feed.xml")
        self.assertEqual(self.store.due_feeds(NOW), [feed])

    def test_feed_is_due_once_its_interval_is_up(self):
        feed = self.store.add_feed("https://example.com/feed.xml", interval_minutes=30)
        self.store.mark_polled(feed.id, NOW)
        self.assertEqual(self.store.due_feeds(NOW + timedelta(minutes=29)), [])
        self.assertEqual(
            [f.id for f in self.store.due_feeds(NOW + timedelta(minutes=30))], [feed.id]
        )

    def test_mark_polled_round_trips_the_time(self):
        feed = self.store.add_feed("https://example.com/feed.xml")
        self.store.mark_polled(feed.id, NOW)
        (stored,) = self.store.feeds()
        self.assertEqual(stored.last_polled_at, NOW)
        self.assertEqual(stored.next_poll_at(), NOW + timedelta(minutes=30))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.store'`

- [ ] **Step 3: Write the implementation**

`feedwatch/store.py`. The `entries` table is created now, in migration 1, together with `feeds`. Task 4 adds the methods that use it and does not change the schema.

```python
"""The SQLite database shared by the poller and the CLI."""

from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

DEFAULT_DB_PATH = Path.home() / ".feedwatch" / "feeds.db"
DEFAULT_INTERVAL_MINUTES = 30

# Migration N (1-based) takes the schema from version N-1 to N, recorded in
# PRAGMA user_version. Append only: an existing database has already run every
# migration up to its version, and has to keep working.
MIGRATIONS: list[tuple[str, ...]] = [
    (
        """CREATE TABLE feeds (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT,
            interval_minutes INTEGER NOT NULL,
            last_polled_at TEXT
        )""",
        """CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            feed_id INTEGER NOT NULL REFERENCES feeds (id),
            guid TEXT NOT NULL,
            title TEXT,
            link TEXT,
            sort_at TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            UNIQUE (feed_id, guid)
        )""",
        "CREATE INDEX entries_unread ON entries (read, sort_at)",
        "CREATE INDEX entries_guid ON entries (guid)",
    ),
]


class DuplicateFeedError(Exception):
    """The URL is already subscribed to."""

    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    interval_minutes: int
    last_polled_at: datetime | None

    def next_poll_at(self) -> datetime | None:
        """When this feed is next due; None if it has never been polled, which means now."""
        if self.last_polled_at is None:
            return None
        return self.last_polled_at + timedelta(minutes=self.interval_minutes)


class Store:
    """The feedwatch database. Every datetime passed in must be timezone-aware."""

    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    @classmethod
    def open(cls, path: Path = DEFAULT_DB_PATH) -> Store:
        """Open the database at ``path``, creating it and its directory if needed, and migrate it."""
        path.parent.mkdir(parents=True, exist_ok=True)
        # The poller and the CLI write to the same file: wait out the other's
        # write lock rather than fail with "database is locked".
        conn = sqlite3.connect(path, timeout=10)
        conn.execute("PRAGMA journal_mode = WAL")
        _migrate(conn)
        return cls(conn)

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> Store:
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()

    def add_feed(
        self, url: str, title: str | None = None, interval_minutes: int = DEFAULT_INTERVAL_MINUTES
    ) -> Feed:
        """Subscribe to ``url``. Raises DuplicateFeedError if it is already subscribed to."""
        try:
            with self._conn:
                cursor = self._conn.execute(
                    "INSERT INTO feeds (url, title, interval_minutes) VALUES (?, ?, ?)",
                    (url, title, interval_minutes),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateFeedError(url) from exc
        return Feed(cursor.lastrowid, url, title, interval_minutes, None)

    def feeds(self) -> list[Feed]:
        rows = self._conn.execute(
            "SELECT id, url, title, interval_minutes, last_polled_at FROM feeds ORDER BY id"
        ).fetchall()
        return [
            Feed(id_, url, title, interval, None if polled is None else _from_text(polled))
            for id_, url, title, interval, polled in rows
        ]

    def due_feeds(self, now: datetime) -> list[Feed]:
        """Feeds never polled, or whose interval has run out by ``now``."""
        return [
            feed for feed in self.feeds()
            if feed.next_poll_at() is None or feed.next_poll_at() <= now
        ]

    def mark_polled(self, feed_id: int, now: datetime) -> None:
        with self._conn:
            self._conn.execute(
                "UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(now), feed_id)
            )


def _migrate(conn: sqlite3.Connection) -> None:
    # IMMEDIATE takes the write lock before the version is read, so when the
    # poller and the CLI open a new database at once each migration runs once.
    conn.execute("BEGIN IMMEDIATE")
    try:
        (version,) = conn.execute("PRAGMA user_version").fetchone()
        for number, statements in enumerate(MIGRATIONS[version:], start=version + 1):
            for statement in statements:
                conn.execute(statement)
            conn.execute(f"PRAGMA user_version = {number}")
        conn.commit()
    except BaseException:
        conn.rollback()
        raise


def _to_text(moment: datetime) -> str:
    # One zone and one precision, so that ordering the text orders the times.
    return moment.astimezone(UTC).isoformat(timespec="seconds")


def _from_text(text: str) -> datetime:
    return datetime.fromisoformat(text)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_store -v`
Expected: `Ran 10 tests` … `OK`

- [ ] **Step 5: Check that the busy-timeout test proves something**

Temporarily change `timeout=10` to `timeout=0` in `Store.open`. Then run:
`python3 -m unittest tests.test_store.OpenTest.test_waits_for_another_writer_instead_of_failing`
Expected: ERROR `sqlite3.OperationalError: database is locked`. Restore `timeout=10` and rerun. Expected: OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: SQLite store with schema migrations and feed subscriptions"
```

---

### Task 4: store — entries: add, list unread, mark read

**Files:**
- Modify: `feedwatch/store.py`
- Modify: `tests/test_store.py`

**Interfaces:**
- Consumes: `feedwatch.parse.Entry` (Task 1), used only as a type hint, and the `Store` from Task 3.
- Produces:
  - `UnknownGuidError(Exception)`, with attribute `.guids: list[str]` (the unknown guids, in the order given) and a message that names each of them.
  - A frozen dataclass `StoredEntry(guid: str, feed: str, title: str | None, link: str | None, sort_at: datetime)`. `feed` is the feed's title, or its URL when untitled.
  - `Store.add_entries(feed_id: int, entries: Iterable[Entry], seen_at: datetime) -> int`, which returns the number of entries that were new.
  - `Store.unread(limit: int = 20) -> list[StoredEntry]`, newest first.
  - `Store.mark_read(guids: Sequence[str]) -> None`. It raises `UnknownGuidError` and marks nothing if any guid is unknown.

- [ ] **Step 1: Write the failing tests**

In `tests/test_store.py`, replace the `from feedwatch.store import ...` line with:

```python
from feedwatch.parse import Entry
from feedwatch.store import (
    MIGRATIONS,
    DuplicateFeedError,
    Feed,
    Store,
    UnknownGuidError,
)
```

and add this class above `if __name__ == "__main__":`:

```python
class EntriesTest(StoreTestCase):
    def setUp(self):
        super().setUp()
        self.feed = self.store.add_feed("https://example.com/feed.xml")

    def entry(self, key, hours_ago=None, title=None):
        published = None if hours_ago is None else NOW - timedelta(hours=hours_ago)
        return Entry(key, title or key, f"https://example.com/{key}", published)

    def test_add_entries_counts_only_new_ones(self):
        self.assertEqual(self.store.add_entries(self.feed.id, [self.entry("a"), self.entry("b")], NOW), 2)
        self.assertEqual(self.store.add_entries(self.feed.id, [self.entry("b"), self.entry("c")], NOW), 1)
        self.assertEqual(self.store.add_entries(self.feed.id, [], NOW), 0)
        self.assertEqual(len(self.store.unread()), 3)

    def test_same_guid_in_another_feed_is_another_entry(self):
        other = self.store.add_feed("https://example.org/feed.xml", "Other")
        self.store.add_entries(self.feed.id, [self.entry("a")], NOW)
        self.assertEqual(self.store.add_entries(other.id, [self.entry("a")], NOW), 1)

    def test_unread_is_newest_first_and_limited(self):
        self.store.add_entries(
            self.feed.id, [self.entry("old", 3), self.entry("new", 1), self.entry("mid", 2)], NOW
        )
        self.assertEqual([e.guid for e in self.store.unread()], ["new", "mid", "old"])
        self.assertEqual([e.guid for e in self.store.unread(limit=2)], ["new", "mid"])

    def test_undated_entry_sorts_by_when_it_was_seen(self):
        self.store.add_entries(self.feed.id, [self.entry("dated", 2)], NOW)
        self.store.add_entries(self.feed.id, [self.entry("undated")], NOW - timedelta(hours=1))
        (first, second) = self.store.unread()
        self.assertEqual((first.guid, first.sort_at), ("undated", NOW - timedelta(hours=1)))
        self.assertEqual(second.guid, "dated")

    def test_unread_names_the_feed_by_title_or_url(self):
        titled = self.store.add_feed("https://example.org/feed.xml", "Titled")
        self.store.add_entries(self.feed.id, [self.entry("a", 2)], NOW)
        self.store.add_entries(titled.id, [self.entry("b", 1)], NOW)
        self.assertEqual(
            [e.feed for e in self.store.unread()], ["Titled", "https://example.com/feed.xml"]
        )

    def test_mark_read_hides_entries_from_unread(self):
        self.store.add_entries(self.feed.id, [self.entry("a"), self.entry("b"), self.entry("c")], NOW)
        self.store.mark_read(["a", "c"])
        self.assertEqual([e.guid for e in self.store.unread()], ["b"])

    def test_mark_read_twice_is_harmless(self):
        self.store.add_entries(self.feed.id, [self.entry("a")], NOW)
        self.store.mark_read(["a"])
        self.store.mark_read(["a", "a"])
        self.assertEqual(self.store.unread(), [])

    def test_mark_read_marks_the_guid_in_every_feed(self):
        other = self.store.add_feed("https://example.org/feed.xml")
        self.store.add_entries(self.feed.id, [self.entry("a")], NOW)
        self.store.add_entries(other.id, [self.entry("a")], NOW)
        self.store.mark_read(["a"])
        self.assertEqual(self.store.unread(), [])

    def test_unknown_guid_is_refused_naming_it_and_nothing_is_marked(self):
        self.store.add_entries(self.feed.id, [self.entry("a")], NOW)
        with self.assertRaises(UnknownGuidError) as caught:
            self.store.mark_read(["a", "nope", "gone"])
        self.assertEqual(caught.exception.guids, ["nope", "gone"])
        self.assertIn("nope", str(caught.exception))
        self.assertIn("gone", str(caught.exception))
        self.assertEqual([e.guid for e in self.store.unread()], ["a"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store -v`
Expected: ERROR with `ImportError: cannot import name 'UnknownGuidError' from 'feedwatch.store'`

- [ ] **Step 3: Write the implementation**

In `feedwatch/store.py`, replace the import block with:

```python
import sqlite3
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from feedwatch.parse import Entry
```

Add after `DuplicateFeedError`:

```python
class UnknownGuidError(Exception):
    """No stored entry has one or more of the given guids."""

    def __init__(self, guids: Sequence[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = list(guids)
```

Add after the `Feed` dataclass:

```python
@dataclass(frozen=True)
class StoredEntry:
    """An entry as listed to the user; ``feed`` is the feed's title, or its URL when untitled."""

    guid: str
    feed: str
    title: str | None
    link: str | None
    sort_at: datetime
```

Add these methods to `Store`, after `mark_polled`:

```python
    def add_entries(self, feed_id: int, entries: Iterable[Entry], seen_at: datetime) -> int:
        """Store the entries not already stored for this feed; return how many were new.

        An entry without a publication time is sorted by ``seen_at`` instead.
        """
        rows = [
            (feed_id, entry.key, entry.title, entry.link, _to_text(entry.published_at or seen_at))
            for entry in entries
        ]
        if not rows:
            return 0
        with self._conn:
            cursor = self._conn.executemany(
                "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, sort_at)"
                " VALUES (?, ?, ?, ?, ?)",
                rows,
            )
        return cursor.rowcount

    def unread(self, limit: int = 20) -> list[StoredEntry]:
        """Up to ``limit`` unread entries, newest first."""
        rows = self._conn.execute(
            """SELECT e.guid, COALESCE(f.title, f.url), e.title, e.link, e.sort_at
               FROM entries e JOIN feeds f ON f.id = e.feed_id
               WHERE e.read = 0
               ORDER BY e.sort_at DESC, e.id DESC
               LIMIT ?""",
            (limit,),
        ).fetchall()
        return [
            StoredEntry(guid, feed, title, link, _from_text(sort_at))
            for guid, feed, title, link, sort_at in rows
        ]

    def mark_read(self, guids: Sequence[str]) -> None:
        """Mark every entry with one of ``guids`` read, in whichever feed it is.

        Raises UnknownGuidError, naming each guid that is not stored, and marks
        nothing, if any guid is unknown.
        """
        wanted = list(dict.fromkeys(guids))
        if not wanted:
            return
        marks = ", ".join("?" * len(wanted))
        with self._conn:
            known = {
                guid
                for (guid,) in self._conn.execute(
                    f"SELECT DISTINCT guid FROM entries WHERE guid IN ({marks})", wanted
                )
            }
            missing = [guid for guid in wanted if guid not in known]
            if missing:
                raise UnknownGuidError(missing)
            self._conn.execute(f"UPDATE entries SET read = 1 WHERE guid IN ({marks})", wanted)
```

The `UNIQUE (feed_id, guid)` constraint from migration 1, combined with `INSERT OR IGNORE`, is what stores each entry once. The `rowcount` of `executemany` counts only the rows actually inserted. The empty-list guard exists because `executemany` with no rows does not report a count.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_store -v`
Expected: `Ran 19 tests` … `OK`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 5: poller — the schedule loop

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch(url) -> bytes` and `FetchError` (Task 2); `parse_feed(xml) -> list[Entry]` and `ParseError` (Task 1); `Store.due_feeds`, `Store.feeds`, `Store.add_entries`, `Store.mark_polled`, `Feed.next_poll_at`, `Store.open` and `DEFAULT_DB_PATH` (Tasks 3–4).
- Produces:
  - `MAX_SLEEP_SECONDS = 60.0`.
  - `poll_feed(store: Store, feed: Feed, now: datetime, fetcher=fetch) -> None`.
  - `poll_due(store: Store, now: datetime, fetcher=fetch) -> None`.
  - `seconds_until_next(store: Store, now: datetime) -> float`.
  - `run(store, fetcher=fetch, clock=..., sleep=time.sleep) -> None`.
  - `main() -> None`, the entry point for `python -m feedwatch.poller`.
  - The logger is named `feedwatch.poller`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import sqlite3
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch.fetch import FetchError
from feedwatch.poller import MAX_SLEEP_SECONDS, poll_due, poll_feed, run, seconds_until_next
from feedwatch.store import Store

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)

GOOD = "https://good.example/feed.xml"
DOWN = "https://down.example/feed.xml"
HTML = "https://html.example/"

RSS = b"""<rss version="2.0"><channel><title>Good</title>
  <item><title>One</title><guid>one</guid><pubDate>Sun, 01 Mar 2026 10:00:00 +0000</pubDate></item>
  <item><title>Two</title><link>https://good.example/two</link></item>
</channel></rss>"""


def fake_fetch(url):
    if url == GOOD:
        return RSS
    if url == HTML:
        return b"<html><body>Moved</body></html>"
    raise FetchError(f"{url}: connection refused")


class _Stop(Exception):
    pass


class PollerTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.store = Store.open(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.store.close)


class PollTest(PollerTestCase):
    def test_stores_entries_of_a_due_feed(self):
        self.store.add_feed(GOOD)
        poll_due(self.store, NOW, fake_fetch)
        self.assertEqual(
            [e.guid for e in self.store.unread()], ["https://good.example/two", "one"]
        )

    def test_entries_are_stored_once_however_often_seen(self):
        self.store.add_feed(GOOD, interval_minutes=1)
        poll_due(self.store, NOW, fake_fetch)
        poll_due(self.store, NOW + timedelta(minutes=1), fake_fetch)
        self.assertEqual(len(self.store.unread()), 2)
        (stored,) = self.store.feeds()
        self.assertEqual(stored.last_polled_at, NOW + timedelta(minutes=1))

    def test_feed_not_yet_due_is_not_fetched(self):
        feed = self.store.add_feed(GOOD, interval_minutes=30)
        self.store.mark_polled(feed.id, NOW)
        fetched = []
        poll_due(self.store, NOW + timedelta(minutes=10), lambda url: fetched.append(url) or RSS)
        self.assertEqual(fetched, [])

    def test_failing_feeds_are_logged_and_skipped_and_others_still_polled(self):
        self.store.add_feed(DOWN)
        self.store.add_feed(HTML)
        self.store.add_feed(GOOD)
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poll_due(self.store, NOW, fake_fetch)
        self.assertEqual(len(self.store.unread()), 2)
        self.assertTrue(any(DOWN in line for line in logs.output))
        self.assertTrue(any(HTML in line for line in logs.output))
        # Failed feeds wait for their next interval like any other.
        self.assertEqual(self.store.due_feeds(NOW + timedelta(minutes=29)), [])

    def test_database_error_propagates(self):
        feed = self.store.add_feed(GOOD)

        class BrokenStore(Store):
            def add_entries(self, *args):
                raise sqlite3.OperationalError("disk I/O error")

        broken = BrokenStore(self.store._conn)
        with self.assertRaises(sqlite3.OperationalError):
            poll_feed(broken, feed, NOW, fake_fetch)


class ScheduleTest(PollerTestCase):
    def test_no_feeds_sleeps_the_maximum(self):
        self.assertEqual(seconds_until_next(self.store, NOW), MAX_SLEEP_SECONDS)

    def test_unpolled_feed_means_no_sleep(self):
        self.store.add_feed(GOOD)
        self.assertEqual(seconds_until_next(self.store, NOW), 0.0)

    def test_sleeps_until_the_earliest_due_feed(self):
        feed = self.store.add_feed(GOOD, interval_minutes=1)
        self.store.mark_polled(feed.id, NOW)
        self.assertEqual(seconds_until_next(self.store, NOW + timedelta(seconds=15)), 45.0)

    def test_sleep_is_capped_so_new_feeds_are_noticed(self):
        feed = self.store.add_feed(GOOD, interval_minutes=30)
        self.store.mark_polled(feed.id, NOW)
        self.assertEqual(seconds_until_next(self.store, NOW), MAX_SLEEP_SECONDS)

    def test_overdue_feed_means_no_sleep(self):
        feed = self.store.add_feed(GOOD, interval_minutes=1)
        self.store.mark_polled(feed.id, NOW)
        self.assertEqual(seconds_until_next(self.store, NOW + timedelta(hours=1)), 0.0)

    def test_run_polls_then_sleeps(self):
        self.store.add_feed(GOOD, interval_minutes=1)
        sleeps = []

        def sleep(seconds):
            sleeps.append(seconds)
            raise _Stop

        with self.assertRaises(_Stop):
            run(self.store, fake_fetch, clock=lambda: NOW, sleep=sleep)
        self.assertEqual(len(self.store.unread()), 2)
        self.assertEqual(sleeps, [60.0])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_poller -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.poller'`

- [ ] **Step 3: Write the implementation**

`feedwatch/poller.py`:

```python
"""The long-running worker: polls each feed when its interval is up.

Run with ``python -m feedwatch.poller``.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from datetime import UTC, datetime

from feedwatch.fetch import FetchError, fetch
from feedwatch.parse import ParseError, parse_feed
from feedwatch.store import DEFAULT_DB_PATH, Feed, Store

log = logging.getLogger(__name__)

# The poller re-reads the feed list every cycle, so this caps how long a feed
# added from the CLI waits before its first poll.
MAX_SLEEP_SECONDS = 60.0

Fetcher = Callable[[str], bytes]


def poll_feed(store: Store, feed: Feed, now: datetime, fetcher: Fetcher = fetch) -> None:
    """Fetch, parse and store one feed, then record it as polled at ``now``.

    A feed that cannot be fetched or parsed is logged and still recorded as
    polled, so it is skipped until its next interval. Database errors propagate.
    """
    try:
        entries = parse_feed(fetcher(feed.url))
    except (FetchError, ParseError) as exc:
        log.warning("skipping %s until its next interval: %s", feed.url, exc)
    else:
        added = store.add_entries(feed.id, entries, now)
        log.info("%s: %d new entries", feed.url, added)
    store.mark_polled(feed.id, now)


def poll_due(store: Store, now: datetime, fetcher: Fetcher = fetch) -> None:
    """Poll every feed that is due at ``now``."""
    for feed in store.due_feeds(now):
        poll_feed(store, feed, now, fetcher)


def seconds_until_next(store: Store, now: datetime) -> float:
    """Seconds until the next feed is due, between 0 and MAX_SLEEP_SECONDS."""
    wait = MAX_SLEEP_SECONDS
    for feed in store.feeds():
        due = feed.next_poll_at()
        if due is None:
            return 0.0
        wait = min(wait, (due - now).total_seconds())
    return max(wait, 0.0)


def run(
    store: Store,
    fetcher: Fetcher = fetch,
    clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Poll due feeds, sleep until the next is due, and repeat; never returns normally."""
    while True:
        poll_due(store, clock(), fetcher)
        sleep(seconds_until_next(store, clock()))


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with Store.open(DEFAULT_DB_PATH) as store:
        try:
            run(store)
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
```

`poll_feed` catches only `FetchError` and `ParseError`. Catching more would make a database error, which `docs/ARCHITECTURE.md` says must stop the poller, look like a skipped feed.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_poller -v`
Expected: `Ran 11 tests` … `OK`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller polls due feeds, skips failing ones, sleeps until the next"
```

---

### Task 6: cli — `feedwatch add | unread | read`, packaging, end-to-end check

**Files:**
- Create: `feedwatch/cli.py`
- Create: `feedwatch/__main__.py`
- Create: `pyproject.toml`
- Modify: `.gitignore`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `Store.open`, `add_feed`, `unread`, `mark_read`, `DuplicateFeedError`, `UnknownGuidError`, `StoredEntry`, `DEFAULT_DB_PATH` and `DEFAULT_INTERVAL_MINUTES` (Tasks 3–4).
- Produces:
  - `feedwatch.cli.main(argv: Sequence[str] | None = None, db_path: Path = DEFAULT_DB_PATH) -> int`.
  - `feedwatch.cli.format_entry(entry: StoredEntry) -> str`.
  - The `feedwatch` console script.
  - `python3 -m feedwatch`.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch.cli import main
from feedwatch.parse import Entry
from feedwatch.store import Store

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class CliTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.db_path = Path(tmp.name) / "feeds.db"

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                status = main(list(argv), db_path=self.db_path)
            except SystemExit as exc:
                status = exc.code
        return status, out.getvalue(), err.getvalue()

    def seed(self, count, title="Example"):
        with Store.open(self.db_path) as store:
            feed = store.add_feed("https://example.com/feed.xml", title)
            store.add_entries(
                feed.id,
                [
                    Entry(f"g{i}", f"Entry {i}", f"https://example.com/{i}",
                          NOW - timedelta(hours=count - i))
                    for i in range(count)
                ],
                NOW,
            )


class AddTest(CliTestCase):
    def test_add_with_defaults(self):
        self.assertEqual(self.run_cli("add", "https://example.com/feed.xml"), (0, "", ""))
        with Store.open(self.db_path) as store:
            (feed,) = store.feeds()
        self.assertEqual((feed.url, feed.title, feed.interval_minutes),
                         ("https://example.com/feed.xml", None, 30))

    def test_add_with_title_and_interval(self):
        self.run_cli("add", "https://example.com/feed.xml", "--title", "Ex", "--every", "5")
        with Store.open(self.db_path) as store:
            (feed,) = store.feeds()
        self.assertEqual((feed.title, feed.interval_minutes), ("Ex", 5))

    def test_duplicate_is_refused_naming_the_url(self):
        self.run_cli("add", "https://example.com/feed.xml")
        status, out, err = self.run_cli("add", "https://example.com/feed.xml")
        self.assertEqual(status, 1)
        self.assertIn("https://example.com/feed.xml", err)

    def test_url_without_http_scheme_is_refused(self):
        for url in ("example.com/feed.xml", "ftp://example.com/feed.xml", "https://"):
            status, out, err = self.run_cli("add", url)
            self.assertEqual(status, 2, url)
            self.assertIn(url, err)

    def test_interval_must_be_a_positive_whole_number(self):
        for every in ("0", "-5", "ten"):
            status, out, err = self.run_cli("add", "https://example.com/feed.xml", "--every", every)
            self.assertEqual(status, 2, every)
        with Store.open(self.db_path) as store:
            self.assertEqual(store.feeds(), [])


class UnreadTest(CliTestCase):
    def test_lists_newest_first_twenty_by_default(self):
        self.seed(25)
        status, out, err = self.run_cli("unread")
        lines = out.splitlines()
        self.assertEqual(status, 0)
        self.assertEqual(len(lines), 20)
        self.assertEqual(lines[0].split("\t")[0], "g24")
        self.assertEqual(lines[-1].split("\t")[0], "g5")

    def test_limit(self):
        self.seed(5)
        status, out, err = self.run_cli("unread", "--limit", "2")
        self.assertEqual([line.split("\t")[0] for line in out.splitlines()], ["g4", "g3"])

    def test_line_shows_guid_time_feed_and_title(self):
        self.seed(1)
        status, out, err = self.run_cli("unread")
        guid, when, feed, title = out.rstrip("\n").split("\t")
        expected = (NOW - timedelta(hours=1)).astimezone()
        self.assertEqual((guid, when, feed, title),
                         ("g0", f"{expected:%Y-%m-%d %H:%M}", "Example", "Entry 0"))

    def test_whitespace_in_titles_keeps_one_line_per_entry(self):
        with Store.open(self.db_path) as store:
            feed = store.add_feed("https://example.com/feed.xml", "Ex\tample")
            store.add_entries(feed.id, [Entry("g", "Two\nlines\tand tab", None, NOW)], NOW)
        status, out, err = self.run_cli("unread")
        self.assertEqual(out.count("\n"), 1)
        self.assertEqual(out.rstrip("\n").split("\t")[2:], ["Ex ample", "Two lines and tab"])

    def test_nothing_unread_prints_nothing(self):
        self.assertEqual(self.run_cli("unread"), (0, "", ""))

    def test_limit_must_be_a_positive_whole_number(self):
        self.assertEqual(self.run_cli("unread", "--limit", "0")[0], 2)


class ReadTest(CliTestCase):
    def test_marks_entries_read(self):
        self.seed(3)
        self.assertEqual(self.run_cli("read", "g0", "g2"), (0, "", ""))
        status, out, err = self.run_cli("unread")
        self.assertEqual([line.split("\t")[0] for line in out.splitlines()], ["g1"])

    def test_unknown_guid_is_refused_naming_it_and_nothing_is_marked(self):
        self.seed(2)
        status, out, err = self.run_cli("read", "g0", "missing")
        self.assertEqual(status, 1)
        self.assertIn("missing", err)
        status, out, err = self.run_cli("unread")
        self.assertEqual(len(out.splitlines()), 2)

    def test_needs_at_least_one_guid(self):
        self.assertEqual(self.run_cli("read")[0], 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_cli -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.cli'`

- [ ] **Step 3: Write the implementation**

`feedwatch/cli.py`:

```python
"""The user's commands: add, unread and read."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path
from urllib.parse import urlsplit

from feedwatch.store import (
    DEFAULT_DB_PATH,
    DEFAULT_INTERVAL_MINUTES,
    DuplicateFeedError,
    Store,
    StoredEntry,
    UnknownGuidError,
)

DEFAULT_UNREAD_LIMIT = 20


def main(argv: Sequence[str] | None = None, db_path: Path = DEFAULT_DB_PATH) -> int:
    """Run one command and return the process exit status.

    Malformed arguments exit with status 2 through argparse; a refused command
    returns 1 after printing why to stderr.
    """
    args = _parser().parse_args(argv)
    with Store.open(db_path) as store:
        try:
            if args.command == "add":
                store.add_feed(args.url, args.title, args.every)
            elif args.command == "unread":
                for entry in store.unread(args.limit):
                    print(format_entry(entry))
            else:
                store.mark_read(args.guids)
        except (DuplicateFeedError, UnknownGuidError) as exc:
            print(f"feedwatch: {exc}", file=sys.stderr)
            return 1
    return 0


def format_entry(entry: StoredEntry) -> str:
    """One tab-separated line: guid, local time, feed, title."""
    title = entry.title or entry.link or "(untitled)"
    fields = [entry.guid, f"{entry.sort_at.astimezone():%Y-%m-%d %H:%M}", entry.feed, title]
    # Feed text may hold tabs and newlines, which would break the one-line, tab-separated shape.
    return "\t".join(" ".join(field.split()) for field in fields)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="feedwatch", description="Subscribe to RSS feeds and read what they brought."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", type=_feed_url, metavar="URL")
    add.add_argument("--title")
    add.add_argument(
        "--every", type=_positive_int, default=DEFAULT_INTERVAL_MINUTES, metavar="MINUTES",
        help=f"poll interval in minutes (default {DEFAULT_INTERVAL_MINUTES})",
    )

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument(
        "--limit", type=_positive_int, default=DEFAULT_UNREAD_LIMIT, metavar="N",
        help=f"how many to list (default {DEFAULT_UNREAD_LIMIT})",
    )

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _positive_int(text: str) -> int:
    try:
        value = int(text)
    except ValueError:
        raise argparse.ArgumentTypeError(f"not a whole number: {text}") from None
    if value < 1:
        raise argparse.ArgumentTypeError(f"must be at least 1: {text}")
    return value


def _feed_url(text: str) -> str:
    parts = urlsplit(text)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise argparse.ArgumentTypeError(f"not an http or https URL: {text}")
    return text
```

`feedwatch/__main__.py`:

```python
import sys

from feedwatch.cli import main

sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_cli -v`
Expected: `Ran 14 tests` … `OK`

- [ ] **Step 5: Add packaging**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "0.1.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`packages` is listed explicitly. Without it, setuptools' flat-layout discovery also finds `tests/` and refuses to build.

Append to `.gitignore`:

```
*.egg-info/
.venv/
```

- [ ] **Step 6: Run the full suite**

Run: `python3 -W error::ResourceWarning -m unittest -v`
Expected: `Ran 57 tests` … `OK`

- [ ] **Step 7: End-to-end check against a local feed**

Install into a throwaway venv. If `python3 -m venv` fails because `ensurepip` is missing, use `uv`:

```bash
python3 -m venv --without-pip .venv && uv pip install -q --python .venv/bin/python -e .
```

Serve a feed locally, then drive both processes with a throwaway `HOME`:

```bash
export HOME=$(mktemp -d)
mkdir -p /tmp/fw-serve && cat > /tmp/fw-serve/feed.xml <<'EOF'
<?xml version="1.0"?>
<rss version="2.0"><channel><title>Local</title>
<item><title>Hello</title><guid>hello-1</guid><pubDate>Sun, 01 Mar 2026 10:00:00 +0000</pubDate></item>
<item><title>World</title><link>http://127.0.0.1:8765/world</link></item>
</channel></rss>
EOF
(cd /tmp/fw-serve && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
.venv/bin/feedwatch add http://127.0.0.1:8765/feed.xml --title Local --every 1
.venv/bin/feedwatch add http://127.0.0.1:8765/missing.xml
.venv/bin/feedwatch add http://127.0.0.1:8765/feed.xml; echo "exit $?"
no_proxy='*' timeout 3 .venv/bin/python -m feedwatch.poller
.venv/bin/feedwatch unread
.venv/bin/feedwatch read hello-1 nope; echo "exit $?"
.venv/bin/feedwatch read hello-1 && .venv/bin/feedwatch unread
pkill -f "http.server 8765"
```

Expected:
- The third `add` prints `feedwatch: already subscribed to http://127.0.0.1:8765/feed.xml` and `exit 1`.
- The poller logs `INFO http://127.0.0.1:8765/feed.xml: 2 new entries`, then `WARNING skipping http://127.0.0.1:8765/missing.xml until its next interval: HTTP 404 File not found`. It keeps running until `timeout` stops it.
- `unread` prints the `World` line, then `hello-1	2026-03-01 …	Local	Hello`.
- `read hello-1 nope` prints `feedwatch: no stored entry with guid nope` and `exit 1`.
- The final `unread` shows only `World`.

- [ ] **Step 8: Commit**

```bash
git add feedwatch/cli.py feedwatch/__main__.py pyproject.toml .gitignore tests/test_cli.py
git commit -m "feat: feedwatch command line: add, unread, read"
```
````


## p002

#### Final message

I wrote the feedwatch v1 implementation plan and committed it as `8219097` on `master` in `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/greenfield/runs/F0-1`. Nothing was implemented in the repo. To check the plan's code, I rebuilt it task by task from the plan's own code blocks in a temporary directory, which I then deleted. Every task's tests pass at the counts the plan states, 63 in total. An end-to-end run against a local HTTP server also worked: add, duplicate refusal, poller storing one feed while skipping a 404, unread, read, and unknown-guid refusal.

Plan: `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/greenfield/runs/F0-1/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

**How it's built:**
- **Tech:** Python 3.11+ using only the standard library, tested with `unittest`. This follows DESIGN's "standard library first".
- **Layout:** one module per component in ARCHITECTURE: fetch, parse, store, poller, cli.
- **Six tasks, bottom-up:**
  1. Package skeleton and RSS parser
  2. Fetch with a 30 s timeout
  3. Store: schema, append-only migrations, WAL, feeds
  4. Store: entries, unread, read
  5. Poller (`python -m feedwatch.poller`)
  6. CLI plus the end-to-end check
- **Closing step:** invoke `dopamine:finishing-work`.

**Choices the spec left open**, listed in the plan for you to confirm:
- `read` is all-or-nothing. If any guid is unknown, nothing is marked and every unknown guid is named.
- Guids are unique only within a feed, so `read GUID` marks every entry with that guid, across feeds.
- Entries with no date, or an unparseable one, sort by when they were fetched. `unread` shows dates in UTC.
- Exit status is 1 when a command is refused and 2 for a usage error.
- The poller wakes every 60 s. A failed poll counts as a poll, so the feed waits for its next interval.
- A feed's title comes only from `--title`; the channel's own title is not read.
- `add` refuses an interval below 1 minute and any URL that isn't http(s).

**Review Focus**, each with a test in the task that owns it:
1. A feed server that connects but never answers.
2. The CLI running while the poller writes, which must never fail with "database is locked".
3. Missing, malformed or non-UTC `pubDate`.
4. An empty `<guid/>`, or an item with neither guid nor link.
5. A zero or negative `--every`, or a URL that isn't http(s).

**Other things to know:**
- `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` as living documents, but neither file exists. The plan does not touch them and leaves them to the finishing sweep.
- One of my early check runs wrote an empty `~/.feedwatch/feeds.db` into the real home directory. I confirmed it had no feeds or entries, that it was created at the moment of that run, and that its schema was the plan's. Then I deleted it. Because of this, the plan's end-to-end step now requires pointing `HOME` at a temporary directory and using a free port.

Plan complete and saved to `docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Please review the plan.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in one SQLite file, and a `feedwatch` command to subscribe to feeds, list unread entries and mark them read.

**Architecture:** One Python package, `feedwatch`, with one module per component in `docs/ARCHITECTURE.md`: `fetch` (HTTP), `parse` (RSS XML to entries), `store` (SQLite schema and queries), `poller` (the long-running schedule, `python -m feedwatch.poller`) and `cli` (the `feedwatch` command). The tasks build them bottom-up, so each task's tests run against real neighbours instead of mocks. The one exception is the poller's tests, which inject a fake `fetch` so they never touch the network.

**Tech Stack:** Python 3.11+, standard library only: `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`, and `unittest` for tests. setuptools is needed only at install time, to provide the `feedwatch` console script.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Read it with `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, which it builds on.

## Global Constraints

- No runtime dependencies (`dependencies = []`). DESIGN: "Standard library first; a dependency has to earn its place."
- `requires-python = ">=3.11"`.
- Commands, verbatim from the spec: `feedwatch add URL [--title TITLE] [--every MINUTES]`, `feedwatch unread [--limit N]`, `feedwatch read GUID [GUID ...]`, `python -m feedwatch.poller`.
- Defaults: poll interval 30 minutes; `unread` lists 20.
- An entry is identified by its feed and its guid, or by its link when it has no guid.
- Database: one SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`, owned by `store`. "An existing database has to keep working": migrations are only ever appended, never edited.
- Module boundaries (ARCHITECTURE): `fetch` never parses; `parse` never stores; `store` never touches the network; `poller` never presents anything; `cli` never polls. `poller` calls `fetch`, `parse` and `store`; `cli` calls only `store`; only `poller` calls `fetch`.
- Failure handling (ARCHITECTURE): a feed that cannot be fetched or parsed is logged and skipped until its next interval while the other feeds are still polled. A database error stops the poller.
- Out of scope: Atom feeds; importing or exporting subscription lists.
- Tests use `unittest` and run from the repository root with `python3 -m unittest`. No test touches the real `~/.feedwatch`: every test passes its own temporary database path.
- Do not edit the living documents listed in `.dopamine/config` (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/PROGRAM-DESIGN.md`, `docs/ROADMAP.md`) during execution. Record what they would need in the ledger; the closing sweep places it.

## Decisions the spec leaves open

These choices are made here so that no implementer has to guess. Reviewers should check them against what the human wants.

- `feedwatch read a b nope` marks nothing and names every unknown guid (`nope`). The command is all-or-nothing.
- Guids are unique only within a feed, so `read GUID` marks every stored entry with that guid, whichever feed it came from.
- "Newest first" sorts by the entry's `pubDate`. An entry with no `pubDate`, or one that cannot be parsed, sorts by the time it was fetched. All times are stored in UTC.
- `unread` prints dates in UTC (`2026-03-01 09:30 UTC`), followed by the feed's title (its URL when it has no title), the entry title (`(untitled)` when it has none), and the guid indented on the next line, ready to paste into `read`.
- Exit status: 0 on success, 1 when a command is refused (duplicate URL, unknown guid), 2 for a usage error (argparse).
- The poller wakes every 60 seconds and polls the feeds that are due. A failed poll still counts as a poll, so the feed waits for its next interval.
- A feed's title comes only from `--title`. The channel's own `<title>` is not read.

## Review Focus

The five inputs the spec is silent on that are most likely to bite someone, most likely first. Each has a test in the task that owns it.

1. **A feed server that accepts the connection and never answers.** Expected: the fetch gives up after 30 seconds, the feed is logged and skipped, and the other feeds are still polled. A stalled poller is a silent outage. Test: `test_a_server_that_never_answers_times_out` (Task 2).
2. **Running `feedwatch unread` or `feedwatch add` while the poller is writing.** Expected: the command reads, or waits briefly to write, and never fails with "database is locked". The two processes share one file all day. Tests: `test_uses_write_ahead_logging`, `test_a_reader_is_not_blocked_by_a_writer`, `test_a_writer_waits_for_another_writer` (Task 3).
3. **A missing or malformed `pubDate`, or one in a non-UTC offset.** Expected: the entry is still stored and sorted by the actual instant, and an undated entry sorts by its fetch time. Tests: `test_a_missing_or_unparseable_date_is_none`, `test_dates_are_normalised_to_utc`, `test_a_minus_zero_zone_is_utc` (Task 1); `test_an_undated_entry_sorts_by_when_it_was_fetched`, `test_dates_in_other_zones_sort_by_the_instant` (Task 4).
4. **An empty `<guid/>`, or an item with neither a guid nor a link.** Expected: an empty guid falls back to the link, and an item with no identity at all is skipped with a warning while the rest of the feed is stored. Tests: `test_an_empty_guid_counts_as_absent`, `test_an_item_with_neither_guid_nor_link_is_skipped` (Task 1).
5. **`--every 0`, a negative interval, or a URL that is not http(s), such as `example.com/feed.xml`.** Expected: `add` refuses it with a message naming the bad value. Otherwise the poller would re-fetch the feed every minute, or log a fetch error for it forever. Tests: `test_add_refuses_an_interval_below_one_minute`, `test_add_refuses_a_url_that_is_not_http`, `test_unread_refuses_a_limit_below_one` (Task 6).

---

## File Structure

```
pyproject.toml              package metadata, `feedwatch` console script (Task 1, edited in Task 6)
.gitignore                  add .venv/ and *.egg-info/ (Task 1)
feedwatch/__init__.py       empty package marker (Task 1)
feedwatch/parse.py          RSS XML -> ParsedEntry list; ParseError (Task 1)
feedwatch/fetch.py          URL -> bytes; FetchError (Task 2)
feedwatch/store.py          open_store, Store, schema migrations, Feed, StoredEntry, errors (Tasks 3-4)
feedwatch/poller.py         poll_once, run, main; `python -m feedwatch.poller` (Task 5)
feedwatch/cli.py            argparse commands add / unread / read; main (Task 6)
tests/__init__.py           empty, so `python3 -m unittest` discovers tests/ (Task 1)
tests/test_parse.py         (Task 1)
tests/test_fetch.py         (Task 2)
tests/test_store.py         opening, migrations, concurrency, feeds (Task 3)
tests/test_store_entries.py entries, unread, mark_read (Task 4)
tests/test_poller.py        (Task 5)
tests/test_cli.py           (Task 6)
```

---

### Task 1: Package skeleton and the RSS parser

**Files:**
- Create: `pyproject.toml`
- Modify: `.gitignore`
- Create: `feedwatch/__init__.py` (empty)
- Create: `tests/__init__.py` (empty)
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ParseError(Exception)`
  - `@dataclass(frozen=True) class ParsedEntry: guid: str | None; link: str | None; title: str | None; published: datetime | None` (field order matters: tests construct it positionally). `published` is always timezone-aware UTC, or `None`.
  - `ParsedEntry.identity -> str | None` (property): `guid or link`
  - `parse_feed(xml: bytes) -> list[ParsedEntry]`: never returns an entry whose `identity` is `None`.

- [ ] **Step 1: Create the package skeleton**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "0.1.0"
description = "Poll RSS feeds into a local SQLite database and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[tool.setuptools]
packages = ["feedwatch"]
```

Append to `.gitignore` (it already holds `__pycache__/`):

```
.venv/
*.egg-info/
```

Create the empty files `feedwatch/__init__.py` and `tests/__init__.py`.

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.parse import ParsedEntry, ParseError, parse_feed


def rss(items: str) -> bytes:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f"<rss version=\"2.0\"><channel><title>Example</title>{items}</channel></rss>"
    ).encode()


class ParseFeedTest(unittest.TestCase):
    def test_reads_guid_link_title_and_date(self):
        entries = parse_feed(rss(
            "<item><guid>g1</guid><link>https://example.com/1</link>"
            "<title>First</title><pubDate>Sun, 01 Mar 2026 09:30:00 +0000</pubDate></item>"
        ))
        self.assertEqual(entries, [ParsedEntry(
            guid="g1",
            link="https://example.com/1",
            title="First",
            published=datetime(2026, 3, 1, 9, 30, tzinfo=timezone.utc),
        )])

    def test_identity_is_the_guid(self):
        [entry] = parse_feed(rss("<item><guid>g1</guid><link>https://example.com/1</link></item>"))
        self.assertEqual(entry.identity, "g1")

    def test_identity_falls_back_to_the_link(self):
        [entry] = parse_feed(rss("<item><link>https://example.com/1</link></item>"))
        self.assertEqual(entry.identity, "https://example.com/1")

    def test_an_empty_guid_counts_as_absent(self):
        [entry] = parse_feed(rss("<item><guid>  </guid><link>https://example.com/1</link></item>"))
        self.assertEqual(entry.identity, "https://example.com/1")

    def test_an_item_with_neither_guid_nor_link_is_skipped(self):
        with self.assertLogs("feedwatch.parse", level="WARNING"):
            entries = parse_feed(rss(
                "<item><title>Orphan</title></item>"
                "<item><guid>g2</guid></item>"
            ))
        self.assertEqual([e.identity for e in entries], ["g2"])

    def test_a_missing_or_unparseable_date_is_none(self):
        entries = parse_feed(rss(
            "<item><guid>a</guid></item>"
            "<item><guid>b</guid><pubDate>yesterday-ish</pubDate></item>"
        ))
        self.assertEqual([e.published for e in entries], [None, None])

    def test_dates_are_normalised_to_utc(self):
        [entry] = parse_feed(rss(
            "<item><guid>a</guid><pubDate>Sun, 01 Mar 2026 10:30:00 +0100</pubDate></item>"
        ))
        self.assertEqual(entry.published, datetime(2026, 3, 1, 9, 30, tzinfo=timezone.utc))

    def test_a_minus_zero_zone_is_utc(self):
        [entry] = parse_feed(rss(
            "<item><guid>a</guid><pubDate>Sun, 01 Mar 2026 09:30:00 -0000</pubDate></item>"
        ))
        self.assertEqual(entry.published, datetime(2026, 3, 1, 9, 30, tzinfo=timezone.utc))

    def test_malformed_xml_is_a_parse_error(self):
        with self.assertRaises(ParseError):
            parse_feed(b"<rss><channel>")

    def test_an_html_page_is_a_parse_error(self):
        with self.assertRaises(ParseError):
            parse_feed(b"<html><body><p>Not a feed</p></body></html>")

    def test_an_atom_feed_is_a_parse_error(self):
        with self.assertRaises(ParseError):
            parse_feed(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>')

    def test_an_empty_body_is_a_parse_error(self):
        with self.assertRaises(ParseError):
            parse_feed(b"")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_parse -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.parse'`

- [ ] **Step 4: Write the implementation**

`feedwatch/parse.py`:

```python
"""Turns RSS 2.0 XML into entries."""

import logging
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

log = logging.getLogger(__name__)


class ParseError(Exception):
    """The document is not well-formed XML, or is not an RSS feed."""


@dataclass(frozen=True)
class ParsedEntry:
    guid: str | None
    link: str | None
    title: str | None
    published: datetime | None

    @property
    def identity(self) -> str | None:
        """The entry's identity within its feed: its guid, or its link when it has no guid."""
        return self.guid or self.link


def parse_feed(xml: bytes) -> list[ParsedEntry]:
    """Return the feed's entries in document order.

    Raises ParseError if `xml` is not well-formed, or its root is not an
    <rss> element with a <channel>. Items with neither a guid nor a link
    are skipped with a warning.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ParseError(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel") if root.tag == "rss" else None
    if channel is None:
        raise ParseError(f"not an RSS feed: root element is <{root.tag}>")
    entries = []
    for item in channel.findall("item"):
        entry = ParsedEntry(
            guid=_text(item, "guid"),
            link=_text(item, "link"),
            title=_text(item, "title"),
            published=_date(_text(item, "pubDate")),
        )
        if entry.identity is None:
            log.warning("skipping an item with neither guid nor link: %r", entry.title)
            continue
        entries.append(entry)
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    # Feeds in the wild emit empty <guid/> and <link/>; those must fall through to the next identity.
    text = item.findtext(tag)
    if text is None:
        return None
    return text.strip() or None


def _date(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        parsed = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        # RFC 2822's "-0000" zone means UTC; parsedate_to_datetime returns it naive.
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_parse -v`
Expected: 12 tests, OK

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml .gitignore feedwatch/__init__.py feedwatch/parse.py tests/__init__.py tests/test_parse.py
git commit -m "feat: parse RSS feeds into entries"
```

---

### Task 2: Fetching a feed

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class FetchError(Exception)`
  - `DEFAULT_TIMEOUT = 30.0`
  - `fetch_feed(url: str, timeout: float = DEFAULT_TIMEOUT) -> bytes`: raises only `FetchError`, for any network, HTTP-status, URL or timeout failure.

The tests run a real `http.server` on an ephemeral port in a background thread. Do not use a fixed port: other processes on the machine may be using it.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import socket
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from feedwatch.fetch import FetchError, fetch_feed

FEED = b"<rss><channel></channel></rss>"


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/feed":
            self.send_response(200)
            self.send_header("Content-Type", "application/rss+xml")
            self.send_header("Content-Length", str(len(FEED)))
            self.end_headers()
            self.wfile.write(FEED)
        elif self.path == "/hang":
            self.server.release.wait(5)
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        pass


class FetchFeedTest(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        self.server.release = threading.Event()
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def tearDown(self):
        self.server.release.set()
        self.server.shutdown()
        self.server.server_close()

    def test_returns_the_body(self):
        self.assertEqual(fetch_feed(f"{self.base}/feed"), FEED)

    def test_an_http_error_status_is_a_fetch_error(self):
        with self.assertRaisesRegex(FetchError, "HTTP 404"):
            fetch_feed(f"{self.base}/missing")

    def test_a_refused_connection_is_a_fetch_error(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        with self.assertRaises(FetchError):
            fetch_feed(f"http://127.0.0.1:{port}/feed")

    def test_a_server_that_never_answers_times_out(self):
        with self.assertRaises(FetchError):
            fetch_feed(f"{self.base}/hang", timeout=0.5)

    def test_a_url_without_a_scheme_is_a_fetch_error(self):
        with self.assertRaises(FetchError):
            fetch_feed("example.com/feed.xml")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.fetch'`

- [ ] **Step 3: Write the implementation**

`feedwatch/fetch.py`:

```python
"""Downloads a feed's XML."""

import http.client
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 30.0
USER_AGENT = "feedwatch/0.1"


class FetchError(Exception):
    """The feed could not be downloaded."""


def fetch_feed(url: str, timeout: float = DEFAULT_TIMEOUT) -> bytes:
    """Return the body served at `url`.

    Raises FetchError on a network failure, a non-2xx status, a URL urllib
    cannot open, or a server that sends nothing for `timeout` seconds.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        exc.close()
        raise FetchError(f"{url}: HTTP {exc.code}") from exc
    except (OSError, http.client.HTTPException, ValueError) as exc:
        raise FetchError(f"{url}: {exc}") from exc
```

`Request(...)` must be inside the `try`, because it raises `ValueError` for a URL with no scheme. `exc.close()` releases the error response's body; without it, a `ResourceWarning` is printed.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_fetch -v`
Expected: 5 tests, OK (a few seconds; the timeout test waits 0.5 s)

- [ ] **Step 5: Commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch a feed over HTTP with a timeout"
```

---

### Task 3: The store: schema, migrations and feeds

**Files:**
- Create: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `DEFAULT_INTERVAL_MINUTES = 30`
  - `default_db_path() -> Path`: `~/.feedwatch/feeds.db`
  - `open_store(path: Path | None = None) -> Store`: creates the directory and the schema; `None` means `default_db_path()`.
  - `class DuplicateFeedError(Exception)` with `.url: str`; `str(exc) == "already subscribed to <url>"`
  - `@dataclass(frozen=True) class Feed: id: int; url: str; title: str | None; interval_minutes: int; last_polled_at: datetime | None`
  - `Store.add_feed(url: str, title: str | None = None, interval_minutes: int = 30) -> Feed`
  - `Store.due_feeds(now: datetime) -> list[Feed]`, ordered by id
  - `Store.mark_polled(feed_id: int, now: datetime) -> None`
  - `Store.close() -> None`; `Store` is a context manager that closes on exit.
  - Every `datetime` passed in or returned is timezone-aware.

Schema notes:
- Both tables are created by migration 1, because ARCHITECTURE names both. `entries.guid` holds the entry's identity, which is its guid or else its link, and `UNIQUE (feed_id, guid)` enforces "store each entry once".
- `PRAGMA user_version` counts the migrations a database has had. Migrations run inside `BEGIN IMMEDIATE`, so a poller and a CLI opening a brand-new database at the same moment cannot both create the tables.
- Times are stored as `datetime.isoformat(timespec="seconds")` in UTC (`2026-03-01T09:30:00+00:00`), so that text order is time order.
- WAL journal mode and a 5-second busy timeout let the CLI work while the poller writes (Review Focus 2).

- [ ] **Step 1: Write the failing tests**

`tests/test_store.py`:

```python
import sqlite3
import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.store import DuplicateFeedError, open_store

T0 = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


class StoreTestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name) / "feeds.db"
        self.store = open_store(self.path)

    def tearDown(self):
        self.store.close()
        self._tmp.cleanup()


class OpenStoreTest(StoreTestCase):
    def test_creates_the_directory_and_the_schema(self):
        nested = Path(self._tmp.name) / "a" / "b" / "feeds.db"
        with open_store(nested) as store:
            store.add_feed("https://example.com/feed")
        self.assertTrue(nested.exists())

    def test_reopening_keeps_the_data_and_runs_no_migration_twice(self):
        self.store.add_feed("https://example.com/feed")
        self.store.close()
        self.store = open_store(self.path)
        self.assertEqual([f.url for f in self.store.due_feeds(T0)], ["https://example.com/feed"])
        conn = sqlite3.connect(self.path)
        self.assertEqual(conn.execute("PRAGMA user_version").fetchone()[0], 1)
        conn.close()

    def test_uses_write_ahead_logging(self):
        conn = sqlite3.connect(self.path)
        self.assertEqual(conn.execute("PRAGMA journal_mode").fetchone()[0], "wal")
        conn.close()

    def test_a_reader_is_not_blocked_by_a_writer(self):
        self.store.add_feed("https://example.com/feed")
        writer = sqlite3.connect(self.path, isolation_level=None, timeout=0)
        writer.execute("BEGIN EXCLUSIVE")
        writer.execute("UPDATE feeds SET title = 'changing'")
        try:
            feeds = self.store.due_feeds(T0)
        finally:
            writer.execute("ROLLBACK")
            writer.close()
        self.assertEqual([f.title for f in feeds], [None])

    def test_a_writer_waits_for_another_writer(self):
        writer = sqlite3.connect(self.path, isolation_level=None, check_same_thread=False)
        writer.execute("BEGIN IMMEDIATE")

        def release():
            time.sleep(0.5)
            writer.execute("COMMIT")

        thread = threading.Thread(target=release)
        thread.start()
        try:
            self.store.add_feed("https://example.com/feed")
        finally:
            thread.join()
            writer.close()
        self.assertEqual(len(self.store.due_feeds(T0)), 1)


class FeedsTest(StoreTestCase):
    def test_add_feed_defaults_to_thirty_minutes(self):
        feed = self.store.add_feed("https://example.com/feed")
        self.assertEqual(feed.interval_minutes, 30)
        self.assertIsNone(feed.title)

    def test_add_feed_keeps_title_and_interval(self):
        feed = self.store.add_feed("https://example.com/feed", title="Example", interval_minutes=5)
        self.assertEqual((feed.title, feed.interval_minutes), ("Example", 5))

    def test_a_url_already_subscribed_to_is_refused(self):
        self.store.add_feed("https://example.com/feed")
        with self.assertRaises(DuplicateFeedError) as caught:
            self.store.add_feed("https://example.com/feed", title="Again")
        self.assertIn("https://example.com/feed", str(caught.exception))

    def test_a_feed_never_polled_is_due(self):
        self.store.add_feed("https://example.com/feed")
        self.assertEqual(len(self.store.due_feeds(T0)), 1)

    def test_a_feed_is_due_again_when_its_interval_is_up(self):
        feed = self.store.add_feed("https://example.com/feed", interval_minutes=10)
        self.store.mark_polled(feed.id, T0)
        self.assertEqual(self.store.due_feeds(T0 + timedelta(minutes=9, seconds=59)), [])
        self.assertEqual(
            [f.id for f in self.store.due_feeds(T0 + timedelta(minutes=10))], [feed.id]
        )

    def test_each_feed_keeps_its_own_interval(self):
        fast = self.store.add_feed("https://example.com/fast", interval_minutes=5)
        slow = self.store.add_feed("https://example.com/slow", interval_minutes=60)
        self.store.mark_polled(fast.id, T0)
        self.store.mark_polled(slow.id, T0)
        self.assertEqual(
            [f.id for f in self.store.due_feeds(T0 + timedelta(minutes=5))], [fast.id]
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.store'`

- [ ] **Step 3: Write the implementation**

`feedwatch/store.py`:

```python
"""The SQLite database shared by the poller and the CLI."""

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_INTERVAL_MINUTES = 30
BUSY_TIMEOUT_SECONDS = 5.0

# Applied in order; a database's PRAGMA user_version counts how many it has
# had. Append new migrations here, never edit a shipped one: databases that
# already ran it will not run it again.
_MIGRATIONS: list[list[str]] = [
    [
        """
        CREATE TABLE feeds (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT,
            interval_minutes INTEGER NOT NULL,
            last_polled_at TEXT
        )
        """,
        """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            feed_id INTEGER NOT NULL REFERENCES feeds (id),
            guid TEXT NOT NULL,
            link TEXT,
            title TEXT,
            published_at TEXT,
            fetched_at TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            UNIQUE (feed_id, guid)
        )
        """,
    ],
]


class DuplicateFeedError(Exception):
    """The URL is already subscribed to."""

    def __init__(self, url: str):
        super().__init__(f"already subscribed to {url}")
        self.url = url



@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    interval_minutes: int
    last_polled_at: datetime | None



def default_db_path() -> Path:
    return Path.home() / ".feedwatch" / "feeds.db"


def open_store(path: Path | None = None) -> "Store":
    """Open the database at `path` (default ~/.feedwatch/feeds.db), creating it and its directory if needed and bringing its schema up to date."""
    path = default_db_path() if path is None else path
    path.parent.mkdir(parents=True, exist_ok=True)
    # isolation_level=None: every transaction is opened explicitly by _write.
    conn = sqlite3.connect(path, timeout=BUSY_TIMEOUT_SECONDS, isolation_level=None)
    # WAL lets the CLI read while the poller is writing.
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    _migrate(conn)
    return Store(conn)


@contextmanager
def _write(conn: sqlite3.Connection) -> Iterator[None]:
    # IMMEDIATE takes the write lock up front, so a second writer waits on the busy timeout instead of failing mid-transaction.
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    conn.execute("COMMIT")


def _migrate(conn: sqlite3.Connection) -> None:
    with _write(conn):
        # Read inside the write lock: the poller and the CLI may open a new database at the same moment.
        version = conn.execute("PRAGMA user_version").fetchone()[0]
        for number, statements in enumerate(_MIGRATIONS[version:], start=version + 1):
            for statement in statements:
                conn.execute(statement)
            conn.execute(f"PRAGMA user_version = {number}")


def _to_text(moment: datetime) -> str:
    # One fixed UTC format, so that text order is time order in ORDER BY.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _from_text(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)


class Store:
    def __init__(self, conn: sqlite3.Connection):
        self._conn = conn

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> "Store":
        return self

    def __exit__(self, *exc_info) -> None:
        self.close()

    def add_feed(self, url: str, title: str | None = None,
                 interval_minutes: int = DEFAULT_INTERVAL_MINUTES) -> Feed:
        """Subscribe to `url`. Raises DuplicateFeedError if it is already subscribed to."""
        try:
            with _write(self._conn):
                cursor = self._conn.execute(
                    "INSERT INTO feeds (url, title, interval_minutes) VALUES (?, ?, ?)",
                    (url, title, interval_minutes),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateFeedError(url) from exc
        return Feed(cursor.lastrowid, url, title, interval_minutes, None)

    def due_feeds(self, now: datetime) -> list[Feed]:
        """Feeds never polled, or whose interval has run out by `now`."""
        rows = self._conn.execute(
            "SELECT id, url, title, interval_minutes, last_polled_at FROM feeds ORDER BY id"
        ).fetchall()
        feeds = [Feed(id, url, title, interval, _from_text(last))
                 for id, url, title, interval, last in rows]
        return [
            feed for feed in feeds
            if feed.last_polled_at is None
            or feed.last_polled_at + timedelta(minutes=feed.interval_minutes) <= now
        ]

    def mark_polled(self, feed_id: int, now: datetime) -> None:
        with _write(self._conn):
            self._conn.execute(
                "UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(now), feed_id)
            )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_store -v`
Expected: 11 tests, OK

To check that `test_a_reader_is_not_blocked_by_a_writer` really depends on WAL, comment out the `PRAGMA journal_mode = WAL` line and rerun. That test should now error with `database is locked` after about 5 seconds. Restore the line afterwards.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: SQLite store with migrations and feed subscriptions"
```

---

### Task 4: The store: entries, unread and mark read

**Files:**
- Modify: `feedwatch/store.py`
- Test: `tests/test_store_entries.py`

**Interfaces:**
- Consumes: `ParsedEntry` and `.identity` (Task 1); `open_store`, `Store`, `_write`, `_to_text`, `_from_text` (Task 3).
- Produces:
  - `class UnknownGuidError(Exception)` with `.guids: list[str]` (the unknown ones, in the order given); `str(exc) == "no stored entry with guid a, b"`
  - `@dataclass(frozen=True) class StoredEntry: guid: str; title: str | None; link: str | None; published_at: datetime | None; feed: str`. `feed` is the feed's title, or its URL when it has none.
  - `Store.add_entries(feed_id: int, entries: Iterable[ParsedEntry], fetched_at: datetime) -> int`: the number of entries that were new.
  - `Store.unread(limit: int = 20) -> list[StoredEntry]`, newest first.
  - `Store.mark_read(guids: Iterable[str]) -> None`: all-or-nothing; raises `UnknownGuidError`.

- [ ] **Step 1: Write the failing tests**

`tests/test_store_entries.py`:

```python
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.parse import ParsedEntry
from feedwatch.store import UnknownGuidError, open_store

T0 = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


def entry(guid, published=None, title=None, link=None):
    return ParsedEntry(guid=guid, link=link, title=title, published=published)


class EntriesTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.store = open_store(Path(self._tmp.name) / "feeds.db")
        self.feed = self.store.add_feed("https://example.com/feed", title="Example")

    def tearDown(self):
        self.store.close()
        self._tmp.cleanup()

    def test_add_entries_counts_only_new_entries(self):
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("a"), entry("b")], T0), 2)
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("b"), entry("c")], T0), 1)
        self.assertEqual(sorted(e.guid for e in self.store.unread()), ["a", "b", "c"])

    def test_an_entry_repeated_within_one_fetch_is_stored_once(self):
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("a"), entry("a")], T0), 1)

    def test_an_entry_without_a_guid_is_identified_by_its_link(self):
        linked = ParsedEntry(guid=None, link="https://example.com/1", title=None, published=None)
        self.store.add_entries(self.feed.id, [linked], T0)
        self.assertEqual(self.store.add_entries(self.feed.id, [linked], T0), 0)
        self.assertEqual([e.guid for e in self.store.unread()], ["https://example.com/1"])

    def test_the_same_guid_in_two_feeds_is_two_entries(self):
        other = self.store.add_feed("https://example.org/feed")
        self.store.add_entries(self.feed.id, [entry("a")], T0)
        self.assertEqual(self.store.add_entries(other.id, [entry("a")], T0), 1)

    def test_a_seen_entry_stays_read(self):
        self.store.add_entries(self.feed.id, [entry("a")], T0)
        self.store.mark_read(["a"])
        self.store.add_entries(self.feed.id, [entry("a")], T0 + timedelta(hours=1))
        self.assertEqual(self.store.unread(), [])

    def test_unread_is_newest_first(self):
        self.store.add_entries(self.feed.id, [
            entry("old", published=T0 - timedelta(days=2)),
            entry("new", published=T0),
            entry("mid", published=T0 - timedelta(days=1)),
        ], T0)
        self.assertEqual([e.guid for e in self.store.unread()], ["new", "mid", "old"])

    def test_an_undated_entry_sorts_by_when_it_was_fetched(self):
        self.store.add_entries(self.feed.id, [entry("dated", published=T0 - timedelta(days=1))], T0)
        self.store.add_entries(self.feed.id, [entry("undated")], T0 + timedelta(hours=1))
        self.assertEqual([e.guid for e in self.store.unread()], ["undated", "dated"])

    def test_dates_in_other_zones_sort_by_the_instant(self):
        plus_two = timezone(timedelta(hours=2))
        self.store.add_entries(self.feed.id, [
            entry("earlier", published=datetime(2026, 3, 1, 10, 0, tzinfo=plus_two)),
            entry("later", published=datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)),
        ], T0)
        self.assertEqual([e.guid for e in self.store.unread()], ["later", "earlier"])

    def test_unread_defaults_to_twenty_and_honours_a_limit(self):
        self.store.add_entries(
            self.feed.id,
            [entry(f"g{i}", published=T0 + timedelta(minutes=i)) for i in range(25)],
            T0,
        )
        self.assertEqual(len(self.store.unread()), 20)
        self.assertEqual([e.guid for e in self.store.unread(limit=2)], ["g24", "g23"])

    def test_unread_carries_title_link_date_and_feed_name(self):
        self.store.add_entries(self.feed.id, [
            entry("a", published=T0, title="Hello", link="https://example.com/a"),
        ], T0)
        [stored] = self.store.unread()
        self.assertEqual(
            (stored.title, stored.link, stored.published_at, stored.feed),
            ("Hello", "https://example.com/a", T0, "Example"),
        )

    def test_an_untitled_feed_is_named_by_its_url(self):
        other = self.store.add_feed("https://example.org/feed")
        self.store.add_entries(other.id, [entry("a")], T0)
        self.assertEqual([e.feed for e in self.store.unread()], ["https://example.org/feed"])

    def test_mark_read_removes_entries_from_unread(self):
        self.store.add_entries(self.feed.id, [entry("a"), entry("b"), entry("c")], T0)
        self.store.mark_read(["a", "c"])
        self.assertEqual([e.guid for e in self.store.unread()], ["b"])

    def test_marking_an_entry_read_twice_is_harmless(self):
        self.store.add_entries(self.feed.id, [entry("a")], T0)
        self.store.mark_read(["a"])
        self.store.mark_read(["a"])
        self.assertEqual(self.store.unread(), [])

    def test_an_unknown_guid_is_refused_by_name_and_nothing_is_marked(self):
        self.store.add_entries(self.feed.id, [entry("a")], T0)
        with self.assertRaises(UnknownGuidError) as caught:
            self.store.mark_read(["a", "nope", "gone"])
        self.assertEqual(caught.exception.guids, ["nope", "gone"])
        self.assertIn("nope", str(caught.exception))
        self.assertEqual([e.guid for e in self.store.unread()], ["a"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store_entries -v`
Expected: ERROR, `ImportError: cannot import name 'UnknownGuidError' from 'feedwatch.store'`

- [ ] **Step 3: Write the implementation**

In `feedwatch/store.py`, replace the import line `from collections.abc import Iterator` with:

```python
from collections.abc import Iterable, Iterator
```

After `from pathlib import Path`, add a blank line and then:

```python
from feedwatch.parse import ParsedEntry
```

After the `DuplicateFeedError` class, add:

```python
class UnknownGuidError(Exception):
    """One or more guids match no stored entry."""

    def __init__(self, guids: list[str]):
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = guids
```

After the `Feed` dataclass, add:

```python
@dataclass(frozen=True)
class StoredEntry:
    guid: str
    title: str | None
    link: str | None
    published_at: datetime | None
    feed: str  # the feed's title, or its URL when it has none
```

At the end of the `Store` class, after `mark_polled`, add:

```python
    def add_entries(self, feed_id: int, entries: Iterable[ParsedEntry],
                    fetched_at: datetime) -> int:
        """Store the entries the feed has not had before; return how many were new."""
        added = 0
        with _write(self._conn):
            for entry in entries:
                cursor = self._conn.execute(
                    "INSERT OR IGNORE INTO entries"
                    " (feed_id, guid, link, title, published_at, fetched_at)"
                    " VALUES (?, ?, ?, ?, ?, ?)",
                    (
                        feed_id,
                        entry.identity,
                        entry.link,
                        entry.title,
                        None if entry.published is None else _to_text(entry.published),
                        _to_text(fetched_at),
                    ),
                )
                added += cursor.rowcount
        return added

    def unread(self, limit: int = 20) -> list[StoredEntry]:
        """Unread entries, newest first; an entry with no date counts as published when it was fetched."""
        rows = self._conn.execute(
            "SELECT e.guid, e.title, e.link, e.published_at, COALESCE(f.title, f.url)"
            " FROM entries e JOIN feeds f ON f.id = e.feed_id"
            " WHERE e.read = 0"
            " ORDER BY COALESCE(e.published_at, e.fetched_at) DESC, e.id DESC"
            " LIMIT ?",
            (limit,),
        ).fetchall()
        return [StoredEntry(guid, title, link, _from_text(published), feed)
                for guid, title, link, published, feed in rows]

    def mark_read(self, guids: Iterable[str]) -> None:
        """Mark every entry with one of `guids` read.

        Raises UnknownGuidError naming each guid that matches no entry, and
        then marks none of them.
        """
        guids = list(dict.fromkeys(guids))
        with _write(self._conn):
            unknown = [
                guid for guid in guids
                if self._conn.execute(
                    "SELECT 1 FROM entries WHERE guid = ? LIMIT 1", (guid,)
                ).fetchone() is None
            ]
            if unknown:
                raise UnknownGuidError(unknown)
            self._conn.executemany(
                "UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids]
            )
```

`INSERT OR IGNORE` against `UNIQUE (feed_id, guid)` is what makes a re-seen entry a no-op. A re-seen entry that was already read therefore stays read.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_store tests.test_store_entries -v`
Expected: 25 tests, OK

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store_entries.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch_feed`, `FetchError` (Task 2); `parse_feed`, `ParseError` (Task 1); `open_store`, `Store.due_feeds`, `Store.add_entries`, `Store.mark_polled` (Tasks 3-4).
- Produces:
  - `TICK_SECONDS = 60`
  - `poll_once(store: Store, now: datetime, fetch: Callable[[str], bytes] = fetch_feed) -> None`
  - `run(store, fetch=fetch_feed, clock=<UTC now>, sleep=time.sleep) -> None`: loops forever.
  - `main() -> int`: the `python -m feedwatch.poller` entry point. Ctrl+C exits with status 0 and no traceback.

The `except` in `poll_once` catches only `FetchError` and `ParseError`. A `sqlite3.Error` must propagate, because ARCHITECTURE says a database error stops the poller. Do not widen it to `except Exception`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.fetch import FetchError
from feedwatch.poller import TICK_SECONDS, poll_once, run
from feedwatch.store import open_store

T0 = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{g}</guid><title>{g}</title></item>" for g in guids)
    return f"<rss version=\"2.0\"><channel>{items}</channel></rss>".encode()


class FakeFetch:
    """Serves canned responses by URL; an Exception value is raised instead."""

    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __call__(self, url):
        self.calls.append(url)
        response = self.responses[url]
        if isinstance(response, Exception):
            raise response
        return response


class PollOnceTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.store = open_store(Path(self._tmp.name) / "feeds.db")

    def tearDown(self):
        self.store.close()
        self._tmp.cleanup()

    def test_stores_the_entries_of_a_due_feed(self):
        self.store.add_feed("https://a.example/feed")
        poll_once(self.store, T0, FakeFetch({"https://a.example/feed": rss("1", "2")}))
        self.assertEqual(sorted(e.guid for e in self.store.unread()), ["1", "2"])

    def test_stores_only_entries_not_seen_before(self):
        self.store.add_feed("https://a.example/feed", interval_minutes=1)
        poll_once(self.store, T0, FakeFetch({"https://a.example/feed": rss("1")}))
        self.store.mark_read(["1"])
        poll_once(self.store, T0 + timedelta(minutes=1),
                  FakeFetch({"https://a.example/feed": rss("1", "2")}))
        self.assertEqual([e.guid for e in self.store.unread()], ["2"])

    def test_a_feed_is_not_polled_before_its_interval_is_up(self):
        self.store.add_feed("https://a.example/feed", interval_minutes=30)
        fetch = FakeFetch({"https://a.example/feed": rss("1")})
        poll_once(self.store, T0, fetch)
        poll_once(self.store, T0 + timedelta(minutes=29), fetch)
        poll_once(self.store, T0 + timedelta(minutes=30), fetch)
        self.assertEqual(len(fetch.calls), 2)

    def test_a_feed_that_cannot_be_fetched_is_logged_and_the_others_still_polled(self):
        self.store.add_feed("https://down.example/feed")
        self.store.add_feed("https://up.example/feed")
        fetch = FakeFetch({
            "https://down.example/feed": FetchError("connection refused"),
            "https://up.example/feed": rss("1"),
        })
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            poll_once(self.store, T0, fetch)
        self.assertIn("https://down.example/feed", "\n".join(logs.output))
        self.assertEqual([e.guid for e in self.store.unread()], ["1"])

    def test_a_feed_that_is_not_rss_is_logged_and_the_others_still_polled(self):
        self.store.add_feed("https://html.example/")
        self.store.add_feed("https://up.example/feed")
        fetch = FakeFetch({
            "https://html.example/": b"<html><body>hello</body></html>",
            "https://up.example/feed": rss("1"),
        })
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            poll_once(self.store, T0, fetch)
        self.assertIn("https://html.example/", "\n".join(logs.output))
        self.assertEqual([e.guid for e in self.store.unread()], ["1"])

    def test_a_failed_feed_is_skipped_until_its_next_interval(self):
        self.store.add_feed("https://down.example/feed", interval_minutes=30)
        fetch = FakeFetch({"https://down.example/feed": FetchError("timed out")})
        with self.assertLogs("feedwatch.poller", level="WARNING"):
            poll_once(self.store, T0, fetch)
        poll_once(self.store, T0 + timedelta(minutes=1), fetch)
        self.assertEqual(len(fetch.calls), 1)

    def test_a_database_error_propagates(self):
        self.store.add_feed("https://a.example/feed")
        self.store.close()
        with self.assertRaises(sqlite3.Error):
            poll_once(self.store, T0, FakeFetch({"https://a.example/feed": rss("1")}))
        self.store = open_store(Path(self._tmp.name) / "feeds.db")


class _Stop(Exception):
    pass


class RunTest(unittest.TestCase):
    def test_polls_then_sleeps_a_tick_each_round(self):
        with tempfile.TemporaryDirectory() as tmp, open_store(Path(tmp) / "feeds.db") as store:
            store.add_feed("https://a.example/feed", interval_minutes=1)
            fetch = FakeFetch({"https://a.example/feed": rss("1")})
            moments = iter([T0, T0 + timedelta(minutes=1)])
            sleeps = []

            def sleep(seconds):
                sleeps.append(seconds)
                if len(sleeps) == 2:
                    raise _Stop

            with self.assertRaises(_Stop):
                run(store, fetch=fetch, clock=lambda: next(moments), sleep=sleep)
        self.assertEqual(len(fetch.calls), 2)
        self.assertEqual(sleeps, [TICK_SECONDS, TICK_SECONDS])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_poller -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.poller'`

- [ ] **Step 3: Write the implementation**

`feedwatch/poller.py`:

```python
"""The long-running worker: polls each feed when its interval is up.

Run with `python -m feedwatch.poller`.
"""

import logging
import sys
import time
from collections.abc import Callable
from datetime import datetime, timezone

from feedwatch.fetch import FetchError, fetch_feed
from feedwatch.parse import ParseError, parse_feed
from feedwatch.store import Store, open_store

log = logging.getLogger(__name__)

# Intervals are whole minutes, so checking once a minute is never late by more than one.
TICK_SECONDS = 60

Fetch = Callable[[str], bytes]


def poll_once(store: Store, now: datetime, fetch: Fetch = fetch_feed) -> None:
    """Poll every feed that is due at `now` and store the entries not seen before.

    A feed that cannot be fetched or parsed is logged and skipped until its
    next interval. A database error propagates.
    """
    for feed in store.due_feeds(now):
        try:
            entries = parse_feed(fetch(feed.url))
        except (FetchError, ParseError) as exc:
            log.warning("skipping %s until its next interval: %s", feed.url, exc)
        else:
            added = store.add_entries(feed.id, entries, now)
            log.info("%s: %d new entries", feed.url, added)
        store.mark_polled(feed.id, now)


def run(store: Store, fetch: Fetch = fetch_feed,
        clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
        sleep: Callable[[float], None] = time.sleep) -> None:
    """Poll due feeds every TICK_SECONDS, forever. Returns only by raising."""
    while True:
        poll_once(store, clock(), fetch)
        sleep(TICK_SECONDS)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with open_store() as store:
        try:
            run(store)
        except KeyboardInterrupt:
            return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -W error::ResourceWarning -m unittest tests.test_poller -v`
Expected: 8 tests, OK

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller stores new entries and skips failing feeds"
```

---

### Task 6: The command line, and an end-to-end check

**Files:**
- Create: `feedwatch/cli.py`
- Modify: `pyproject.toml` (add the console script)
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `open_store`, `Store`, `DEFAULT_INTERVAL_MINUTES`, `DuplicateFeedError`, `UnknownGuidError`, and `Store.add_feed`, `Store.unread`, `Store.mark_read` (Tasks 3-4). `ParsedEntry` is used only in the tests, to seed data.
- Produces: `main(argv: list[str] | None = None, db_path: Path | None = None) -> int`, which is the `feedwatch` console script. `build_parser() -> argparse.ArgumentParser`.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.cli import main
from feedwatch.parse import ParsedEntry
from feedwatch.store import open_store

T0 = datetime(2026, 3, 1, 9, 30, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.db = Path(self._tmp.name) / "feeds.db"

    def tearDown(self):
        self._tmp.cleanup()

    def feedwatch(self, *argv):
        """Run the CLI; return (exit status, stdout, stderr)."""
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                status = main(list(argv), db_path=self.db)
            except SystemExit as exc:
                status = exc.code
        return status, out.getvalue(), err.getvalue()

    def seed(self, *entries, title="Example"):
        with open_store(self.db) as store:
            feed = store.add_feed("https://example.com/feed", title=title)
            store.add_entries(feed.id, entries, T0)

    # add

    def test_add_subscribes_with_the_default_interval(self):
        status, out, _ = self.feedwatch("add", "https://example.com/feed")
        self.assertEqual(status, 0)
        self.assertIn("every 30 minutes", out)
        with open_store(self.db) as store:
            [feed] = store.due_feeds(T0)
        self.assertEqual((feed.url, feed.title, feed.interval_minutes),
                         ("https://example.com/feed", None, 30))

    def test_add_takes_a_title_and_an_interval(self):
        status, out, _ = self.feedwatch(
            "add", "https://example.com/feed", "--title", "Example", "--every", "1"
        )
        self.assertEqual(status, 0)
        self.assertIn("every 1 minute.", out)
        with open_store(self.db) as store:
            [feed] = store.due_feeds(T0)
        self.assertEqual((feed.title, feed.interval_minutes), ("Example", 1))

    def test_add_refuses_a_url_already_subscribed_to_and_names_it(self):
        self.feedwatch("add", "https://example.com/feed")
        status, _, err = self.feedwatch("add", "https://example.com/feed")
        self.assertEqual(status, 1)
        self.assertIn("https://example.com/feed", err)

    def test_add_refuses_an_interval_below_one_minute(self):
        for every in ("0", "-5", "soon"):
            with self.subTest(every=every):
                status, _, err = self.feedwatch("add", "https://example.com/feed", "--every", every)
                self.assertEqual(status, 2)
                self.assertIn(every, err)

    def test_add_refuses_a_url_that_is_not_http(self):
        for url in ("example.com/feed.xml", "ftp://example.com/feed.xml"):
            with self.subTest(url=url):
                status, _, err = self.feedwatch("add", url)
                self.assertEqual(status, 2)
                self.assertIn(url, err)

    # unread

    def test_unread_with_nothing_stored_says_so(self):
        status, out, _ = self.feedwatch("unread")
        self.assertEqual((status, out), (0, "No unread entries.\n"))

    def test_unread_lists_newest_first_with_date_feed_title_and_guid(self):
        self.seed(
            ParsedEntry("old", None, "Older post", T0 - timedelta(days=1)),
            ParsedEntry("new", None, "Newer post", T0),
        )
        status, out, _ = self.feedwatch("unread")
        self.assertEqual(status, 0)
        self.assertEqual(out, (
            "2026-03-01 09:30 UTC  Example  Newer post\n"
            "    new\n"
            "2026-02-28 09:30 UTC  Example  Older post\n"
            "    old\n"
        ))

    def test_unread_shows_untitled_and_undated_entries(self):
        self.seed(ParsedEntry("g", None, None, None))
        _, out, _ = self.feedwatch("unread")
        self.assertEqual(out, "undated  Example  (untitled)\n    g\n")

    def test_unread_lists_twenty_unless_limited(self):
        self.seed(*[ParsedEntry(f"g{i}", None, None, T0 + timedelta(minutes=i)) for i in range(25)])
        _, out, _ = self.feedwatch("unread")
        self.assertEqual(out.count("\n    g"), 20)
        _, out, _ = self.feedwatch("unread", "--limit", "3")
        self.assertEqual(out.count("\n    g"), 3)

    def test_unread_refuses_a_limit_below_one(self):
        status, _, _ = self.feedwatch("unread", "--limit", "0")
        self.assertEqual(status, 2)

    # read

    def test_read_marks_entries_read(self):
        self.seed(ParsedEntry("a", None, None, T0), ParsedEntry("b", None, None, T0))
        status, out, _ = self.feedwatch("read", "a", "b")
        self.assertEqual((status, out), (0, "Marked 2 entries read.\n"))
        self.assertEqual(self.feedwatch("unread")[1], "No unread entries.\n")

    def test_read_refuses_an_unknown_guid_and_names_it(self):
        self.seed(ParsedEntry("a", None, None, T0))
        status, _, err = self.feedwatch("read", "a", "nope")
        self.assertEqual(status, 1)
        self.assertIn("nope", err)
        self.assertIn("    a\n", self.feedwatch("unread")[1])

    def test_read_needs_at_least_one_guid(self):
        status, _, _ = self.feedwatch("read")
        self.assertEqual(status, 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_cli -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.cli'`

- [ ] **Step 3: Write the implementation**

`feedwatch/cli.py`:

```python
"""The feedwatch command: subscribe to feeds and read what they brought."""

import argparse
import sys
import urllib.parse
from pathlib import Path

from feedwatch.store import (
    DEFAULT_INTERVAL_MINUTES,
    DuplicateFeedError,
    Store,
    UnknownGuidError,
    open_store,
)

DEFAULT_LIMIT = 20


def _positive_int(text: str) -> int:
    try:
        value = int(text)
    except ValueError:
        raise argparse.ArgumentTypeError(f"not a whole number: {text}") from None
    if value < 1:
        raise argparse.ArgumentTypeError(f"must be at least 1: {text}")
    return value


def _feed_url(text: str) -> str:
    parts = urllib.parse.urlsplit(text)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise argparse.ArgumentTypeError(f"not an http or https URL: {text}")
    return text


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="feedwatch", description="Read your RSS feeds from the command line."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", type=_feed_url, metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=_positive_int, default=DEFAULT_INTERVAL_MINUTES,
                     metavar="MINUTES",
                     help=f"poll interval in minutes (default {DEFAULT_INTERVAL_MINUTES})")

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=_positive_int, default=DEFAULT_LIMIT, metavar="N",
                        help=f"how many to list (default {DEFAULT_LIMIT})")

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def main(argv: list[str] | None = None, db_path: Path | None = None) -> int:
    """Run one command; return the process exit status."""
    args = build_parser().parse_args(argv)
    with open_store(db_path) as store:
        if args.command == "add":
            return _add(store, args)
        if args.command == "unread":
            return _unread(store, args)
        return _read(store, args)


def _add(store: Store, args: argparse.Namespace) -> int:
    try:
        store.add_feed(args.url, title=args.title, interval_minutes=args.every)
    except DuplicateFeedError as exc:
        print(f"feedwatch: {exc}", file=sys.stderr)
        return 1
    unit = "minute" if args.every == 1 else "minutes"
    print(f"Subscribed to {args.url}, polled every {args.every} {unit}.")
    return 0


def _unread(store: Store, args: argparse.Namespace) -> int:
    entries = store.unread(limit=args.limit)
    if not entries:
        print("No unread entries.")
        return 0
    for entry in entries:
        when = entry.published_at.strftime("%Y-%m-%d %H:%M UTC") if entry.published_at else "undated"
        print(f"{when}  {entry.feed}  {entry.title or '(untitled)'}")
        print(f"    {entry.guid}")
    return 0


def _read(store: Store, args: argparse.Namespace) -> int:
    try:
        store.mark_read(args.guids)
    except UnknownGuidError as exc:
        print(f"feedwatch: {exc}", file=sys.stderr)
        return 1
    count = len(set(args.guids))
    print(f"Marked {count} {'entry' if count == 1 else 'entries'} read.")
    return 0
```

Add to `pyproject.toml`, after the `[project]` table:

```toml
[project.scripts]
feedwatch = "feedwatch.cli:main"
```

- [ ] **Step 4: Run the whole suite**

Run: `python3 -W error::ResourceWarning -m unittest`
Expected: 63 tests, OK

- [ ] **Step 5: Check it end to end**

Install the package into a throwaway virtualenv, then drive both processes against a local feed. **Point `HOME` at a temporary directory first.** Otherwise `open_store()` creates the real `~/.feedwatch/feeds.db`. Run the whole block in one shell from the repository root:

```bash
set -u
REPO=$(pwd)
python3 -m venv .venv && .venv/bin/pip install -q -e . \
  || { rm -rf .venv && uv venv -q .venv && uv pip install -q --python .venv/bin/python -e .; }
SMOKE=$(mktemp -d)
export HOME=$SMOKE/home
mkdir -p $SMOKE/www
cat > $SMOKE/www/feed.xml <<'XML'
<?xml version="1.0"?>
<rss version="2.0"><channel><title>Local</title>
<item><guid>local-1</guid><title>Hello from the smoke test</title><pubDate>Sun, 01 Mar 2026 09:30:00 +0000</pubDate></item>
</channel></rss>
XML
PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1])")
python3 -m http.server $PORT --bind 127.0.0.1 --directory $SMOKE/www >/dev/null 2>&1 &
SRV=$!
sleep 1
U=http://127.0.0.1:$PORT
$REPO/.venv/bin/feedwatch add $U/feed.xml --title Local --every 1
$REPO/.venv/bin/feedwatch add $U/feed.xml; echo "exit=$?"
$REPO/.venv/bin/feedwatch add $U/missing.xml
timeout -s INT 3 $REPO/.venv/bin/python -m feedwatch.poller
$REPO/.venv/bin/feedwatch unread
$REPO/.venv/bin/feedwatch read local-1 && $REPO/.venv/bin/feedwatch unread
$REPO/.venv/bin/feedwatch read nope; echo "exit=$?"
kill $SRV; rm -rf $SMOKE
```

Expected output, in order:
- `Subscribed to http://127.0.0.1:<port>/feed.xml, polled every 1 minute.`
- `feedwatch: already subscribed to http://127.0.0.1:<port>/feed.xml` then `exit=1`
- `Subscribed to http://127.0.0.1:<port>/missing.xml, polled every 30 minutes.`
- a poller log line `INFO http://127.0.0.1:<port>/feed.xml: 1 new entries`, then `WARNING skipping http://127.0.0.1:<port>/missing.xml until its next interval: ... HTTP 404`, and no traceback when the poller is interrupted
- `2026-03-01 09:30 UTC  Local  Hello from the smoke test` followed by `    local-1`
- `Marked 1 entry read.` then `No unread entries.`
- `feedwatch: no stored entry with guid nope` then `exit=1`

Afterwards, confirm that `ls ~/.feedwatch` in a fresh shell shows nothing created by this check.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py pyproject.toml tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

## Finishing

- [ ] Run `python3 -W error::ResourceWarning -m unittest` one last time. Expected: 63 tests, OK.
- [ ] Invoke `dopamine:finishing-work` before the workspace is cleaned up. It sweeps the ledger into the living documents. `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are listed in `.dopamine/config` but do not exist yet; that sweep decides what goes in them, not any task.
````


## p003

#### Final message

The implementation plan for feedwatch v1 is written and committed as 93d791c. Nothing was implemented in the repo.

To check the plan, I copied its code into a scratch directory outside the repo and ran it. All 59 tests passed. The end-to-end run worked too: adding feeds, polling with one feed returning 404, listing unread newest first, and refusing an unknown guid by name. I fixed two wrong test counts the run turned up. I didn't run the plan's virtualenv install step.

**What the plan covers.** It has five tasks, one per module from the architecture doc, in this order: `parse`, `store`, `fetch`, `poller`, `cli`. Each task writes its tests before its code. The design uses only the standard library:
- **Tests:** they use the built-in `unittest` instead of pytest, to keep dependencies at zero.
- **Database:** SQLite in WAL mode with a 30-second lock timeout, so the poller and the command line can use the file at the same time.
- **Schema changes:** versioned migrations, so a database created now keeps working as later features add tables and columns.
- **Poller:** wakes every 30 seconds to check which feeds are due, so a newly added feed is picked up without a restart.

The plan also lists five ways real use could break that the spec doesn't mention, each covered by a test:
- `~/.feedwatch/` doesn't exist yet on first run.
- The command line and the poller write at the same moment.
- A server accepts the connection and never answers.
- An item has no guid, a blank guid, or neither guid nor link.
- Dates are in mixed time zones, missing, or unreadable.

**Choices the plan makes where the spec is silent.** These are listed in their own section of the plan so the human can overturn any of them:
- Only documents with an `<rss><channel>` root count as RSS. RSS 1.0 (RDF) feeds are refused like any other non-RSS document. This is the one most worth checking.
- A failed poll counts as a poll, so the feed waits a full interval before the next try.
- `read` marks the guids it knows and refuses each unknown one by name, with exit status 1.
- A guid that appears in two feeds is marked read in both.
- An entry without a date is sorted by when it was fetched.
- `add` refuses URLs that don't start with `http://` or `https://`, and intervals or limits below 1.
- Dates are shown in the user's local time.

**Other things to pass on:**
- A security hook suggested using `defusedxml` for parsing feeds. I didn't add it, because the design doc says standard library first. Python's built-in XML parser doesn't load external entities, and current Python has protection against entity-expansion attacks.
- `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` as living documents, but neither exists. I didn't create them.
- I ran the finishing-work step: a reconstructed ledger and a "nothing to drain" commit (d8a8b54). Nothing goes into the living documents until the plan is actually carried out.

Files are in `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/greenfield/runs/F0-2/docs/superpowers/plans/`:
- `2026-10-12-feedwatch-v1.md`
- `2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md`

Plan complete and saved to `docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Please review it and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md (added)

````
Reconstructed ledger, written 2026-10-12 from the planning conversation; there was no superpowers ledger for this unit.

# feedwatch v1 — planning

- Wrote docs/superpowers/plans/2026-10-12-feedwatch-v1.md from docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md. No code was written to the repository.
- The plan's code was checked by extracting it into a scratch directory outside the repo: all 59 tests passed and the smoke scenario behaved as described.
- Decisions the plan takes where the spec is silent are listed in its "Decisions this plan makes where the spec is silent" section. They become facts about the system only once the plan is executed, so nothing is drained now.
- Declared living documents docs/PROGRAM-DESIGN.md and docs/ROADMAP.md do not exist.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five modules in one package, matching `docs/ARCHITECTURE.md`: `fetch` (HTTP only), `parse` (RSS XML to `Entry` objects), `store` (the SQLite file and its schema), `poller` (the schedule; calls fetch, parse and store) and `cli` (presentation; calls store only). The poller and the CLI are separate processes sharing `~/.feedwatch/feeds.db`, so the database runs in WAL mode with a busy timeout, and the schema is versioned with `PRAGMA user_version` so later features can add tables and columns to an existing file.

**Tech Stack:** Python 3.11+ standard library only: `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`. Tests use `unittest` (run with `python -m unittest`). Packaging uses `pyproject.toml` with the setuptools build backend, for the `feedwatch` console script only.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, which it incorporates).

## Global Constraints

- Standard library first; no runtime dependencies (`dependencies = []`).
- Database file: `~/.feedwatch/feeds.db`, tables `feeds` and `entries`; `store` is authoritative for both.
- "The schema gains tables and columns as features land, and an existing database has to keep working."
- Module boundaries: `fetch` never parses; `parse` never stores; `store` never touches the network; `poller` never presents anything; `cli` never polls. `poller` calls `fetch`, `parse` and `store`; `cli` calls `store`; only `poller` calls `fetch`.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`; interval defaults to 30 minutes.
- Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries, newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- Poller entry point: `python -m feedwatch.poller`.
- An entry is identified by its feed and its guid, or its link when it has no guid. Each entry is stored once, however often it is seen.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled.
- A database error stops the poller.
- Out of scope: Atom feeds; importing or exporting subscription lists; multiple users; full-text search; a web interface.
- Living documents (`docs/DESIGN.md`, `docs/ARCHITECTURE.md`, and the declared `docs/PROGRAM-DESIGN.md`, `docs/ROADMAP.md`) are not edited by any task. Anything learned that belongs in them goes in the execution ledger for the sweep.

## Decisions this plan makes where the spec is silent

- "RSS feed" means a document whose root is `<rss>` with a `<channel>` child (RSS 0.9x/2.0). RSS 1.0 (`<rdf:RDF>`) is refused like any other non-RSS document.
- An item with neither a guid nor a link has nothing to identify it and is skipped. A blank `<guid>` counts as absent.
- An entry without a usable `pubDate` is ordered by when it was first fetched.
- A failed poll counts as a poll: the feed's `last_polled_at` is set, so it waits a full interval before the next try.
- `read` marks every known guid it is given and refuses each unknown one by name (exit status 1). A guid shared by entries in two feeds marks both.
- `add` refuses URLs that are not `http(s)://host...` and intervals or limits below 1, via argparse (exit status 2).
- `unread` shows dates in the user's local time zone.
- The poller wakes every 30 seconds to look for due feeds, so feeds added by the CLI are picked up without a restart.

## Review Focus

1. **First run, nothing exists yet** — `~/.feedwatch/` is missing when either process first starts: it must be created, and `unread` on the empty database prints "no unread entries" instead of failing. Pinned in Task 2 (`test_creates_missing_directory`) and Task 5 (`test_add_on_first_run_creates_database`, `test_unread_when_nothing_unread`).
2. **CLI and poller writing at the same moment** — `feedwatch read` while the poller is storing entries must wait for the lock, not die with "database is locked"; two processes opening a brand-new file at once must not both apply the first migration. Pinned in Task 2 (`test_uses_wal_and_waits_for_locks`, `test_a_write_waits_for_another_connections_lock`).
3. **A server that accepts the connection and never answers** — one hung feed must not stall the poller and with it every other feed. Pinned in Task 3 (`test_unresponsive_server_times_out`).
4. **Items without a usable identity** — no guid, a blank guid, or neither guid nor link: fall back to the link, or skip; never store an entry under an empty key that would swallow later distinct items. Pinned in Task 1 (`test_link_identifies_an_item_without_guid`, `test_blank_guid_falls_back_to_link`, `test_item_with_neither_guid_nor_link_is_skipped`).
5. **Dates in mixed time zones, missing or unparseable** — "newest first" must hold across `+0200`, `-0500` and `GMT` dates and undated items, and a garbage `pubDate` must not reject the feed. Pinned in Task 1 (`test_dates_are_normalised_to_utc`, `test_missing_or_unreadable_date_is_none`) and Task 2 (`test_unread_newest_first_across_timezones_and_missing_dates`).

---

## File Structure

```
pyproject.toml            package metadata; `feedwatch` console script
.gitignore                adds .venv/ and *.egg-info/
feedwatch/__init__.py     package docstring only
feedwatch/__main__.py     `python -m feedwatch` runs the CLI
feedwatch/parse.py        Entry, ParseError, parse(xml) -> list[Entry]
feedwatch/store.py        connect, schema migrations, feeds and entries
feedwatch/fetch.py        FetchError, fetch(url, timeout) -> bytes
feedwatch/poller.py       poll_once, run, main; `python -m feedwatch.poller`
feedwatch/cli.py          main(argv, db_path) -> int; add / unread / read
tests/__init__.py
tests/test_parse.py
tests/test_store.py
tests/test_fetch.py
tests/test_poller.py
tests/test_cli.py
```

Tests run from the repository root with `python -m unittest` (no install needed). Installation is only for the `feedwatch` command, in Task 5's smoke test.

---

### Task 1: Package skeleton and `parse`

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/parse.py`, `tests/__init__.py`, `tests/test_parse.py`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.parse.Entry` — frozen dataclass `Entry(guid: str, title: str, link: str | None, published: datetime | None)`; `guid` is the item's guid, or its link when it has none; `published` is UTC-aware or `None`; `title` is `""` when absent.
  - `feedwatch.parse.ParseError(Exception)`.
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]` — raises `ParseError` for anything that is not an RSS document.

- [ ] **Step 1: Create the package skeleton**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=69"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py`:

```python
"""Feedwatch: poll RSS feeds into SQLite and read them from the command line."""
```

`tests/__init__.py`: empty file.

Append to `.gitignore`:

```
.venv/
*.egg-info/
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timedelta, timezone

from feedwatch.parse import Entry, ParseError, parse


def rss(items: str) -> bytes:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<rss version="2.0"><channel><title>Example</title>'
        f"{items}"
        "</channel></rss>"
    ).encode("utf-8")


class ParseTest(unittest.TestCase):
    def test_reads_guid_title_link_and_date(self):
        entries = parse(rss(
            "<item><guid>g1</guid><title>First</title>"
            "<link>https://example.com/1</link>"
            "<pubDate>Sun, 01 Mar 2026 12:00:00 +0000</pubDate></item>"
        ))
        self.assertEqual(entries, [Entry(
            guid="g1",
            title="First",
            link="https://example.com/1",
            published=datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc),
        )])

    def test_items_come_back_in_document_order(self):
        entries = parse(rss("<item><guid>a</guid></item><item><guid>b</guid></item>"))
        self.assertEqual([e.guid for e in entries], ["a", "b"])

    def test_link_identifies_an_item_without_guid(self):
        [entry] = parse(rss("<item><title>T</title><link>https://example.com/a</link></item>"))
        self.assertEqual(entry.guid, "https://example.com/a")

    def test_blank_guid_falls_back_to_link(self):
        [entry] = parse(rss("<item><guid>  </guid><link>https://example.com/b</link></item>"))
        self.assertEqual(entry.guid, "https://example.com/b")

    def test_item_with_neither_guid_nor_link_is_skipped(self):
        entries = parse(rss("<item><title>Orphan</title></item><item><guid>g2</guid></item>"))
        self.assertEqual([e.guid for e in entries], ["g2"])

    def test_untitled_item_has_empty_title(self):
        [entry] = parse(rss("<item><guid>g</guid></item>"))
        self.assertEqual(entry.title, "")

    def test_dates_are_normalised_to_utc(self):
        entries = parse(rss(
            "<item><guid>a</guid><pubDate>Sun, 01 Mar 2026 14:00:00 +0200</pubDate></item>"
            "<item><guid>b</guid><pubDate>Sun, 01 Mar 2026 12:00:00 GMT</pubDate></item>"
        ))
        for entry in entries:
            self.assertEqual(entry.published, datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc))
            self.assertEqual(entry.published.utcoffset(), timedelta(0))

    def test_missing_or_unreadable_date_is_none(self):
        entries = parse(rss(
            "<item><guid>a</guid></item>"
            "<item><guid>b</guid><pubDate>yesterday</pubDate></item>"
        ))
        self.assertEqual([e.published for e in entries], [None, None])

    def test_declared_encoding_is_honoured(self):
        xml = (
            '<?xml version="1.0" encoding="ISO-8859-1"?>'
            '<rss version="2.0"><channel>'
            "<item><guid>g</guid><title>Café</title></item>"
            "</channel></rss>"
        ).encode("iso-8859-1")
        [entry] = parse(xml)
        self.assertEqual(entry.title, "Café")

    def test_malformed_xml_is_refused(self):
        with self.assertRaises(ParseError):
            parse(b"<rss><channel>")

    def test_empty_body_is_refused(self):
        with self.assertRaises(ParseError):
            parse(b"")

    def test_html_page_is_refused(self):
        with self.assertRaises(ParseError):
            parse(b"<html><body>Not a feed</body></html>")

    def test_atom_feed_is_refused(self):
        with self.assertRaises(ParseError):
            parse(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>')

    def test_rss_without_channel_is_refused(self):
        with self.assertRaises(ParseError):
            parse(b'<rss version="2.0"></rss>')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.parse'`

- [ ] **Step 4: Implement `parse`**

`feedwatch/parse.py`:

```python
"""Turn RSS XML into entries. Owns the feed format; never stores."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime


class ParseError(Exception):
    """The document is not an RSS feed."""


@dataclass(frozen=True)
class Entry:
    """One item of a feed.

    ``guid`` is the item's <guid>, or its <link> when it has none; together
    with the feed it identifies the entry. ``published`` is in UTC, or None
    when the item has no readable date.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None


def parse(xml: bytes) -> list[Entry]:
    """Return the items of an RSS document, in document order.

    Items with neither a guid nor a link are skipped. Raises ParseError when
    ``xml`` is not well-formed, or is not an <rss> document with a <channel>.
    """
    try:
        # Bytes, not str: the parser then honours the encoding the XML declares.
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ParseError(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel") if root.tag == "rss" else None
    if channel is None:
        raise ParseError(f"not an RSS feed (root element <{root.tag}>)")

    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(Entry(
            guid=guid,
            title=_text(item, "title") or "",
            link=link,
            published=_date(_text(item, "pubDate")),
        ))
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    element = item.find(tag)
    if element is None or element.text is None:
        return None
    return element.text.strip() or None


def _date(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        moment = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if moment.tzinfo is None:
        # No zone, or RFC 2822's "-0000" (UTC, local zone unknown): read as UTC.
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 14 tests, all `ok`.

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml .gitignore feedwatch/__init__.py feedwatch/parse.py tests/__init__.py tests/test_parse.py
git commit -m "feat: package skeleton and RSS parsing"
```

---

### Task 2: `store` — the SQLite database

**Files:**
- Create: `feedwatch/store.py`, `tests/test_store.py`

**Interfaces:**
- Consumes: `feedwatch.parse.Entry` (Task 1).
- Produces:
  - Constants: `DEFAULT_PATH: Path` (`~/.feedwatch/feeds.db`), `DEFAULT_INTERVAL_MINUTES = 30`, `UNREAD_LIMIT = 20`, `MIGRATIONS: list[list[str]]`.
  - `AlreadySubscribed(Exception)` with attribute `url: str`.
  - `Feed` — frozen dataclass `Feed(id: int, url: str, title: str | None, interval_minutes: int, last_polled_at: datetime | None)`.
  - `UnreadEntry` — frozen dataclass `UnreadEntry(guid: str, title: str, link: str | None, when: datetime, feed: str)`; `when` is UTC; `feed` is the feed's title, or its URL when it has none.
  - `connect(path: Path | str = DEFAULT_PATH) -> sqlite3.Connection`
  - `add_feed(conn, url: str, title: str | None = None, interval_minutes: int = DEFAULT_INTERVAL_MINUTES) -> Feed` — raises `AlreadySubscribed`.
  - `feeds(conn) -> list[Feed]`
  - `due_feeds(conn, now: datetime) -> list[Feed]`
  - `mark_polled(conn, feed_id: int, at: datetime) -> None`
  - `add_entries(conn, feed_id: int, entries: Iterable[Entry], fetched_at: datetime) -> int` — returns how many were new.
  - `unread(conn, limit: int = UNREAD_LIMIT) -> list[UnreadEntry]`
  - `mark_read(conn, guids: Iterable[str]) -> list[str]` — returns the guids not stored.
  - All `datetime` arguments must be timezone-aware.

- [ ] **Step 1: Write the failing tests**

`tests/test_store.py`:

```python
import sqlite3
import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.parse import Entry

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
URL = "https://example.com/rss"


def entry(guid, published=None):
    return Entry(guid=guid, title=f"Title {guid}", link=None, published=published)


class StoreTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.path = self.dir / "feeds.db"
        self.conn = store.connect(self.path)
        self.addCleanup(self.conn.close)


class ConnectTest(StoreTestCase):
    def test_creates_missing_directory(self):
        path = self.dir / "home" / ".feedwatch" / "feeds.db"
        store.connect(path).close()
        self.assertTrue(path.exists())

    def test_reopening_keeps_data_and_schema_version(self):
        store.add_feed(self.conn, URL)
        self.conn.close()
        conn = store.connect(self.path)
        self.addCleanup(conn.close)
        self.assertEqual([f.url for f in store.feeds(conn)], [URL])
        self.assertEqual(
            conn.execute("PRAGMA user_version").fetchone()[0], len(store.MIGRATIONS)
        )

    def test_uses_wal_and_waits_for_locks(self):
        self.assertEqual(self.conn.execute("PRAGMA journal_mode").fetchone()[0], "wal")
        self.assertGreaterEqual(self.conn.execute("PRAGMA busy_timeout").fetchone()[0], 5000)

    def test_a_write_waits_for_another_connections_lock(self):
        locked = threading.Event()

        def hold_write_lock():
            other = sqlite3.connect(self.path, isolation_level=None)
            other.execute("BEGIN IMMEDIATE")
            locked.set()
            time.sleep(0.5)
            other.execute("COMMIT")
            other.close()

        holder = threading.Thread(target=hold_write_lock)
        holder.start()
        locked.wait()
        self.assertEqual(store.unread(self.conn), [])
        store.add_feed(self.conn, URL)
        holder.join()
        self.assertEqual(len(store.feeds(self.conn)), 1)


class FeedTest(StoreTestCase):
    def test_add_feed_defaults(self):
        feed = store.add_feed(self.conn, URL)
        self.assertEqual(
            (feed.url, feed.title, feed.interval_minutes, feed.last_polled_at),
            (URL, None, 30, None),
        )
        self.assertEqual(store.feeds(self.conn), [feed])

    def test_add_feed_with_title_and_interval(self):
        store.add_feed(self.conn, URL, title="Example", interval_minutes=5)
        [feed] = store.feeds(self.conn)
        self.assertEqual((feed.title, feed.interval_minutes), ("Example", 5))

    def test_duplicate_url_is_refused(self):
        store.add_feed(self.conn, URL)
        with self.assertRaises(store.AlreadySubscribed) as caught:
            store.add_feed(self.conn, URL)
        self.assertEqual(caught.exception.url, URL)
        self.assertEqual(len(store.feeds(self.conn)), 1)

    def test_mark_polled_round_trips(self):
        feed = store.add_feed(self.conn, URL)
        store.mark_polled(self.conn, feed.id, T0)
        [stored] = store.feeds(self.conn)
        self.assertEqual(stored.last_polled_at, T0)

    def test_due_feeds(self):
        never = store.add_feed(self.conn, "https://a.example/rss")
        recent = store.add_feed(self.conn, "https://b.example/rss")
        old = store.add_feed(self.conn, "https://c.example/rss")
        store.mark_polled(self.conn, recent.id, T0 - timedelta(minutes=29))
        store.mark_polled(self.conn, old.id, T0 - timedelta(minutes=30))
        self.assertEqual(
            {f.id for f in store.due_feeds(self.conn, T0)}, {never.id, old.id}
        )


class EntryTest(StoreTestCase):
    def setUp(self):
        super().setUp()
        self.feed = store.add_feed(self.conn, URL, title="Example")

    def test_add_entries_stores_each_once(self):
        self.assertEqual(
            store.add_entries(self.conn, self.feed.id, [entry("a"), entry("b")], T0), 2
        )
        self.assertEqual(
            store.add_entries(self.conn, self.feed.id, [entry("a"), entry("c")], T0), 1
        )
        self.assertEqual(sorted(e.guid for e in store.unread(self.conn)), ["a", "b", "c"])

    def test_duplicate_within_one_batch_is_stored_once(self):
        self.assertEqual(
            store.add_entries(self.conn, self.feed.id, [entry("a"), entry("a")], T0), 1
        )

    def test_same_guid_in_two_feeds_is_two_entries(self):
        other = store.add_feed(self.conn, "https://other.example/rss")
        store.add_entries(self.conn, self.feed.id, [entry("a")], T0)
        self.assertEqual(store.add_entries(self.conn, other.id, [entry("a")], T0), 1)

    def test_unread_newest_first_across_timezones_and_missing_dates(self):
        eastern = timezone(timedelta(hours=-5))
        store.add_entries(self.conn, self.feed.id, [
            entry("old", published=T0 - timedelta(days=1)),
            entry("new", published=(T0 + timedelta(hours=1)).astimezone(eastern)),
            entry("undated"),
        ], fetched_at=T0)
        self.assertEqual(
            [e.guid for e in store.unread(self.conn)], ["new", "undated", "old"]
        )

    def test_unread_entry_fields(self):
        store.add_entries(self.conn, self.feed.id, [
            Entry(guid="a", title="A", link="https://example.com/a", published=T0),
        ], fetched_at=T0)
        self.assertEqual(store.unread(self.conn), [store.UnreadEntry(
            guid="a", title="A", link="https://example.com/a", when=T0, feed="Example",
        )])

    def test_unread_names_an_untitled_feed_by_url(self):
        untitled = store.add_feed(self.conn, "https://untitled.example/rss")
        store.add_entries(self.conn, untitled.id, [entry("b", published=T0)], T0)
        self.assertEqual(
            [e.feed for e in store.unread(self.conn)], ["https://untitled.example/rss"]
        )

    def test_unread_limit(self):
        store.add_entries(self.conn, self.feed.id, [
            entry(f"e{i:02}", published=T0 + timedelta(minutes=i)) for i in range(25)
        ], T0)
        self.assertEqual(len(store.unread(self.conn)), 20)
        self.assertEqual(
            [e.guid for e in store.unread(self.conn, limit=2)], ["e24", "e23"]
        )

    def test_mark_read(self):
        store.add_entries(self.conn, self.feed.id, [entry("a"), entry("b")], T0)
        self.assertEqual(store.mark_read(self.conn, ["a"]), [])
        self.assertEqual([e.guid for e in store.unread(self.conn)], ["b"])

    def test_mark_read_reports_unknown_and_marks_the_rest(self):
        store.add_entries(self.conn, self.feed.id, [entry("a")], T0)
        self.assertEqual(store.mark_read(self.conn, ["a", "nope"]), ["nope"])
        self.assertEqual(store.unread(self.conn), [])

    def test_marking_twice_is_not_an_error(self):
        store.add_entries(self.conn, self.feed.id, [entry("a")], T0)
        store.mark_read(self.conn, ["a"])
        self.assertEqual(store.mark_read(self.conn, ["a"]), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: ERROR, `ImportError: cannot import name 'store' from 'feedwatch'`

- [ ] **Step 3: Implement `store`**

`feedwatch/store.py`:

```python
"""The SQLite database. Owns the schema; never touches the network."""

from __future__ import annotations

import sqlite3
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.parse import Entry

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"
DEFAULT_INTERVAL_MINUTES = 30
UNREAD_LIMIT = 20

# Migration N takes a database from PRAGMA user_version N-1 to N. Append only:
# a database already on disk is at some earlier version and must reach the last.
MIGRATIONS: list[list[str]] = [
    [
        """
        CREATE TABLE feeds (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT,
            interval_minutes INTEGER NOT NULL,
            last_polled_at TEXT
        )
        """,
        """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            feed_id INTEGER NOT NULL REFERENCES feeds (id),
            guid TEXT NOT NULL,
            title TEXT NOT NULL,
            link TEXT,
            published_at TEXT,
            fetched_at TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            UNIQUE (feed_id, guid)
        )
        """,
    ],
]

# Fixed-width UTC text, so ORDER BY on a time column is chronological.
_TIME_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


class AlreadySubscribed(Exception):
    """A feed with this URL is already stored."""

    def __init__(self, url: str) -> None:
        super().__init__(url)
        self.url = url


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    interval_minutes: int
    last_polled_at: datetime | None


@dataclass(frozen=True)
class UnreadEntry:
    """An unread entry as listed: ``when`` is its publication time, or when it
    was fetched if it has none; ``feed`` is the feed's title, or its URL."""

    guid: str
    title: str
    link: str | None
    when: datetime
    feed: str


def connect(path: Path | str = DEFAULT_PATH) -> sqlite3.Connection:
    """Open the database at ``path``, creating it and its directory if needed,
    and bring its schema up to date."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and the CLI share this file: WAL lets reads run during a write,
    # and the timeout makes a writer wait for the lock instead of failing.
    conn = sqlite3.connect(path, timeout=30, isolation_level=None)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    _migrate(conn)
    return conn


def add_feed(
    conn: sqlite3.Connection,
    url: str,
    title: str | None = None,
    interval_minutes: int = DEFAULT_INTERVAL_MINUTES,
) -> Feed:
    """Subscribe to ``url``. Raises AlreadySubscribed if it is already stored."""
    try:
        cursor = conn.execute(
            "INSERT INTO feeds (url, title, interval_minutes) VALUES (?, ?, ?)",
            (url, title, interval_minutes),
        )
    except sqlite3.IntegrityError as exc:
        raise AlreadySubscribed(url) from exc
    return Feed(cursor.lastrowid, url, title, interval_minutes, None)


def feeds(conn: sqlite3.Connection) -> list[Feed]:
    """Every subscribed feed, in the order they were added."""
    rows = conn.execute(
        "SELECT id, url, title, interval_minutes, last_polled_at FROM feeds ORDER BY id"
    )
    return [
        Feed(
            row["id"],
            row["url"],
            row["title"],
            row["interval_minutes"],
            None if row["last_polled_at"] is None else _from_text(row["last_polled_at"]),
        )
        for row in rows
    ]


def due_feeds(conn: sqlite3.Connection, now: datetime) -> list[Feed]:
    """The feeds never polled, or last polled at least their interval before ``now``."""
    return [
        feed
        for feed in feeds(conn)
        if feed.last_polled_at is None
        or feed.last_polled_at + timedelta(minutes=feed.interval_minutes) <= now
    ]


def mark_polled(conn: sqlite3.Connection, feed_id: int, at: datetime) -> None:
    conn.execute(
        "UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(at), feed_id)
    )


def add_entries(
    conn: sqlite3.Connection,
    feed_id: int,
    entries: Iterable[Entry],
    fetched_at: datetime,
) -> int:
    """Store the entries of feed ``feed_id`` not already stored; return how many were new."""
    added = 0
    with _transaction(conn):
        for entry in entries:
            cursor = conn.execute(
                """
                INSERT INTO entries (feed_id, guid, title, link, published_at, fetched_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT (feed_id, guid) DO NOTHING
                """,
                (
                    feed_id,
                    entry.guid,
                    entry.title,
                    entry.link,
                    None if entry.published is None else _to_text(entry.published),
                    _to_text(fetched_at),
                ),
            )
            added += cursor.rowcount
    return added


def unread(conn: sqlite3.Connection, limit: int = UNREAD_LIMIT) -> list[UnreadEntry]:
    """Up to ``limit`` unread entries, newest first."""
    rows = conn.execute(
        """
        SELECT e.guid, e.title, e.link,
               COALESCE(e.published_at, e.fetched_at) AS at,
               COALESCE(f.title, f.url) AS feed
        FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id
        WHERE NOT e.read
        ORDER BY at DESC, e.id DESC
        LIMIT ?
        """,
        (limit,),
    )
    return [
        UnreadEntry(row["guid"], row["title"], row["link"], _from_text(row["at"]), row["feed"])
        for row in rows
    ]


def mark_read(conn: sqlite3.Connection, guids: Iterable[str]) -> list[str]:
    """Mark every entry with one of ``guids`` read; return the guids not stored."""
    unknown = []
    with _transaction(conn):
        for guid in guids:
            cursor = conn.execute("UPDATE entries SET read = 1 WHERE guid = ?", (guid,))
            if cursor.rowcount == 0:
                unknown.append(guid)
    return unknown


@contextmanager
def _transaction(conn: sqlite3.Connection) -> Iterator[None]:
    conn.execute("BEGIN IMMEDIATE")
    try:
        yield
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    conn.execute("COMMIT")


def _migrate(conn: sqlite3.Connection) -> None:
    # The version is read inside an IMMEDIATE transaction, so a poller and a CLI
    # opening a new file at once cannot both apply the same migration.
    with _transaction(conn):
        version = conn.execute("PRAGMA user_version").fetchone()[0]
        for number, statements in enumerate(MIGRATIONS[version:], start=version + 1):
            for statement in statements:
                conn.execute(statement)
            conn.execute(f"PRAGMA user_version = {number}")


def _to_text(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime(_TIME_FORMAT)


def _from_text(text: str) -> datetime:
    return datetime.strptime(text, _TIME_FORMAT).replace(tzinfo=timezone.utc)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 19 tests, all `ok`.

- [ ] **Step 5: Run the whole suite**

Run: `python -m unittest -v`
Expected: all tests from Tasks 1–2 `ok`.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: SQLite store with versioned schema"
```

---

### Task 3: `fetch` — download a feed

**Files:**
- Create: `feedwatch/fetch.py`, `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.fetch.FetchError(Exception)`.
  - `feedwatch.fetch.TIMEOUT_SECONDS = 30`.
  - `feedwatch.fetch.fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes` — the response body; every failure (bad URL, DNS, refused connection, timeout, HTTP error status, broken response) raises `FetchError` whose message names the URL.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import http.server
import socket
import threading
import time
import unittest

from feedwatch.fetch import FetchError, fetch

BODY = b'<rss version="2.0"><channel></channel></rss>'


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/slow":
            # Accept the request and never answer.
            time.sleep(2)
            return
        if self.path == "/missing":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/rss+xml")
        self.send_header("Content-Length", str(len(BODY)))
        self.end_headers()
        self.wfile.write(BODY)

    def log_message(self, format, *args):
        pass


class FetchTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def test_returns_the_body(self):
        self.assertEqual(fetch(self.base + "/feed.xml"), BODY)

    def test_http_error_status_is_a_fetch_error(self):
        url = self.base + "/missing"
        with self.assertRaises(FetchError) as caught:
            fetch(url)
        self.assertIn("404", str(caught.exception))
        self.assertIn(url, str(caught.exception))

    def test_refused_connection_is_a_fetch_error(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        with self.assertRaises(FetchError):
            fetch(f"http://127.0.0.1:{port}/feed.xml")

    def test_unresponsive_server_times_out(self):
        started = time.monotonic()
        with self.assertRaises(FetchError):
            fetch(self.base + "/slow", timeout=0.5)
        self.assertLess(time.monotonic() - started, 1.5)

    def test_malformed_url_is_a_fetch_error(self):
        with self.assertRaises(FetchError):
            fetch("not a url")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.fetch'`

- [ ] **Step 3: Implement `fetch`**

`feedwatch/fetch.py`:

```python
"""Download a feed's XML. Owns HTTP; never parses."""

from __future__ import annotations

import http.client
import urllib.request

USER_AGENT = "feedwatch/1.0"
TIMEOUT_SECONDS = 30


class FetchError(Exception):
    """The feed could not be downloaded."""


def fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes:
    """Return the body served at ``url``.

    Raises FetchError for a malformed URL, any network failure, an HTTP error
    status, or no response within ``timeout`` seconds of a network operation.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    # URLError, HTTPError and timeouts are all OSErrors; ValueError is a malformed URL.
    except (OSError, http.client.HTTPException, ValueError) as exc:
        raise FetchError(f"{url}: {exc}") from exc
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 5 tests, all `ok`.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feeds over HTTP with a timeout"
```

---

### Task 4: `poller` — the long-running worker

**Files:**
- Create: `feedwatch/poller.py`, `tests/test_poller.py`

**Interfaces:**
- Consumes:
  - `feedwatch.fetch.fetch(url: str, timeout: float = ...) -> bytes`, `feedwatch.fetch.FetchError` (Task 3).
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]`, `feedwatch.parse.ParseError` (Task 1).
  - `feedwatch.store.connect`, `due_feeds(conn, now)`, `add_entries(conn, feed_id, entries, fetched_at) -> int`, `mark_polled(conn, feed_id, at)` (Task 2).
- Produces:
  - `feedwatch.poller.TICK_SECONDS = 30`.
  - `poll_once(conn, now: datetime, download: Callable[[str], bytes] = fetch) -> None`.
  - `run(conn, clock: Callable[[], datetime] = <UTC now>, sleep: Callable[[float], None] = time.sleep, download: Callable[[str], bytes] = fetch) -> None` — never returns normally.
  - `main() -> None`; `python -m feedwatch.poller` calls it.
  - Logger name: `feedwatch.poller`; a skipped feed logs at WARNING with the feed URL in the message.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import poller, store
from feedwatch.fetch import FetchError

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
A = "https://a.example/rss"
B = "https://b.example/rss"


def rss(*guids):
    items = "".join(f"<item><guid>{g}</guid><title>{g}</title></item>" for g in guids)
    return f'<rss version="2.0"><channel>{items}</channel></rss>'.encode()


class FakeWeb:
    """Stands in for fetch: serves canned bodies by URL and records requests."""

    def __init__(self, pages):
        self.pages = pages
        self.requested = []

    def __call__(self, url):
        self.requested.append(url)
        page = self.pages[url]
        if isinstance(page, Exception):
            raise page
        return page


class Stop(Exception):
    pass


class PollerTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.conn = store.connect(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.conn.close)

    def unread_guids(self):
        return sorted(e.guid for e in store.unread(self.conn))

    def test_stores_the_entries_of_a_due_feed(self):
        store.add_feed(self.conn, A)
        poller.poll_once(self.conn, T0, FakeWeb({A: rss("1", "2")}))
        self.assertEqual(self.unread_guids(), ["1", "2"])
        [feed] = store.feeds(self.conn)
        self.assertEqual(feed.last_polled_at, T0)

    def test_stores_each_entry_once_across_polls(self):
        store.add_feed(self.conn, A)
        poller.poll_once(self.conn, T0, FakeWeb({A: rss("1")}))
        poller.poll_once(self.conn, T0 + timedelta(minutes=30), FakeWeb({A: rss("1", "2")}))
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_waits_for_the_feeds_interval(self):
        store.add_feed(self.conn, A, interval_minutes=10)
        web = FakeWeb({A: rss("1")})
        poller.poll_once(self.conn, T0, web)
        poller.poll_once(self.conn, T0 + timedelta(minutes=9), web)
        poller.poll_once(self.conn, T0 + timedelta(minutes=10), web)
        self.assertEqual(web.requested, [A, A])

    def test_unfetchable_feed_is_logged_and_the_others_still_polled(self):
        store.add_feed(self.conn, A)
        store.add_feed(self.conn, B)
        web = FakeWeb({A: FetchError(f"{A}: connection refused"), B: rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.conn, T0, web)
        self.assertEqual(len(logs.output), 1)
        self.assertIn(A, logs.output[0])
        self.assertEqual(self.unread_guids(), ["b1"])

    def test_non_rss_feed_is_logged_and_the_others_still_polled(self):
        store.add_feed(self.conn, A)
        store.add_feed(self.conn, B)
        web = FakeWeb({A: b"<html><body>Moved</body></html>", B: rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.conn, T0, web)
        self.assertIn(A, logs.output[0])
        self.assertEqual(self.unread_guids(), ["b1"])

    def test_failed_feed_is_skipped_until_its_next_interval(self):
        store.add_feed(self.conn, A, interval_minutes=30)
        web = FakeWeb({A: FetchError(f"{A}: timed out")})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poller.poll_once(self.conn, T0, web)
            poller.poll_once(self.conn, T0 + timedelta(minutes=1), web)
        self.assertEqual(web.requested, [A])
        web.pages[A] = rss("1")
        poller.poll_once(self.conn, T0 + timedelta(minutes=30), web)
        self.assertEqual(self.unread_guids(), ["1"])

    def test_database_error_propagates(self):
        store.add_feed(self.conn, A)
        self.conn.execute("DROP TABLE entries")
        with self.assertRaises(sqlite3.Error):
            poller.poll_once(self.conn, T0, FakeWeb({A: rss("1")}))

    def test_run_polls_then_sleeps_each_tick(self):
        store.add_feed(self.conn, A)
        times = iter([T0, T0 + timedelta(minutes=30)])
        sleeps = []

        def sleep(seconds):
            sleeps.append(seconds)
            if len(sleeps) == 2:
                raise Stop

        web = FakeWeb({A: rss("1")})
        with self.assertRaises(Stop):
            poller.run(self.conn, clock=lambda: next(times), sleep=sleep, download=web)
        self.assertEqual(web.requested, [A, A])
        self.assertEqual(sleeps, [poller.TICK_SECONDS, poller.TICK_SECONDS])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR, `ImportError: cannot import name 'poller' from 'feedwatch'`

- [ ] **Step 3: Implement `poller`**

`feedwatch/poller.py`:

```python
"""The long-running worker. Owns the schedule; never presents anything.

Run with ``python -m feedwatch.poller``.
"""

from __future__ import annotations

import logging
import sqlite3
import time
from collections.abc import Callable
from datetime import datetime, timezone

from feedwatch import store
from feedwatch.fetch import FetchError, fetch
from feedwatch.parse import ParseError, parse

log = logging.getLogger("feedwatch.poller")

# Feeds added by the CLI are noticed at the next tick, and a due feed is
# polled within this many seconds of its interval coming up.
TICK_SECONDS = 30


def poll_once(
    conn: sqlite3.Connection,
    now: datetime,
    download: Callable[[str], bytes] = fetch,
) -> None:
    """Poll every feed due at ``now`` and store the entries not seen before.

    A feed that cannot be fetched or parsed is logged and left until its next
    interval. Database errors propagate.
    """
    for feed in store.due_feeds(conn, now):
        try:
            entries = parse(download(feed.url))
        except (FetchError, ParseError) as exc:
            log.warning("skipping %s until its next interval: %s", feed.url, exc)
        else:
            added = store.add_entries(conn, feed.id, entries, fetched_at=now)
            log.info("%s: %d new entries", feed.url, added)
        store.mark_polled(conn, feed.id, now)


def run(
    conn: sqlite3.Connection,
    clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
    sleep: Callable[[float], None] = time.sleep,
    download: Callable[[str], bytes] = fetch,
) -> None:
    """Poll due feeds every TICK_SECONDS, forever."""
    while True:
        poll_once(conn, clock(), download)
        sleep(TICK_SECONDS)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    conn = store.connect()
    try:
        run(conn)
    except KeyboardInterrupt:
        pass
    finally:
        conn.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 8 tests, all `ok`.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller that stores new entries on each feed's interval"
```

---

### Task 5: `cli` — the `feedwatch` command

**Files:**
- Create: `feedwatch/cli.py`, `feedwatch/__main__.py`, `tests/test_cli.py`

**Interfaces:**
- Consumes: `feedwatch.store` — `DEFAULT_PATH`, `DEFAULT_INTERVAL_MINUTES`, `UNREAD_LIMIT`, `AlreadySubscribed` (`.url`), `connect`, `add_feed`, `unread`, `mark_read`, `UnreadEntry` fields `guid, title, link, when, feed` (Task 2). Test seeding also uses `store.add_entries`, `store.feeds` and `feedwatch.parse.Entry`.
- Produces:
  - `feedwatch.cli.main(argv: list[str] | None = None, db_path: Path | str = store.DEFAULT_PATH) -> int` — exit status: 0 on success, 1 on a refusal (duplicate URL, unknown guid), 2 on bad arguments (raised as `SystemExit` by argparse). The `feedwatch` console script calls `main()`.
  - Output: refusals go to stderr, prefixed `feedwatch: `. `unread` prints, per entry, a header line `YYYY-MM-DD HH:MM  <feed>  <title>` (local time; `(untitled)` for an empty title), then `  <guid>`, then `  <link>` when the link differs from the guid; or `no unread entries`.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import contextlib
import io
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import cli, store
from feedwatch.parse import Entry

URL = "https://example.com/rss"
T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.db = Path(tmp.name) / "home" / ".feedwatch" / "feeds.db"

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = cli.main(list(argv), db_path=self.db)
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def stored_feeds(self):
        conn = store.connect(self.db)
        try:
            return store.feeds(conn)
        finally:
            conn.close()

    def seed(self, *guids):
        """Store one entry per guid in one feed; later guids are published later."""
        conn = store.connect(self.db)
        try:
            feed = store.add_feed(conn, URL, title="Example")
            store.add_entries(conn, feed.id, [
                Entry(
                    guid=guid,
                    title=f"Title {guid}",
                    link=f"https://example.com/{guid}",
                    published=T0 + timedelta(minutes=i),
                )
                for i, guid in enumerate(guids)
            ], fetched_at=T0)
        finally:
            conn.close()

    def test_add_on_first_run_creates_database(self):
        code, out, err = self.run_cli("add", URL)
        self.assertEqual((code, err), (0, ""))
        self.assertIn(URL, out)
        [feed] = self.stored_feeds()
        self.assertEqual((feed.url, feed.title, feed.interval_minutes), (URL, None, 30))

    def test_add_with_title_and_interval(self):
        code, _, _ = self.run_cli("add", URL, "--title", "Example", "--every", "5")
        self.assertEqual(code, 0)
        [feed] = self.stored_feeds()
        self.assertEqual((feed.title, feed.interval_minutes), ("Example", 5))

    def test_add_refuses_a_duplicate_naming_the_url(self):
        self.run_cli("add", URL)
        code, _, err = self.run_cli("add", URL)
        self.assertEqual(code, 1)
        self.assertIn(URL, err)
        self.assertEqual(len(self.stored_feeds()), 1)

    def test_add_refuses_something_that_is_not_a_url(self):
        code, _, err = self.run_cli("add", "example.com/rss")
        self.assertEqual(code, 2)
        self.assertIn("example.com/rss", err)
        self.assertEqual(self.stored_feeds(), [])

    def test_add_refuses_an_interval_below_one_minute(self):
        code, _, _ = self.run_cli("add", URL, "--every", "0")
        self.assertEqual(code, 2)
        self.assertEqual(self.stored_feeds(), [])

    def test_unread_when_nothing_unread(self):
        code, out, _ = self.run_cli("unread")
        self.assertEqual((code, out), (0, "no unread entries\n"))

    def test_unread_lists_newest_first_with_guid_and_link(self):
        self.seed("a", "b", "c")
        code, out, _ = self.run_cli("unread")
        self.assertEqual(code, 0)
        positions = [out.index(f"Title {g}") for g in ("c", "b", "a")]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("Example", out)
        self.assertIn("  a\n", out)
        self.assertIn("  https://example.com/a\n", out)

    def test_unread_shows_twenty_by_default(self):
        self.seed(*[f"e{i:02}" for i in range(25)])
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out.count("Title e"), 20)
        self.assertIn("Title e24", out)
        self.assertNotIn("Title e04", out)

    def test_unread_limit(self):
        self.seed(*[f"e{i:02}" for i in range(25)])
        _, out, _ = self.run_cli("unread", "--limit", "3")
        self.assertEqual(out.count("Title e"), 3)

    def test_unread_refuses_a_limit_below_one(self):
        code, _, _ = self.run_cli("unread", "--limit", "0")
        self.assertEqual(code, 2)

    def test_read_marks_entries_read(self):
        self.seed("a", "b")
        code, _, err = self.run_cli("read", "a", "b")
        self.assertEqual((code, err), (0, ""))
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out, "no unread entries\n")

    def test_read_refuses_an_unknown_guid_naming_it(self):
        self.seed("a")
        code, _, err = self.run_cli("read", "a", "nope")
        self.assertEqual(code, 1)
        self.assertIn("nope", err)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out, "no unread entries\n")

    def test_read_needs_at_least_one_guid(self):
        code, _, _ = self.run_cli("read")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR, `ImportError: cannot import name 'cli' from 'feedwatch'`

- [ ] **Step 3: Implement `cli` and `__main__`**

`feedwatch/cli.py`:

```python
"""The user's commands. Owns presentation; never polls."""

from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path
from urllib.parse import urlsplit

from feedwatch import store


def main(argv: list[str] | None = None, db_path: Path | str = store.DEFAULT_PATH) -> int:
    """Run one feedwatch command; return its exit status.

    Bad arguments raise SystemExit(2) from argparse.
    """
    args = _parser().parse_args(argv)
    conn = store.connect(db_path)
    try:
        return args.run(conn, args)
    finally:
        conn.close()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="feedwatch", description="Read your RSS feeds from the command line."
    )
    commands = parser.add_subparsers(required=True, metavar="COMMAND")

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", type=_feed_url, metavar="URL")
    add.add_argument("--title")
    add.add_argument(
        "--every",
        type=_positive_int,
        default=store.DEFAULT_INTERVAL_MINUTES,
        metavar="MINUTES",
        help="poll interval in minutes (default: %(default)s)",
    )
    add.set_defaults(run=_add)

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument(
        "--limit",
        type=_positive_int,
        default=store.UNREAD_LIMIT,
        metavar="N",
        help="how many to list (default: %(default)s)",
    )
    unread.set_defaults(run=_unread)

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    read.set_defaults(run=_read)

    return parser


def _add(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    try:
        feed = store.add_feed(conn, args.url, args.title, args.every)
    except store.AlreadySubscribed as exc:
        print(f"feedwatch: already subscribed to {exc.url}", file=sys.stderr)
        return 1
    print(f"subscribed to {feed.url}, polled every {feed.interval_minutes} minutes")
    return 0


def _unread(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    entries = store.unread(conn, args.limit)
    if not entries:
        print("no unread entries")
        return 0
    for entry in entries:
        when = entry.when.astimezone()
        print(f"{when:%Y-%m-%d %H:%M}  {entry.feed}  {entry.title or '(untitled)'}")
        print(f"  {entry.guid}")
        if entry.link and entry.link != entry.guid:
            print(f"  {entry.link}")
    return 0


def _read(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    unknown = store.mark_read(conn, args.guids)
    for guid in unknown:
        print(f"feedwatch: no stored entry has guid {guid}", file=sys.stderr)
    return 1 if unknown else 0


def _feed_url(value: str) -> str:
    parts = urlsplit(value)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise argparse.ArgumentTypeError(f"not an http(s) URL: {value}")
    return value


def _positive_int(value: str) -> int:
    try:
        number = int(value)
    except ValueError:
        number = 0
    if number < 1:
        raise argparse.ArgumentTypeError(f"must be a whole number of at least 1: {value}")
    return number
```

`feedwatch/__main__.py`:

```python
from feedwatch.cli import main

raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 13 tests, all `ok`.

- [ ] **Step 5: Run the whole suite**

Run: `python -m unittest -v`
Expected: 59 tests, all `ok`.

- [ ] **Step 6: Smoke-test the installed command end to end**

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
SMOKE=$(mktemp -d)
mkdir "$SMOKE/site"
cat > "$SMOKE/site/feed.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Smoke</title>
<item><guid>s1</guid><title>First post</title><link>http://127.0.0.1:8765/1</link>
<pubDate>Sun, 01 Mar 2026 12:00:00 +0000</pubDate></item>
<item><guid>s2</guid><title>Second post</title><link>http://127.0.0.1:8765/2</link>
<pubDate>Mon, 02 Mar 2026 12:00:00 +0000</pubDate></item>
</channel></rss>
EOF
python3 -m http.server 8765 --bind 127.0.0.1 --directory "$SMOKE/site" &
SERVER=$!
HOME="$SMOKE" .venv/bin/feedwatch add http://127.0.0.1:8765/feed.xml --title Smoke
HOME="$SMOKE" .venv/bin/feedwatch add http://127.0.0.1:8765/missing.xml
HOME="$SMOKE" timeout 5 .venv/bin/python -m feedwatch.poller
HOME="$SMOKE" .venv/bin/feedwatch unread
HOME="$SMOKE" .venv/bin/feedwatch read s1 s2
HOME="$SMOKE" .venv/bin/feedwatch unread
kill $SERVER
```

Expected:
- Both `add` commands print `subscribed to ..., polled every 30 minutes`.
- The poller logs a WARNING `skipping http://127.0.0.1:8765/missing.xml until its next interval: ... HTTP Error 404 ...` and an INFO `http://127.0.0.1:8765/feed.xml: 2 new entries`, then is stopped by `timeout`.
- The first `unread` lists `Second post` above `First post`, each with its guid line.
- `read s1 s2` exits 0; the second `unread` prints `no unread entries`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/cli.py feedwatch/__main__.py tests/test_cli.py
git commit -m "feat: feedwatch command: add, unread, read"
```
````


## p004

#### Final message

The implementation plan is written and committed. It's at `docs/superpowers/plans/2026-10-12-feedwatch-v1.md` in /home/wogi/projects/dopamine/.dopamine/run/program-design/red/greenfield/runs/F0-6, commit `c9a67ce`. The repo was on `master`, so I made a new branch `feedwatch-v1` for the commit. Nothing was implemented in the repo.

**What it builds:** Python 3.11+ using only the standard library at runtime; `pytest` is the one dev dependency, and `uv` runs everything. There are six tasks, each test-first:
1. Project files and the RSS parser.
2. Fetching over HTTP with a 30-second timeout.
3. The SQLite database (`~/.feedwatch/feeds.db`) and feed subscriptions. The schema has version numbers so an existing database keeps working as it grows, and both processes can use the file at the same time.
4. Storing new entries once, listing unread ones newest first, and marking them read.
5. The poller (`python -m feedwatch.poller`). It checks every 60 seconds, logs and skips a feed that can't be fetched or isn't RSS, and stops on a database error.
6. The `feedwatch add` / `unread` / `read` commands, then an end-to-end check against a local HTTP server.

**Checked:** I put the plan's code together in a scratch directory outside the repo and ran it. All 59 tests passed and the end-to-end check printed what the plan says it should. This found one bug, now fixed in the plan: a URL without a scheme made `fetch` crash instead of reporting a fetch error.

**Decisions I made where the spec says nothing** (listed in the plan for review):
- "RSS" means the RSS 0.91–2.0 family. RSS 1.0 (RDF) is treated like Atom: logged and skipped.
- An entry with neither a guid nor a link is left out.
- `read GUID` marks that guid read in every feed that has it. If any guid is unknown, it names all of them and marks nothing.
- Entries with no date are sorted by when they were first stored and shown as "undated".
- A failed poll still counts, so the feed is tried again one interval later.
- `add` accepts only http/https URLs. `--every` and `--limit` must be at least 1.
- Exit codes: 1 for a refusal, 2 for bad arguments.

**Inputs the spec doesn't mention that the plan tests:**
- The first run, when `~/.feedwatch/` doesn't exist yet.
- A feed server that connects but never answers.
- Entries with no date or a malformed one.
- Bad values for `--every`, `--limit` or the URL.
- Running a command while the poller is writing to the database.

**Docs:** `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are listed as living documents in `.dopamine/config` but don't exist. The plan's closing section says so and tells whoever runs it to record new facts in the ledger and run `dopamine:finishing-work`, not edit DESIGN.md or ARCHITECTURE.md mid-way.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a long-running poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five modules, one per component in `docs/ARCHITECTURE.md`: `fetch` (HTTP only), `parse` (RSS XML to entries), `store` (the SQLite schema and every query), `poller` (the schedule; calls fetch, parse, store) and `cli` (presentation; calls store only). Both processes open `~/.feedwatch/feeds.db`; the database runs in WAL mode with a busy timeout so the CLI and the poller can use it at the same time. The schema is versioned with `PRAGMA user_version` so later features can add to it without breaking an existing database.

**Tech Stack:** Python 3.11+, standard library only at runtime (`urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`). `pytest` as the only development dependency. `uv` runs everything; `hatchling` builds the package.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, which it points to).

## Global Constraints

- Standard library first; a dependency has to earn its place. No runtime dependencies; `pytest` is a dev-only dependency group.
- Database: one SQLite file, `~/.feedwatch/feeds.db`, tables `feeds` and `entries`. `store` owns the schema; an existing database has to keep working as the schema grows.
- Module boundaries: `fetch` never parses; `parse` never stores; `store` never touches the network; `poller` never presents anything; `cli` never polls. `poller` calls `fetch`, `parse`, `store`; `cli` calls only `store`; only `poller` calls `fetch`.
- `feedwatch add URL [--title TITLE] [--every MINUTES]` — interval defaults to 30 minutes; a URL already subscribed to is refused with a message naming the URL.
- `feedwatch unread [--limit N]` — unread entries, newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` — a guid that is not stored is refused with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores entries not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; other feeds are still polled. A database error stops the poller.
- Out of scope: Atom feeds; importing or exporting subscription lists.

## Review Focus

1. **First run on a machine with no `~/.feedwatch/` directory** — the first `feedwatch add` (or poller start) creates the directory and the database instead of failing with "unable to open database file". Pinned in Task 3 (`test_open_db_creates_missing_directory`).
2. **A feed server that accepts the connection and never answers** — the fetch times out and the feed is skipped, so one dead host cannot stall every other feed forever. Pinned in Task 2 (`test_slow_server_times_out`).
3. **Items with no `pubDate`, or a date in a format that is not RFC 822** — the entry is still stored and listed (ordered by when it was first seen, shown as "undated"), not dropped and not a crash. Pinned in Task 1 (`test_missing_or_malformed_date_is_none`), Task 4 (`test_undated_entries_sort_by_when_first_seen`) and Task 6 (`test_unread_shows_untitled_undated_entry`).
4. **`--every 0`, a negative interval, `--limit 0`, or a URL without `http(s)://`** — refused by argument parsing with exit code 2 and nothing written, rather than a feed polled every tick, an always-empty listing, or a subscription the poller can never fetch. Pinned in Task 6 (`test_refuses_bad_arguments`).
5. **Running a CLI command while the poller is mid-write** — the command waits for the write to finish instead of failing with "database is locked". Pinned in Task 3 (`test_a_write_waits_for_another_connections_write`, `test_reads_are_not_blocked_by_an_open_write`).

## Decisions this plan makes where the spec is silent

- RSS means the RSS 0.91–2.0 family: a root `<rss>` with a `<channel>` of `<item>`s. RSS 1.0 (RDF) is treated like Atom — "not an RSS feed", logged and skipped.
- An item with neither a guid nor a link cannot be identified, so it is left out; the rest of the feed is stored.
- `feedwatch read GUID` marks every stored entry with that guid, whichever feed it came from. If any guid is unknown, the command names every unknown guid and marks nothing.
- "Newest first" orders by the item's `pubDate`, falling back to when the poller first stored it.
- A failed poll still counts as a poll: the feed's next attempt is one interval later.
- The poller wakes every 60 seconds and polls whatever is due, so a feed added while it runs is picked up within a minute.
- The CLI accepts only `http` and `https` URLs.
- Exit codes: 0 on success, 1 for a refusal (duplicate URL, unknown guid), 2 for bad arguments (argparse's own).

## File Structure

```
pyproject.toml                 package metadata, console script, pytest dev group
.gitignore                     + .venv/, .pytest_cache/
src/feedwatch/__init__.py      package marker
src/feedwatch/parse.py         Entry, ParseError, parse(xml) -> list[Entry]
src/feedwatch/fetch.py         FetchError, fetch(url, timeout) -> bytes
src/feedwatch/store.py         open_db, schema migrations, Feed/StoredEntry, every query
src/feedwatch/poller.py        poll_once, run, main; `python -m feedwatch.poller`
src/feedwatch/cli.py           argparse commands add / unread / read; main(argv, db_path) -> int
tests/test_parse.py
tests/test_fetch.py
tests/test_store_feeds.py
tests/test_store_entries.py
tests/test_poller.py
tests/test_cli.py
```

---

### Task 1: Project skeleton and the RSS parser

**Files:**
- Create: `pyproject.toml`
- Modify: `.gitignore`
- Create: `src/feedwatch/__init__.py`
- Create: `src/feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.parse.Entry` — frozen dataclass `Entry(guid: str, title: str | None, link: str | None, published: datetime | None)`; `published` is timezone-aware UTC when present.
  - `feedwatch.parse.ParseError(Exception)`.
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]` — entries in document order; raises `ParseError` when `xml` is not well-formed or not RSS.

- [ ] **Step 1: Create the project files**

`pyproject.toml`:

```toml
[project]
name = "feedwatch"
version = "0.1.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:main"

[dependency-groups]
dev = ["pytest>=8"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

Append to `.gitignore` (it already contains `__pycache__/`):

```
.venv/
.pytest_cache/
```

`src/feedwatch/__init__.py`:

```python
"""Poll RSS feeds into a local SQLite database and read them from the command line."""
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
from datetime import datetime, timezone

import pytest

from feedwatch.parse import Entry, ParseError, parse


def rss(*items: str) -> bytes:
    return (
        "<?xml version='1.0' encoding='utf-8'?>"
        "<rss version='2.0'><channel><title>Example</title>"
        + "".join(items)
        + "</channel></rss>"
    ).encode()


def test_reads_guid_title_link_and_date_of_each_item():
    xml = rss(
        "<item><guid>a-1</guid><title>First</title><link>https://example.com/1</link>"
        "<pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>",
        "<item><guid>a-2</guid><title>Second</title><link>https://example.com/2</link>"
        "<pubDate>Tue, 03 Mar 2026 10:00:00 +0100</pubDate></item>",
    )
    assert parse(xml) == [
        Entry("a-1", "First", "https://example.com/1", datetime(2026, 3, 2, 9, 0, tzinfo=timezone.utc)),
        Entry("a-2", "Second", "https://example.com/2", datetime(2026, 3, 3, 9, 0, tzinfo=timezone.utc)),
    ]


def test_guid_falls_back_to_link_when_missing_or_blank():
    xml = rss(
        "<item><title>No guid</title><link>https://example.com/1</link></item>",
        "<item><guid>  </guid><link>https://example.com/2</link></item>",
    )
    assert [entry.guid for entry in parse(xml)] == ["https://example.com/1", "https://example.com/2"]


def test_item_without_guid_or_link_is_left_out():
    xml = rss(
        "<item><title>Unidentifiable</title></item>",
        "<item><guid>kept</guid></item>",
    )
    assert [entry.guid for entry in parse(xml)] == ["kept"]


def test_missing_or_malformed_date_is_none():
    xml = rss(
        "<item><guid>no-date</guid></item>",
        "<item><guid>bad-date</guid><pubDate>yesterday</pubDate></item>",
    )
    assert [entry.published for entry in parse(xml)] == [None, None]


def test_minus_zero_zone_is_read_as_utc():
    xml = rss("<item><guid>z</guid><pubDate>Mon, 02 Mar 2026 09:00:00 -0000</pubDate></item>")
    assert parse(xml)[0].published == datetime(2026, 3, 2, 9, 0, tzinfo=timezone.utc)


def test_channel_without_items_has_no_entries():
    assert parse(rss()) == []


@pytest.mark.parametrize(
    "xml",
    [
        b"",
        b"this is not xml",
        b"<html><body><p>Moved<br></p></body></html>",
        b"<html><body><p>Moved</p></body></html>",
        b"<feed xmlns='http://www.w3.org/2005/Atom'><entry/></feed>",
        b"<rss version='2.0'/>",
    ],
)
def test_rejects_documents_that_are_not_rss(xml):
    with pytest.raises(ParseError):
        parse(xml)
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `uv run pytest tests/test_parse.py -v`
Expected: collection error, `ModuleNotFoundError: No module named 'feedwatch.parse'`. (`uv run` creates `.venv` and `uv.lock` on first use.)

- [ ] **Step 4: Write the implementation**

`src/feedwatch/parse.py`:

```python
"""Turn RSS XML into entries."""

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime


class ParseError(Exception):
    """The document is not well-formed XML, or is not an RSS feed."""


@dataclass(frozen=True)
class Entry:
    guid: str
    title: str | None
    link: str | None
    published: datetime | None


def parse(xml: bytes) -> list[Entry]:
    """Return the feed's entries in document order.

    An entry's guid is the item's <guid>, or its <link> when it has none;
    items with neither are left out. `published` is UTC, or None when the
    item has no readable <pubDate>. Raises ParseError if `xml` is not an
    RSS 0.91-2.0 document.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ParseError(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise ParseError(f"not an RSS feed (root element <{root.tag}>)")

    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            Entry(
                guid=guid,
                title=_text(item, "title"),
                link=link,
                published=_date(_text(item, "pubDate")),
            )
        )
    return entries


def _text(element: ET.Element, tag: str) -> str | None:
    child = element.find(tag)
    if child is None or child.text is None:
        return None
    return child.text.strip() or None


def _date(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        moment = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if moment.tzinfo is None:
        # parsedate_to_datetime returns a naive datetime for the "-0000" zone, which RFC 5322 defines as UTC.
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `uv run pytest tests/test_parse.py -v`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml uv.lock .gitignore src/feedwatch/__init__.py src/feedwatch/parse.py tests/test_parse.py
git commit -m "feat: project skeleton and RSS parser"
```

---

### Task 2: Fetching a feed

**Files:**
- Create: `src/feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.fetch.FetchError(Exception)` — its message says why (e.g. `"HTTP Error 404: Not Found"`, `"timed out"`); it does not repeat the URL.
  - `feedwatch.fetch.fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes` — the response body; raises `FetchError` on any network error, timeout or HTTP error status.
  - `feedwatch.fetch.TIMEOUT_SECONDS = 30`.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import http.server
import threading
import time

import pytest

from feedwatch.fetch import FetchError, fetch

FEED = b"<rss version='2.0'><channel/></rss>"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/feed":
            self._reply(FEED)
        elif self.path == "/agent":
            self._reply(self.headers["User-Agent"].encode())
        elif self.path == "/slow":
            time.sleep(1)
            self._reply(FEED)
        else:
            self.send_error(404)

    def _reply(self, body):
        try:
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except OSError:
            pass  # The client in test_slow_server_times_out has already hung up.

    def log_message(self, *args):
        pass


@pytest.fixture
def server():
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}"
    httpd.shutdown()
    httpd.server_close()


def test_returns_the_body(server):
    assert fetch(f"{server}/feed") == FEED


def test_sends_a_feedwatch_user_agent(server):
    assert fetch(f"{server}/agent").startswith(b"feedwatch/")


def test_http_error_status_raises(server):
    with pytest.raises(FetchError, match="404"):
        fetch(f"{server}/missing")


def test_slow_server_times_out(server):
    with pytest.raises(FetchError):
        fetch(f"{server}/slow", timeout=0.2)


def test_unreachable_host_raises():
    with pytest.raises(FetchError):
        fetch("http://127.0.0.1:1/feed", timeout=2)


def test_malformed_url_raises():
    with pytest.raises(FetchError):
        fetch("not a url")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run pytest tests/test_fetch.py -v`
Expected: collection error, `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 3: Write the implementation**

`src/feedwatch/fetch.py`:

```python
"""Download a feed's XML."""

import http.client
import urllib.request

# Some hosts refuse urllib's default User-Agent.
USER_AGENT = "feedwatch/0.1"
TIMEOUT_SECONDS = 30


class FetchError(Exception):
    """The feed could not be downloaded."""


def fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes:
    """Return the body served at `url`.

    Raises FetchError on a network error, a timeout, an HTTP error status
    or a URL urllib cannot request.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as exc:
        raise FetchError(str(exc) or type(exc).__name__) from exc
```

(`urllib.error.URLError`, `HTTPError`, `TimeoutError` and connection errors are all `OSError` subclasses; `ValueError` covers a URL with no scheme, which `Request` itself raises, so it is built inside the `try`; `HTTPException` covers a truncated or garbled response. The parser is the standard library's `xml.etree.ElementTree` rather than `defusedxml`: Python's bundled expat does not resolve external entities and, from expat 2.4.1, limits entity expansion, so the stdlib-first principle holds.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run pytest tests/test_fetch.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feeds over HTTP with a timeout"
```

---

### Task 3: The database and feed subscriptions

**Files:**
- Create: `src/feedwatch/store.py`
- Test: `tests/test_store_feeds.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.store.DEFAULT_DB_PATH: Path` — `~/.feedwatch/feeds.db`.
  - `feedwatch.store.MIGRATIONS: list[str]`.
  - `feedwatch.store.open_db(path: Path = DEFAULT_DB_PATH) -> sqlite3.Connection` — creates the parent directory, enables WAL and a 30-second busy timeout, brings the schema up to date.
  - `feedwatch.store.Feed` — frozen dataclass `Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)`.
  - `feedwatch.store.DuplicateFeed(Exception)` with attribute `.url: str`.
  - `feedwatch.store.add_feed(conn, url: str, title: str | None = None, every_minutes: int = 30) -> Feed` — raises `DuplicateFeed`.
  - `feedwatch.store.feeds(conn) -> list[Feed]` — in subscription order.
  - `feedwatch.store.due_feeds(conn, now: datetime) -> list[Feed]` — never polled, or polled at least `every_minutes` before `now`.
  - `feedwatch.store.mark_polled(conn, feed_id: int, now: datetime) -> None`.
  - All `datetime` arguments are timezone-aware.

- [ ] **Step 1: Write the failing tests**

`tests/test_store_feeds.py`:

```python
import sqlite3
import threading
from datetime import datetime, timedelta, timezone

import pytest

from feedwatch import store

URL = "https://a.example/feed"
T0 = datetime(2026, 3, 2, 9, 0, tzinfo=timezone.utc)


@pytest.fixture
def conn(tmp_path):
    connection = store.open_db(tmp_path / "feeds.db")
    yield connection
    connection.close()


def test_open_db_creates_missing_directory(tmp_path):
    path = tmp_path / "home" / ".feedwatch" / "feeds.db"
    store.open_db(path).close()
    assert path.exists()


def test_reopening_keeps_data_and_schema_version(tmp_path):
    path = tmp_path / "feeds.db"
    first = store.open_db(path)
    store.add_feed(first, URL)
    first.close()

    second = store.open_db(path)
    assert [feed.url for feed in store.feeds(second)] == [URL]
    assert second.execute("PRAGMA user_version").fetchone()[0] == len(store.MIGRATIONS)
    second.close()


def test_add_feed_defaults_to_thirty_minutes(conn):
    feed = store.add_feed(conn, URL)
    assert (feed.url, feed.title, feed.every_minutes, feed.last_polled_at) == (URL, None, 30, None)
    assert store.feeds(conn) == [feed]


def test_add_feed_keeps_title_and_interval(conn):
    store.add_feed(conn, URL, "Example", 15)
    [feed] = store.feeds(conn)
    assert (feed.title, feed.every_minutes) == ("Example", 15)


def test_add_feed_refuses_a_url_already_subscribed(conn):
    store.add_feed(conn, URL)
    with pytest.raises(store.DuplicateFeed) as refused:
        store.add_feed(conn, URL, "Again", 5)
    assert refused.value.url == URL
    assert len(store.feeds(conn)) == 1


def test_new_feed_is_due(conn):
    feed = store.add_feed(conn, URL)
    assert store.due_feeds(conn, T0) == [feed]


def test_feed_is_due_again_once_its_interval_is_up(conn):
    feed = store.add_feed(conn, URL, every_minutes=30)
    store.mark_polled(conn, feed.id, T0)
    assert store.due_feeds(conn, T0 + timedelta(minutes=29)) == []
    assert [f.id for f in store.due_feeds(conn, T0 + timedelta(minutes=30))] == [feed.id]
    assert store.feeds(conn)[0].last_polled_at == T0


def test_reads_are_not_blocked_by_an_open_write(tmp_path):
    path = tmp_path / "feeds.db"
    writer = store.open_db(path)
    store.add_feed(writer, URL)
    writer.execute("BEGIN IMMEDIATE")
    writer.execute("INSERT INTO feeds (url, every_minutes) VALUES ('https://b.example/feed', 30)")

    reader = store.open_db(path)
    assert [feed.url for feed in store.feeds(reader)] == [URL]
    writer.rollback()


def test_a_write_waits_for_another_connections_write(tmp_path):
    path = tmp_path / "feeds.db"
    store.open_db(path).close()
    holder = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
    holder.execute("BEGIN IMMEDIATE")
    threading.Timer(0.3, holder.execute, args=("COMMIT",)).start()

    conn = store.open_db(path)
    store.add_feed(conn, URL)
    assert [feed.url for feed in store.feeds(conn)] == [URL]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run pytest tests/test_store_feeds.py -v`
Expected: collection error, `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`src/feedwatch/store.py`:

```python
"""The SQLite database: subscribed feeds and the entries they brought."""

import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEFAULT_DB_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Migration N brings the schema from user_version N-1 to N. Append new
# steps and never edit a shipped one: databases already at a later version
# will not run it again.
MIGRATIONS = [
    """
    CREATE TABLE feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled_at TEXT
    );
    CREATE TABLE entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT,
        link TEXT,
        published_at TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    );
    CREATE INDEX entries_by_guid ON entries (guid);
    """,
]


class DuplicateFeed(Exception):
    """A feed with this URL is already subscribed."""

    def __init__(self, url: str):
        super().__init__(url)
        self.url = url


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None


def open_db(path: Path = DEFAULT_DB_PATH) -> sqlite3.Connection:
    """Open the database at `path`, creating it and its directory if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and the CLI share this file: WAL lets one read while the
    # other writes, and the timeout makes a second writer wait, not fail.
    conn = sqlite3.connect(path, timeout=30)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    for number, script in enumerate(MIGRATIONS[version:], start=version + 1):
        conn.executescript(f"BEGIN; {script} PRAGMA user_version = {number}; COMMIT;")
    return conn


def add_feed(
    conn: sqlite3.Connection, url: str, title: str | None = None, every_minutes: int = 30
) -> Feed:
    """Subscribe to `url`. Raises DuplicateFeed if it is already subscribed."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as exc:
        raise DuplicateFeed(url) from exc
    return Feed(cursor.lastrowid, url, title, every_minutes, None)


def feeds(conn: sqlite3.Connection) -> list[Feed]:
    """Every subscribed feed, in the order they were added."""
    rows = conn.execute(
        "SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id"
    )
    return [Feed(id, url, title, every, _moment(polled)) for id, url, title, every, polled in rows]


def due_feeds(conn: sqlite3.Connection, now: datetime) -> list[Feed]:
    """Feeds never polled, or last polled at least their interval before `now`."""
    return [
        feed
        for feed in feeds(conn)
        if feed.last_polled_at is None
        or now >= feed.last_polled_at + timedelta(minutes=feed.every_minutes)
    ]


def mark_polled(conn: sqlite3.Connection, feed_id: int, now: datetime) -> None:
    with conn:
        conn.execute("UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_iso(now), feed_id))


def _iso(moment: datetime) -> str:
    # One fixed UTC format, so ORDER BY on the text sorts chronologically.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _moment(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run pytest tests/test_store_feeds.py -v`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/feedwatch/store.py tests/test_store_feeds.py
git commit -m "feat: SQLite store with versioned schema and feed subscriptions"
```

---

### Task 4: Storing, listing and marking entries

**Files:**
- Modify: `src/feedwatch/store.py`
- Test: `tests/test_store_entries.py`

**Interfaces:**
- Consumes: `feedwatch.parse.Entry` (Task 1); `open_db`, `add_feed`, `_iso`, `_moment` from `store` (Task 3).
- Produces:
  - `feedwatch.store.StoredEntry` — frozen dataclass `StoredEntry(guid: str, title: str | None, link: str | None, published_at: datetime | None, feed_title: str | None, feed_url: str)`.
  - `feedwatch.store.UnknownGuids(Exception)` with attribute `.guids: list[str]`.
  - `feedwatch.store.store_entries(conn, feed_id: int, entries: list[Entry], now: datetime) -> int` — number of entries that were new.
  - `feedwatch.store.unread(conn, limit: int) -> list[StoredEntry]` — newest first.
  - `feedwatch.store.mark_read(conn, guids: list[str]) -> None` — raises `UnknownGuids` and marks nothing if any guid is not stored.

- [ ] **Step 1: Write the failing tests**

`tests/test_store_entries.py`:

```python
from datetime import datetime, timedelta, timezone

import pytest

from feedwatch import store
from feedwatch.parse import Entry

T0 = datetime(2026, 3, 2, 9, 0, tzinfo=timezone.utc)


@pytest.fixture
def conn(tmp_path):
    connection = store.open_db(tmp_path / "feeds.db")
    yield connection
    connection.close()


@pytest.fixture
def feed(conn):
    return store.add_feed(conn, "https://a.example/feed", "Example")


def entry(guid, published=None):
    return Entry(guid, f"Post {guid}", f"https://a.example/{guid}", published)


def test_new_entries_are_stored_unread(conn, feed):
    assert store.store_entries(conn, feed.id, [entry("a1", T0)], T0) == 1
    assert store.unread(conn, 20) == [
        store.StoredEntry("a1", "Post a1", "https://a.example/a1", T0, "Example", "https://a.example/feed")
    ]


def test_an_entry_seen_again_is_stored_once(conn, feed):
    store.store_entries(conn, feed.id, [entry("a1")], T0)
    assert store.store_entries(conn, feed.id, [entry("a1"), entry("a2")], T0 + timedelta(hours=1)) == 1
    assert sorted(e.guid for e in store.unread(conn, 20)) == ["a1", "a2"]


def test_the_same_guid_in_two_feeds_is_two_entries(conn, feed):
    other = store.add_feed(conn, "https://b.example/feed")
    store.store_entries(conn, feed.id, [entry("same")], T0)
    store.store_entries(conn, other.id, [entry("same")], T0)
    assert len(store.unread(conn, 20)) == 2


def test_unread_is_newest_first_and_limited(conn, feed):
    store.store_entries(
        conn,
        feed.id,
        [entry("mid", T0 + timedelta(days=1)), entry("old", T0), entry("new", T0 + timedelta(days=2))],
        T0,
    )
    assert [e.guid for e in store.unread(conn, 20)] == ["new", "mid", "old"]
    assert [e.guid for e in store.unread(conn, 2)] == ["new", "mid"]


def test_undated_entries_sort_by_when_first_seen(conn, feed):
    store.store_entries(conn, feed.id, [entry("dated", T0 + timedelta(hours=1))], T0)
    store.store_entries(conn, feed.id, [entry("undated")], T0 + timedelta(hours=2))
    assert [e.guid for e in store.unread(conn, 20)] == ["undated", "dated"]


def test_mark_read_removes_entries_from_unread(conn, feed):
    store.store_entries(conn, feed.id, [entry("a1"), entry("a2"), entry("a3")], T0)
    store.mark_read(conn, ["a1", "a3"])
    assert [e.guid for e in store.unread(conn, 20)] == ["a2"]


def test_mark_read_accepts_an_already_read_guid(conn, feed):
    store.store_entries(conn, feed.id, [entry("a1")], T0)
    store.mark_read(conn, ["a1"])
    store.mark_read(conn, ["a1"])
    assert store.unread(conn, 20) == []


def test_mark_read_refuses_unknown_guids_and_marks_nothing(conn, feed):
    store.store_entries(conn, feed.id, [entry("a1")], T0)
    with pytest.raises(store.UnknownGuids) as refused:
        store.mark_read(conn, ["a1", "nope", "nada"])
    assert refused.value.guids == ["nope", "nada"]
    assert [e.guid for e in store.unread(conn, 20)] == ["a1"]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run pytest tests/test_store_entries.py -v`
Expected: FAIL with `AttributeError: module 'feedwatch.store' has no attribute 'store_entries'` (and `StoredEntry`, `mark_read`, `UnknownGuids`).

- [ ] **Step 3: Write the implementation**

In `src/feedwatch/store.py`, add below the existing imports:

```python
from feedwatch.parse import Entry
```

Add after the `DuplicateFeed` class:

```python
class UnknownGuids(Exception):
    """No stored entry has these guids."""

    def __init__(self, guids: list[str]):
        super().__init__(", ".join(guids))
        self.guids = guids
```

Add after the `Feed` dataclass:

```python
@dataclass(frozen=True)
class StoredEntry:
    guid: str
    title: str | None
    link: str | None
    published_at: datetime | None
    feed_title: str | None
    feed_url: str
```

Add after `mark_polled`:

```python
def store_entries(
    conn: sqlite3.Connection, feed_id: int, entries: list[Entry], now: datetime
) -> int:
    """Store the entries this feed has not brought before; return how many were new."""
    new = 0
    with conn:
        for entry in entries:
            cursor = conn.execute(
                "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published_at, seen_at)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (
                    feed_id,
                    entry.guid,
                    entry.title,
                    entry.link,
                    None if entry.published is None else _iso(entry.published),
                    _iso(now),
                ),
            )
            new += cursor.rowcount
    return new


def unread(conn: sqlite3.Connection, limit: int) -> list[StoredEntry]:
    """Up to `limit` unread entries, newest first.

    An entry without a publication date counts as published when it was first stored.
    """
    rows = conn.execute(
        """
        SELECT e.guid, e.title, e.link, e.published_at, f.title, f.url
        FROM entries e JOIN feeds f ON f.id = e.feed_id
        WHERE e.read = 0
        ORDER BY COALESCE(e.published_at, e.seen_at) DESC, e.id DESC
        LIMIT ?
        """,
        (limit,),
    )
    return [
        StoredEntry(guid, title, link, _moment(published), feed_title, feed_url)
        for guid, title, link, published, feed_title, feed_url in rows
    ]


def mark_read(conn: sqlite3.Connection, guids: list[str]) -> None:
    """Mark every entry with one of `guids` read, in whichever feed it is.

    Raises UnknownGuids, naming each guid that is not stored, and marks
    nothing if any of them is unknown.
    """
    with conn:
        unknown = [
            guid
            for guid in dict.fromkeys(guids)
            if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None
        ]
        if unknown:
            raise UnknownGuids(unknown)
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run pytest -v`
Expected: all PASS (Tasks 1–4).

- [ ] **Step 5: Commit**

```bash
git add src/feedwatch/store.py tests/test_store_entries.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 5: The poller

**Files:**
- Create: `src/feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch.fetch`, `fetch.FetchError` (Task 2); `parse.parse`, `parse.ParseError` (Task 1); `store.open_db`, `store.due_feeds`, `store.store_entries`, `store.mark_polled`, `store.DEFAULT_DB_PATH` (Tasks 3–4).
- Produces:
  - `feedwatch.poller.TICK_SECONDS = 60`.
  - `feedwatch.poller.poll_once(conn, now: datetime, fetch: Callable[[str], bytes] = fetch_url) -> None`.
  - `feedwatch.poller.run(conn, *, clock: Callable[[], datetime], sleep: Callable[[float], None], fetch: Callable[[str], bytes]) -> NoReturn`.
  - `feedwatch.poller.main(db_path: Path = store.DEFAULT_DB_PATH) -> None`; `python -m feedwatch.poller` calls it.
  - Logger name `"feedwatch.poller"`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import logging
import sqlite3
from datetime import datetime, timedelta, timezone

import pytest

from feedwatch import poller, store
from feedwatch.fetch import FetchError

URL_A = "https://a.example/feed"
URL_B = "https://b.example/feed"
T0 = datetime(2026, 3, 2, 9, 0, tzinfo=timezone.utc)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid><title>Post {guid}</title></item>" for guid in guids)
    return f"<rss version='2.0'><channel>{items}</channel></rss>".encode()


class FakeWeb:
    """Stands in for fetch: returns or raises the page configured for each URL."""

    def __init__(self, pages):
        self.pages = pages
        self.requested = []

    def __call__(self, url):
        self.requested.append(url)
        page = self.pages[url]
        if isinstance(page, Exception):
            raise page
        return page


@pytest.fixture
def conn(tmp_path):
    connection = store.open_db(tmp_path / "feeds.db")
    yield connection
    connection.close()


def unread_guids(conn):
    return {entry.guid for entry in store.unread(conn, 100)}


def test_stores_the_entries_of_a_due_feed(conn):
    store.add_feed(conn, URL_A)
    poller.poll_once(conn, T0, FakeWeb({URL_A: rss("a1", "a2")}))
    assert unread_guids(conn) == {"a1", "a2"}


def test_an_entry_seen_again_is_not_stored_twice(conn):
    store.add_feed(conn, URL_A)
    web = FakeWeb({URL_A: rss("a1")})
    poller.poll_once(conn, T0, web)
    web.pages[URL_A] = rss("a1", "a2")
    poller.poll_once(conn, T0 + timedelta(minutes=30), web)
    assert sorted(entry.guid for entry in store.unread(conn, 100)) == ["a1", "a2"]


def test_a_feed_is_not_polled_before_its_interval_is_up(conn):
    store.add_feed(conn, URL_A, every_minutes=30)
    web = FakeWeb({URL_A: rss("a1")})
    poller.poll_once(conn, T0, web)
    poller.poll_once(conn, T0 + timedelta(minutes=29), web)
    poller.poll_once(conn, T0 + timedelta(minutes=30), web)
    assert web.requested == [URL_A, URL_A]


@pytest.mark.parametrize(
    "broken",
    [FetchError("HTTP Error 404: Not Found"), b"<html><body>Moved</body></html>"],
    ids=["unfetchable", "not-rss"],
)
def test_a_broken_feed_is_logged_and_the_others_still_polled(conn, caplog, broken):
    store.add_feed(conn, URL_A)
    store.add_feed(conn, URL_B)
    with caplog.at_level(logging.WARNING, logger="feedwatch.poller"):
        poller.poll_once(conn, T0, FakeWeb({URL_A: broken, URL_B: rss("b1")}))
    assert unread_guids(conn) == {"b1"}
    assert URL_A in caplog.text


def test_a_broken_feed_is_skipped_until_its_next_interval(conn):
    store.add_feed(conn, URL_A, every_minutes=30)
    web = FakeWeb({URL_A: FetchError("timed out")})
    poller.poll_once(conn, T0, web)
    poller.poll_once(conn, T0 + timedelta(minutes=10), web)
    web.pages[URL_A] = rss("a1")
    poller.poll_once(conn, T0 + timedelta(minutes=30), web)
    assert web.requested == [URL_A, URL_A]
    assert unread_guids(conn) == {"a1"}


def test_a_database_error_stops_the_poller(conn, monkeypatch):
    store.add_feed(conn, URL_A)

    def fail(*args):
        raise sqlite3.OperationalError("disk I/O error")

    monkeypatch.setattr(store, "store_entries", fail)
    with pytest.raises(sqlite3.OperationalError):
        poller.poll_once(conn, T0, FakeWeb({URL_A: rss("a1")}))


class Stop(Exception):
    pass


def test_run_polls_every_tick_and_picks_up_feeds_added_meanwhile(conn):
    store.add_feed(conn, URL_A, every_minutes=1)
    web = FakeWeb({URL_A: rss("a1"), URL_B: rss("b1")})
    moments = iter([T0, T0 + timedelta(minutes=1)])
    sleeps = []

    def sleep(seconds):
        sleeps.append(seconds)
        if len(sleeps) == 1:
            store.add_feed(conn, URL_B)
        else:
            raise Stop

    with pytest.raises(Stop):
        poller.run(conn, clock=lambda: next(moments), sleep=sleep, fetch=web)
    assert web.requested == [URL_A, URL_A, URL_B]
    assert sleeps == [poller.TICK_SECONDS, poller.TICK_SECONDS]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run pytest tests/test_poller.py -v`
Expected: collection error, `ImportError: cannot import name 'poller' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`src/feedwatch/poller.py`:

```python
"""The long-running worker: polls each feed when its interval is up."""

import logging
import sqlite3
import time
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path
from typing import NoReturn

from feedwatch import store
from feedwatch.fetch import FetchError, fetch as fetch_url
from feedwatch.parse import ParseError, parse

log = logging.getLogger("feedwatch.poller")

# How often the poller wakes to look for due feeds; a feed is polled at most this long after it falls due.
TICK_SECONDS = 60


def poll_once(
    conn: sqlite3.Connection, now: datetime, fetch: Callable[[str], bytes] = fetch_url
) -> None:
    """Poll every feed that is due at `now` and store the entries it has not brought before.

    A feed that cannot be fetched or parsed is logged and counts as polled,
    so it is next tried one interval later. Database errors propagate.
    """
    for feed in store.due_feeds(conn, now):
        try:
            entries = parse(fetch(feed.url))
        except (FetchError, ParseError) as exc:
            log.warning("skipping %s until its next interval: %s", feed.url, exc)
        else:
            new = store.store_entries(conn, feed.id, entries, now)
            log.info("%s: %d new entries", feed.url, new)
        store.mark_polled(conn, feed.id, now)


def run(
    conn: sqlite3.Connection,
    *,
    clock: Callable[[], datetime],
    sleep: Callable[[float], None],
    fetch: Callable[[str], bytes],
) -> NoReturn:
    """Poll whatever is due, then sleep a tick, forever."""
    while True:
        poll_once(conn, clock(), fetch)
        sleep(TICK_SECONDS)


def main(db_path: Path = store.DEFAULT_DB_PATH) -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    conn = store.open_db(db_path)
    try:
        run(conn, clock=lambda: datetime.now(timezone.utc), sleep=time.sleep, fetch=fetch_url)
    except KeyboardInterrupt:
        pass
    finally:
        conn.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run pytest -v`
Expected: all PASS (Tasks 1–5).

- [ ] **Step 5: Commit**

```bash
git add src/feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller that stores new entries and skips broken feeds"
```

---

### Task 6: The command line

**Files:**
- Create: `src/feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.open_db`, `store.add_feed`, `store.feeds`, `store.store_entries`, `store.unread`, `store.mark_read`, `store.DuplicateFeed`, `store.UnknownGuids`, `store.StoredEntry`, `store.DEFAULT_DB_PATH` (Tasks 3–4); `parse.Entry` in tests only (Task 1).
- Produces:
  - `feedwatch.cli.main(argv: list[str] | None = None, db_path: Path = store.DEFAULT_DB_PATH) -> int` — exit status; the `feedwatch` console script (declared in `pyproject.toml`, Task 1) calls it with no arguments.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
from datetime import datetime, timezone

import pytest

from feedwatch import cli, store
from feedwatch.parse import Entry

URL = "https://a.example/feed"
SEEN = datetime(2026, 3, 10, 9, 0, tzinfo=timezone.utc)


@pytest.fixture
def db(tmp_path):
    return tmp_path / "feeds.db"


def run(db, *argv):
    return cli.main(list(argv), db_path=db)


def subscribed(db):
    conn = store.open_db(db)
    try:
        return store.feeds(conn)
    finally:
        conn.close()


def seed(db, *entries):
    conn = store.open_db(db)
    feed = store.add_feed(conn, URL, "Example")
    store.store_entries(conn, feed.id, list(entries), SEEN)
    conn.close()


def entry(guid, day=1):
    return Entry(guid, f"Post {guid}", f"https://a.example/{guid}", datetime(2026, 3, day, 9, 0, tzinfo=timezone.utc))


def test_add_subscribes_every_thirty_minutes_by_default(db, capsys):
    assert run(db, "add", URL) == 0
    [feed] = subscribed(db)
    assert (feed.url, feed.title, feed.every_minutes) == (URL, None, 30)
    assert URL in capsys.readouterr().out


def test_add_takes_a_title_and_an_interval(db):
    assert run(db, "add", URL, "--title", "Example", "--every", "15") == 0
    [feed] = subscribed(db)
    assert (feed.title, feed.every_minutes) == ("Example", 15)


def test_add_refuses_a_url_already_subscribed_and_names_it(db, capsys):
    run(db, "add", URL)
    capsys.readouterr()
    assert run(db, "add", URL, "--every", "5") == 1
    assert URL in capsys.readouterr().err
    assert [feed.every_minutes for feed in subscribed(db)] == [30]


@pytest.mark.parametrize(
    "argv",
    [
        ["add", URL, "--every", "0"],
        ["add", URL, "--every", "-5"],
        ["add", URL, "--every", "soon"],
        ["add", "example.com/feed"],
        ["add", "ftp://example.com/feed"],
        ["unread", "--limit", "0"],
        ["read"],
    ],
)
def test_refuses_bad_arguments(db, argv):
    with pytest.raises(SystemExit) as exited:
        run(db, *argv)
    assert exited.value.code == 2
    assert not db.exists()


def test_unread_lists_newest_first_with_guid_and_feed(db, capsys):
    seed(db, entry("old", 1), entry("new", 3), entry("mid", 2))
    assert run(db, "unread") == 0
    out = capsys.readouterr().out
    assert out.index("Post new") < out.index("Post mid") < out.index("Post old")
    assert "guid: new" in out
    assert "Example" in out


def test_unread_shows_twenty_unless_a_limit_is_set(db, capsys):
    seed(db, *(entry(f"e{number}") for number in range(25)))
    run(db, "unread")
    assert capsys.readouterr().out.count("guid: ") == 20
    run(db, "unread", "--limit", "3")
    assert capsys.readouterr().out.count("guid: ") == 3


def test_unread_says_so_when_nothing_is_unread(db, capsys):
    assert run(db, "unread") == 0
    assert "No unread entries." in capsys.readouterr().out


def test_unread_shows_untitled_undated_entry(db, capsys):
    seed(db, Entry("bare", None, None, None))
    run(db, "unread")
    out = capsys.readouterr().out
    assert "(untitled)" in out
    assert "undated" in out
    assert "guid: bare" in out


def test_read_marks_entries_read(db, capsys):
    seed(db, entry("a", 1), entry("b", 2), entry("c", 3))
    assert run(db, "read", "a", "c") == 0
    capsys.readouterr()
    run(db, "unread")
    out = capsys.readouterr().out
    assert "guid: b" in out
    assert "guid: a" not in out
    assert "guid: c" not in out


def test_read_refuses_an_unknown_guid_names_it_and_marks_nothing(db, capsys):
    seed(db, entry("a"))
    assert run(db, "read", "a", "nope") == 1
    assert "nope" in capsys.readouterr().err
    run(db, "unread")
    assert "guid: a" in capsys.readouterr().out
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run pytest tests/test_cli.py -v`
Expected: collection error, `ImportError: cannot import name 'cli' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`src/feedwatch/cli.py`:

```python
"""The feedwatch command: subscribe to feeds, list unread entries, mark them read."""

import argparse
import sqlite3
import sys
from pathlib import Path
from urllib.parse import urlsplit

from feedwatch import store


def main(argv: list[str] | None = None, db_path: Path = store.DEFAULT_DB_PATH) -> int:
    """Run one command and return the process exit status."""
    args = _parser().parse_args(argv)
    conn = store.open_db(db_path)
    try:
        return args.handler(conn, args)
    finally:
        conn.close()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read your RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", type=_feed_url, metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=_positive_int, default=30, metavar="MINUTES",
                     help="poll interval in minutes (default 30)")
    add.set_defaults(handler=_add)

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=_positive_int, default=20, metavar="N",
                        help="how many to show (default 20)")
    unread.set_defaults(handler=_unread)

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    read.set_defaults(handler=_read)
    return parser


def _feed_url(value: str) -> str:
    parts = urlsplit(value)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise argparse.ArgumentTypeError(f"not an http(s) URL: {value}")
    return value


def _positive_int(value: str) -> int:
    try:
        number = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"not a whole number: {value}") from None
    if number < 1:
        raise argparse.ArgumentTypeError(f"must be at least 1: {value}")
    return number


def _add(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    try:
        feed = store.add_feed(conn, args.url, args.title, args.every)
    except store.DuplicateFeed as exc:
        print(f"Already subscribed to {exc.url}", file=sys.stderr)
        return 1
    print(f"Subscribed to {feed.url}, polled every {feed.every_minutes} minutes.")
    return 0


def _unread(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    entries = store.unread(conn, args.limit)
    if not entries:
        print("No unread entries.")
    for entry in entries:
        print(_describe(entry))
    return 0


def _describe(entry: store.StoredEntry) -> str:
    when = "undated" if entry.published_at is None else entry.published_at.astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [f"{when}  {entry.feed_title or entry.feed_url}  {entry.title or '(untitled)'}"]
    if entry.link:
        lines.append(f"  {entry.link}")
    lines.append(f"  guid: {entry.guid}")
    return "\n".join(lines)


def _read(conn: sqlite3.Connection, args: argparse.Namespace) -> int:
    try:
        store.mark_read(conn, args.guids)
    except store.UnknownGuids as exc:
        print(f"No stored entry with guid: {', '.join(exc.guids)}", file=sys.stderr)
        return 1
    count = len(set(args.guids))
    print(f"Marked {count} {'entry' if count == 1 else 'entries'} read.")
    return 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run pytest -v`
Expected: all PASS (Tasks 1–6).

- [ ] **Step 5: Smoke-test both processes end to end against a local feed**

Run, from the repository root (a throwaway `HOME` keeps the real `~/.feedwatch` untouched):

```bash
export SMOKE=$(mktemp -d)
mkdir "$SMOKE/site"
cat > "$SMOKE/site/feed.xml" <<'EOF'
<rss version="2.0"><channel><title>Smoke</title>
<item><guid>smoke-1</guid><title>Hello</title><pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>
</channel></rss>
EOF
uv run python -m http.server 8765 --bind 127.0.0.1 --directory "$SMOKE/site" >/dev/null 2>&1 &
SERVER=$!
sleep 1
HOME="$SMOKE" uv run feedwatch add http://127.0.0.1:8765/feed.xml --title Smoke
HOME="$SMOKE" uv run feedwatch add http://127.0.0.1:8765/missing.xml
HOME="$SMOKE" timeout 5 uv run python -m feedwatch.poller
HOME="$SMOKE" uv run feedwatch unread
HOME="$SMOKE" uv run feedwatch read smoke-1
HOME="$SMOKE" uv run feedwatch read smoke-1 nope; echo "exit $?"
kill $SERVER
```

Expected:
- the two `add` lines print `Subscribed to …`;
- the poller logs `… 1 new entries` for `feed.xml` and a `WARNING skipping http://127.0.0.1:8765/missing.xml until its next interval: HTTP Error 404: File not found`, then is stopped by `timeout`;
- `unread` prints `2026-03-02 …  Smoke  Hello` and `  guid: smoke-1`;
- the first `read` prints `Marked 1 entry read.`; the second prints `No stored entry with guid: nope` on stderr and `exit 1`.

- [ ] **Step 6: Commit**

```bash
git add src/feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

## After the last task

Invoke `dopamine:finishing-work` before the workspace is cleaned up. Facts this work establishes that the living documents in `.dopamine/config` do not yet hold (the decisions listed under "Decisions this plan makes where the spec is silent", the module interfaces, the `user_version` migration scheme) go in the execution ledger, not straight into `docs/DESIGN.md` or `docs/ARCHITECTURE.md`; the sweep places them. Note that `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are listed as living documents but do not exist yet.
````


## p005

#### Final message

I wrote the feedwatch v1 implementation plan and committed it as `9b8fedc` on `master`. No feedwatch code was added to the repo.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

To check the plan's code, I copied it into a throwaway directory outside the repo. All 47 tests passed on Python 3.14, and the manual end-to-end run gave the expected results. It hasn't been run on 3.11, which is the version the project targets.

**The tasks (TDD, one commit each, full code in each):**
1. Domain types, error classes, `pyproject.toml`, and storing feeds in SQLite.
2. Storing entries once, listing unread newest first, marking read.
3. Parsing RSS.
4. Downloading feeds.
5. The poller.
6. The `feedwatch add / unread / read` commands, plus a manual check of the real commands in a throwaway home directory.
7. Close: check the diff against `PROGRAM-DESIGN.md`, run `dopamine:finishing-work`, then `superpowers:finishing-a-development-branch`.

Every `PROGRAM-DESIGN.md` rule is copied into Global Constraints with its check. It left no structural choice open, so I didn't run `brainstorm-program-design`.

**Choices I made within those rules (stated in the plan):**
- **No parallel fetching yet:** the poller downloads feeds one after another, each with a 30-second timeout.
- **Database type:** `store` exports a `Connection` type, so the commands module never imports `sqlite3`.
- **Closing connections:** connections are closed with `contextlib.closing`.
- **Test code:** the rules apply to test code too.
- **Test framework:** tests use the standard library's `unittest`.

**Five things the spec doesn't cover, each pinned by a test (the plan's Review Focus):**
- **Missing or unreadable `pubDate`:** the entry is kept with no date and sorted by when it was first seen.
- **Item with no guid and no link:** it is skipped, and the rest of the feed is stored.
- **A failing feed:** it waits for its next interval instead of being retried every 30-second check.
- **`add` with a non-http(s) URL:** it is refused, and the download step also refuses such URLs, so `file:` URLs can't be read from disk.
- **`read` with some unknown guids:** it names every unknown guid and marks nothing.

**XML security:** a security hook suggested `defusedxml`. I kept the standard library's `ElementTree` because the project is limited to the standard library. `ElementTree` doesn't load external entities, and current expat versions guard against "billion laughs" entity expansion.

**Session close:** as the session instructions require, I ran the `finishing-work` sweep for this planning work and committed it as `483b9df` ("nothing to drain"), with a reconstructed ledger at `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md`. `ROADMAP.md` is declared in `.dopamine/config` but doesn't exist, and I didn't create it.

Please review the plan and check it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md (added)

````
Reconstructed ledger for the ad-hoc unit `2026-10-12-feedwatch-v1-planning`, written 2026-10-12 from the planning conversation; there was no superpowers ledger.

- Wrote `docs/superpowers/plans/2026-10-12-feedwatch-v1.md` for spec `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Plan only; no code was written to the repository.
- Copied every PROGRAM-DESIGN.md rule and its check into the plan's Global Constraints. No structural choice was found open, so brainstorm-program-design was not run.
- Decisions taken inside the existing rules and recorded in the plan only: v1 fetches feeds sequentially on the poller thread with a 30 s timeout (no executor yet); `store` exports `Connection` so callers need not import `sqlite3`; connections are closed through `contextlib.closing`; the rules apply to test code too.
- The plan's code was assembled in a scratch directory outside the repository: 47 unittest tests passed on Python 3.14, and the smoke steps behaved as the plan expects.
- No living-document consequence: the plan only applies DESIGN.md, ARCHITECTURE.md and PROGRAM-DESIGN.md and does not change them. ROADMAP.md is declared in .dopamine/config but absent.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a long-running poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five components from `docs/ARCHITECTURE.md`, one module each under `feedwatch/`: `fetch` (HTTP), `parse` (RSS XML to items), `store` (SQLite, module functions taking `conn`), `poller` (schedule loop, `python -m feedwatch.poller`) and `cli` (argparse commands). Domain values are frozen dataclasses in `feedwatch/models.py`; failures are `FeedwatchError` subclasses in `feedwatch/errors.py`, caught only by `poller` and `cli`.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`); tests use `unittest`; packaging via `pyproject.toml` with the setuptools build backend for the `feedwatch` console script.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`

## Global Constraints

From the spec:

- `feedwatch add URL [--title TITLE] [--every MINUTES]`; interval defaults to **30** minutes. A URL already subscribed to is refused with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries newest first; limit defaults to **20**.
- `feedwatch read GUID [GUID ...]` marks entries read; a guid that is not stored is refused with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores only entries it has not seen. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not RSS, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller (`ARCHITECTURE.md`).
- Database file: `~/.feedwatch/feeds.db`, tables `feeds` and `entries`.
- Out of scope: Atom feeds; importing or exporting subscription lists.
- Python 3.11 floor: no syntax or stdlib API newer than 3.11. No third-party runtime dependency.

From `docs/PROGRAM-DESIGN.md` (every rule applies to this plan; each is followed by the check the reviewer applies to the diff):

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

Decisions this plan takes within those rules:

- v1 fetches feeds one after another on the poller's thread, each bounded by a 30-second timeout; no executor yet. A handful of feeds at 30-minute intervals cannot back up behind one slow feed for long, and the Concurrency rule keeps the executor available when that changes.
- Because `cli` may not import `sqlite3`, `store` exports `Connection = sqlite3.Connection` as the type others annotate with, and callers close connections with `contextlib.closing(store.connect(...))` rather than calling `conn.close()`.
- The rules above apply to test code too: test helpers are annotated, and tests reach the database only through `store`.

## Review Focus

1. **An item with no `<pubDate>`, or one in a form RFC 822 parsing cannot read (e.g. ISO 8601):** the entry is still stored with no publication time, and `unread` orders it by when it was first seen. The feed's other items are unaffected. Tests: Task 3 `test_unreadable_or_missing_pub_date_is_none`, Task 2 `test_unread_is_newest_first_using_seen_at_when_unpublished`.
2. **An item with no `<guid>` and no `<link>`:** it cannot be told apart from any other, so it is left out; the feed's identifiable items are still stored. Test: Task 3 `test_item_without_guid_or_link_is_left_out`.
3. **A feed that fails is not retried on every 30-second tick:** a failed fetch or parse still records the poll time, so the feed waits for its next interval as the spec says. Test: Task 5 `test_failed_feed_waits_for_its_next_interval`.
4. **`add` with something that is not an http(s) URL** (a typo with no scheme, `file:///etc/passwd`, `ftp://…`): refused with a message naming it, nothing stored, and `fetch` independently refuses non-http schemes so a stored row can never make the poller read local files. Tests: Task 6 `test_add_refuses_non_http_url`, Task 4 `test_non_http_scheme_raises_fetch_error`.
5. **`read` with a mix of stored and unknown guids:** the command is refused naming every unknown guid, and nothing is marked read, so a typo does not leave the user unsure which entries changed. Tests: Task 2 `test_mark_read_with_unknown_guid_marks_nothing`, Task 6 `test_read_unknown_guid_is_refused`.

---

## File Structure

```
pyproject.toml            package metadata; `feedwatch` console script -> feedwatch.cli:main
feedwatch/__init__.py     empty package marker
feedwatch/models.py       Feed, Item, Entry frozen dataclasses
feedwatch/errors.py       FeedwatchError and its subclasses
feedwatch/store.py        component: SQLite schema and every query
feedwatch/parse.py        component: RSS XML bytes -> list[Item]
feedwatch/fetch.py        component: URL -> bytes over HTTP(S)
feedwatch/poller.py       component: poll_due() and the run-forever main()
feedwatch/cli.py          component: argparse commands, run() and main()
tests/__init__.py         makes tests/ a package for unittest discovery
tests/rss.py              test helper: builds RSS documents
tests/test_store.py
tests/test_parse.py
tests/test_fetch.py
tests/test_poller.py
tests/test_cli.py
```

Run every test with `python -m unittest -v` from the repository root (Python 3.11 or newer).

---

### Task 1: Models, errors and the feed half of `store`

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/models.py`, `feedwatch/errors.py`, `feedwatch/store.py`, `tests/__init__.py`
- Modify: `.gitignore`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)`
  - `feedwatch.models.Item(guid: str, title: str, link: str | None, published: datetime | None)`
  - `feedwatch.models.Entry(guid: str, title: str, link: str | None, published: datetime | None, seen_at: datetime, feed_title: str)`
  - `feedwatch.errors`: `FeedwatchError`, `FetchError`, `NotRSSError`, `AlreadySubscribedError(url: str)` (attribute `.url`), `UnknownGuidError(guids: list[str])` (attribute `.guids`), `InvalidArgumentError`
  - `feedwatch.store.Connection` (alias of `sqlite3.Connection`), `store.DEFAULT_PATH: Path`, `store.SCHEMA_STEPS: tuple[str, ...]`
  - `store.connect(path: Path = DEFAULT_PATH) -> Connection`
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed` — raises `AlreadySubscribedError`
  - `store.list_feeds(conn: Connection) -> list[Feed]`
  - `store.mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None`
  - All datetimes passed in or returned are timezone-aware.

- [ ] **Step 1: Scaffold the package**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py` and `tests/__init__.py`: empty files.

Append to `.gitignore`:

```
*.egg-info/
build/
```

`feedwatch/models.py`:

```python
"""Feedwatch's domain values."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    """A subscribed feed. `title` is None when the user gave none."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None


@dataclass(frozen=True)
class Item:
    """An entry as a feed presents it, before it is stored.

    `guid` is the feed's <guid>, or its <link> when it has no guid.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None


@dataclass(frozen=True)
class Entry:
    """A stored entry, with the title of its feed (or the feed's URL when untitled)."""

    guid: str
    title: str
    link: str | None
    published: datetime | None
    seen_at: datetime
    feed_title: str
```

`feedwatch/errors.py`:

```python
"""Every failure feedwatch raises."""


class FeedwatchError(Exception):
    """Base class of every feedwatch failure; its message is fit to show the user."""


class FetchError(FeedwatchError):
    """A feed's URL could not be downloaded."""


class NotRSSError(FeedwatchError):
    """A downloaded document is not an RSS feed."""


class AlreadySubscribedError(FeedwatchError):
    """The URL is already subscribed to."""

    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url


class UnknownGuidError(FeedwatchError):
    """No stored entry has one or more of the given guids."""

    def __init__(self, guids: list[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = guids


class InvalidArgumentError(FeedwatchError):
    """A command-line argument has a value feedwatch cannot use."""
```

- [ ] **Step 2: Write the failing tests**

`tests/test_store.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribedError
from feedwatch.models import Feed

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.path = Path(directory) / "nested" / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))


class FeedsTest(StoreTestCase):
    def test_connect_creates_missing_directory_and_empty_schema(self) -> None:
        self.assertTrue(self.path.exists())
        self.assertEqual(store.list_feeds(self.conn), [])

    def test_connect_to_existing_database_keeps_its_data(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with closing(store.connect(self.path)) as again:
            self.assertEqual([f.url for f in store.list_feeds(again)], ["https://a.example/rss"])

    def test_add_feed_returns_the_stored_feed(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=15)
        self.assertEqual(
            feed,
            Feed(id=feed.id, url="https://a.example/rss", title="A", every_minutes=15, last_polled=None),
        )
        self.assertEqual(store.list_feeds(self.conn), [feed])

    def test_add_feed_refuses_a_url_already_subscribed(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribedError) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=5)
        self.assertIn("https://a.example/rss", str(caught.exception))
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_mark_polled_records_the_time(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.mark_polled(self.conn, feed.id, at=T0)
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled, T0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: ERROR — `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 4: Write `feedwatch/store.py`**

```python
"""The SQLite database. Every query feedwatch runs lives here."""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribedError
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Append-only: an existing database has already run every earlier step, so
# editing one would leave old and new databases with different schemas.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
)


def connect(path: Path = DEFAULT_PATH) -> Connection:
    """Open the database at `path`, creating the file, its directory and its schema as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`; raises AlreadySubscribedError if it is subscribed already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise AlreadySubscribedError(url) from error
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def list_feeds(conn: Connection) -> list[Feed]:
    """Return every subscribed feed, oldest subscription first."""
    rows = conn.execute(
        "SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id"
    ).fetchall()
    return [
        Feed(
            id=row[0],
            url=row[1],
            title=row[2],
            every_minutes=row[3],
            last_polled=None if row[4] is None else datetime.fromisoformat(row[4]),
        )
        for row in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    """Record that the feed was polled at `at`, whether or not the poll succeeded."""
    with conn:
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (_encode(at), feed_id))


def _encode(moment: datetime) -> str:
    # One UTC format for every stored time, so that SQL can order them as text.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 5 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml .gitignore feedwatch/__init__.py feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/__init__.py tests/test_store.py
git commit -m "feat: feedwatch package, domain types and feed storage"
```

---

### Task 2: Entries in `store`

**Files:**
- Modify: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: Task 1's `Connection`, `connect`, `add_feed`, `_encode`, `Item`, `Entry`, `UnknownGuidError`.
- Produces:
  - `store.add_entries(conn: Connection, feed_id: int, *, items: list[Item], seen_at: datetime) -> int` — stores items whose `(feed_id, guid)` is not stored yet; returns how many were new.
  - `store.unread(conn: Connection, limit: int) -> list[Entry]` — newest first by `published`, or `seen_at` when unpublished.
  - `store.mark_read(conn: Connection, guids: list[str]) -> int` — marks every entry (in any feed) carrying one of `guids` read and returns the number of distinct guids; raises `UnknownGuidError` naming every unknown guid and marks nothing if any is unknown.

- [ ] **Step 1: Write the failing tests**

Add to the imports at the top of `tests/test_store.py`:

```python
from datetime import timedelta

from feedwatch.errors import UnknownGuidError
from feedwatch.models import Item
```

Add before the `if __name__ == "__main__":` line:

```python
def item(guid: str, *, published: datetime | None = None) -> Item:
    return Item(guid=guid, title=f"Title {guid}", link=f"https://a.example/{guid}", published=published)


class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)

    def test_add_entries_stores_each_entry_once(self) -> None:
        first = store.add_entries(self.conn, self.feed.id, items=[item("1"), item("2")], seen_at=T0)
        again = store.add_entries(
            self.conn, self.feed.id, items=[item("2"), item("3")], seen_at=T0 + timedelta(hours=1)
        )
        self.assertEqual((first, again), (2, 1))
        self.assertEqual(sorted(e.guid for e in store.unread(self.conn, 20)), ["1", "2", "3"])

    def test_a_guid_repeated_within_one_poll_is_stored_once(self) -> None:
        new = store.add_entries(self.conn, self.feed.id, items=[item("1"), item("1")], seen_at=T0)
        self.assertEqual(new, 1)

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        other = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.add_entries(self.conn, self.feed.id, items=[item("1")], seen_at=T0)
        store.add_entries(self.conn, other.id, items=[item("1")], seen_at=T0)
        self.assertEqual(
            sorted(e.feed_title for e in store.unread(self.conn, 20)), ["A", "https://b.example/rss"]
        )

    def test_unread_is_newest_first_using_seen_at_when_unpublished(self) -> None:
        store.add_entries(
            self.conn,
            self.feed.id,
            items=[
                item("ten", published=T0 - timedelta(hours=2)),
                item("unpublished"),
                item("eleven", published=T0 - timedelta(hours=1)),
            ],
            seen_at=T0,
        )
        entries = store.unread(self.conn, 20)
        self.assertEqual([e.guid for e in entries], ["unpublished", "eleven", "ten"])
        self.assertIsNone(entries[0].published)
        self.assertEqual(entries[0].seen_at, T0)
        self.assertEqual(entries[1].published, T0 - timedelta(hours=1))

    def test_unread_honours_the_limit(self) -> None:
        store.add_entries(self.conn, self.feed.id, items=[item(str(n)) for n in range(5)], seen_at=T0)
        self.assertEqual(len(store.unread(self.conn, 2)), 2)

    def test_mark_read_removes_entries_from_unread(self) -> None:
        store.add_entries(self.conn, self.feed.id, items=[item("1"), item("2")], seen_at=T0)
        self.assertEqual(store.mark_read(self.conn, ["1", "1"]), 1)
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["2"])

    def test_mark_read_with_unknown_guid_marks_nothing(self) -> None:
        store.add_entries(self.conn, self.feed.id, items=[item("1")], seen_at=T0)
        with self.assertRaises(UnknownGuidError) as caught:
            store.mark_read(self.conn, ["1", "nope", "nada"])
        self.assertEqual(caught.exception.guids, ["nope", "nada"])
        self.assertIn("nope", str(caught.exception))
        self.assertIn("nada", str(caught.exception))
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["1"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the 7 new tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'` (or `unread`); Task 1's 5 still pass.

- [ ] **Step 3: Implement**

In `feedwatch/store.py`, change the imports to:

```python
from feedwatch.errors import AlreadySubscribedError, UnknownGuidError
from feedwatch.models import Entry, Feed, Item
```

Add after `mark_polled`:

```python
def add_entries(conn: Connection, feed_id: int, *, items: list[Item], seen_at: datetime) -> int:
    """Store the items this feed has not stored before; returns how many were new."""
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    feed_id,
                    item.guid,
                    item.title,
                    item.link,
                    None if item.published is None else _encode(item.published),
                    _encode(seen_at),
                )
                for item in items
            ],
        )
        return conn.total_changes - before


def unread(conn: Connection, limit: int) -> list[Entry]:
    """Return up to `limit` unread entries, newest first; an unpublished entry counts as new when first seen."""
    rows = conn.execute(
        "SELECT e.guid, e.title, e.link, e.published, e.seen_at, COALESCE(f.title, f.url)"
        " FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id"
        " WHERE e.read = 0"
        # Ties come from one poll; RSS lists newest first, so insertion order breaks them.
        " ORDER BY COALESCE(e.published, e.seen_at) DESC, e.id ASC"
        " LIMIT ?",
        (limit,),
    ).fetchall()
    return [
        Entry(
            guid=row[0],
            title=row[1],
            link=row[2],
            published=None if row[3] is None else datetime.fromisoformat(row[3]),
            seen_at=datetime.fromisoformat(row[4]),
            feed_title=row[5],
        )
        for row in rows
    ]


def mark_read(conn: Connection, guids: list[str]) -> int:
    """Mark read every entry carrying one of `guids`; returns how many distinct guids were marked.

    Raises UnknownGuidError naming every guid no entry carries, and then marks nothing.
    """
    distinct = list(dict.fromkeys(guids))
    with conn:
        placeholders = ", ".join("?" * len(distinct))
        known = {
            row[0]
            for row in conn.execute(
                f"SELECT DISTINCT guid FROM entries WHERE guid IN ({placeholders})", distinct
            )
        }
        unknown = [guid for guid in distinct if guid not in known]
        if unknown:
            raise UnknownGuidError(unknown)
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in distinct])
    return len(distinct)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 12 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 3: `parse`

**Files:**
- Create: `feedwatch/parse.py`, `tests/rss.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: `Item`, `NotRSSError` from Task 1.
- Produces:
  - `feedwatch.parse.parse_feed(xml: bytes) -> list[Item]` — items in document order; raises `NotRSSError` when `xml` is not well-formed or its root is not `<rss>` with a `<channel>`.
  - Test helpers `tests.rss.rss_feed(*items: str) -> bytes` and `tests.rss.rss_item(*, guid: str | None = None, link: str | None = None, title: str = "An entry", pub_date: str | None = None) -> str` (used again in Task 5).

- [ ] **Step 1: Write the test helper**

`tests/rss.py`:

```python
"""Builds RSS 2.0 documents for tests."""

from xml.sax.saxutils import escape


def rss_item(
    *,
    guid: str | None = None,
    link: str | None = None,
    title: str = "An entry",
    pub_date: str | None = None,
) -> str:
    parts = [f"<title>{escape(title)}</title>"]
    if guid is not None:
        parts.append(f"<guid>{escape(guid)}</guid>")
    if link is not None:
        parts.append(f"<link>{escape(link)}</link>")
    if pub_date is not None:
        parts.append(f"<pubDate>{escape(pub_date)}</pubDate>")
    return "<item>" + "".join(parts) + "</item>"


def rss_feed(*items: str) -> bytes:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<rss version="2.0"><channel><title>A feed</title>'
        + "".join(items)
        + "</channel></rss>"
    ).encode("utf-8")
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import NotRSSError
from feedwatch.models import Item
from feedwatch.parse import parse_feed
from tests.rss import rss_feed, rss_item


class ParseFeedTest(unittest.TestCase):
    def test_reads_guid_title_link_and_pub_date(self) -> None:
        xml = rss_feed(
            rss_item(
                guid="tag:a,2026:1",
                link="https://a.example/1",
                title="First & best",
                pub_date="Sun, 01 Mar 2026 10:00:00 GMT",
            )
        )
        self.assertEqual(
            parse_feed(xml),
            [
                Item(
                    guid="tag:a,2026:1",
                    title="First & best",
                    link="https://a.example/1",
                    published=datetime(2026, 3, 1, 10, 0, tzinfo=timezone.utc),
                )
            ],
        )

    def test_pub_date_offset_is_converted_to_utc(self) -> None:
        [item] = parse_feed(rss_feed(rss_item(guid="1", pub_date="Sun, 01 Mar 2026 10:00:00 +0100")))
        self.assertEqual(item.published, datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc))

    def test_keeps_document_order(self) -> None:
        items = parse_feed(rss_feed(rss_item(guid="b"), rss_item(guid="a")))
        self.assertEqual([i.guid for i in items], ["b", "a"])

    def test_item_without_guid_is_identified_by_its_link(self) -> None:
        [item] = parse_feed(rss_feed(rss_item(link="https://a.example/2")))
        self.assertEqual(item.guid, "https://a.example/2")

    def test_whitespace_around_guid_is_ignored(self) -> None:
        [item] = parse_feed(rss_feed(rss_item(guid="  1\n ")))
        self.assertEqual(item.guid, "1")

    def test_item_without_guid_or_link_is_left_out(self) -> None:
        items = parse_feed(rss_feed(rss_item(title="anonymous"), rss_item(guid="kept")))
        self.assertEqual([i.guid for i in items], ["kept"])

    def test_unreadable_or_missing_pub_date_is_none(self) -> None:
        items = parse_feed(
            rss_feed(
                rss_item(guid="none"),
                rss_item(guid="iso", pub_date="2026-03-01T10:00:00Z"),
                rss_item(guid="junk", pub_date="yesterday"),
                rss_item(guid="far", pub_date="Mon, 01 Jan 99999 00:00:00 GMT"),
            )
        )
        self.assertEqual([(i.guid, i.published) for i in items], [
            ("none", None), ("iso", None), ("junk", None), ("far", None),
        ])

    def test_missing_title_is_empty(self) -> None:
        [item] = parse_feed(rss_feed("<item><guid>1</guid></item>"))
        self.assertEqual((item.title, item.link), ("", None))

    def test_empty_channel_has_no_items(self) -> None:
        self.assertEqual(parse_feed(rss_feed()), [])

    def test_atom_is_not_rss(self) -> None:
        atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>'
        with self.assertRaises(NotRSSError):
            parse_feed(atom)

    def test_html_is_not_rss(self) -> None:
        with self.assertRaises(NotRSSError):
            parse_feed(b"<!DOCTYPE html><html><body><p>Not found<br></body></html>")

    def test_rss_without_channel_is_not_rss(self) -> None:
        with self.assertRaises(NotRSSError):
            parse_feed(b'<rss version="2.0"></rss>')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 4: Write `feedwatch/parse.py`**

```python
"""Turns RSS 2.0 XML into items."""

import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import mktime_tz, parsedate_tz

from feedwatch.errors import NotRSSError
from feedwatch.models import Item


def parse_feed(xml: bytes) -> list[Item]:
    """Return the feed's items in document order; raises NotRSSError if `xml` is not an RSS feed.

    An item with neither a guid nor a link cannot be told apart from any other and is left out.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        raise NotRSSError(f"not well-formed XML: {error}") from error
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise NotRSSError(f"root element <{root.tag}> is not an RSS channel")
    items = []
    for element in channel.findall("item"):
        link = _text(element, "link")
        guid = _text(element, "guid") or link
        if guid:
            items.append(
                Item(
                    guid=guid,
                    title=_text(element, "title"),
                    link=link or None,
                    published=_published(_text(element, "pubDate")),
                )
            )
    return items


def _text(element: ET.Element, tag: str) -> str:
    return (element.findtext(tag) or "").strip()


def _published(text: str) -> datetime | None:
    # parsedate_tz answers None for a date it cannot read instead of raising,
    # so one bad date costs that item its date, not the feed its other items.
    fields = parsedate_tz(text)
    if fields is None or not 1 <= fields[0] <= 9999:
        return None
    return datetime.fromtimestamp(mktime_tz(fields), timezone.utc)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 12 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/parse.py tests/rss.py tests/test_parse.py
git commit -m "feat: parse RSS 2.0 items, identified by guid or link"
```

---

### Task 4: `fetch`

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `FetchError` from Task 1.
- Produces: `feedwatch.fetch.fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes`, `fetch.TIMEOUT_SECONDS = 30.0`. Raises `FetchError` (message starts with the URL) for a non-http(s) URL, an unreadable URL, an HTTP error status, a refused connection or a timeout.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import unittest
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, HTTPServer

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch

BODY = b'<rss version="2.0"><channel/></rss>'


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/feed":
            self.send_response(200)
            self.send_header("Content-Type", "application/rss+xml")
            self.send_header("Content-Length", str(len(BODY)))
            self.end_headers()
            self.wfile.write(BODY)
        else:
            self.send_error(404)

    def log_message(self, format: str, *args: object) -> None:
        # Keeps the per-request access log out of the test output.
        pass


class FetchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.server = HTTPServer(("127.0.0.1", 0), _Handler)
        # Bounds handle_request() so a test that never connects cannot hang the executor's shutdown.
        self.server.timeout = 5
        self.addCleanup(self.server.server_close)
        self.executor = self.enterContext(ThreadPoolExecutor(max_workers=1))
        self.base = f"http://127.0.0.1:{self.server.server_port}"

    def serve_one_request(self) -> None:
        self.executor.submit(self.server.handle_request)

    def test_returns_the_body(self) -> None:
        self.serve_one_request()
        self.assertEqual(fetch(f"{self.base}/feed"), BODY)

    def test_http_error_status_raises_fetch_error(self) -> None:
        self.serve_one_request()
        with self.assertRaises(FetchError) as caught:
            fetch(f"{self.base}/missing")
        self.assertIn(f"{self.base}/missing", str(caught.exception))

    def test_unresponsive_server_raises_fetch_error(self) -> None:
        # Nothing calls handle_request(), so the connection is accepted but never answered.
        with self.assertRaises(FetchError):
            fetch(f"{self.base}/feed", timeout=0.2)

    def test_refused_connection_raises_fetch_error(self) -> None:
        self.server.server_close()
        with self.assertRaises(FetchError):
            fetch(f"{self.base}/feed")

    def test_non_http_scheme_raises_fetch_error(self) -> None:
        for url in ("file:///etc/passwd", "ftp://a.example/feed", "a.example/feed"):
            with self.subTest(url=url), self.assertRaises(FetchError):
                fetch(url)

    def test_malformed_url_raises_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch("http://[")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 3: Write `feedwatch/fetch.py`**

```python
"""Downloads feed XML over HTTP(S). The only module that touches the network."""

import http.client
import urllib.request
from urllib.parse import urlsplit

from feedwatch.errors import FetchError

TIMEOUT_SECONDS = 30.0


def fetch(url: str, timeout: float = TIMEOUT_SECONDS) -> bytes:
    """Return the body served at `url`; raises FetchError if it cannot be downloaded.

    Only http and https URLs are fetched: urllib would otherwise read file: URLs from disk.
    """
    try:
        if urlsplit(url).scheme not in ("http", "https"):
            raise FetchError(f"{url}: not an http or https URL")
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1.0"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except (OSError, http.client.HTTPException, ValueError) as error:
        raise FetchError(f"{url}: {error}") from error
```

Note for the implementer: `urllib.error.URLError`, `HTTPError` and `TimeoutError` are all `OSError` subclasses; `ValueError` covers malformed URLs such as `http://[`. `FetchError` is none of the three, so the scheme check's own raise passes through the `except` untouched.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 6 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feed XML over http(s) with a timeout"
```

---

### Task 5: `poller`

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.connect`, `store.list_feeds`, `store.add_entries`, `store.mark_polled`, `store.Connection`, `parse.parse_feed`, `fetch.fetch`, `FeedwatchError`, `Feed`; test helpers `tests.rss.rss_feed`, `tests.rss.rss_item`.
- Produces:
  - `feedwatch.poller.poll_due(conn: store.Connection, now: datetime, *, download: Callable[[str], bytes] = fetch.fetch) -> int` — polls every due feed, returns the number of new entries stored. A feed is due when never polled or when `now - last_polled >= every_minutes`. A `FeedwatchError` from downloading or parsing is logged at WARNING on logger `feedwatch.poller` with the feed URL, and the feed still counts as polled. Any other exception (a database error) propagates.
  - `poller.main() -> None` and `poller.TICK_SECONDS = 30`; run as `python -m feedwatch.poller`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchError
from feedwatch.poller import poll_due
from tests.rss import rss_feed, rss_item

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
A = "https://a.example/rss"
B = "https://b.example/rss"


class FakeWeb:
    """Serves fixed pages by URL and records what was requested."""

    def __init__(self, pages: dict[str, bytes]) -> None:
        self.pages = pages
        self.requested: list[str] = []

    def download(self, url: str) -> bytes:
        self.requested.append(url)
        if url not in self.pages:
            raise FetchError(f"{url}: HTTP Error 404: Not Found")
        return self.pages[url]


class PollDueTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.conn = self.enterContext(closing(store.connect(Path(directory) / "feeds.db")))

    def unread_guids(self) -> list[str]:
        return sorted(e.guid for e in store.unread(self.conn, 100))

    def test_new_feed_is_polled_and_its_entries_stored(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        web = FakeWeb({A: rss_feed(rss_item(guid="1"), rss_item(guid="2"))})
        self.assertEqual(poll_due(self.conn, T0, download=web.download), 2)
        self.assertEqual(self.unread_guids(), ["1", "2"])
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled, T0)

    def test_feed_is_polled_again_only_when_its_interval_is_up(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        web = FakeWeb({A: rss_feed(rss_item(guid="1"))})
        poll_due(self.conn, T0, download=web.download)
        poll_due(self.conn, T0 + timedelta(minutes=29), download=web.download)
        poll_due(self.conn, T0 + timedelta(minutes=30), download=web.download)
        self.assertEqual(web.requested, [A, A])

    def test_entries_seen_again_are_not_stored_again(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        web = FakeWeb({A: rss_feed(rss_item(guid="1"))})
        poll_due(self.conn, T0, download=web.download)
        web.pages[A] = rss_feed(rss_item(guid="1"), rss_item(guid="2"))
        self.assertEqual(poll_due(self.conn, T0 + timedelta(minutes=30), download=web.download), 1)
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_unfetchable_feed_is_logged_and_others_still_polled(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        store.add_feed(self.conn, B, title=None, every_minutes=30)
        web = FakeWeb({B: rss_feed(rss_item(guid="b1"))})
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            new = poll_due(self.conn, T0, download=web.download)
        self.assertEqual(new, 1)
        self.assertEqual(self.unread_guids(), ["b1"])
        self.assertTrue(any(A in line for line in logs.output))

    def test_feed_that_is_not_rss_is_logged_and_others_still_polled(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        store.add_feed(self.conn, B, title=None, every_minutes=30)
        web = FakeWeb({A: b"<html><body>moved</body></html>", B: rss_feed(rss_item(guid="b1"))})
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            poll_due(self.conn, T0, download=web.download)
        self.assertEqual(self.unread_guids(), ["b1"])
        self.assertTrue(any(A in line for line in logs.output))

    def test_failed_feed_waits_for_its_next_interval(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        web = FakeWeb({})
        with self.assertLogs("feedwatch.poller", level="WARNING"):
            poll_due(self.conn, T0, download=web.download)
        poll_due(self.conn, T0 + timedelta(minutes=1), download=web.download)
        self.assertEqual(web.requested, [A])
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled, T0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Write `feedwatch/poller.py`**

```python
"""The long-running worker: polls each feed when its interval is up and stores new entries."""

import logging
import time
from collections.abc import Callable
from contextlib import closing
from datetime import datetime, timedelta, timezone

from feedwatch import fetch, parse, store
from feedwatch.errors import FeedwatchError
from feedwatch.models import Feed

TICK_SECONDS = 30

log = logging.getLogger("feedwatch.poller")


def poll_due(
    conn: store.Connection,
    now: datetime,
    *,
    download: Callable[[str], bytes] = fetch.fetch,
) -> int:
    """Poll every feed whose interval is up and store its new entries; returns how many were new.

    A feed that cannot be downloaded or is not RSS is logged and still counts as polled,
    so it waits for its next interval. A database error propagates and stops the poller.
    """
    new = 0
    for feed in store.list_feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            items = parse.parse_feed(download(feed.url))
        except FeedwatchError as error:
            log.warning("skipping %s until its next interval: %s", feed.url, error)
        else:
            new += store.add_entries(conn, feed.id, items=items, seen_at=now)
        store.mark_polled(conn, feed.id, at=now)
    return new


def main() -> None:
    """Poll forever, checking for due feeds every TICK_SECONDS, until interrupted."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with closing(store.connect()) as conn:
        try:
            while True:
                new = poll_due(conn, datetime.now(timezone.utc))
                if new:
                    log.info("stored %d new entries", new)
                time.sleep(TICK_SECONDS)
        except KeyboardInterrupt:
            log.info("stopped")


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled is None or now - feed.last_polled >= timedelta(minutes=feed.every_minutes)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 6 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller that stores new entries and skips failing feeds"
```

---

### Task 6: `cli`

**Files:**
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store.list_feeds`, `store.add_entries`, `store.unread`, `store.mark_read`, `store.Connection`, `FeedwatchError`, `InvalidArgumentError`, `Entry`, `Item`.
- Produces:
  - `feedwatch.cli.run(argv: list[str], *, conn: store.Connection, out: TextIO, err: TextIO) -> int` — exit status 0 on success, 1 when a `FeedwatchError` was reported on `err` as `feedwatch: <message>`. Malformed usage is argparse's own (`SystemExit(2)`).
  - `cli.main() -> int` — the `feedwatch` console script; also `python -m feedwatch.cli`.
  - Output: `add` prints `Subscribed to URL, polled every N minutes.`; `unread` prints, per entry, the guid on an unindented line, then an indented line `YYYY-MM-DD HH:MM  FEED: TITLE` (local time; title `(untitled)` when empty), then an indented link line when the link differs from the guid; with none it prints `No unread entries.`; `read` prints `Marked N read.`

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.cli import run
from feedwatch.models import Item

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.conn = self.enterContext(closing(store.connect(Path(directory) / "feeds.db")))
        self.out = io.StringIO()
        self.err = io.StringIO()

    def feedwatch(self, *argv: str) -> int:
        return run(list(argv), conn=self.conn, out=self.out, err=self.err)

    def store_entries(self, count: int) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        items = [
            Item(guid=f"g{n}", title=f"Entry {n}", link=None, published=T0 + timedelta(minutes=n))
            for n in range(count)
        ]
        store.add_entries(self.conn, feed.id, items=items, seen_at=T0)

    def listed_guids(self) -> list[str]:
        return [line for line in self.out.getvalue().splitlines() if line and not line.startswith(" ")]

    def test_add_subscribes_every_30_minutes_by_default(self) -> None:
        self.assertEqual(self.feedwatch("add", "https://a.example/rss"), 0)
        [feed] = store.list_feeds(self.conn)
        self.assertEqual((feed.url, feed.title, feed.every_minutes), ("https://a.example/rss", None, 30))
        self.assertIn("https://a.example/rss", self.out.getvalue())

    def test_add_takes_title_and_interval(self) -> None:
        self.assertEqual(self.feedwatch("add", "https://a.example/rss", "--title", "A", "--every", "5"), 0)
        [feed] = store.list_feeds(self.conn)
        self.assertEqual((feed.title, feed.every_minutes), ("A", 5))

    def test_add_refuses_a_url_already_subscribed(self) -> None:
        self.feedwatch("add", "https://a.example/rss")
        self.assertEqual(self.feedwatch("add", "https://a.example/rss"), 1)
        self.assertIn("https://a.example/rss", self.err.getvalue())
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_add_refuses_non_http_url(self) -> None:
        for url in ("a.example/rss", "file:///etc/passwd", "ftp://a.example/rss", "http://", "http://["):
            with self.subTest(url=url):
                self.err.truncate(0)
                self.assertEqual(self.feedwatch("add", url), 1)
                self.assertIn(url, self.err.getvalue())
        self.assertEqual(store.list_feeds(self.conn), [])

    def test_add_refuses_an_interval_below_one_minute(self) -> None:
        self.assertEqual(self.feedwatch("add", "https://a.example/rss", "--every", "0"), 1)
        self.assertIn("--every", self.err.getvalue())
        self.assertEqual(store.list_feeds(self.conn), [])

    def test_unread_with_nothing_stored(self) -> None:
        self.assertEqual(self.feedwatch("unread"), 0)
        self.assertEqual(self.out.getvalue(), "No unread entries.\n")

    def test_unread_lists_20_newest_first_by_default(self) -> None:
        self.store_entries(25)
        self.assertEqual(self.feedwatch("unread"), 0)
        self.assertEqual(self.listed_guids(), [f"g{n}" for n in range(24, 4, -1)])
        self.assertIn("A: Entry 24", self.out.getvalue())

    def test_unread_honours_limit(self) -> None:
        self.store_entries(5)
        self.assertEqual(self.feedwatch("unread", "--limit", "2"), 0)
        self.assertEqual(self.listed_guids(), ["g4", "g3"])

    def test_unread_refuses_a_limit_below_one(self) -> None:
        self.assertEqual(self.feedwatch("unread", "--limit", "0"), 1)
        self.assertIn("--limit", self.err.getvalue())

    def test_read_marks_entries_read(self) -> None:
        self.store_entries(3)
        self.assertEqual(self.feedwatch("read", "g0", "g2"), 0)
        self.assertEqual(self.out.getvalue(), "Marked 2 read.\n")
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["g1"])

    def test_read_unknown_guid_is_refused(self) -> None:
        self.store_entries(1)
        self.assertEqual(self.feedwatch("read", "g0", "nope"), 1)
        self.assertIn("nope", self.err.getvalue())
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["g0"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.cli'`.

- [ ] **Step 3: Write `feedwatch/cli.py`**

```python
"""The user's commands: subscribe to feeds, list unread entries, mark them read."""

import argparse
import sys
from contextlib import closing
from typing import TextIO
from urllib.parse import urlsplit

from feedwatch import store
from feedwatch.errors import FeedwatchError, InvalidArgumentError
from feedwatch.models import Entry

DEFAULT_EVERY_MINUTES = 30
DEFAULT_LIMIT = 20


def run(argv: list[str], *, conn: store.Connection, out: TextIO, err: TextIO) -> int:
    """Run one command; returns the exit status, 1 when a failure was reported on `err`."""
    args = _parser().parse_args(argv)
    try:
        if args.command == "add":
            _add(conn, _http_url(args.url), title=args.title, every=args.every, out=out)
        elif args.command == "unread":
            _unread(conn, args.limit, out=out)
        else:
            count = store.mark_read(conn, args.guids)
            print(f"Marked {count} read.", file=out)
    except FeedwatchError as error:
        print(f"feedwatch: {error}", file=err)
        return 1
    return 0


def main() -> int:
    """Entry point of the `feedwatch` command, against ~/.feedwatch/feeds.db."""
    with closing(store.connect()) as conn:
        return run(sys.argv[1:], conn=conn, out=sys.stdout, err=sys.stderr)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=DEFAULT_EVERY_MINUTES, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=DEFAULT_LIMIT, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _http_url(text: str) -> str:
    try:
        parts = urlsplit(text)
    except ValueError as error:
        raise InvalidArgumentError(f"{text} is not a valid URL") from error
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise InvalidArgumentError(f"{text} is not an http or https URL")
    return text


def _require_positive(option: str, value: int) -> None:
    if value < 1:
        raise InvalidArgumentError(f"{option} must be at least 1, not {value}")


def _add(conn: store.Connection, url: str, *, title: str | None, every: int, out: TextIO) -> None:
    _require_positive("--every", every)
    feed = store.add_feed(conn, url, title=title, every_minutes=every)
    print(f"Subscribed to {feed.url}, polled every {feed.every_minutes} minutes.", file=out)


def _unread(conn: store.Connection, limit: int, *, out: TextIO) -> None:
    _require_positive("--limit", limit)
    entries = store.unread(conn, limit)
    if not entries:
        print("No unread entries.", file=out)
    for entry in entries:
        print(_format(entry), file=out)


def _format(entry: Entry) -> str:
    when = (entry.published or entry.seen_at).astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [entry.guid, f"  {when}  {entry.feed_title}: {entry.title or '(untitled)'}"]
    if entry.link and entry.link != entry.guid:
        lines.append(f"  {entry.link}")
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 11 tests, OK.

- [ ] **Step 5: Run the whole suite**

Run: `python -m unittest -v`
Expected: 47 tests, OK.

- [ ] **Step 6: Smoke-test the real commands in a throwaway home**

```bash
export HOME="$(mktemp -d)"
python -m feedwatch.cli add https://example.com/rss --title Example --every 1
python -m feedwatch.cli add https://example.com/rss; echo "exit $?"
python -m feedwatch.cli unread
python -m feedwatch.cli read nope; echo "exit $?"
timeout 3 python -m feedwatch.poller; echo "poller exit $?"
ls "$HOME/.feedwatch/feeds.db"
```

Expected: `Subscribed to https://example.com/rss, polled every 1 minutes.`; then `feedwatch: already subscribed to https://example.com/rss` and `exit 1`; `No unread entries.`; `feedwatch: no stored entry with guid nope` and `exit 1`; the poller logs a WARNING `skipping https://example.com/rss until its next interval: …` (example.com serves HTML, or the fetch fails offline) and is still running when `timeout` stops it (`poller exit 124`); the database file exists.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

### Task 7: Close the work

- [ ] **Step 1: Check the diff against `PROGRAM-DESIGN.md`**

Run `git diff <base>...HEAD -- feedwatch tests` and apply each *Check* line from Global Constraints to the added lines. Fix any deviation in a commit of its own before going on.

- [ ] **Step 2: Sweep the living documents**

Invoke `dopamine:finishing-work` (seal the ledger beside this plan, drain it into the living documents, commit `sweep: 2026-10-12-feedwatch-v1 — …`).

- [ ] **Step 3: Integrate the branch**

Invoke `superpowers:finishing-a-development-branch`.
````


## p006

#### Final message

I wrote the feedwatch v1 plan and committed it as `bd5a473` ("plan: feedwatch v1"). Nothing is implemented in the repo. I extracted the plan's code into a scratch copy outside the repo (`/tmp/fwcheck`): all 45 tests pass and the end-to-end check in Task 5 gives the expected output.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

**Tasks**, using only the standard library and `unittest`:
1. **Skeleton and `parse`:** `pyproject.toml`, `errors`, the `Entry` model, and `parse.entries(xml) -> list[Entry]`, which raises `NotRssError`.
2. **`fetch`:** `fetch.download(url, timeout=30.0) -> bytes`, which raises `FetchError`.
3. **`store`:** the schema in `SCHEMA_STEPS`, plus `connect`, `add_feed`, `feeds`, `record_poll`, `unread` and `mark_read`, and the `Feed` and `UnreadEntry` models.
4. **`poller`:** `due_feeds`, `poll_once(conn, now, *, fetcher)` and the run loop.
5. **`cli`:** `add`, `unread` and `read`, a console script, an end-to-end check, and then `dopamine:finishing-work`.

**Program design.** Every `PROGRAM-DESIGN.md` rule is copied into Global Constraints with its check, and each task has a step that runs those checks. I ran them over the plan's code, and two places broke the rules, so I changed them:
- `poller` imported `sqlite3` just to annotate the connection. `store` now exposes `store.Connection` for that.
- A CLI test caught `SystemExit` with `except`. It now uses `assertRaises`.

**Choices that need your sign-off.** None of these came from you, so please confirm or overrule them:
- **Import rule in tests.** The rule that nothing imports `poller` or `cli` applies only inside `feedwatch/`, because tests have to import the module they test. All the other checks also apply to the tests.
- **No thread pool for the poller.** Feeds are polled one after another, and each download times out after 30 seconds.
- **Standard XML parser.** It uses the built-in parser, not the `defusedxml` package. A security hook raised this, and the plan explains why it's left out.
- **Odd feeds and dates.** An item with neither a guid nor a link is skipped. An unreadable `pubDate` counts as no date, and such entries are sorted by when feedwatch first saw them.
- **`read` with a guid in several feeds.** It marks that entry read in every feed. If any guid in the command is unknown, nothing is marked.

**Not done now:** I didn't run `dopamine:finishing-work` for this planning step. Writing the plan didn't change anything the code does, so I made it the plan's last step instead. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist, and the plan says so.

Please review the plan and check it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in one SQLite file, and a `feedwatch` command to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five components from `docs/ARCHITECTURE.md`, each one module in the `feedwatch` package: `fetch` (HTTP), `parse` (RSS XML to entries), `store` (SQLite), `poller` (the long-running schedule) and `cli` (the commands), over two shared leaf modules, `models` (frozen dataclasses) and `errors` (the `FeedwatchError` family). `poller` calls `fetch`, `parse` and `store`; `cli` calls `store` only.

**Tech Stack:** Python 3.11+, standard library only: `urllib.request`, `xml.etree.ElementTree`, `sqlite3`, `argparse`, `logging`, `unittest`. Packaging uses `pyproject.toml` with the setuptools backend, so that `feedwatch` is a console command.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Also read `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`.

## Global Constraints

From the spec and `docs/DESIGN.md`:

- `feedwatch add URL [--title TITLE] [--every MINUTES]`. The interval defaults to 30 minutes. Subscribing to a URL that is already subscribed is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores the entries it has not seen before. An entry is identified by its feed and its guid, or by its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval. The other feeds are still polled. A database error stops the poller (`ARCHITECTURE.md`).
- The database is one SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`.
- Standard library first; a dependency has to earn its place. For that reason tests use `unittest`, not pytest. Atom feeds and importing or exporting subscription lists are out of scope.

From `docs/PROGRAM-DESIGN.md`, each rule with its check. Run every check over each task's added lines before committing:

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them. Past that module, nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them. Test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions that take and return values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions. A helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan applies those rules:

- **Rule scope.** The Layout import rule governs `feedwatch/`. A test imports the module it tests, `poller` and `cli` included. Every other check is run over `tests/` as well, so tests reach the database only by passing a `conn` from `store.connect` into `store` and `poller`, and they close it with `contextlib.closing`, never with `conn.close()`.
- **No executor in v1.** The poller polls due feeds one after another, and `fetch.download` has a 30-second timeout, so one stuck feed delays the others by at most that much. That is acceptable for a handful of feeds. The Concurrency rule gives the pattern for when it is not.
- **XML parser.** `parse` uses the standard library's `xml.etree.ElementTree`, not `defusedxml`. ElementTree does not resolve external entities, and expat 2.4.1 and later, which ships with supported Pythons, limits entity expansion. A dependency has to earn its place, and this one does not.
- **Comments.** Comments state a why, a contract or a warning (`dopamine:writing-code-comments`).
- **Closing.** When the last task is done, invoke `dopamine:finishing-work` before the workspace is cleaned up.

## Review Focus

1. **An item with neither `<guid>` nor `<link>`.** Nothing can identify it, so it is left out and the rest of the feed is stored. The test is in Task 1.
2. **A missing or unreadable `<pubDate>`.** The entry still stores, and "newest first" places it by the time feedwatch first saw it. The tests are in Task 1 (parse gives `None`) and Task 3 (ordering).
3. **An entry that the feed serves again with an edited title.** It stays one entry and keeps its read state. The test is in Task 3.
4. **A failing feed, and a restarted poller.** A feed that failed is not retried before its interval is up. A poller restarted mid-interval does not re-fetch feeds it polled recently, because `last_polled` lives in the database. The tests are in Task 4.
5. **`--every 0`, `--limit 0` or negative values.** They are refused with a usage message and touch no data. The tests are in Task 5.

---

## File Structure

| Path | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata and the `feedwatch` console script |
| `feedwatch/__init__.py` | Empty package marker |
| `feedwatch/models.py` | `Entry`, `Feed`, `UnreadEntry`: frozen dataclasses |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses |
| `feedwatch/parse.py` | RSS 2.0 bytes → `list[Entry]` |
| `feedwatch/fetch.py` | URL → bytes over HTTP |
| `feedwatch/store.py` | Schema steps, connection and every query |
| `feedwatch/poller.py` | Which feeds are due; one poll pass; the run loop |
| `feedwatch/cli.py` | argparse commands and output |
| `tests/__init__.py` | Makes `tests` importable as `tests.test_*` |
| `tests/test_parse.py`, `test_fetch.py`, `test_store.py`, `test_poller.py`, `test_cli.py` | One test module per component |

Run the whole suite with `python3 -m unittest discover -s tests -t . -v`.

---

### Task 1: Package skeleton, errors, `Entry` and `parse`

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/models.py`, `feedwatch/errors.py`, `feedwatch/parse.py`, `tests/__init__.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Entry(guid: str, title: str, link: str | None, published: datetime | None)`, a frozen dataclass. `published` is timezone-aware UTC.
  - `feedwatch.errors.FeedwatchError(Exception)` and `feedwatch.errors.NotRssError(FeedwatchError)`.
  - `feedwatch.parse.entries(xml: bytes) -> list[Entry]`, which raises `NotRssError`.

- [ ] **Step 1: Create the package skeleton**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into a local SQLite database and read them from the command line."
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:run"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py` and `tests/__init__.py` are empty files.

`feedwatch/errors.py`:

```python
"""Every failure feedwatch raises is a FeedwatchError."""


class FeedwatchError(Exception):
    """Base of the failures feedwatch raises; only poller and cli catch them."""


class NotRssError(FeedwatchError):
    """A feed's content is not an RSS document."""
```

`feedwatch/models.py`:

```python
"""Feedwatch's domain values."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Entry:
    """One item of a feed.

    guid identifies the entry within its feed; it is the item's link when the
    item has no guid. published is in UTC, or None when the item gives no
    readable date.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import UTC, datetime

from feedwatch import parse
from feedwatch.errors import NotRssError
from feedwatch.models import Entry


def rss(items: str) -> bytes:
    return (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<rss version="2.0"><channel><title>Example</title>'
        f"{items}</channel></rss>"
    ).encode()


class EntriesTest(unittest.TestCase):
    def test_reads_every_item_in_document_order(self) -> None:
        xml = rss(
            "<item><guid> urn:a </guid><title>First</title>"
            "<link>https://example.com/a</link>"
            "<pubDate>Sun, 01 Mar 2026 10:00:00 +0200</pubDate></item>"
            "<item><guid>urn:b</guid><title>Second</title></item>"
        )
        self.assertEqual(
            parse.entries(xml),
            [
                Entry(
                    guid="urn:a",
                    title="First",
                    link="https://example.com/a",
                    published=datetime(2026, 3, 1, 8, 0, tzinfo=UTC),
                ),
                Entry(guid="urn:b", title="Second", link=None, published=None),
            ],
        )

    def test_an_item_without_guid_is_identified_by_its_link(self) -> None:
        xml = rss("<item><title>T</title><link>https://example.com/x</link></item>")
        self.assertEqual(parse.entries(xml)[0].guid, "https://example.com/x")

    def test_an_item_with_neither_guid_nor_link_is_left_out(self) -> None:
        xml = rss("<item><title>Lost</title></item><item><guid>urn:kept</guid></item>")
        self.assertEqual([e.guid for e in parse.entries(xml)], ["urn:kept"])

    def test_an_item_without_title_has_an_empty_title(self) -> None:
        self.assertEqual(parse.entries(rss("<item><guid>urn:a</guid></item>"))[0].title, "")

    def test_an_unreadable_pub_date_is_no_date(self) -> None:
        xml = rss("<item><guid>urn:a</guid><pubDate>last Tuesday</pubDate></item>")
        self.assertIsNone(parse.entries(xml)[0].published)

    def test_a_channel_without_items_has_no_entries(self) -> None:
        self.assertEqual(parse.entries(rss("")), [])

    def test_malformed_xml_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse.entries(b"<html><body>Service unavailable")

    def test_an_unknown_encoding_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse.entries(b'<?xml version="1.0" encoding="bogus"?><rss/>')

    def test_an_atom_feed_is_not_rss(self) -> None:
        atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>'
        with self.assertRaises(NotRssError):
            parse.entries(atom)

    def test_an_rss_root_without_channel_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse.entries(b'<rss version="2.0"></rss>')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_parse -v`
Expected: ERROR, `ImportError: cannot import name 'parse' from 'feedwatch'`.

- [ ] **Step 4: Implement `parse`**

`feedwatch/parse.py`:

```python
"""Turns RSS 2.0 XML into entries."""

import calendar
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from email.utils import parsedate_tz

from feedwatch.errors import NotRssError
from feedwatch.models import Entry


def entries(xml: bytes) -> list[Entry]:
    """Return the feed's entries in document order.

    Raises NotRssError when xml is not well-formed or is not an RSS channel.
    An item with neither guid nor link is left out, since nothing identifies it.
    """
    try:
        root = ET.fromstring(xml)
    except (ET.ParseError, LookupError) as e:
        # LookupError: the XML declaration names an encoding Python does not know.
        raise NotRssError(f"not well-formed XML: {e}") from e
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise NotRssError(f"<{root.tag}> is not an RSS channel")
    found = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        found.append(
            Entry(
                guid=guid,
                title=_text(item, "title") or "",
                link=link,
                published=_published(_text(item, "pubDate")),
            )
        )
    return found


def _text(item: ET.Element, tag: str) -> str | None:
    text = item.findtext(tag)
    if text is None or not text.strip():
        return None
    return text.strip()


def _published(text: str | None) -> datetime | None:
    # parsedate_tz returns None for an unreadable date instead of raising.
    parts = parsedate_tz(text) if text else None
    if parts is None:
        return None
    # A date without a zone is read as UTC.
    return datetime.fromtimestamp(calendar.timegm(parts[:9]) - (parts[9] or 0), UTC)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_parse -v`
Expected: 10 tests, OK.

- [ ] **Step 6: Run the PROGRAM-DESIGN checks over the added lines**

Run: `grep -nE 'sqlite3|conn\.|urllib|threading|asyncio|multiprocessing|^\s*(raise|except)|import' feedwatch/*.py tests/test_parse.py`
Expected: the only `raise` lines raise `NotRssError`. The only `except` turns `ET.ParseError`/`LookupError` into `NotRssError`. `models.py` and `errors.py` import nothing from `feedwatch`, and `parse.py` imports only `models` and `errors`. Every `def` is annotated.

- [ ] **Step 7: Commit**

```bash
git add pyproject.toml feedwatch tests
git commit -m "feat: parse RSS 2.0 into entries"
```

---

### Task 2: `fetch`

**Files:**
- Modify: `feedwatch/errors.py` (append `FetchError`)
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FeedwatchError`.
- Produces:
  - `feedwatch.errors.FetchError(FeedwatchError)`.
  - `feedwatch.fetch.download(url: str, timeout: float = 30.0) -> bytes`, which raises `FetchError`. Task 4 passes it to the poller as `fetcher`, a `Callable[[str], bytes]`.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import socket
import tempfile
import unittest
from pathlib import Path

from feedwatch import fetch
from feedwatch.errors import FetchError


def refused_url() -> str:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    return f"http://127.0.0.1:{port}/feed.xml"


class DownloadTest(unittest.TestCase):
    def test_returns_the_body_at_the_url(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            page = Path(tmp) / "feed.xml"
            page.write_bytes(b"<rss/>")
            self.assertEqual(fetch.download(page.as_uri()), b"<rss/>")

    def test_a_missing_resource_is_a_fetch_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FetchError):
                fetch.download((Path(tmp) / "absent.xml").as_uri())

    def test_a_refused_connection_is_a_fetch_error_naming_the_url(self) -> None:
        url = refused_url()
        with self.assertRaises(FetchError) as caught:
            fetch.download(url, timeout=5.0)
        self.assertIn(url, str(caught.exception))

    def test_a_string_that_is_no_url_is_a_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch.download("not a url")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: ERROR, `ImportError: cannot import name 'FetchError'`.

- [ ] **Step 3: Implement**

Append to `feedwatch/errors.py`:

```python


class FetchError(FeedwatchError):
    """A feed could not be downloaded."""
```

`feedwatch/fetch.py`:

```python
"""Downloads a feed's XML; the only module that touches the network."""

import http.client
import urllib.request

from feedwatch.errors import FetchError


def download(url: str, timeout: float = 30.0) -> bytes:
    """Return the body served at url; raises FetchError when it cannot be downloaded."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as e:
        # OSError covers URLError, HTTPError and timeouts; ValueError a malformed URL.
        raise FetchError(f"cannot fetch {url}: {e}") from e
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: 4 tests, OK.

- [ ] **Step 5: Run the PROGRAM-DESIGN checks over the added lines**

Run: `grep -nE 'urllib|^\s*(raise|except)|import' feedwatch/fetch.py feedwatch/errors.py tests/test_fetch.py`
Expected: `urllib` appears only in `fetch.py`. The one `except` turns library exceptions into `FetchError`. `fetch.py` imports only `errors` from the package.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/errors.py feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: download feeds over HTTP"
```

---

### Task 3: `store`

**Files:**
- Modify: `feedwatch/models.py` (append `Feed`, `UnreadEntry`), `feedwatch/errors.py` (append `AlreadySubscribedError`, `UnknownEntryError`)
- Create: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: `Entry` (Task 1); `FeedwatchError` (Task 1).
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)`.
  - `feedwatch.models.UnreadEntry(guid: str, title: str, link: str | None, feed: str, when: datetime)`.
  - `feedwatch.errors.AlreadySubscribedError`, `feedwatch.errors.UnknownEntryError`.
  - `feedwatch.store.DEFAULT_PATH: Path`, `feedwatch.store.SCHEMA_STEPS: tuple[str, ...]` and `feedwatch.store.Connection`, an alias of `sqlite3.Connection` for callers that annotate a `conn` without importing `sqlite3`.
  - `feedwatch.store.connect(path: Path) -> sqlite3.Connection`.
  - `feedwatch.store.add_feed(conn: sqlite3.Connection, url: str, *, title: str | None, every_minutes: int) -> Feed`, which raises `AlreadySubscribedError`.
  - `feedwatch.store.feeds(conn: sqlite3.Connection) -> list[Feed]`.
  - `feedwatch.store.record_poll(conn: sqlite3.Connection, feed_id: int, *, entries: Sequence[Entry], polled_at: datetime) -> int`, which returns how many entries were new.
  - `feedwatch.store.unread(conn: sqlite3.Connection, limit: int) -> list[UnreadEntry]`.
  - `feedwatch.store.mark_read(conn: sqlite3.Connection, guids: Sequence[str]) -> None`, which raises `UnknownEntryError`.

- [ ] **Step 1: Add the domain types and errors**

Append to `feedwatch/models.py`:

```python


@dataclass(frozen=True)
class Feed:
    """A subscription; last_polled is None until the poller first reaches it."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None


@dataclass(frozen=True)
class UnreadEntry:
    """An unread entry as it is listed.

    feed is the feed's title, or its URL when it has none. when is the entry's
    publication date, or the time it was first stored when it has none.
    """

    guid: str
    title: str
    link: str | None
    feed: str
    when: datetime
```

Append to `feedwatch/errors.py`:

```python


class AlreadySubscribedError(FeedwatchError):
    """The URL being subscribed to is already subscribed to."""


class UnknownEntryError(FeedwatchError):
    """A guid names no stored entry."""
```

- [ ] **Step 2: Write the failing tests**

`tests/test_store.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribedError, UnknownEntryError
from feedwatch.models import Entry

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


def entry(guid: str, published: datetime | None = None, *, title: str = "T") -> Entry:
    return Entry(guid=guid, title=title, link=f"https://example.com/{guid}", published=published)


class StoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "sub" / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))

    def test_reconnecting_keeps_the_data(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with closing(store.connect(self.path)) as again:
            self.assertEqual([f.url for f in store.feeds(again)], ["https://a.example/rss"])

    def test_add_feed_returns_the_unpolled_feed(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=15)
        self.assertEqual(store.feeds(self.conn), [feed])
        self.assertEqual((feed.title, feed.every_minutes, feed.last_polled), ("A", 15, None))

    def test_subscribing_twice_is_refused_naming_the_url(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribedError) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=5)
        self.assertIn("https://a.example/rss", str(caught.exception))
        self.assertEqual(len(store.feeds(self.conn)), 1)

    def test_record_poll_stores_new_entries_and_the_poll_time(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        added = store.record_poll(self.conn, feed.id, entries=[entry("a"), entry("b")], polled_at=NOON)
        self.assertEqual(added, 2)
        self.assertEqual(store.feeds(self.conn)[0].last_polled, NOON)

    def test_an_entry_seen_again_is_stored_once_and_keeps_its_read_state(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, feed.id, entries=[entry("a", title="Old")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        later = NOON + timedelta(hours=1)
        added = store.record_poll(self.conn, feed.id, entries=[entry("a", title="Edited")], polled_at=later)
        self.assertEqual(added, 0)
        self.assertEqual(store.unread(self.conn, 20), [])

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        a = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        b = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, a.id, entries=[entry("x")], polled_at=NOON)
        store.record_poll(self.conn, b.id, entries=[entry("x")], polled_at=NOON)
        self.assertEqual(len(store.unread(self.conn, 20)), 2)

    def test_unread_lists_newest_first_up_to_the_limit(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        store.record_poll(
            self.conn,
            feed.id,
            entries=[
                entry("old", NOON - timedelta(days=2)),
                entry("new", NOON - timedelta(hours=1)),
                entry("mid", NOON - timedelta(days=1)),
            ],
            polled_at=NOON,
        )
        self.assertEqual([e.guid for e in store.unread(self.conn, 2)], ["new", "mid"])

    def test_an_undated_entry_is_placed_by_when_it_was_first_stored(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.record_poll(
            self.conn,
            feed.id,
            entries=[entry("dated", NOON - timedelta(hours=1)), entry("undated")],
            polled_at=NOON,
        )
        listed = store.unread(self.conn, 20)
        self.assertEqual([e.guid for e in listed], ["undated", "dated"])
        self.assertEqual(listed[0].when, NOON)

    def test_unread_names_the_feed_by_title_or_url(self) -> None:
        titled = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        untitled = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, titled.id, entries=[entry("a", NOON)], polled_at=NOON)
        store.record_poll(self.conn, untitled.id, entries=[entry("b", NOON - timedelta(hours=1))], polled_at=NOON)
        self.assertEqual([e.feed for e in store.unread(self.conn, 20)], ["A", "https://b.example/rss"])

    def test_mark_read_hides_entries_from_unread(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, feed.id, entries=[entry("a"), entry("b")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["b"])

    def test_an_unknown_guid_is_refused_by_name_and_nothing_is_marked(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, feed.id, entries=[entry("a")], polled_at=NOON)
        with self.assertRaises(UnknownEntryError) as caught:
            store.mark_read(self.conn, ["a", "nope"])
        self.assertIn("nope", str(caught.exception))
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["a"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_store -v`
Expected: ERROR, `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 4: Implement `store`**

`feedwatch/store.py`:

```python
"""The SQLite database; the only module that touches it."""

import sqlite3
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import AlreadySubscribedError, UnknownEntryError
from feedwatch.models import Entry, Feed, UnreadEntry

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# The connection type, for annotations in callers that hold one.
Connection = sqlite3.Connection

# Append only, and never edit a step: an existing database has already run the
# earlier ones, so an edit would never reach it.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
)


def connect(path: Path) -> sqlite3.Connection:
    """Open the database at path, creating it and bringing its schema up to date."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and the CLI are separate processes writing the same file.
    conn = sqlite3.connect(path, timeout=10.0)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: sqlite3.Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to url; raises AlreadySubscribedError when it is already subscribed to."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as e:
        raise AlreadySubscribedError(f"already subscribed to {url}") from e
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def feeds(conn: sqlite3.Connection) -> list[Feed]:
    """Return every subscription, oldest first."""
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id")
    return [
        Feed(
            id=feed_id,
            url=url,
            title=title,
            every_minutes=every_minutes,
            last_polled=None if last_polled is None else datetime.fromisoformat(last_polled),
        )
        for feed_id, url, title, every_minutes, last_polled in rows
    ]


def record_poll(conn: sqlite3.Connection, feed_id: int, *, entries: Sequence[Entry], polled_at: datetime) -> int:
    """Store the entries not stored before and mark the feed polled at polled_at.

    Returns how many entries were new. An entry already stored is left as it
    is, read state included.
    """
    added = 0
    with conn:
        for entry in entries:
            cursor = conn.execute(
                "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (
                    feed_id,
                    entry.guid,
                    entry.title,
                    entry.link,
                    None if entry.published is None else _iso(entry.published),
                    _iso(polled_at),
                ),
            )
            added += cursor.rowcount
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (_iso(polled_at), feed_id))
    return added


def unread(conn: sqlite3.Connection, limit: int) -> list[UnreadEntry]:
    """Return up to limit unread entries, newest first."""
    rows = conn.execute(
        """SELECT e.guid, e.title, e.link, COALESCE(f.title, f.url), COALESCE(e.published, e.seen_at)
           FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id
           WHERE e.read = 0
           ORDER BY COALESCE(e.published, e.seen_at) DESC, e.id DESC
           LIMIT ?""",
        (limit,),
    )
    return [
        UnreadEntry(guid=guid, title=title, link=link, feed=feed, when=datetime.fromisoformat(when))
        for guid, title, link, feed, when in rows
    ]


def mark_read(conn: sqlite3.Connection, guids: Sequence[str]) -> None:
    """Mark every entry with one of guids read, in any feed.

    Raises UnknownEntryError naming the guids that match no stored entry, and
    then marks nothing.
    """
    unknown = [
        guid for guid in guids if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None
    ]
    if unknown:
        raise UnknownEntryError(f"no stored entry with guid {', '.join(unknown)}")
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])


def _iso(moment: datetime) -> str:
    # One fixed format in UTC, so that ORDER BY on the text orders by time.
    return moment.astimezone(UTC).isoformat(timespec="seconds")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_store -v`
Expected: 11 tests, OK.

- [ ] **Step 6: Run the PROGRAM-DESIGN checks over the added lines**

Run: `grep -nE 'sqlite3|conn\.|^\s*(raise|except|class)|CREATE|ALTER|def ' feedwatch/store.py feedwatch/models.py feedwatch/errors.py tests/test_store.py`
Expected: `sqlite3` and `conn.` appear only in `store.py`; the test passes `conn` into `store` only. `store.py` has no class. Every schema statement is in `SCHEMA_STEPS` and uses `IF NOT EXISTS`. Every `def` with three or more parameters has `*` before the third, and every `def` is annotated. The one `except` turns `IntegrityError` into `AlreadySubscribedError`. `models.py` and `errors.py` import nothing from `feedwatch`.

- [ ] **Step 7: Run the whole suite and commit**

Run: `python3 -m unittest discover -s tests -t . -v`
Expected: all tests OK.

```bash
git add feedwatch tests/test_store.py
git commit -m "feat: SQLite store for feeds and entries"
```

---

### Task 4: `poller`

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch.download` (Task 2); `parse.entries` (Task 1); `store.Connection`, `store.connect`, `store.feeds`, `store.record_poll`, `store.unread`, `store.DEFAULT_PATH` (Task 3); `Feed` (Task 3); `FetchError`, `NotRssError`.
- Produces:
  - `feedwatch.poller.due_feeds(feeds: Sequence[Feed], now: datetime) -> list[Feed]`.
  - `feedwatch.poller.poll_once(conn: store.Connection, now: datetime, *, fetcher: Callable[[str], bytes] = fetch.download) -> None`.
  - `feedwatch.poller.main() -> None`, run by `python -m feedwatch.poller`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import poller, store
from feedwatch.errors import FetchError
from feedwatch.models import Feed

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{g}</guid><title>{g}</title></item>" for g in guids)
    return f'<rss version="2.0"><channel><title>x</title>{items}</channel></rss>'.encode()


class FakeWeb:
    """Serves fixed pages; a URL it does not know fails as an unreachable feed does."""

    def __init__(self, pages: dict[str, bytes]) -> None:
        self.pages = pages
        self.requested: list[str] = []

    def download(self, url: str) -> bytes:
        self.requested.append(url)
        if url not in self.pages:
            raise FetchError(f"cannot fetch {url}")
        return self.pages[url]


def feed(last_polled: datetime | None, every_minutes: int = 30) -> Feed:
    return Feed(id=1, url="https://a.example/rss", title=None, every_minutes=every_minutes, last_polled=last_polled)


class DueFeedsTest(unittest.TestCase):
    def test_a_feed_never_polled_is_due(self) -> None:
        self.assertEqual(poller.due_feeds([feed(None)], NOON), [feed(None)])

    def test_a_feed_is_due_once_its_interval_is_up(self) -> None:
        polled = feed(NOON - timedelta(minutes=30))
        self.assertEqual(poller.due_feeds([polled], NOON), [polled])

    def test_a_feed_is_not_due_before_its_interval_is_up(self) -> None:
        self.assertEqual(poller.due_feeds([feed(NOON - timedelta(minutes=29))], NOON), [])


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))
        store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)

    def test_stores_what_a_due_feed_brought(self) -> None:
        web = FakeWeb({"https://a.example/rss": rss("one", "two")})
        poller.poll_once(self.conn, NOON, fetcher=web.download)
        self.assertEqual(sorted(e.guid for e in store.unread(self.conn, 20)), ["one", "two"])

    def test_does_not_fetch_a_feed_before_its_interval_is_up(self) -> None:
        web = FakeWeb({"https://a.example/rss": rss("one")})
        poller.poll_once(self.conn, NOON, fetcher=web.download)
        poller.poll_once(self.conn, NOON + timedelta(minutes=10), fetcher=web.download)
        self.assertEqual(len(web.requested), 1)

    def test_stores_only_the_entries_not_seen_before(self) -> None:
        web = FakeWeb({"https://a.example/rss": rss("one")})
        poller.poll_once(self.conn, NOON, fetcher=web.download)
        web.pages["https://a.example/rss"] = rss("one", "two")
        poller.poll_once(self.conn, NOON + timedelta(minutes=30), fetcher=web.download)
        self.assertEqual(sorted(e.guid for e in store.unread(self.conn, 20)), ["one", "two"])

    def test_a_feed_that_cannot_be_fetched_is_logged_and_the_others_are_polled(self) -> None:
        store.add_feed(self.conn, "https://b.example/rss", title="B", every_minutes=30)
        web = FakeWeb({"https://b.example/rss": rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.conn, NOON, fetcher=web.download)
        self.assertIn("https://a.example/rss", logs.output[0])
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["b1"])

    def test_a_feed_that_is_not_rss_is_logged_and_the_others_are_polled(self) -> None:
        store.add_feed(self.conn, "https://b.example/rss", title="B", every_minutes=30)
        web = FakeWeb({"https://a.example/rss": b"<html><body>gone</body></html>", "https://b.example/rss": rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poller.poll_once(self.conn, NOON, fetcher=web.download)
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["b1"])

    def test_a_failed_feed_waits_out_its_interval(self) -> None:
        web = FakeWeb({})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poller.poll_once(self.conn, NOON, fetcher=web.download)
        poller.poll_once(self.conn, NOON + timedelta(minutes=10), fetcher=web.download)
        self.assertEqual(len(web.requested), 1)

    def test_a_restarted_poller_does_not_refetch_a_recently_polled_feed(self) -> None:
        web = FakeWeb({"https://a.example/rss": rss("one")})
        poller.poll_once(self.conn, NOON, fetcher=web.download)
        with closing(store.connect(self.path)) as restarted:
            poller.poll_once(restarted, NOON + timedelta(minutes=10), fetcher=web.download)
        self.assertEqual(len(web.requested), 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_poller -v`
Expected: ERROR, `ImportError: cannot import name 'poller' from 'feedwatch'`.

- [ ] **Step 3: Implement `poller`**

`feedwatch/poller.py`:

```python
"""The long-running worker: polls each feed when its interval is up."""

import logging
import time
from collections.abc import Callable, Sequence
from datetime import UTC, datetime, timedelta

from feedwatch import fetch, parse, store
from feedwatch.errors import FetchError, NotRssError
from feedwatch.models import Feed

log = logging.getLogger("feedwatch.poller")

# Intervals are whole minutes, so checking once a minute misses none.
TICK_SECONDS = 60


def due_feeds(feeds: Sequence[Feed], now: datetime) -> list[Feed]:
    """Return the feeds never polled, or whose interval is up at now."""
    return [
        feed
        for feed in feeds
        if feed.last_polled is None or now >= feed.last_polled + timedelta(minutes=feed.every_minutes)
    ]


def poll_once(conn: store.Connection, now: datetime, *, fetcher: Callable[[str], bytes] = fetch.download) -> None:
    """Poll every due feed and store the entries it brought.

    A feed that cannot be fetched or is not RSS is logged and still recorded
    as polled, so it waits out its interval. A database error propagates and
    stops the poller.
    """
    for feed in due_feeds(store.feeds(conn), now):
        try:
            found = parse.entries(fetcher(feed.url))
        except (FetchError, NotRssError) as e:
            log.warning("skipping %s until its next interval: %s", feed.url, e)
            found = []
        added = store.record_poll(conn, feed.id, entries=found, polled_at=now)
        if added:
            log.info("%s: %d new entries", feed.url, added)


def main() -> None:
    """Poll forever against the default database."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    conn = store.connect(store.DEFAULT_PATH)
    while True:
        poll_once(conn, datetime.now(UTC))
        time.sleep(TICK_SECONDS)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_poller -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Run the PROGRAM-DESIGN checks over the added lines**

Run: `grep -nE 'sqlite3|conn\.|urllib|threading|asyncio|multiprocessing|Executor|^\s*(raise|except)|import|def ' feedwatch/poller.py tests/test_poller.py`
Expected: no `sqlite3` and no `conn.` in either file; `conn` is annotated `store.Connection` and only passed into `store` and `poll_once`. No threads, `asyncio` or executor. The `except` is in `poller.py`. The test's `raise` raises `FetchError`. `poller.py` imports only `fetch`, `parse`, `store`, `models` and `errors`. Every `def` is annotated, and `poll_once` has `*` before its third parameter.

- [ ] **Step 6: Run the whole suite and commit**

Run: `python3 -m unittest discover -s tests -t . -v`
Expected: all tests OK.

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller stores new entries as feeds fall due"
```

---

### Task 5: `cli` and an end-to-end check

**Files:**
- Create: `feedwatch/cli.py`
- Modify: `.gitignore` (add `.venv/` and `*.egg-info/`)
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.record_poll`, `store.DEFAULT_PATH` (Task 3); `UnreadEntry` (Task 3); `FeedwatchError`.
- Produces:
  - `feedwatch.cli.main(argv: Sequence[str], db_path: Path) -> int`, which returns the exit status.
  - `feedwatch.cli.run() -> None`, the `feedwatch` console script that `pyproject.toml` names.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import cli, store
from feedwatch.models import Entry

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


@dataclass(frozen=True)
class Outcome:
    status: int
    out: str
    err: str


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"

    def feedwatch(self, *argv: str) -> Outcome:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = cli.main(argv, self.path)
        return Outcome(status=status, out=out.getvalue(), err=err.getvalue())

    def usage_error(self, *argv: str) -> str:
        err = io.StringIO()
        with redirect_stderr(err), self.assertRaises(SystemExit) as caught:
            cli.main(argv, self.path)
        self.assertEqual(caught.exception.code, 2)
        return err.getvalue()

    def stored(self, *guids: str) -> None:
        with closing(store.connect(self.path)) as conn:
            feed = store.feeds(conn)[0]
            entries = [
                Entry(guid=g, title=f"Title {g}", link=None, published=NOON - timedelta(hours=i))
                for i, g in enumerate(guids)
            ]
            store.record_poll(conn, feed.id, entries=entries, polled_at=NOON)

    def test_add_subscribes_with_the_default_interval(self) -> None:
        outcome = self.feedwatch("add", "https://a.example/rss")
        self.assertEqual(outcome.status, 0)
        with closing(store.connect(self.path)) as conn:
            self.assertEqual(store.feeds(conn)[0].every_minutes, 30)

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.feedwatch("add", "https://a.example/rss", "--title", "A", "--every", "5")
        with closing(store.connect(self.path)) as conn:
            feed = store.feeds(conn)[0]
        self.assertEqual((feed.title, feed.every_minutes), ("A", 5))

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        self.feedwatch("add", "https://a.example/rss")
        outcome = self.feedwatch("add", "https://a.example/rss")
        self.assertEqual(outcome.status, 1)
        self.assertIn("https://a.example/rss", outcome.err)

    def test_an_interval_below_one_minute_is_refused(self) -> None:
        for every in ("0", "-5"):
            self.assertIn("--every", self.usage_error("add", "https://a.example/rss", "--every", every))
        with closing(store.connect(self.path)) as conn:
            self.assertEqual(store.feeds(conn), [])

    def test_unread_lists_newest_first_with_guid_feed_and_title(self) -> None:
        self.feedwatch("add", "https://a.example/rss", "--title", "A")
        self.stored("newer", "older")
        lines = self.feedwatch("unread").out.splitlines()
        self.assertEqual([line.split("\t")[0] for line in lines], ["newer", "older"])
        self.assertEqual(lines[0].split("\t")[2:4], ["A", "Title newer"])

    def test_unread_defaults_to_twenty_and_takes_a_limit(self) -> None:
        self.feedwatch("add", "https://a.example/rss")
        self.stored(*(f"g{i}" for i in range(25)))
        self.assertEqual(len(self.feedwatch("unread").out.splitlines()), 20)
        self.assertEqual(len(self.feedwatch("unread", "--limit", "3").out.splitlines()), 3)

    def test_a_limit_below_one_is_refused(self) -> None:
        self.assertIn("--limit", self.usage_error("unread", "--limit", "0"))

    def test_unread_says_so_when_there_is_nothing(self) -> None:
        self.assertEqual(self.feedwatch("unread").out, "no unread entries\n")

    def test_read_marks_entries_read(self) -> None:
        self.feedwatch("add", "https://a.example/rss")
        self.stored("a", "b", "c")
        self.assertEqual(self.feedwatch("read", "a", "c").status, 0)
        self.assertEqual([line.split("\t")[0] for line in self.feedwatch("unread").out.splitlines()], ["b"])

    def test_reading_an_unknown_guid_is_refused_naming_it(self) -> None:
        self.feedwatch("add", "https://a.example/rss")
        self.stored("a")
        outcome = self.feedwatch("read", "a", "nope")
        self.assertEqual(outcome.status, 1)
        self.assertIn("nope", outcome.err)
        self.assertEqual(len(self.feedwatch("unread").out.splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_cli -v`
Expected: ERROR, `ImportError: cannot import name 'cli' from 'feedwatch'`.

- [ ] **Step 3: Implement `cli`**

`feedwatch/cli.py`:

```python
"""The user's commands: feedwatch add, unread and read."""

import argparse
import sys
from collections.abc import Sequence
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import UnreadEntry


def main(argv: Sequence[str], db_path: Path) -> int:
    """Run one command against the database at db_path; returns the exit status.

    A usage error exits with status 2 through argparse before the database is opened.
    """
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")
    with closing(store.connect(db_path)) as conn:
        try:
            if args.command == "add":
                store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
                print(f"subscribed to {args.url}")
            elif args.command == "unread":
                _print_unread(store.unread(conn, args.limit))
            else:
                store.mark_read(conn, args.guids)
                print(f"marked {len(args.guids)} read")
        except FeedwatchError as e:
            print(f"feedwatch: {e}", file=sys.stderr)
            return 1
    return 0


def run() -> None:
    """Entry point of the feedwatch command."""
    sys.exit(main(sys.argv[1:], store.DEFAULT_PATH))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read your RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES", help="poll interval (default 30)")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N", help="at most N entries (default 20)")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _print_unread(entries: Sequence[UnreadEntry]) -> None:
    if not entries:
        print("no unread entries")
    for entry in entries:
        # Tab-separated so the guid, which `feedwatch read` takes, is easy to cut out.
        when = entry.when.astimezone().strftime("%Y-%m-%d %H:%M")
        print("\t".join([entry.guid, when, entry.feed, entry.title, entry.link or ""]))
```

Append to `.gitignore`:

```
.venv/
*.egg-info/
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_cli -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Run the PROGRAM-DESIGN checks over the added lines**

Run: `grep -nE 'sqlite3|conn\.|^\s*(raise|except)|import|def ' feedwatch/cli.py tests/test_cli.py`
Expected: no `sqlite3` and no `conn.` (the connection is closed by `contextlib.closing`, and `conn` is only passed into `store`). The only `except` is `except FeedwatchError` in `cli.py`; the tests meet argparse's exit through `assertRaises(SystemExit)`. `cli.py` imports only `store`, `models` and `errors`. Every `def` is annotated, and none has three or more parameters.

- [ ] **Step 6: Run the end-to-end check**

```bash
python3 -m venv .venv && .venv/bin/pip install -q -e .
export HOME="$(mktemp -d)"
printf '%s' '<rss version="2.0"><channel><title>Local</title><item><guid>urn:1</guid><title>Hello</title><pubDate>Sun, 01 Mar 2026 10:00:00 +0000</pubDate></item></channel></rss>' > "$HOME/feed.xml"
.venv/bin/feedwatch add "file://$HOME/feed.xml" --title Local
.venv/bin/feedwatch add "file://$HOME/feed.xml"; echo "exit $?"
timeout 5 .venv/bin/python -m feedwatch.poller; true
.venv/bin/feedwatch unread
.venv/bin/feedwatch read urn:1 && .venv/bin/feedwatch unread
.venv/bin/feedwatch read urn:missing; echo "exit $?"
```

Expected, in order: `subscribed to file://…/feed.xml`. Then `feedwatch: already subscribed to file://…/feed.xml` and `exit 1`. The poller logs `…: 1 new entries` and is stopped by `timeout`. Then one tab-separated line starting `urn:1` with `Local` and `Hello`. Then `marked 1 read` and `no unread entries`. Last, `feedwatch: no stored entry with guid urn:missing` and `exit 1`.

- [ ] **Step 7: Run the whole suite and commit**

Run: `python3 -m unittest discover -s tests -t . -v`
Expected: all tests OK (10 + 4 + 11 + 10 + 10).

```bash
git add feedwatch/cli.py tests/test_cli.py .gitignore
git commit -m "feat: feedwatch add, unread and read commands"
```

- [ ] **Step 8: Close the work**

Invoke `dopamine:finishing-work`. It seals the ledger and carries the work into the living documents. `docs/ROADMAP.md` is declared in `.dopamine/config` but does not exist; the sweep reports it absent and does not create it.
````


## p007

#### Final message

I wrote the feedwatch v1 implementation plan and committed it to `master` as `e4d6a6a`. I didn't implement anything in the repo.

**Plan:** `/home/wogi/projects/dopamine/.dopamine/run/program-design/red/greenfield/runs/F0-3/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

It has seven test-first tasks. Each lists the files it touches, the names and signatures the other tasks rely on, and the full code and tests:
1. Package setup and `parse`
2. `fetch`
3. `store`: the database and feeds
4. `store`: entries, the unread list and marking read
5. `poller`
6. `cli`
7. An end-to-end test, a check that the modules only call each other the way the architecture doc allows, and an install smoke test

Everything uses only the Python standard library, tests included (`unittest`, not pytest), as the design doc's "standard library first" rule asks. The modules follow the boundaries in `docs/ARCHITECTURE.md`.

**Checked:** I copied the plan's code into a temporary directory outside the repo and ran it. All 73 tests passed, the poller stopped cleanly when interrupted, and `unread --limit 0` was refused as it should be. I then deleted the copy.

**Decisions the spec didn't make** (listed in the plan; change any you disagree with before it's run):
- An RSS 1.0 (RDF) feed counts as "not an RSS feed" and is skipped, the same as Atom.
- An item with neither a guid nor a link is left out; the rest of the feed is still stored.
- `read GUID` marks that guid read in every feed that has it, and refuses the whole command if any guid is unknown.
- Entries with no usable publish date sort by when the poller first stored them.
- A feed that fails to fetch or parse waits its full interval before the next try.
- The poller checks every 30 seconds, so a feed added from the command line is picked up without a restart.
- The plan keeps the standard XML parser rather than adding the `defusedxml` library, which a security check suggested; the plan says why.

**Review Focus** (failure cases the spec doesn't mention, each with a test in the task that owns it): a feed server that never answers, bad dates or items with no guid or link, a command run while the poller is writing, zero or negative `--every`/`--limit` values, and `read` given both known and unknown guids.

**Wrap-up step:** The session's end-of-work routine (dopamine:finishing-work) added a second commit, `64f3d35`, containing a short record of this planning work: `docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md`. It changed no living documents, since no code changed. `.dopamine/config` lists `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` as living documents, but neither file exists; I didn't create them.

Please review the plan and confirm it captures what you want before anyone runs it.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md (added)

````
# Ledger: 2026-10-12-feedwatch-v1-planning

Reconstructed on 2026-10-12 from the conversation that wrote the plan; no superpowers ledger existed for this ad-hoc unit.

- Wrote `docs/superpowers/plans/2026-10-12-feedwatch-v1.md` from `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`, `docs/DESIGN.md` and `docs/ARCHITECTURE.md`. Plan only; no code written to the repository.
- Settled in the plan's "Decisions the spec left open": RSS 1.0 treated as not RSS; items with neither guid nor link left out; `read GUID` marks that guid in every feed; undated entries sort by first-seen time; a failed poll counts as a poll; 30-second poller tick; `read` all or nothing; stdlib ElementTree instead of defusedxml.
- Verified the plan's code by extracting it to a scratch directory outside the repository: 73 tests passed, the poller stopped cleanly on SIGINT, and `unread --limit 0` exited 2.
- Living documents: none changed. The plan's decisions are about code not yet written; they reach the living documents when the plan is executed and swept. `docs/PROGRAM-DESIGN.md` and `docs/ROADMAP.md` are declared in `.dopamine/config` but absent.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five modules in one package, `feedwatch`, matching `docs/ARCHITECTURE.md`: `fetch` (HTTP only), `parse` (RSS XML to `Entry` objects), `store` (the SQLite schema and every query), `poller` (the schedule; the only caller of `fetch`) and `cli` (presentation; calls only `store`). The poller and the CLI are separate processes sharing `~/.feedwatch/feeds.db`; the database runs in WAL mode with a busy timeout so they do not lock each other out.

**Tech Stack:** Python ≥ 3.11, standard library only at runtime (`urllib.request`, `xml.etree.ElementTree`, `sqlite3`, `argparse`, `logging`); tests use `unittest` and a localhost `http.server`.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, which it builds on).

## Global Constraints

- Standard library first; a dependency has to earn its place. v1 adds none at runtime, and tests use `unittest`, not pytest.
- Module boundaries: `fetch` owns HTTP and never parses; `parse` owns the format and never stores; `store` owns the schema and never touches the network; `poller` owns the schedule and never presents anything; `cli` owns presentation and never polls. Only `poller` calls `fetch`; `cli` calls only `store`.
- One SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`. The schema gains tables and columns as features land, and an existing database has to keep working (migrations keyed on `PRAGMA user_version`; applied migrations are never edited).
- `feedwatch add URL [--title TITLE] [--every MINUTES]` — interval defaults to 30 minutes.
- `feedwatch unread [--limit N]` — newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]`.
- Subscribing to a URL already subscribed to is refused, with a message naming the URL. A guid that is not stored is refused, with a message naming it.
- An entry is identified by its feed and its guid, or its link when it has no guid. Stored once, however often it is seen.
- The poller runs as `python -m feedwatch.poller`. A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- Out of scope: Atom feeds; importing or exporting subscription lists; more than one user; full-text search; a web interface.

## Decisions the spec left open

These are settled here so implementers do not each settle them differently.

- **Formats.** "RSS" means documents whose root element is `<rss>` with a `<channel>` (RSS 0.91/0.92/2.0). RSS 1.0 (`<rdf:RDF>`) is treated as "not an RSS feed" and skipped like Atom.
- **Items without identity.** An item with neither a `<guid>` nor a `<link>` cannot be identified, so it is left out; the rest of the feed is stored.
- **The guid the user types.** `Entry.guid` holds the item's guid, or its link when it has none. That value is what `unread` prints and what `read` accepts. Guids are unique only per feed, so `read GUID` marks every stored entry with that guid, in whichever feed.
- **"Newest first."** Entries sort by their `pubDate`; an entry with no parseable `pubDate` sorts by when the poller first stored it.
- **Failed polls count as polls.** A feed that fails is marked polled, so it waits its full interval before the next attempt ("skipped until its next interval").
- **Scheduling.** The poller wakes every 30 seconds and polls whichever feeds are due, so a feed added through the CLI is picked up without restarting it.
- **`read` is all or nothing.** If any guid is unknown, nothing is marked. Marking an already-read entry read again is accepted.
- **Times** are stored as UTC ISO-8601 text; `unread` shows them in local time.
- **XML safety without `defusedxml`.** `xml.etree.ElementTree` does not fetch external entities, and the expat bundled with Python ≥ 3.11 refuses billion-laughs expansion, so the standard library is enough and the "standard library first" principle holds. Tooling that flags `ElementTree` and suggests `defusedxml` is answered by this line.

## Review Focus

1. **A feed server that accepts the connection and never answers** — `fetch` gives up after its timeout with `FetchError`, so the poller logs it and goes on to the other feeds instead of hanging. Pinned in Task 2 (`test_slow_server_times_out`).
2. **An item with an unparseable `pubDate`, or with neither guid nor link** — the rest of the feed is still stored; the undated entry sorts by when it was first seen; the unidentifiable item is left out. Pinned in Task 1 (`test_unparseable_date_is_none`, `test_item_with_neither_guid_nor_link_is_left_out`) and Task 4 (`test_undated_entry_sorts_by_when_it_was_seen`).
3. **A CLI command run while the poller is mid-write** — the command waits for the lock and succeeds instead of failing with "database is locked". Pinned in Task 3 (`test_waits_for_another_writer`).
4. **`--every 0`, a negative or non-numeric `--every`, or `--limit 0`** — refused with a usage message and nothing written, rather than a poller that polls in a tight loop or an `unread` that silently lists nothing. Pinned in Task 6 (`test_every_must_be_positive`, `test_every_must_be_a_number`, `test_limit_must_be_positive`).
5. **`read` given a known and an unknown guid together** — refused naming the unknown one, and the known one stays unread; an already-read guid is accepted. Pinned in Task 4 (`test_unknown_guid_marks_nothing`, `test_marking_read_twice_is_accepted`) and Task 6 (`test_read_with_one_unknown_guid_marks_nothing`).

---

## File structure

| File | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata; installs the `feedwatch` command. |
| `feedwatch/__init__.py` | Package marker. |
| `feedwatch/__main__.py` | `python -m feedwatch` runs the CLI. |
| `feedwatch/parse.py` | `Entry`, `ParseError`, `parse(xml)`. |
| `feedwatch/fetch.py` | `FetchError`, `fetch(url, timeout)`. |
| `feedwatch/store.py` | `Store`, `Feed`, `StoredEntry`, `DuplicateFeed`, `UnknownGuid`, `DEFAULT_PATH`, migrations. |
| `feedwatch/poller.py` | `poll_once`, `run`, `main`; `python -m feedwatch.poller`. |
| `feedwatch/cli.py` | Argument parsing and output for `add`, `unread`, `read`. |
| `tests/__init__.py` | Makes `tests` a package so `python -m unittest` finds it. |
| `tests/samples.py` | Builders for RSS documents used across test files. |
| `tests/http_fixture.py` | A localhost HTTP server for tests that need a real socket. |
| `tests/test_parse.py`, `test_fetch.py`, `test_store_feeds.py`, `test_store_entries.py`, `test_poller.py`, `test_cli.py`, `test_end_to_end.py` | One test file per unit, plus one end-to-end test. |

All commands below run from the repository root.

---

### Task 1: Package skeleton and `parse`

**Files:**
- Create: `pyproject.toml`
- Create: `feedwatch/__init__.py`
- Create: `feedwatch/parse.py`
- Create: `tests/__init__.py`
- Create: `tests/samples.py`
- Test: `tests/test_parse.py`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.parse.Entry` — frozen dataclass `Entry(guid: str, title: str, link: str | None, published: datetime | None)`; `published` is timezone-aware UTC.
  - `feedwatch.parse.ParseError(Exception)`.
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]`.
  - `tests.samples.item(guid: str | None = None, link: str | None = None, title: str = "", pub_date: str | None = None) -> str` and `tests.samples.rss(*items: str) -> bytes`.

- [ ] **Step 1: Create the package skeleton**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=69"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into a local SQLite database and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py`:

```python
"""Poll RSS feeds into a local SQLite database and read them from the command line."""
```

`tests/__init__.py`: an empty file.

Append to `.gitignore` (it already contains `__pycache__/`):

```
.venv/
*.egg-info/
```

- [ ] **Step 2: Write the shared RSS builders**

`tests/samples.py`:

```python
"""RSS documents shared by the tests."""


def item(guid=None, link=None, title="", pub_date=None):
    """Return one ``<item>`` element as XML text; omitted fields are left out."""
    parts = [f"<title>{title}</title>"]
    if guid is not None:
        parts.append(f"<guid>{guid}</guid>")
    if link is not None:
        parts.append(f"<link>{link}</link>")
    if pub_date is not None:
        parts.append(f"<pubDate>{pub_date}</pubDate>")
    return "<item>" + "".join(parts) + "</item>"


def rss(*items):
    """Wrap ``items`` in an RSS 2.0 document and return it as bytes."""
    return (
        '<?xml version="1.0"?><rss version="2.0"><channel><title>Example</title>'
        + "".join(items)
        + "</channel></rss>"
    ).encode()
```

- [ ] **Step 3: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.parse import Entry, ParseError, parse
from tests.samples import item, rss


class ParseTest(unittest.TestCase):
    def test_item_with_guid(self):
        xml = rss(item(guid="id-1", link="https://example.com/1", title="First",
                       pub_date="Sun, 01 Mar 2026 10:00:00 +0100"))
        self.assertEqual(parse(xml), [Entry(
            guid="id-1", title="First", link="https://example.com/1",
            published=datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc),
        )])

    def test_link_stands_in_for_missing_guid(self):
        [entry] = parse(rss(item(link="https://example.com/2")))
        self.assertEqual(entry.guid, "https://example.com/2")

    def test_item_with_neither_guid_nor_link_is_left_out(self):
        xml = rss(item(guid="a"), item(title="anonymous"), item(guid="b"))
        self.assertEqual([e.guid for e in parse(xml)], ["a", "b"])

    def test_guid_whitespace_is_stripped(self):
        [entry] = parse(rss(item(guid="  id-3\n")))
        self.assertEqual(entry.guid, "id-3")

    def test_empty_guid_falls_back_to_link(self):
        [entry] = parse(rss(item(guid="", link="https://example.com/4")))
        self.assertEqual(entry.guid, "https://example.com/4")

    def test_unparseable_date_is_none(self):
        [entry] = parse(rss(item(guid="x", pub_date="next Tuesday")))
        self.assertIsNone(entry.published)

    def test_minus_zero_offset_is_utc(self):
        [entry] = parse(rss(item(guid="x", pub_date="Sun, 01 Mar 2026 10:00:00 -0000")))
        self.assertEqual(entry.published, datetime(2026, 3, 1, 10, 0, tzinfo=timezone.utc))

    def test_missing_title_is_empty(self):
        [entry] = parse(rss("<item><guid>x</guid></item>"))
        self.assertEqual(entry.title, "")

    def test_empty_channel_has_no_entries(self):
        self.assertEqual(parse(rss()), [])

    def test_malformed_xml_is_parse_error(self):
        with self.assertRaises(ParseError):
            parse(b"<rss><channel>")

    def test_empty_body_is_parse_error(self):
        with self.assertRaises(ParseError):
            parse(b"")

    def test_html_is_parse_error(self):
        with self.assertRaises(ParseError):
            parse(b"<html><body>Not found</body></html>")

    def test_atom_is_parse_error(self):
        with self.assertRaises(ParseError):
            parse(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 5: Write the implementation**

`feedwatch/parse.py`:

```python
"""Turn RSS XML into entries. Owns the feed format; never stores anything."""

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime


class ParseError(Exception):
    """The document is not well-formed XML, or not an RSS feed."""


@dataclass(frozen=True)
class Entry:
    """One item of a feed.

    ``guid`` is the item's guid, or its link when it has none; with the feed
    it belongs to, it identifies the entry. ``published`` is in UTC.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None


def parse(xml: bytes) -> list[Entry]:
    """Return the entries of an RSS 0.9x/2.0 document, in document order.

    Items with neither a guid nor a link are left out. Raises ParseError when
    ``xml`` is not an RSS feed.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ParseError(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise ParseError(f"not an RSS feed (root element <{root.tag}>)")
    entries = []
    for element in channel.findall("item"):
        link = _text(element, "link")
        guid = _text(element, "guid") or link
        if guid is None:
            continue
        entries.append(Entry(
            guid=guid,
            title=_text(element, "title") or "",
            link=link,
            published=_date(_text(element, "pubDate")),
        ))
    return entries


def _text(element: ET.Element, tag: str) -> str | None:
    child = element.find(tag)
    if child is None or child.text is None:
        return None
    return child.text.strip() or None


def _date(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        parsed = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        # RFC 2822 reads "-0000" as UTC with no offset known, and returns it naive.
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 13 tests, OK.

- [ ] **Step 7: Commit**

```bash
git add pyproject.toml .gitignore feedwatch/__init__.py feedwatch/parse.py tests/__init__.py tests/samples.py tests/test_parse.py
git commit -m "feat: parse RSS feeds into entries"
```

---

### Task 2: `fetch`

**Files:**
- Create: `feedwatch/fetch.py`
- Create: `tests/http_fixture.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.fetch.FetchError(Exception)`.
  - `feedwatch.fetch.fetch(url: str, timeout: float = 30.0) -> bytes`.
  - `tests.http_fixture.serve(routes: dict[str, tuple[int, bytes, float]])` — context manager yielding `(base_url: str, requests: list)`; each route is `path -> (status, body, delay_seconds)`; `requests` collects each request's headers (an `email.message.Message`, case-insensitive).

- [ ] **Step 1: Write the test HTTP server**

`tests/http_fixture.py`:

```python
"""A throwaway HTTP server on localhost for tests that need a real socket."""

import threading
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


@contextmanager
def serve(routes):
    """Serve ``routes`` and yield ``(base_url, requests)``.

    ``routes`` maps a path to ``(status, body, delay_seconds)``; other paths
    get 404. ``requests`` receives the headers of every request served.
    """
    requests = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.headers)
            status, body, delay = routes.get(self.path, (404, b"not found", 0.0))
            time.sleep(delay)
            try:
                self.send_response(status)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                # A delayed route exists to make the client give up first.
                pass

        def log_message(self, format, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}", requests
    finally:
        server.shutdown()
        server.server_close()
```

- [ ] **Step 2: Write the failing tests**

`tests/test_fetch.py`:

```python
import socket
import unittest

from feedwatch.fetch import FetchError, fetch
from tests.http_fixture import serve


def unused_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class FetchTest(unittest.TestCase):
    def test_returns_body(self):
        with serve({"/feed.xml": (200, b"<rss/>", 0.0)}) as (base, _):
            self.assertEqual(fetch(base + "/feed.xml"), b"<rss/>")

    def test_sends_a_user_agent(self):
        with serve({"/feed.xml": (200, b"<rss/>", 0.0)}) as (base, requests):
            fetch(base + "/feed.xml")
        self.assertEqual(requests[0]["User-Agent"], "feedwatch/1.0")

    def test_not_found_is_fetch_error(self):
        with serve({}) as (base, _):
            with self.assertRaises(FetchError):
                fetch(base + "/missing.xml")

    def test_server_error_is_fetch_error(self):
        with serve({"/feed.xml": (500, b"oops", 0.0)}) as (base, _):
            with self.assertRaises(FetchError):
                fetch(base + "/feed.xml")

    def test_slow_server_times_out(self):
        with serve({"/slow.xml": (200, b"<rss/>", 1.0)}) as (base, _):
            with self.assertRaises(FetchError):
                fetch(base + "/slow.xml", timeout=0.2)

    def test_refused_connection_is_fetch_error(self):
        with self.assertRaises(FetchError):
            fetch(f"http://127.0.0.1:{unused_port()}/feed.xml")

    def test_unusable_url_is_fetch_error(self):
        with self.assertRaises(FetchError):
            fetch("not a url")

    def test_error_names_the_url(self):
        with self.assertRaises(FetchError) as caught:
            fetch("not a url")
        self.assertIn("not a url", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 4: Write the implementation**

`feedwatch/fetch.py`:

```python
"""Download a feed's XML. Owns HTTP; never parses."""

import http.client
import urllib.request

USER_AGENT = "feedwatch/1.0"


class FetchError(Exception):
    """The feed could not be downloaded."""


def fetch(url: str, timeout: float = 30.0) -> bytes:
    """Return the body served at ``url``.

    ``timeout`` bounds each network operation, in seconds. Raises FetchError
    for an unusable URL, a network failure, a timeout or a non-2xx response.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except (ValueError, OSError, http.client.HTTPException) as exc:
        # URLError, HTTPError and timeouts are all OSError; ValueError is a malformed URL.
        raise FetchError(f"{url}: {exc}") from exc
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 8 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/fetch.py tests/http_fixture.py tests/test_fetch.py
git commit -m "feat: fetch feeds over HTTP with a timeout"
```

---

### Task 3: `store` — the database and feeds

**Files:**
- Create: `feedwatch/store.py`
- Test: `tests/test_store_feeds.py`

**Interfaces:**
- Consumes: `feedwatch.parse.Entry` (imported for Task 4's signatures; not used yet).
- Produces:
  - `feedwatch.store.DEFAULT_PATH: Path` — `~/.feedwatch/feeds.db`.
  - `feedwatch.store.Feed` — frozen dataclass `Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)` with `is_due(now: datetime) -> bool`.
  - `feedwatch.store.DuplicateFeed(Exception)` with attribute `url: str`; `str(exc)` is `"already subscribed to <url>"`.
  - `feedwatch.store.Store`:
    - `Store.open(path: Path = DEFAULT_PATH) -> Store` (classmethod); usable as a context manager; `close() -> None`.
    - `add_feed(url: str, title: str | None, every_minutes: int) -> Feed` — raises `DuplicateFeed`.
    - `feeds() -> list[Feed]` — in the order added.
    - `mark_polled(feed_id: int, at: datetime) -> None`.
  - All datetimes passed to and returned by `Store` are timezone-aware; they are stored as UTC.

- [ ] **Step 1: Write the failing tests**

`tests/test_store_feeds.py`:

```python
import sqlite3
import tempfile
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.store import DuplicateFeed, Feed, Store

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class StoreFeedsTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / "nested" / "feeds.db"
        self.store = Store.open(self.path)
        self.addCleanup(self.store.close)

    def test_open_creates_missing_directory(self):
        self.assertTrue(self.path.exists())

    def test_add_feed(self):
        feed = self.store.add_feed("https://example.com/rss", "Example", 15)
        self.assertEqual(self.store.feeds(), [feed])
        self.assertEqual(feed.url, "https://example.com/rss")
        self.assertEqual(feed.title, "Example")
        self.assertEqual(feed.every_minutes, 15)
        self.assertIsNone(feed.last_polled_at)

    def test_title_is_optional(self):
        self.assertIsNone(self.store.add_feed("https://example.com/rss", None, 30).title)

    def test_duplicate_url_is_refused_naming_it(self):
        self.store.add_feed("https://example.com/rss", None, 30)
        with self.assertRaises(DuplicateFeed) as caught:
            self.store.add_feed("https://example.com/rss", "Again", 5)
        self.assertEqual(caught.exception.url, "https://example.com/rss")
        self.assertIn("https://example.com/rss", str(caught.exception))
        self.assertEqual(len(self.store.feeds()), 1)

    def test_mark_polled(self):
        feed = self.store.add_feed("https://example.com/rss", None, 30)
        self.store.mark_polled(feed.id, NOON)
        self.assertEqual(self.store.feeds()[0].last_polled_at, NOON)

    def test_data_survives_reopening(self):
        self.store.add_feed("https://example.com/rss", None, 30)
        self.store.close()
        with Store.open(self.path) as reopened:
            self.assertEqual([f.url for f in reopened.feeds()], ["https://example.com/rss"])
            version = reopened._conn.execute("PRAGMA user_version").fetchone()[0]
        self.assertEqual(version, 1)

    def test_waits_for_another_writer(self):
        ready = threading.Event()

        def hold_write_lock():
            conn = sqlite3.connect(self.path, isolation_level=None)
            conn.execute("BEGIN IMMEDIATE")
            ready.set()
            time.sleep(0.3)
            conn.execute("COMMIT")
            conn.close()

        holder = threading.Thread(target=hold_write_lock)
        holder.start()
        ready.wait()
        self.store.add_feed("https://example.com/rss", None, 30)
        holder.join()
        self.assertEqual(len(self.store.feeds()), 1)


class FeedIsDueTest(unittest.TestCase):
    def feed(self, last_polled_at):
        return Feed(id=1, url="u", title=None, every_minutes=30, last_polled_at=last_polled_at)

    def test_never_polled_is_due(self):
        self.assertTrue(self.feed(None).is_due(NOON))

    def test_not_due_before_interval(self):
        self.assertFalse(self.feed(NOON - timedelta(minutes=29)).is_due(NOON))

    def test_due_when_interval_is_up(self):
        self.assertTrue(self.feed(NOON - timedelta(minutes=30)).is_due(NOON))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store_feeds -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.store'`.

- [ ] **Step 3: Write the implementation**

`feedwatch/store.py`:

```python
"""The SQLite database of feeds and entries. Owns the schema; never touches the network."""

import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch.parse import Entry

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Migration N takes the schema from version N to N+1; PRAGMA user_version
# records how many have run. Append new migrations and never edit one that
# has shipped: existing databases have already applied it.
_MIGRATIONS = [
    [
        """
        CREATE TABLE feeds (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            title TEXT,
            every_minutes INTEGER NOT NULL,
            last_polled_at TEXT
        )
        """,
        """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            feed_id INTEGER NOT NULL REFERENCES feeds (id),
            guid TEXT NOT NULL,
            title TEXT NOT NULL,
            link TEXT,
            published TEXT,
            seen_at TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0,
            UNIQUE (feed_id, guid)
        )
        """,
    ],
]


class DuplicateFeed(Exception):
    """A feed with this URL is already subscribed to."""

    def __init__(self, url: str):
        super().__init__(f"already subscribed to {url}")
        self.url = url


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None

    def is_due(self, now: datetime) -> bool:
        """True when the feed has never been polled or its interval is up at ``now``."""
        if self.last_polled_at is None:
            return True
        return now >= self.last_polled_at + timedelta(minutes=self.every_minutes)


class Store:
    def __init__(self, conn: sqlite3.Connection):
        self._conn = conn

    @classmethod
    def open(cls, path: Path = DEFAULT_PATH) -> "Store":
        """Open the database at ``path``, creating it and bringing its schema up to date."""
        path.parent.mkdir(parents=True, exist_ok=True)
        # The poller and the CLI write to the same file from separate processes:
        # wait out the other's transaction rather than fail with "database is locked".
        conn = sqlite3.connect(path, timeout=10.0, isolation_level=None)
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA foreign_keys = ON")
        store = cls(conn)
        store._migrate()
        return store

    def close(self) -> None:
        self._conn.close()

    def __enter__(self) -> "Store":
        return self

    def __exit__(self, *exc_info) -> None:
        self.close()

    @contextmanager
    def _transaction(self):
        # IMMEDIATE takes the write lock up front, so two processes opening a new
        # database cannot both read user_version 0 and both create the tables.
        self._conn.execute("BEGIN IMMEDIATE")
        try:
            yield
        except BaseException:
            self._conn.execute("ROLLBACK")
            raise
        self._conn.execute("COMMIT")

    def _migrate(self) -> None:
        with self._transaction():
            version = self._conn.execute("PRAGMA user_version").fetchone()[0]
            if version >= len(_MIGRATIONS):
                return
            for statements in _MIGRATIONS[version:]:
                for statement in statements:
                    self._conn.execute(statement)
            self._conn.execute(f"PRAGMA user_version = {len(_MIGRATIONS)}")

    def add_feed(self, url: str, title: str | None, every_minutes: int) -> Feed:
        """Subscribe to ``url``. Raises DuplicateFeed if it is already subscribed to."""
        try:
            with self._transaction():
                cursor = self._conn.execute(
                    "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                    (url, title, every_minutes),
                )
        except sqlite3.IntegrityError as exc:
            raise DuplicateFeed(url) from exc
        return Feed(cursor.lastrowid, url, title, every_minutes, None)

    def feeds(self) -> list[Feed]:
        rows = self._conn.execute(
            "SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id"
        ).fetchall()
        return [
            Feed(feed_id, url, title, every, _from_text(last))
            for feed_id, url, title, every, last in rows
        ]

    def mark_polled(self, feed_id: int, at: datetime) -> None:
        with self._transaction():
            self._conn.execute(
                "UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(at), feed_id)
            )


def _to_text(moment: datetime) -> str:
    # One fixed format and offset, so ORDER BY on the text is chronological.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _from_text(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store_feeds -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store_feeds.py
git commit -m "feat: store feeds in SQLite with versioned schema"
```

---

### Task 4: `store` — entries, unread and read

**Files:**
- Modify: `feedwatch/store.py` (add `StoredEntry`, `UnknownGuid` and three `Store` methods)
- Test: `tests/test_store_entries.py`

**Interfaces:**
- Consumes: `Store`, `Store.add_feed`, `_transaction`, `_to_text`, `_from_text` from Task 3; `feedwatch.parse.Entry` from Task 1.
- Produces:
  - `feedwatch.store.StoredEntry` — frozen dataclass `StoredEntry(guid: str, title: str, link: str | None, published: datetime | None, seen_at: datetime, feed_title: str)`; `feed_title` is the feed's title, or its URL when it has none.
  - `feedwatch.store.UnknownGuid(Exception)` with attribute `guid: str`; `str(exc)` is `"no entry with guid <guid>"`.
  - `Store.add_entries(feed_id: int, entries: Iterable[Entry], seen_at: datetime) -> int` — number newly stored.
  - `Store.unread(limit: int) -> list[StoredEntry]` — newest first.
  - `Store.mark_read(guids: Sequence[str]) -> None` — all or nothing; raises `UnknownGuid`.

- [ ] **Step 1: Write the failing tests**

`tests/test_store_entries.py`:

```python
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.parse import Entry
from feedwatch.store import Store, UnknownGuid


def at(hour):
    return datetime(2026, 3, 1, hour, 0, tzinfo=timezone.utc)


def entry(guid, published=None, title="t"):
    return Entry(guid=guid, title=title, link=f"https://example.com/{guid}", published=published)


class StoreEntriesTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.store = Store.open(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.store.close)
        self.feed = self.store.add_feed("https://example.com/rss", "Example", 30)

    def test_add_entries_counts_new_ones(self):
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("a"), entry("b")], at(9)), 2)

    def test_entry_is_stored_once(self):
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("a"), entry("b")], at(10)), 1)
        self.assertEqual(sorted(e.guid for e in self.store.unread(20)), ["a", "b"])

    def test_repeated_guid_within_one_fetch_is_stored_once(self):
        self.assertEqual(self.store.add_entries(self.feed.id, [entry("a"), entry("a")], at(9)), 1)

    def test_same_guid_in_two_feeds_is_two_entries(self):
        other = self.store.add_feed("https://example.org/rss", None, 30)
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        self.assertEqual(self.store.add_entries(other.id, [entry("a")], at(9)), 1)

    def test_unread_fields(self):
        self.store.add_entries(self.feed.id, [entry("a", published=at(8), title="Hello")], at(9))
        [stored] = self.store.unread(20)
        self.assertEqual(stored.guid, "a")
        self.assertEqual(stored.title, "Hello")
        self.assertEqual(stored.link, "https://example.com/a")
        self.assertEqual(stored.published, at(8))
        self.assertEqual(stored.seen_at, at(9))
        self.assertEqual(stored.feed_title, "Example")

    def test_feed_without_title_shows_its_url(self):
        other = self.store.add_feed("https://example.org/rss", None, 30)
        self.store.add_entries(other.id, [entry("a")], at(9))
        self.assertEqual(self.store.unread(20)[0].feed_title, "https://example.org/rss")

    def test_unread_is_newest_first(self):
        self.store.add_entries(self.feed.id, [entry("old", at(1)), entry("new", at(5)), entry("mid", at(3))], at(9))
        self.assertEqual([e.guid for e in self.store.unread(20)], ["new", "mid", "old"])

    def test_undated_entry_sorts_by_when_it_was_seen(self):
        self.store.add_entries(self.feed.id, [entry("dated-10", at(10)), entry("dated-12", at(12))], at(11))
        self.store.add_entries(self.feed.id, [entry("undated")], at(11))
        self.assertEqual([e.guid for e in self.store.unread(20)], ["dated-12", "undated", "dated-10"])

    def test_unread_respects_limit(self):
        self.store.add_entries(self.feed.id, [entry(f"e{i}", at(i)) for i in range(5)], at(9))
        self.assertEqual([e.guid for e in self.store.unread(2)], ["e4", "e3"])

    def test_mark_read_hides_entry(self):
        self.store.add_entries(self.feed.id, [entry("a"), entry("b")], at(9))
        self.store.mark_read(["a"])
        self.assertEqual([e.guid for e in self.store.unread(20)], ["b"])

    def test_mark_read_covers_every_feed_with_that_guid(self):
        other = self.store.add_feed("https://example.org/rss", None, 30)
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        self.store.add_entries(other.id, [entry("a")], at(9))
        self.store.mark_read(["a"])
        self.assertEqual(self.store.unread(20), [])

    def test_unknown_guid_is_refused_naming_it(self):
        with self.assertRaises(UnknownGuid) as caught:
            self.store.mark_read(["nope"])
        self.assertEqual(caught.exception.guid, "nope")
        self.assertIn("nope", str(caught.exception))

    def test_unknown_guid_marks_nothing(self):
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        with self.assertRaises(UnknownGuid):
            self.store.mark_read(["a", "nope"])
        self.assertEqual([e.guid for e in self.store.unread(20)], ["a"])

    def test_marking_read_twice_is_accepted(self):
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        self.store.mark_read(["a"])
        self.store.mark_read(["a"])
        self.assertEqual(self.store.unread(20), [])

    def test_read_entry_is_not_revived_by_a_later_poll(self):
        self.store.add_entries(self.feed.id, [entry("a")], at(9))
        self.store.mark_read(["a"])
        self.store.add_entries(self.feed.id, [entry("a")], at(10))
        self.assertEqual(self.store.unread(20), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store_entries -v`
Expected: ERROR — `ImportError: cannot import name 'UnknownGuid' from 'feedwatch.store'`.

- [ ] **Step 3: Write the implementation**

In `feedwatch/store.py`, add to the imports:

```python
from collections.abc import Iterable, Sequence
```

Add after `class DuplicateFeed`:

```python
class UnknownGuid(Exception):
    """No stored entry has this guid."""

    def __init__(self, guid: str):
        super().__init__(f"no entry with guid {guid}")
        self.guid = guid
```

Add after `class Feed`:

```python
@dataclass(frozen=True)
class StoredEntry:
    """An entry as the CLI shows it; ``feed_title`` falls back to the feed's URL."""

    guid: str
    title: str
    link: str | None
    published: datetime | None
    seen_at: datetime
    feed_title: str
```

Add to `class Store`, after `mark_polled`:

```python
    def add_entries(self, feed_id: int, entries: Iterable[Entry], seen_at: datetime) -> int:
        """Store the entries of ``feed_id`` not stored before; return how many were new."""
        added = 0
        with self._transaction():
            for entry in entries:
                cursor = self._conn.execute(
                    "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
                    " VALUES (?, ?, ?, ?, ?, ?)",
                    (
                        feed_id,
                        entry.guid,
                        entry.title,
                        entry.link,
                        None if entry.published is None else _to_text(entry.published),
                        _to_text(seen_at),
                    ),
                )
                added += cursor.rowcount
        return added

    def unread(self, limit: int) -> list[StoredEntry]:
        """Return up to ``limit`` unread entries, newest first.

        An entry without a publication date counts as published when it was first seen.
        """
        rows = self._conn.execute(
            """
            SELECT e.guid, e.title, e.link, e.published, e.seen_at, COALESCE(f.title, f.url)
            FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id
            WHERE e.read = 0
            ORDER BY COALESCE(e.published, e.seen_at) DESC, e.id DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()
        return [
            StoredEntry(guid, title, link, _from_text(published), _from_text(seen_at), feed_title)
            for guid, title, link, published, seen_at, feed_title in rows
        ]

    def mark_read(self, guids: Sequence[str]) -> None:
        """Mark read every entry, in any feed, whose guid is in ``guids``.

        All or nothing: raises UnknownGuid, naming the first guid not stored,
        and marks none.
        """
        with self._transaction():
            for guid in guids:
                cursor = self._conn.execute("UPDATE entries SET read = 1 WHERE guid = ?", (guid,))
                if cursor.rowcount == 0:
                    raise UnknownGuid(guid)
```

(`rowcount` counts matched rows for an `UPDATE`, so an already-read entry still counts as found; raising inside `_transaction` rolls back the guids marked before it.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store_entries tests.test_store_feeds -v`
Expected: 25 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store_entries.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 5: `poller`

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch`, `FetchError` (Task 2); `parse`, `ParseError` (Task 1); `Store.open`, `Store.feeds`, `Feed.is_due`, `Store.add_entries`, `Store.mark_polled`, `Store.unread`, `DEFAULT_PATH` (Tasks 3–4).
- Produces:
  - `feedwatch.poller.poll_once(store: Store, now: datetime, fetch_fn: Callable[[str], bytes] = fetch) -> None`.
  - `feedwatch.poller.run(store: Store, *, tick_seconds: float = TICK_SECONDS, clock: Callable[[], datetime] = ..., sleep: Callable[[float], None] = time.sleep, fetch_fn: Callable[[str], bytes] = fetch) -> None` — never returns normally.
  - `feedwatch.poller.main(db_path: Path = DEFAULT_PATH) -> int` — exit status; `python -m feedwatch.poller` calls it.
  - `feedwatch.poller.TICK_SECONDS = 30.0`.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import poller
from feedwatch.fetch import FetchError
from feedwatch.store import Store
from tests.samples import item, rss

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
GOOD = "https://good.example/rss"
BAD = "https://bad.example/rss"


class FakeFetch:
    """Serves canned bodies by URL; an Exception value is raised instead."""

    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def __call__(self, url):
        self.calls.append(url)
        response = self.responses[url]
        if isinstance(response, Exception):
            raise response
        return response


class PollOnceTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.store = Store.open(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.store.close)

    def guids(self):
        return sorted(e.guid for e in self.store.unread(100))

    def test_due_feed_entries_are_stored(self):
        self.store.add_feed(GOOD, None, 30)
        poller.poll_once(self.store, NOON, FakeFetch({GOOD: rss(item(guid="a"), item(guid="b"))}))
        self.assertEqual(self.guids(), ["a", "b"])

    def test_seen_entries_are_stored_once(self):
        self.store.add_feed(GOOD, None, 30)
        fake = FakeFetch({GOOD: rss(item(guid="a"))})
        poller.poll_once(self.store, NOON, fake)
        poller.poll_once(self.store, NOON + timedelta(minutes=30), fake)
        self.assertEqual(len(fake.calls), 2)
        self.assertEqual(self.guids(), ["a"])

    def test_feed_is_not_fetched_before_its_interval(self):
        self.store.add_feed(GOOD, None, 30)
        fake = FakeFetch({GOOD: rss()})
        poller.poll_once(self.store, NOON, fake)
        poller.poll_once(self.store, NOON + timedelta(minutes=29), fake)
        self.assertEqual(fake.calls, [GOOD])

    def test_each_feed_keeps_its_own_interval(self):
        self.store.add_feed(GOOD, None, 5)
        self.store.add_feed(BAD, None, 60)
        fake = FakeFetch({GOOD: rss(), BAD: rss()})
        poller.poll_once(self.store, NOON, fake)
        poller.poll_once(self.store, NOON + timedelta(minutes=5), fake)
        self.assertEqual(fake.calls, [GOOD, BAD, GOOD])

    def test_unfetchable_feed_is_logged_and_others_still_polled(self):
        self.store.add_feed(BAD, None, 30)
        self.store.add_feed(GOOD, None, 30)
        fake = FakeFetch({BAD: FetchError("connection refused"), GOOD: rss(item(guid="a"))})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.store, NOON, fake)
        self.assertIn(BAD, logs.output[0])
        self.assertEqual(self.guids(), ["a"])

    def test_non_rss_feed_is_logged_and_others_still_polled(self):
        self.store.add_feed(BAD, None, 30)
        self.store.add_feed(GOOD, None, 30)
        fake = FakeFetch({BAD: b"<html><body>Moved</body></html>", GOOD: rss(item(guid="a"))})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.store, NOON, fake)
        self.assertIn(BAD, logs.output[0])
        self.assertEqual(self.guids(), ["a"])

    def test_failed_feed_waits_for_its_next_interval(self):
        self.store.add_feed(BAD, None, 30)
        fake = FakeFetch({BAD: FetchError("timed out")})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poller.poll_once(self.store, NOON, fake)
        poller.poll_once(self.store, NOON + timedelta(minutes=10), fake)
        self.assertEqual(fake.calls, [BAD])

    def test_database_error_propagates(self):
        self.store.add_feed(GOOD, None, 30)
        self.store.close()
        with self.assertRaises(sqlite3.Error):
            poller.poll_once(self.store, NOON, FakeFetch({GOOD: rss()}))


class Stop(Exception):
    pass


class RunTest(unittest.TestCase):
    def test_polls_then_sleeps_a_tick(self):
        with tempfile.TemporaryDirectory() as tmp, Store.open(Path(tmp) / "feeds.db") as store:
            store.add_feed(GOOD, None, 30)
            fake = FakeFetch({GOOD: rss(item(guid="a"))})
            sleeps = []

            def sleep(seconds):
                sleeps.append(seconds)
                if len(sleeps) == 2:
                    raise Stop

            with self.assertRaises(Stop):
                poller.run(store, tick_seconds=7.0, clock=lambda: NOON, sleep=sleep, fetch_fn=fake)
            self.assertEqual(sleeps, [7.0, 7.0])
            self.assertEqual(fake.calls, [GOOD])
            self.assertEqual([e.guid for e in store.unread(20)], ["a"])


class MainTest(unittest.TestCase):
    def test_database_error_stops_the_poller_with_status_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            # A directory cannot be opened as a database file.
            with self.assertLogs("feedwatch.poller", "ERROR"):
                self.assertEqual(poller.main(db_path=Path(tmp)), 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR — `ImportError: cannot import name 'poller' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`feedwatch/poller.py`:

```python
"""The long-running worker. Owns the schedule; never presents anything.

Run with ``python -m feedwatch.poller``.
"""

import logging
import sqlite3
import sys
import time
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.fetch import FetchError, fetch
from feedwatch.parse import ParseError, parse
from feedwatch.store import DEFAULT_PATH, Store

log = logging.getLogger("feedwatch.poller")

# Feeds are checked this often, not slept on until the next one is due, so a
# feed added through the CLI is picked up without restarting the poller.
TICK_SECONDS = 30.0


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def poll_once(store: Store, now: datetime, fetch_fn: Callable[[str], bytes] = fetch) -> None:
    """Poll every feed due at ``now`` and store the entries not seen before.

    A feed that cannot be fetched or parsed is logged and, like any polled
    feed, waits for its next interval. Database errors propagate.
    """
    for feed in store.feeds():
        if not feed.is_due(now):
            continue
        try:
            entries = parse(fetch_fn(feed.url))
        except (FetchError, ParseError) as exc:
            log.warning("skipping %s until its next interval: %s", feed.url, exc)
        else:
            added = store.add_entries(feed.id, entries, now)
            log.info("%s: %d new entries", feed.url, added)
        store.mark_polled(feed.id, now)


def run(
    store: Store,
    *,
    tick_seconds: float = TICK_SECONDS,
    clock: Callable[[], datetime] = _utcnow,
    sleep: Callable[[float], None] = time.sleep,
    fetch_fn: Callable[[str], bytes] = fetch,
) -> None:
    """Poll due feeds every ``tick_seconds``, forever."""
    while True:
        poll_once(store, clock(), fetch_fn)
        sleep(tick_seconds)


def main(db_path: Path = DEFAULT_PATH) -> int:
    """Run the poller until interrupted; return 1 if a database error stops it."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        with Store.open(db_path) as store:
            run(store)
    except KeyboardInterrupt:
        return 0
    except sqlite3.Error:
        log.exception("database error; stopping")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller polls due feeds and skips failing ones"
```

---

### Task 6: `cli`

**Files:**
- Create: `feedwatch/cli.py`
- Create: `feedwatch/__main__.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `Store.open`, `Store.add_feed`, `Store.unread`, `Store.mark_read`, `DuplicateFeed`, `UnknownGuid`, `DEFAULT_PATH` (Tasks 3–4).
- Produces: `feedwatch.cli.main(argv: list[str] | None = None, db_path: Path = DEFAULT_PATH) -> int` — exit status: 0 on success, 1 on a refusal or database error, 2 (via `SystemExit` from argparse) on a usage error. The `feedwatch` console script and `python -m feedwatch` call it.

Output formats (tests rely on them):
- `add`: `Subscribed to <url>, polled every <n> minutes.`
- `unread`: per entry, a line `<YYYY-MM-DD HH:MM local>  <feed title>  <entry title or "(untitled)">` followed by a line of four spaces and the guid. With none: `No unread entries.`
- `read`: `Marked <n> read.` where `n` counts distinct guids given.
- Refusals: `feedwatch: <exception message>` on stderr.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import cli
from feedwatch.parse import Entry
from feedwatch.store import Store

URL = "https://example.com/rss"


def at(hour):
    return datetime(2026, 3, 1, hour, 0, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.db = Path(tmp.name) / "feeds.db"

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                code = cli.main(list(argv), db_path=self.db)
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue(), err.getvalue()

    def seed(self, *entries):
        with Store.open(self.db) as store:
            feed = store.add_feed(URL, "Example", 30)
            store.add_entries(feed.id, entries, at(9))

    def feeds(self):
        with Store.open(self.db) as store:
            return store.feeds()

    def unread_guids(self, out):
        return [line.strip() for line in out.splitlines() if line.startswith("    ")]

    # add

    def test_add_defaults_to_every_30_minutes(self):
        code, out, _ = self.run_cli("add", URL)
        self.assertEqual(code, 0)
        self.assertIn(URL, out)
        [feed] = self.feeds()
        self.assertEqual((feed.url, feed.title, feed.every_minutes), (URL, None, 30))

    def test_add_with_title_and_interval(self):
        self.run_cli("add", URL, "--title", "Example", "--every", "5")
        [feed] = self.feeds()
        self.assertEqual((feed.title, feed.every_minutes), ("Example", 5))

    def test_add_twice_is_refused_naming_the_url(self):
        self.run_cli("add", URL)
        code, _, err = self.run_cli("add", URL)
        self.assertEqual(code, 1)
        self.assertIn(URL, err)
        self.assertEqual(len(self.feeds()), 1)

    def test_every_must_be_positive(self):
        for value in ("0", "-5"):
            code, _, err = self.run_cli("add", URL, "--every", value)
            self.assertEqual(code, 2)
            self.assertIn("must be at least 1", err)
        self.assertFalse(self.db.exists())

    def test_every_must_be_a_number(self):
        code, _, err = self.run_cli("add", URL, "--every", "hourly")
        self.assertEqual(code, 2)
        self.assertIn("not a whole number", err)

    # unread

    def test_unread_is_newest_first(self):
        self.seed(Entry("old", "Old", None, at(1)), Entry("new", "New", None, at(5)))
        code, out, _ = self.run_cli("unread")
        self.assertEqual(code, 0)
        self.assertEqual(self.unread_guids(out), ["new", "old"])
        self.assertIn("Example", out)
        self.assertIn("New", out)

    def test_unread_shows_twenty_by_default(self):
        self.seed(*[Entry(f"e{i:02}", "t", None, at(0).replace(minute=i)) for i in range(25)])
        _, out, _ = self.run_cli("unread")
        self.assertEqual(len(self.unread_guids(out)), 20)

    def test_unread_limit(self):
        self.seed(*[Entry(f"e{i}", "t", None, at(i)) for i in range(5)])
        _, out, _ = self.run_cli("unread", "--limit", "2")
        self.assertEqual(self.unread_guids(out), ["e4", "e3"])

    def test_limit_must_be_positive(self):
        code, _, err = self.run_cli("unread", "--limit", "0")
        self.assertEqual(code, 2)
        self.assertIn("must be at least 1", err)

    def test_untitled_entry(self):
        self.seed(Entry("a", "", None, at(1)))
        _, out, _ = self.run_cli("unread")
        self.assertIn("(untitled)", out)

    def test_nothing_unread(self):
        code, out, _ = self.run_cli("unread")
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "No unread entries.")

    # read

    def test_read_marks_entries(self):
        self.seed(Entry("a", "t", None, at(1)), Entry("b", "t", None, at(2)), Entry("c", "t", None, at(3)))
        code, out, _ = self.run_cli("read", "a", "c")
        self.assertEqual(code, 0)
        self.assertIn("Marked 2 read.", out)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(self.unread_guids(out), ["b"])

    def test_read_unknown_guid_is_refused_naming_it(self):
        self.seed(Entry("a", "t", None, at(1)))
        code, _, err = self.run_cli("read", "nope")
        self.assertEqual(code, 1)
        self.assertIn("nope", err)

    def test_read_with_one_unknown_guid_marks_nothing(self):
        self.seed(Entry("a", "t", None, at(1)))
        code, _, _ = self.run_cli("read", "a", "nope")
        self.assertEqual(code, 1)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(self.unread_guids(out), ["a"])

    def test_read_needs_a_guid(self):
        code, _, _ = self.run_cli("read")
        self.assertEqual(code, 2)

    def test_no_command_is_a_usage_error(self):
        code, _, _ = self.run_cli()
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR — `ImportError: cannot import name 'cli' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`feedwatch/cli.py`:

```python
"""The user's commands. Owns presentation; never polls."""

import argparse
import sqlite3
import sys
from pathlib import Path

from feedwatch.store import DEFAULT_PATH, DuplicateFeed, Store, UnknownGuid


def _positive_int(text: str) -> int:
    try:
        value = int(text)
    except ValueError:
        raise argparse.ArgumentTypeError(f"not a whole number: {text}") from None
    if value < 1:
        raise argparse.ArgumentTypeError(f"must be at least 1: {text}")
    return value


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read your RSS feeds.")
    commands = parser.add_subparsers(dest="command", required=True)

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=_positive_int, default=30, metavar="MINUTES",
                     help="poll interval in minutes (default 30)")

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=_positive_int, default=20, metavar="N",
                        help="how many to list (default 20)")

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def main(argv: list[str] | None = None, db_path: Path = DEFAULT_PATH) -> int:
    """Run one command and return its exit status."""
    args = _parser().parse_args(argv)
    try:
        with Store.open(db_path) as store:
            if args.command == "add":
                feed = store.add_feed(args.url, args.title, args.every)
                print(f"Subscribed to {feed.url}, polled every {feed.every_minutes} minutes.")
            elif args.command == "unread":
                _print_unread(store, args.limit)
            else:
                store.mark_read(args.guids)
                print(f"Marked {len(set(args.guids))} read.")
    except (DuplicateFeed, UnknownGuid) as exc:
        print(f"feedwatch: {exc}", file=sys.stderr)
        return 1
    except sqlite3.Error as exc:
        print(f"feedwatch: database error: {exc}", file=sys.stderr)
        return 1
    return 0


def _print_unread(store: Store, limit: int) -> None:
    entries = store.unread(limit)
    if not entries:
        print("No unread entries.")
        return
    for entry in entries:
        stamp = (entry.published or entry.seen_at).astimezone().strftime("%Y-%m-%d %H:%M")
        print(f"{stamp}  {entry.feed_title}  {entry.title or '(untitled)'}")
        print(f"    {entry.guid}")
```

`feedwatch/__main__.py`:

```python
import sys

from feedwatch.cli import main

sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 16 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/cli.py feedwatch/__main__.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

### Task 7: End to end, boundaries and installation

**Files:**
- Test: `tests/test_end_to_end.py`

**Interfaces:**
- Consumes: `cli.main` (Task 6), `poller.poll_once` (Task 5), `Store.open` (Task 3), `tests.http_fixture.serve` (Task 2), `tests.samples` (Task 1).
- Produces: nothing new.

- [ ] **Step 1: Write the end-to-end test**

`tests/test_end_to_end.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import cli, poller
from feedwatch.store import Store
from tests.http_fixture import serve
from tests.samples import item, rss

FEED = rss(
    item(guid="id-1", title="First", pub_date="Sun, 01 Mar 2026 09:00:00 +0000"),
    item(link="https://example.com/2", title="Second", pub_date="Sun, 01 Mar 2026 10:00:00 +0000"),
)


class EndToEndTest(unittest.TestCase):
    def test_subscribe_poll_list_and_read(self):
        with tempfile.TemporaryDirectory() as tmp, serve({
            "/feed.xml": (200, FEED, 0.0),
            "/broken.xml": (500, b"", 0.0),
        }) as (base, _):
            db = Path(tmp) / "feeds.db"
            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(cli.main(["add", base + "/broken.xml"], db_path=db), 0)
                self.assertEqual(cli.main(["add", base + "/feed.xml", "--title", "Example"], db_path=db), 0)

            with Store.open(db) as store, self.assertLogs("feedwatch.poller", "WARNING"):
                poller.poll_once(store, datetime.now(timezone.utc))

            out = io.StringIO()
            with redirect_stdout(out):
                cli.main(["unread"], db_path=db)
            guids = [line.strip() for line in out.getvalue().splitlines() if line.startswith("    ")]
            self.assertEqual(guids, ["https://example.com/2", "id-1"])

            with redirect_stdout(io.StringIO()):
                self.assertEqual(cli.main(["read", "id-1", "https://example.com/2"], db_path=db), 0)
            out = io.StringIO()
            with redirect_stdout(out):
                cli.main(["unread"], db_path=db)
            self.assertEqual(out.getvalue().strip(), "No unread entries.")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it**

Run: `python -m unittest tests.test_end_to_end -v`
Expected: 1 test, OK. (Tasks 1–6 already implement everything it exercises; if it fails, the failure is an integration bug in one of them — fix it there, with a unit test in that task's test file.)

- [ ] **Step 3: Check the module boundaries**

Run: `grep -rnE "^(from|import) feedwatch" feedwatch/`
Expected: `fetch` is imported only by `feedwatch/poller.py`; `feedwatch/cli.py` imports only `feedwatch.store` (and `feedwatch/__main__.py` only `feedwatch.cli`); `feedwatch/store.py` imports only `feedwatch.parse`; `feedwatch/parse.py` and `feedwatch/fetch.py` import nothing from `feedwatch`. Fix any import that crosses `docs/ARCHITECTURE.md`'s lines.

- [ ] **Step 4: Run the whole suite**

Run: `python -m unittest discover -v`
Expected: 73 tests, OK (parse 13, fetch 8, store feeds 10, store entries 15, poller 10, cli 16, end to end 1).

- [ ] **Step 5: Install and smoke-test the commands**

```bash
python -m venv .venv
.venv/bin/pip install -e .
.venv/bin/feedwatch --help
.venv/bin/feedwatch unread --limit 0; echo "exit $?"
```

Expected: `--help` lists `add`, `unread`, `read`; the second command prints a usage error mentioning `must be at least 1` and `exit 2`. Do not run `feedwatch add` here without `--help`: it would write to your real `~/.feedwatch/feeds.db`.

Then confirm the poller entry point starts and stops cleanly against a scratch database:

```bash
timeout --preserve-status -s INT 2 .venv/bin/python -c "import sys; from pathlib import Path; from feedwatch import poller; sys.exit(poller.main(Path('/tmp/feedwatch-smoke/feeds.db')))"; echo "exit $?"
rm -rf /tmp/feedwatch-smoke
```

(`timeout` delivers the interrupt; a job backgrounded with `&` in a non-interactive shell ignores SIGINT, so `kill -INT` would not stop it.)

Expected: no traceback, `exit 0`.

- [ ] **Step 6: Commit**

```bash
git add tests/test_end_to_end.py
git commit -m "test: end-to-end subscribe, poll, list and read"
```

---

## After the last task

Before `superpowers:finishing-a-development-branch`, run `dopamine:finishing-work` so the ledger of this execution is sealed beside this plan and drained into the living documents listed in `.dopamine/config`.
````


## p008

#### Final message

The plan is written and committed as `86f781e` ("plan: feedwatch v1") on `master`. No feedwatch code was added to the repo.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

To check it, I copied the plan's code into a temporary directory outside the repo. All 46 tests passed. A smoke run of add, poller, unread and read against a local `file://` feed gave the output the plan expects. The program-design checks found no problems in that code.

**What the plan builds.** It has eight tasks:
1. The package, plus the domain types and errors.
2. The database connection, schema and subscriptions.
3. Stored entries: each kept once, listing unread ones, marking them read.
4. Reading RSS feeds.
5. Downloading feeds.
6. The poller.
7. The `feedwatch add | unread | read` commands.
8. An end-to-end check, then `dopamine:finishing-work`.

It uses only Python 3.11's standard library. Tests use `unittest`, and `setuptools` is used only to install the `feedwatch` command.

**Global Constraints.** These hold the spec's values (30-minute interval, limit of 20, refusal messages, `~/.feedwatch/feeds.db`). They also hold every rule from `docs/PROGRAM-DESIGN.md` with its check, copied word for word. Following those rules shaped some of the code:
- Other modules refer to the database connection by a name defined in `store`, so `sqlite3` is only imported there.
- The download function is passed into the poller, so tests can swap in a fake.
- Bad `--every` and `--limit` values are rejected through argparse, without raising an exception.

**Two judgement calls you may want to look at:**
- **Import rule and tests.** I read the rule "nothing imports `cli` or `poller`" as covering the package's own modules. `tests/test_cli.py` and `tests/test_poller.py` import the module they test, and the plan says so in its Global Constraints.
- **Single-threaded poller.** The poller fetches due feeds one after another with a 30-second timeout and wakes once a minute; it uses no thread pool. The program-design document allows this. I didn't think it was an open structural question, so I didn't stop to ask.

**Review Focus.** Five inputs the spec doesn't mention, each with its own test in the plan:
- An item with no guid is stored under its link; one with neither is skipped.
- A missing or malformed `pubDate` doesn't drop the entry.
- An entry you've read stays read when the feed shows it again.
- A page that is valid XML but not RSS (such as an Atom feed) is logged, skipped and counted as polled.
- `--every` or `--limit` values below 1 are refused.

**Security warning about the XML parser.** A security hook recommended `defusedxml`. I didn't add it, because the design document says a dependency has to earn its place. Instead the plan has a test that a malicious XML document built to blow up when its entities are expanded is refused, and a comment explaining why the standard parser is safe here. That safety depends on the expat library being version 2.4.1 or later.

I didn't run `dopamine:finishing-work`, because no plan has been carried out yet. The plan's final task runs it after the plan is implemented.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a long-running poller that stores new RSS entries in SQLite, and a `feedwatch` command to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five components from `docs/ARCHITECTURE.md`, each one module in the `feedwatch` package: `fetch` (HTTP only), `parse` (RSS XML to entries), `store` (the only module touching SQLite), `poller` (the schedule; calls fetch, parse, store) and `cli` (presentation; calls store). Domain values are frozen dataclasses in `models.py`, failures are `FeedwatchError` subclasses in `errors.py`. The poller polls due feeds one after another in a single thread, with a fetch timeout, waking once a minute; v1 needs no executor.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`, `unittest`). `setuptools` only as the build backend that installs the `feedwatch` console script.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/PROGRAM-DESIGN.md`).

## Global Constraints

From the spec and the living documents:

- Python 3.11, standard library first; no runtime dependency.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`; interval defaults to **30** minutes. Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]`; newest first; limit defaults to **20**.
- `feedwatch read GUID [GUID ...]`; a guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- One SQLite file, `~/.feedwatch/feeds.db`, tables `feeds` and `entries`; an existing database has to keep working as the schema grows.
- Out of scope: Atom feeds; importing or exporting subscription lists; more than one user; full-text search.

From `docs/PROGRAM-DESIGN.md`, each rule with its check. Every task's code is held to these; run every check over the task's added lines before committing it.

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated (`self` excepted, by convention).
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules. (Scope: the import graph of the `feedwatch` package. `tests/test_cli.py` and `tests/test_poller.py` import the module they test.)
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

Consequences for this plan, already applied in the code below: modules outside `store` annotate a connection as `store.Connection` (an alias of `sqlite3.Connection`) so they never import `sqlite3`; tests close connections through `contextlib.closing` rather than calling methods on them; `--every` and `--limit` are validated with `argparse`'s `parser.error`, which exits without a `raise`.

## Review Focus

1. **An RSS item with no `<guid>`** must be stored under its link; one with neither guid nor link cannot be identified and must be left out without failing the rest of the feed. Test: `test_parse.py::test_item_without_guid_uses_link`, `test_item_without_guid_or_link_is_left_out` (Task 4).
2. **A missing or malformed `<pubDate>`** must not drop the entry or fail the feed; the entry sorts by when it was first seen. Test: `test_parse.py::test_missing_or_malformed_pubdate_is_none` (Task 4) and `test_store.py::test_undated_entry_sorts_by_when_it_was_seen` (Task 3).
3. **An entry the user has read, seen again on the next poll,** must stay read. Test: `test_store.py::test_reseen_entry_keeps_its_read_state` (Task 3).
4. **A URL that returns well-formed XML that is not RSS** (an Atom feed, an XHTML page) must be logged and skipped like a fetch failure, and still count as polled so it is not retried every minute. Test: `test_parse.py::test_atom_feed_is_refused` (Task 4) and `test_poller.py::test_failing_feeds_are_logged_and_others_still_polled` (Task 6).
5. **`--every 0`, a negative `--every`, or `--limit 0`** must be refused with a message, not stored or silently ignored. Test: `test_cli.py::test_add_refuses_an_interval_below_one`, `test_unread_refuses_a_limit_below_one` (Task 7).

---

## File Structure

```
pyproject.toml              package metadata; the `feedwatch` console script
feedwatch/__init__.py       empty
feedwatch/models.py         Feed, Entry, UnreadEntry (frozen dataclasses)
feedwatch/errors.py         FeedwatchError and its subclasses
feedwatch/store.py          connect, SCHEMA_STEPS, feed and entry functions
feedwatch/parse.py          parse_feed: RSS bytes -> list[Entry]
feedwatch/fetch.py          fetch: URL -> bytes
feedwatch/poller.py         poll_once, main; `python -m feedwatch.poller`
feedwatch/cli.py            main; `feedwatch add | unread | read`
tests/__init__.py           empty; makes `python -m unittest` discover tests/
tests/test_errors.py
tests/test_models.py
tests/test_store.py
tests/test_parse.py
tests/test_fetch.py
tests/test_poller.py
tests/test_cli.py
```

Run the whole suite from the repository root with `python -m unittest -v`.

---

### Task 1: Package, domain types and errors

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/models.py`, `feedwatch/errors.py`
- Test: `tests/__init__.py`, `tests/test_models.py`, `tests/test_errors.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)`
  - `feedwatch.models.Entry(guid: str, title: str, link: str | None, published_at: datetime | None)`; `guid` is the item's guid, or its link when it has none; datetimes are timezone-aware UTC.
  - `feedwatch.models.UnreadEntry(feed_title: str | None, feed_url: str, entry: Entry)`
  - `feedwatch.errors.FeedwatchError(Exception)`, `AlreadySubscribed(url: str)`, `UnknownEntry(guids: Sequence[str])`, `FetchError(message: str)`, `FeedParseError(message: str)`

- [ ] **Step 1: Write the failing tests**

`tests/__init__.py`: empty file.

`tests/test_models.py`:

```python
import dataclasses
import unittest

from feedwatch.models import Entry, Feed


class ModelsTest(unittest.TestCase):
    def test_feed_is_frozen(self) -> None:
        feed = Feed(id=1, url="https://example.org/rss", title=None, every_minutes=30, last_polled_at=None)
        with self.assertRaises(dataclasses.FrozenInstanceError):
            feed.title = "changed"  # type: ignore[misc]

    def test_entry_is_frozen(self) -> None:
        entry = Entry(guid="g1", title="Hello", link=None, published_at=None)
        with self.assertRaises(dataclasses.FrozenInstanceError):
            entry.guid = "g2"  # type: ignore[misc]


if __name__ == "__main__":
    unittest.main()
```

`tests/test_errors.py`:

```python
import unittest

from feedwatch.errors import AlreadySubscribed, FeedParseError, FeedwatchError, FetchError, UnknownEntry


class ErrorsTest(unittest.TestCase):
    def test_already_subscribed_names_the_url(self) -> None:
        error = AlreadySubscribed("https://example.org/rss")
        self.assertIsInstance(error, FeedwatchError)
        self.assertIn("https://example.org/rss", str(error))

    def test_unknown_entry_names_every_guid(self) -> None:
        error = UnknownEntry(["guid-a", "guid-b"])
        self.assertIsInstance(error, FeedwatchError)
        self.assertIn("guid-a", str(error))
        self.assertIn("guid-b", str(error))

    def test_fetch_and_parse_errors_are_feedwatch_errors(self) -> None:
        self.assertIsInstance(FetchError("x"), FeedwatchError)
        self.assertIsInstance(FeedParseError("x"), FeedwatchError)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_models tests.test_errors -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch'`.

- [ ] **Step 3: Write the package**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into a local SQLite database and read them from the command line."
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py`: empty file.

`feedwatch/models.py`:

```python
"""Feedwatch's domain values."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    """A subscription. `last_polled_at` is None until the poller first tries it."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None


@dataclass(frozen=True)
class Entry:
    """One item of a feed.

    `guid` is the item's guid, or its link when it has none; with the feed it
    identifies the entry. `published_at` is None when the item gives no usable date.
    """

    guid: str
    title: str
    link: str | None
    published_at: datetime | None


@dataclass(frozen=True)
class UnreadEntry:
    """An unread entry with the feed it came from."""

    feed_title: str | None
    feed_url: str
    entry: Entry
```

`feedwatch/errors.py`:

```python
"""Every failure feedwatch raises is a FeedwatchError; only poller and cli catch them."""

from collections.abc import Sequence


class FeedwatchError(Exception):
    """Base class of every feedwatch failure."""


class AlreadySubscribed(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url


class UnknownEntry(FeedwatchError):
    def __init__(self, guids: Sequence[str]) -> None:
        super().__init__("no entry with guid " + ", ".join(guids))
        self.guids = tuple(guids)


class FetchError(FeedwatchError):
    """A feed could not be downloaded."""


class FeedParseError(FeedwatchError):
    """A downloaded document is not an RSS feed."""
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_models tests.test_errors -v`
Expected: 5 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add pyproject.toml feedwatch/__init__.py feedwatch/models.py feedwatch/errors.py tests/__init__.py tests/test_models.py tests/test_errors.py
git commit -m "feat: feedwatch package with domain types and errors"
```

---

### Task 2: Store — connection, schema and feeds

**Files:**
- Create: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: `Feed` from `feedwatch.models`; `AlreadySubscribed` from `feedwatch.errors`.
- Produces:
  - `store.Connection` — alias of `sqlite3.Connection`, for annotations outside `store`.
  - `store.DEFAULT_PATH: Path` — `~/.feedwatch/feeds.db`.
  - `store.SCHEMA_STEPS: tuple[str, ...]`
  - `store.connect(path: Path = DEFAULT_PATH) -> Connection`
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed` — raises `AlreadySubscribed`.
  - `store.list_feeds(conn: Connection) -> list[Feed]` — in order of subscription.
  - `store.mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None`

- [ ] **Step 1: Write the failing tests**

`tests/test_store.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribed

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
URL = "https://example.org/rss"


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.path = Path(directory) / "nested" / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))


class FeedsTest(StoreTestCase):
    def test_connect_creates_the_directory_and_reopens_an_existing_database(self) -> None:
        store.add_feed(self.conn, URL, title="Example", every_minutes=30)
        self.assertTrue(self.path.exists())
        with closing(store.connect(self.path)) as again:
            self.assertEqual([feed.url for feed in store.list_feeds(again)], [URL])

    def test_add_feed_returns_and_lists_the_feed(self) -> None:
        feed = store.add_feed(self.conn, URL, title=None, every_minutes=30)
        self.assertEqual(feed.url, URL)
        self.assertIsNone(feed.title)
        self.assertEqual(feed.every_minutes, 30)
        self.assertIsNone(feed.last_polled_at)
        self.assertEqual(store.list_feeds(self.conn), [feed])

    def test_subscribing_twice_is_refused_naming_the_url(self) -> None:
        store.add_feed(self.conn, URL, title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribed) as caught:
            store.add_feed(self.conn, URL, title="Other", every_minutes=5)
        self.assertIn(URL, str(caught.exception))
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_mark_polled_is_read_back(self) -> None:
        feed = store.add_feed(self.conn, URL, title=None, every_minutes=30)
        store.mark_polled(self.conn, feed.id, at=NOW)
        [polled] = store.list_feeds(self.conn)
        self.assertEqual(polled.last_polled_at, NOW)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: FAIL with `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 3: Write `feedwatch/store.py`**

```python
"""The SQLite database. The only module that touches it."""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribed
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Every step runs on every connect, so each must be idempotent.
# Append new steps; editing an existing one breaks databases already created.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled_at TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published_at TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
    "CREATE INDEX IF NOT EXISTS entries_by_guid ON entries (guid)",
)


def connect(path: Path = DEFAULT_PATH) -> Connection:
    """Open the database at `path`, creating it, its directory and its schema as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    # The poller writes while the CLI reads; WAL lets a reader proceed during a write.
    conn.execute("PRAGMA journal_mode = WAL")
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`. Raises AlreadySubscribed if it is subscribed to already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise AlreadySubscribed(url) from error
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled_at=None)


def list_feeds(conn: Connection) -> list[Feed]:
    """Every subscription, in the order it was added."""
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id")
    return [
        Feed(
            id=row["id"],
            url=row["url"],
            title=row["title"],
            every_minutes=row["every_minutes"],
            last_polled_at=_moment(row["last_polled_at"]),
        )
        for row in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    """Record that the poller tried this feed at `at`, whether or not it succeeded."""
    with conn:
        conn.execute("UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_text(at), feed_id))


def _text(moment: datetime) -> str:
    # One fixed format in UTC, so ORDER BY on the text orders by time.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _moment(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 4 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store opens the database and keeps subscriptions"
```

---

### Task 3: Store — entries

**Files:**
- Modify: `feedwatch/store.py` (imports; append functions after `mark_polled`)
- Test: `tests/test_store.py` (append `EntriesTest` above the `if __name__` block)

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store._text`, `store._moment` (Task 2); `Entry`, `UnreadEntry` from `feedwatch.models`; `UnknownEntry` from `feedwatch.errors`.
- Produces:
  - `store.add_entries(conn: Connection, feed_id: int, *, entries: Sequence[Entry], seen_at: datetime) -> int` — returns how many were new; an entry already stored is left as it is, read state included.
  - `store.unread(conn: Connection, *, limit: int) -> list[UnreadEntry]` — newest first by `published_at`, or by when first seen for an undated entry.
  - `store.mark_read(conn: Connection, guids: Sequence[str]) -> None` — raises `UnknownEntry` naming every unknown guid, and then marks none.

- [ ] **Step 1: Write the failing tests**

Add to the imports of `tests/test_store.py`:

```python
from datetime import timedelta

from feedwatch.errors import UnknownEntry
from feedwatch.models import Entry
```

Append above the `if __name__ == "__main__":` block:

```python
def entry(guid: str, published_at: datetime | None = None) -> Entry:
    return Entry(guid=guid, title=f"Title {guid}", link=f"https://example.org/{guid}", published_at=published_at)


class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, URL, title="Example", every_minutes=30)

    def unread_guids(self, limit: int = 100) -> list[str]:
        return [unread.entry.guid for unread in store.unread(self.conn, limit=limit)]

    def test_an_entry_is_stored_once_however_often_it_is_seen(self) -> None:
        first = store.add_entries(self.conn, self.feed.id, entries=[entry("a"), entry("b")], seen_at=NOW)
        second = store.add_entries(self.conn, self.feed.id, entries=[entry("a"), entry("b"), entry("c")], seen_at=NOW)
        self.assertEqual((first, second), (2, 1))
        self.assertCountEqual(self.unread_guids(), ["a", "b", "c"])

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        other = store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        store.add_entries(self.conn, self.feed.id, entries=[entry("same")], seen_at=NOW)
        store.add_entries(self.conn, other.id, entries=[entry("same")], seen_at=NOW)
        self.assertEqual(self.unread_guids(), ["same", "same"])

    def test_unread_is_newest_first_and_limited(self) -> None:
        entries = [entry("old", NOW - timedelta(days=2)), entry("new", NOW), entry("mid", NOW - timedelta(days=1))]
        store.add_entries(self.conn, self.feed.id, entries=entries, seen_at=NOW)
        self.assertEqual(self.unread_guids(), ["new", "mid", "old"])
        self.assertEqual(self.unread_guids(limit=2), ["new", "mid"])

    def test_unread_carries_the_feed_and_the_entry(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("a", NOW)], seen_at=NOW)
        [unread] = store.unread(self.conn, limit=20)
        self.assertEqual((unread.feed_title, unread.feed_url), ("Example", URL))
        self.assertEqual(unread.entry, entry("a", NOW))

    def test_undated_entry_sorts_by_when_it_was_seen(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("dated", NOW - timedelta(hours=1))], seen_at=NOW)
        store.add_entries(self.conn, self.feed.id, entries=[entry("undated")], seen_at=NOW + timedelta(hours=1))
        self.assertEqual(self.unread_guids(), ["undated", "dated"])

    def test_mark_read_removes_entries_from_unread(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("a"), entry("b")], seen_at=NOW)
        store.mark_read(self.conn, ["a"])
        self.assertEqual(self.unread_guids(), ["b"])

    def test_reseen_entry_keeps_its_read_state(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("a")], seen_at=NOW)
        store.mark_read(self.conn, ["a"])
        store.add_entries(self.conn, self.feed.id, entries=[entry("a")], seen_at=NOW + timedelta(hours=1))
        self.assertEqual(self.unread_guids(), [])

    def test_unknown_guid_is_refused_naming_it_and_nothing_is_marked(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("a")], seen_at=NOW)
        with self.assertRaises(UnknownEntry) as caught:
            store.mark_read(self.conn, ["a", "missing"])
        self.assertIn("missing", str(caught.exception))
        self.assertEqual(caught.exception.guids, ("missing",))
        self.assertEqual(self.unread_guids(), ["a"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the 8 new tests FAIL with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'`; the 4 from Task 2 still pass.

- [ ] **Step 3: Implement**

In `feedwatch/store.py`, replace the import block with:

```python
import sqlite3
from collections.abc import Sequence
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribed, UnknownEntry
from feedwatch.models import Entry, Feed, UnreadEntry
```

Append after `mark_polled` (above `_text`):

```python
def add_entries(conn: Connection, feed_id: int, *, entries: Sequence[Entry], seen_at: datetime) -> int:
    """Store the entries this feed has not had before; return how many that was.

    An entry already stored is left as it is, so a read entry stays read.
    """
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published_at, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    feed_id,
                    entry.guid,
                    entry.title,
                    entry.link,
                    None if entry.published_at is None else _text(entry.published_at),
                    _text(seen_at),
                )
                for entry in entries
            ],
        )
        return conn.total_changes - before


def unread(conn: Connection, *, limit: int) -> list[UnreadEntry]:
    """At most `limit` unread entries, newest first; an undated entry counts from when it was first seen."""
    rows = conn.execute(
        """SELECT feeds.title AS feed_title, feeds.url AS feed_url,
                  entries.guid, entries.title, entries.link, entries.published_at
           FROM entries JOIN feeds ON feeds.id = entries.feed_id
           WHERE entries.read = 0
           ORDER BY COALESCE(entries.published_at, entries.seen_at) DESC, entries.id DESC
           LIMIT ?""",
        (limit,),
    )
    return [
        UnreadEntry(
            feed_title=row["feed_title"],
            feed_url=row["feed_url"],
            entry=Entry(
                guid=row["guid"],
                title=row["title"],
                link=row["link"],
                published_at=_moment(row["published_at"]),
            ),
        )
        for row in rows
    ]


def mark_read(conn: Connection, guids: Sequence[str]) -> None:
    """Mark read every entry whose guid is in `guids`, in whichever feed.

    Raises UnknownEntry naming each guid that is not stored, and then marks none.
    """
    unknown = [
        guid
        for guid in dict.fromkeys(guids)
        if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None
    ]
    if unknown:
        raise UnknownEntry(unknown)
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 12 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store keeps entries once, lists unread and marks them read"
```

---

### Task 4: Parse RSS

**Files:**
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: `Entry` from `feedwatch.models`; `FeedParseError` from `feedwatch.errors`.
- Produces: `parse.parse_feed(xml: bytes) -> list[Entry]` — entries in document order; raises `FeedParseError` when `xml` is not XML or not an RSS document (`<rss>` root with a `<channel>`).

- [ ] **Step 1: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import FeedParseError
from feedwatch.models import Entry
from feedwatch.parse import parse_feed


def rss(items: str) -> bytes:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Example</title><link>https://example.org/</link>
{items}
</channel></rss>""".encode()


class ParseFeedTest(unittest.TestCase):
    def test_parses_items_in_document_order_with_dates_in_utc(self) -> None:
        entries = parse_feed(rss("""
            <item><guid>g-1</guid><title>First</title><link>https://example.org/1</link>
                  <pubDate>Sun, 01 Mar 2026 13:00:00 +0100</pubDate></item>
            <item><guid isPermaLink="false">g-2</guid><title>Second</title></item>
        """))
        self.assertEqual(
            entries,
            [
                Entry(
                    guid="g-1",
                    title="First",
                    link="https://example.org/1",
                    published_at=datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc),
                ),
                Entry(guid="g-2", title="Second", link=None, published_at=None),
            ],
        )

    def test_item_without_guid_uses_link(self) -> None:
        [entry] = parse_feed(rss("<item><title>T</title><link> https://example.org/x </link></item>"))
        self.assertEqual(entry.guid, "https://example.org/x")
        self.assertEqual(entry.link, "https://example.org/x")

    def test_item_without_guid_or_link_is_left_out(self) -> None:
        entries = parse_feed(rss("<item><title>Lost</title></item><item><guid>kept</guid></item>"))
        self.assertEqual([entry.guid for entry in entries], ["kept"])

    def test_missing_or_malformed_pubdate_is_none(self) -> None:
        entries = parse_feed(rss("""
            <item><guid>none</guid></item>
            <item><guid>blank</guid><pubDate>  </pubDate></item>
            <item><guid>garbage</guid><pubDate>yesterday-ish</pubDate></item>
        """))
        self.assertEqual([entry.published_at for entry in entries], [None, None, None])

    def test_title_whitespace_is_collapsed_and_missing_title_is_empty(self) -> None:
        entries = parse_feed(rss("<item><guid>a</guid><title>\n  Two\n  lines </title></item><item><guid>b</guid></item>"))
        self.assertEqual([entry.title for entry in entries], ["Two lines", ""])

    def test_feed_without_items_is_empty(self) -> None:
        self.assertEqual(parse_feed(rss("")), [])

    def test_not_xml_is_refused(self) -> None:
        with self.assertRaises(FeedParseError):
            parse_feed(b"<html><body>Not found</body>")

    def test_atom_feed_is_refused(self) -> None:
        atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><id>x</id></entry></feed>'
        with self.assertRaises(FeedParseError):
            parse_feed(atom)

    def test_rss_root_without_channel_is_refused(self) -> None:
        with self.assertRaises(FeedParseError):
            parse_feed(b'<rss version="2.0"></rss>')

    def test_entity_expansion_bomb_is_refused(self) -> None:
        entities = '<!ENTITY e0 "lol">' + "".join(
            f'<!ENTITY e{n} "{f"&e{n - 1};" * 10}">' for n in range(1, 10)
        )
        bomb = f"<!DOCTYPE rss [{entities}]><rss><channel><item><guid>&e9;</guid></item></channel></rss>"
        with self.assertRaises(FeedParseError):
            parse_feed(bomb.encode())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 3: Write `feedwatch/parse.py`**

```python
"""Turns RSS XML into entries."""

import xml.etree.ElementTree as ElementTree
from datetime import datetime, timezone
from email.utils import mktime_tz, parsedate_tz

from feedwatch.errors import FeedParseError
from feedwatch.models import Entry


def parse_feed(xml: bytes) -> list[Entry]:
    """The entries of an RSS document, in document order.

    An item with neither a guid nor a link cannot be identified and is left out.
    Raises FeedParseError if `xml` is not XML, or not an `<rss>` document with a `<channel>`.
    """
    # Feeds are untrusted input. ElementTree never fetches external entities, and
    # expat 2.4.1+ (bundled with Python 3.11) refuses entity-expansion bombs as a ParseError.
    try:
        root = ElementTree.fromstring(xml)
    except ElementTree.ParseError as error:
        raise FeedParseError(f"not XML: {error}") from error
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise FeedParseError(f"not an RSS feed: the document is <{root.tag}>")
    entries = []
    for item in channel.findall("item"):
        link = _child_text(item, "link")
        guid = _child_text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            Entry(
                guid=guid,
                title=" ".join((_child_text(item, "title") or "").split()),
                link=link,
                published_at=_published_at(_child_text(item, "pubDate")),
            )
        )
    return entries


def _child_text(item: ElementTree.Element, tag: str) -> str | None:
    """The stripped text of `item`'s child `tag`; None when the child is absent or blank."""
    text = (item.findtext(tag) or "").strip()
    return text or None


def _published_at(pub_date: str | None) -> datetime | None:
    # A date that does not parse counts as no date: the entry is still worth keeping,
    # and parsedate_tz reports it by returning None rather than raising.
    parts = None if pub_date is None else parsedate_tz(pub_date)
    if parts is None:
        return None
    return datetime.fromtimestamp(mktime_tz(parts), tz=timezone.utc)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS items into entries"
```

---

### Task 5: Fetch

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `FetchError` from `feedwatch.errors`.
- Produces: `fetch.fetch(url: str, *, timeout: float = 30.0) -> bytes` — raises `FetchError` for any failure to download, an HTTP error status included. Satisfies `Callable[[str], bytes]`, which is how `poller` takes it.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py`:

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch


class FetchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = Path(self.enterContext(tempfile.TemporaryDirectory()))

    def test_returns_the_body(self) -> None:
        path = self.directory / "feed.xml"
        path.write_bytes(b"<rss/>")
        self.assertEqual(fetch(path.as_uri()), b"<rss/>")

    def test_missing_resource_raises_fetch_error_naming_the_url(self) -> None:
        url = (self.directory / "absent.xml").as_uri()
        with self.assertRaises(FetchError) as caught:
            fetch(url)
        self.assertIn(url, str(caught.exception))

    def test_refused_connection_raises_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch("http://127.0.0.1:9/feed.xml", timeout=5)

    def test_malformed_url_raises_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch("not a url")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 3: Write `feedwatch/fetch.py`**

```python
"""Downloads feeds. The only module that touches the network."""

import http.client
import urllib.request

from feedwatch.errors import FetchError


def fetch(url: str, *, timeout: float = 30.0) -> bytes:
    """The body at `url`. Raises FetchError if it cannot be downloaded, an HTTP error status included."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    # OSError covers URLError, HTTPError and timeouts; ValueError a malformed URL;
    # HTTPException a server that breaks off mid-response.
    except (OSError, ValueError, http.client.HTTPException) as error:
        raise FetchError(f"{url}: {error}") from error
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 4 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch downloads a feed or raises FetchError"
```

---

### Task 6: Poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.Connection`, `store.DEFAULT_PATH`, `store.connect`, `store.list_feeds`, `store.add_entries`, `store.mark_polled`, `store.add_feed` (tests), `store.unread` (tests); `parse.parse_feed`; `fetch.fetch`; `Feed`; `FetchError`, `FeedParseError`.
- Produces:
  - `poller.poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> None` — polls every feed due at `now`; logs and skips a feed that fails to fetch or parse, and records it as polled either way.
  - `poller.main(db_path: Path = store.DEFAULT_PATH) -> None` — runs forever; `python -m feedwatch.poller` calls it.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchError
from feedwatch.poller import poll_once

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
GOOD = "https://good.example/rss"


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid><title>{guid}</title></item>" for guid in guids)
    return f'<rss version="2.0"><channel><title>T</title>{items}</channel></rss>'.encode()


class FakeFetch:
    """Serves fixed bodies by URL; any other URL fails as unreachable."""

    def __init__(self, bodies: dict[str, bytes]) -> None:
        self.bodies = bodies
        self.calls: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.calls.append(url)
        if url not in self.bodies:
            raise FetchError(f"{url}: unreachable")
        return self.bodies[url]


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.conn = self.enterContext(closing(store.connect(Path(directory) / "feeds.db")))

    def unread_guids(self) -> list[str]:
        return sorted(unread.entry.guid for unread in store.unread(self.conn, limit=100))

    def test_a_new_feed_is_polled_and_its_entries_stored(self) -> None:
        store.add_feed(self.conn, GOOD, title=None, every_minutes=30)
        poll_once(self.conn, NOW, fetch_feed=FakeFetch({GOOD: rss("a", "b")}))
        self.assertEqual(self.unread_guids(), ["a", "b"])

    def test_a_feed_is_polled_again_only_when_its_interval_is_up(self) -> None:
        store.add_feed(self.conn, GOOD, title=None, every_minutes=30)
        fake = FakeFetch({GOOD: rss("a")})
        poll_once(self.conn, NOW, fetch_feed=fake)
        poll_once(self.conn, NOW + timedelta(minutes=29), fetch_feed=fake)
        self.assertEqual(len(fake.calls), 1)
        poll_once(self.conn, NOW + timedelta(minutes=30), fetch_feed=fake)
        self.assertEqual(len(fake.calls), 2)

    def test_each_feed_keeps_its_own_interval(self) -> None:
        fast = "https://fast.example/rss"
        store.add_feed(self.conn, GOOD, title=None, every_minutes=30)
        store.add_feed(self.conn, fast, title=None, every_minutes=5)
        fake = FakeFetch({GOOD: rss("a"), fast: rss("b")})
        poll_once(self.conn, NOW, fetch_feed=fake)
        poll_once(self.conn, NOW + timedelta(minutes=5), fetch_feed=fake)
        self.assertEqual(fake.calls, [GOOD, fast, fast])

    def test_entries_seen_on_every_poll_are_stored_once(self) -> None:
        store.add_feed(self.conn, GOOD, title=None, every_minutes=30)
        poll_once(self.conn, NOW, fetch_feed=FakeFetch({GOOD: rss("a")}))
        poll_once(self.conn, NOW + timedelta(minutes=30), fetch_feed=FakeFetch({GOOD: rss("a", "b")}))
        self.assertEqual(self.unread_guids(), ["a", "b"])

    def test_failing_feeds_are_logged_and_others_still_polled(self) -> None:
        unreachable = "https://down.example/rss"
        not_rss = "https://atom.example/feed"
        store.add_feed(self.conn, unreachable, title=None, every_minutes=30)
        store.add_feed(self.conn, not_rss, title=None, every_minutes=30)
        store.add_feed(self.conn, GOOD, title=None, every_minutes=30)
        fake = FakeFetch({not_rss: b'<feed xmlns="http://www.w3.org/2005/Atom"/>', GOOD: rss("a")})
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            poll_once(self.conn, NOW, fetch_feed=fake)
        self.assertEqual(self.unread_guids(), ["a"])
        self.assertEqual(len(logs.records), 2)
        self.assertIn(unreachable, logs.output[0])
        self.assertIn(not_rss, logs.output[1])
        # A failed feed waits for its interval like any other.
        poll_once(self.conn, NOW + timedelta(minutes=1), fetch_feed=fake)
        self.assertEqual(len(fake.calls), 3)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Write `feedwatch/poller.py`**

```python
"""The long-running worker: polls each feed when its interval is up."""

import logging
import time
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import fetch, parse, store
from feedwatch.errors import FeedParseError, FetchError
from feedwatch.models import Feed

_log = logging.getLogger(__name__)

# Intervals are whole minutes, so waking once a minute is late by under a minute.
_TICK_SECONDS = 60


def poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> None:
    """Poll every feed whose interval is up at `now` and store the entries it has not had before.

    A feed that cannot be fetched or parsed is logged and skipped; it still counts
    as polled, so it is tried again after its interval.
    """
    for feed in store.list_feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            entries = parse.parse_feed(fetch_feed(feed.url))
        except (FetchError, FeedParseError) as error:
            _log.warning("skipping %s: %s", feed.url, error)
        else:
            new = store.add_entries(conn, feed.id, entries=entries, seen_at=now)
            _log.info("%s: %d new entries", feed.url, new)
        store.mark_polled(conn, feed.id, at=now)


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled_at is None or now - feed.last_polled_at >= timedelta(minutes=feed.every_minutes)


def main(db_path: Path = store.DEFAULT_PATH) -> None:
    """Poll until interrupted. A database error is not caught, and stops the poller."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    conn = store.connect(db_path)
    while True:
        poll_once(conn, datetime.now(timezone.utc), fetch_feed=fetch.fetch)
        time.sleep(_TICK_SECONDS)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 5 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller polls due feeds and skips the ones that fail"
```

---

### Task 7: Command line

**Files:**
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.DEFAULT_PATH`, `store.connect`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.add_entries` (tests), `store.list_feeds` (tests); `UnreadEntry`, `Entry`; `FeedwatchError`.
- Produces: `cli.main(argv: Sequence[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int` — the exit status: 0 on success, 1 when a `FeedwatchError` is reported on stderr as `feedwatch: <message>`; argparse exits with 2 on a usage error. The `feedwatch` console script calls it.

Output: `add` prints `subscribed to URL`; `unread` prints one line per entry, `GUID  YYYY-MM-DD HH:MM  FEED  TITLE` (date in local time, `-` when undated; `FEED` is the title given to `add`, else the URL; `(untitled)` for an empty title), or `no unread entries`; `read` prints `marked N read`.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.cli import main
from feedwatch.models import Entry

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)
URL = "https://example.org/rss"


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.db_path = Path(directory) / "feeds.db"

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = main(list(argv), db_path=self.db_path)
        return status, out.getvalue(), err.getvalue()

    def usage_error(self, *argv: str) -> str:
        """Run a command argparse must refuse; return what it printed on stderr."""
        err = io.StringIO()
        with redirect_stderr(err), self.assertRaises(SystemExit) as caught:
            main(list(argv), db_path=self.db_path)
        self.assertEqual(caught.exception.code, 2)
        return err.getvalue()

    def seed(self, *guids: str) -> None:
        """Subscribe to URL and store one entry per guid, the first given the newest."""
        with closing(store.connect(self.db_path)) as conn:
            feed = store.add_feed(conn, URL, title="Example", every_minutes=30)
            entries = [
                Entry(guid=guid, title=f"Title {guid}", link=None, published_at=NOW - timedelta(hours=age))
                for age, guid in enumerate(guids)
            ]
            store.add_entries(conn, feed.id, entries=entries, seen_at=NOW)

    def test_add_subscribes_with_the_default_interval(self) -> None:
        status, out, _ = self.run_cli("add", URL)
        self.assertEqual(status, 0)
        self.assertIn(URL, out)
        with closing(store.connect(self.db_path)) as conn:
            [feed] = store.list_feeds(conn)
        self.assertEqual((feed.url, feed.title, feed.every_minutes), (URL, None, 30))

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.run_cli("add", URL, "--title", "Example", "--every", "5")
        with closing(store.connect(self.db_path)) as conn:
            [feed] = store.list_feeds(conn)
        self.assertEqual((feed.title, feed.every_minutes), ("Example", 5))

    def test_adding_a_url_twice_is_refused_naming_it(self) -> None:
        self.run_cli("add", URL)
        status, _, err = self.run_cli("add", URL)
        self.assertEqual(status, 1)
        self.assertIn(URL, err)

    def test_add_refuses_an_interval_below_one(self) -> None:
        for every in ("0", "-5"):
            self.assertIn("--every", self.usage_error("add", URL, "--every", every))
        with closing(store.connect(self.db_path)) as conn:
            self.assertEqual(store.list_feeds(conn), [])

    def test_unread_lists_newest_first(self) -> None:
        self.seed("newest", "middle", "oldest")
        status, out, _ = self.run_cli("unread")
        self.assertEqual(status, 0)
        lines = out.splitlines()
        self.assertEqual([line.split()[0] for line in lines], ["newest", "middle", "oldest"])
        self.assertIn("Example", lines[0])
        self.assertIn("Title newest", lines[0])

    def test_unread_defaults_to_twenty_and_takes_a_limit(self) -> None:
        self.seed(*[f"g{n}" for n in range(25)])
        self.assertEqual(len(self.run_cli("unread")[1].splitlines()), 20)
        limited = [line.split()[0] for line in self.run_cli("unread", "--limit", "3")[1].splitlines()]
        self.assertEqual(limited, ["g0", "g1", "g2"])

    def test_unread_refuses_a_limit_below_one(self) -> None:
        self.assertIn("--limit", self.usage_error("unread", "--limit", "0"))

    def test_unread_says_so_when_there_is_nothing(self) -> None:
        status, out, _ = self.run_cli("unread")
        self.assertEqual((status, out.strip()), (0, "no unread entries"))

    def test_read_marks_entries_read(self) -> None:
        self.seed("a", "b", "c")
        status, _, _ = self.run_cli("read", "a", "c")
        self.assertEqual(status, 0)
        self.assertEqual([line.split()[0] for line in self.run_cli("unread")[1].splitlines()], ["b"])

    def test_read_refuses_an_unknown_guid_naming_it_and_marks_nothing(self) -> None:
        self.seed("a")
        status, _, err = self.run_cli("read", "a", "missing")
        self.assertEqual(status, 1)
        self.assertIn("missing", err)
        self.assertEqual([line.split()[0] for line in self.run_cli("unread")[1].splitlines()], ["a"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.cli'`.

- [ ] **Step 3: Write `feedwatch/cli.py`**

```python
"""The user's commands: add, unread and read."""

import argparse
import sys
from collections.abc import Sequence
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import UnreadEntry


def main(argv: Sequence[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
    """Run one command; return the process exit status."""
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")
    try:
        with closing(store.connect(db_path)) as conn:
            if args.command == "add":
                store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
                print(f"subscribed to {args.url}")
            elif args.command == "unread":
                unread = store.unread(conn, limit=args.limit)
                print("\n".join(_line(item) for item in unread) if unread else "no unread entries")
            else:
                store.mark_read(conn, args.guids)
                print(f"marked {len(set(args.guids))} read")
    except FeedwatchError as error:
        print(f"feedwatch: {error}", file=sys.stderr)
        return 1
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES", help="poll interval (default 30)")

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N", help="how many (default 20)")

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _line(item: UnreadEntry) -> str:
    entry = item.entry
    when = "-" if entry.published_at is None else entry.published_at.astimezone().strftime("%Y-%m-%d %H:%M")
    return f"{entry.guid}  {when}  {item.feed_title or item.feed_url}  {entry.title or '(untitled)'}"


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

### Task 8: End-to-end check and close

**Files:** none created; this task verifies the assembly and closes the work.

- [ ] **Step 1: Run the whole suite**

Run: `python -m unittest -v`
Expected: 46 tests, OK.

- [ ] **Step 2: Install and run the two processes against a local feed, with a throwaway home**

```bash
export HOME="$(mktemp -d)"
python -m venv "$HOME/venv" && "$HOME/venv/bin/pip" install -q -e .
printf '<rss version="2.0"><channel><title>Local</title><item><guid>local-1</guid><title>Hello</title></item></channel></rss>' > "$HOME/feed.xml"
"$HOME/venv/bin/feedwatch" add "file://$HOME/feed.xml" --title Local
"$HOME/venv/bin/feedwatch" add "file://$HOME/feed.xml"; echo "exit $?"
timeout 5 "$HOME/venv/bin/python" -m feedwatch.poller; echo "poller stopped"
"$HOME/venv/bin/feedwatch" unread
"$HOME/venv/bin/feedwatch" read local-1 && "$HOME/venv/bin/feedwatch" unread
"$HOME/venv/bin/feedwatch" read nope; echo "exit $?"
```

Expected, in order: `subscribed to file://…/feed.xml`; `feedwatch: already subscribed to file://…/feed.xml` and `exit 1`; a log line `file://…/feed.xml: 1 new entries`, then `poller stopped`; a line starting `local-1  -  Local  Hello`; `marked 1 read` then `no unread entries`; `feedwatch: no entry with guid nope` and `exit 1`. `ls "$HOME/.feedwatch/feeds.db"` shows the database at the documented path.

- [ ] **Step 3: Run every Global Constraints check over the whole branch**

Run `git diff <base>...HEAD -- feedwatch tests` and apply each check from Global Constraints to the added lines. Fix any deviation in a new commit before closing.

- [ ] **Step 4: Close the work**

Invoke `dopamine:finishing-work` (seal the ledger beside this plan, drain it into the living documents, commit `sweep: 2026-10-12-feedwatch-v1 — …`), then `superpowers:finishing-a-development-branch`.
````


## p009

#### Final message

I've written the plan and committed it as 78db088 ("plan: feedwatch v1"). It's at `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Nothing is implemented in the repository.

Before committing, I built every task's code in a scratch directory outside the repo. All 32 tests pass on Python 3.11, and the `feedwatch` command works end to end. I also checked that Task 2's step-by-step edits rebuild exactly the store module that was tested.

**What the plan builds, in six tasks:**
1. **Types and the feed table:** the domain types (`Feed`, `Entry`), the error classes under `FeedwatchError`, and the SQLite store's feed functions (`connect`, `add_feed`, `list_feeds`, `record_poll`) with the append-only `SCHEMA_STEPS`.
2. **Entries:** saving each entry once, listing unread entries newest first, and marking entries read.
3. **Parsing:** turning RSS into entries. An item with no guid is identified by its link, and one with neither is skipped. Anything that isn't RSS is rejected.
4. **Fetching:** downloading a feed, with any failure raised as `FetchError`.
5. **The poller:** it checks each feed when its interval is up and logs and skips a feed that fails. It still records the attempt, so a dead feed waits for its next interval instead of being retried every minute.
6. **The command line:** `add`, `unread` and `read`, plus `pyproject.toml` for the `feedwatch` command.

**Program-design rules:** each rule in `PROGRAM-DESIGN.md` is copied with its check into the plan's Global Constraints, and the plan's code passes all of them. A few choices follow from the rules:
- Other modules refer to the connection type as `store.Connection`, so nothing outside `store` imports `sqlite3`.
- Tests close connections with `contextlib.closing`.
- The command line rejects bad arguments through argparse's usage error (`parser.error`).
- The poller takes the fetch function as a parameter, so its tests need no mocks.

The document left no structural choice open, so I had nothing to ask you.

**Decisions the spec didn't settle:**
- **`feedwatch add`:** a URL without http/https is refused, and so is `--every` below 1.
- **`feedwatch unread`:** `--limit` below 1 is refused, because SQLite would read a negative limit as no limit.
- **`feedwatch read`:** with one unknown guid, nothing is marked read.
- **Polling:** feeds are polled one at a time, with a 10-second fetch timeout and a check once a minute.
- **Dates:** an entry without a date is sorted by when it was first seen, and a date with no time zone is read as UTC.

The plan's Review Focus section lists five inputs the spec doesn't mention that could still trip a user, and each has a test in the task that owns it.

**One extra commit:** the session instructions say to run the `finishing-work` sweep after any unit of work, so I did. It added a reconstructed ledger next to the plan and a commit, 7f0083f, "sweep: … — nothing to drain". There's no code yet, so no living document needed changing. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist; per the sweep rules I reported it and did not create it.

Please review the plan and tell me whether it captures what you want before anyone implements it.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md (added)

````
Reconstructed ledger, 2026-10-12, written from the planning conversation; no superpowers ledger existed for this unit of work.

# 2026-10-12-feedwatch-v1-planning

- Wrote `docs/superpowers/plans/2026-10-12-feedwatch-v1.md` from `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`; committed as "plan: feedwatch v1". No code was added to the repository.
- Copied every `docs/PROGRAM-DESIGN.md` rule, with its check, into the plan's Global Constraints, and ran the checks over the plan's code. No structural choice was left open by the document, so nothing was put to the human.
- Choices made inside the existing rules, recorded in the plan only: other modules annotate a connection as `store.Connection`; tests close connections with `contextlib.closing`; `cli` validates arguments with `parser.error`; the poller polls feeds in turn with no executor.
- `docs/ROADMAP.md` is declared in `.dopamine/config` and absent.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** The five components of `docs/ARCHITECTURE.md` become five modules of the `feedwatch` package (`fetch`, `parse`, `store`, `poller`, `cli`), plus `models` (frozen dataclasses) and `errors` (the `FeedwatchError` hierarchy). `store` is module functions over a `sqlite3` connection whose schema is the append-only `SCHEMA_STEPS`; `poller` and `cli` are the only modules that hold a connection or catch errors. The poller polls feeds one after another on one thread, waking once a minute; `fetch`'s timeout bounds how long one feed can hold it up.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`, `unittest`). Packaging: `pyproject.toml` with setuptools, used only to install the `feedwatch` command.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`).

## Global Constraints

From the spec and the design documents:

- Python 3.11 floor (`requires-python = ">=3.11"`); standard library only, so `dependencies = []`, and tests use `unittest`, not pytest.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`, interval default `30` minutes; a URL already subscribed is refused with a message naming the URL.
- `feedwatch unread [--limit N]`: unread entries, newest first, default `20`.
- `feedwatch read GUID [GUID ...]`: a guid that is not stored is refused with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up; an entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not RSS, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- One SQLite file, `~/.feedwatch/feeds.db`, tables `feeds` and `entries`; an existing database has to keep working as the schema grows.
- Out of scope: Atom feeds; importing or exporting subscription lists.

From `docs/PROGRAM-DESIGN.md`, each rule with its check. Run every check over each task's added lines before committing it. The checks govern the `feedwatch/` package; a test module imports the module it tests, `cli` and `poller` included, and the layout check does not apply to `tests/`. The signature, error and effect checks apply to test code as well.

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`; XML, database rows and argv are turned into them in the module that reads them.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed; no `None`, `False` or `(ok, reason)` return signals failure; only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects.** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. Only `store` touches the database and only `fetch` the network; `store` is module functions taking `conn` first, with no class wrapping the connection.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
  Consequences in this plan: other modules annotate a connection as `store.Connection`, not `sqlite3.Connection`; tests close connections with `contextlib.closing`, never `conn.close()`; `cli` checks a URL's scheme with `str.startswith`, not `urllib.parse`; the poller takes `fetch_feed` as a parameter so its tests need no mock.
- **Signatures.** Parameters after the second are keyword-only; every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated. (Test methods count `self`, so a test helper's second argument after `self` is keyword-only too.)
- **Layout.** Split by responsibility, not technical layer. Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not an `ARCHITECTURE.md` component has at most two public functions; no pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function. (This plan adds no logic module; `models` and `errors` hold only types.)
- **Concurrency.** The poller is one thread; work that must not block it runs in a `ThreadPoolExecutor` owned by `poller`, each task with its own `store.connect()`.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor. (v1 needs no executor: feeds are polled in turn, and `fetch`'s 10-second timeout bounds each.)
- **Persistence.** The schema only grows: a new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

A quick mechanical pass over the package for the effect, error and concurrency checks (an empty result for the first three lines is a pass; every `except` listed must be in `poller.py`, `cli.py`, or convert a library exception):

```bash
grep -n "sqlite3\|conn\." feedwatch/*.py tests/*.py | grep -v "^feedwatch/store.py"
grep -n "urllib" feedwatch/*.py tests/*.py | grep -v "^feedwatch/fetch.py"
grep -n "threading\|asyncio\|multiprocessing" feedwatch/*.py tests/*.py
grep -n "except" feedwatch/*.py
```

## Review Focus

- **`read` with one unknown guid among known ones** (`feedwatch read a typo`): the command is refused naming `typo`, and `a` stays unread rather than half the command taking effect. Pinned in Task 2 (`test_mark_read_with_an_unknown_guid_names_it_and_marks_nothing`) and Task 6.
- **A feed that keeps failing** (down host, HTML error page): it is retried at its next interval, not on every one-minute tick, so a dead feed does not flood the log. Pinned in Task 5 (`test_a_failing_feed_waits_for_its_next_interval`).
- **Items with no usable date** (missing or garbled `pubDate`, or a date without a zone): the entry is still stored, sorts by when it was first seen, and a zoneless date is read as UTC rather than local time. Pinned in Task 2 (`test_an_undated_entry_counts_from_when_it_was_seen`) and Task 3 (`test_items_become_entries`, `test_a_date_without_a_zone_is_utc`).
- **Items identified by link, or by nothing**: an item with no guid is stored under its link and stored only once across polls; an item with neither guid nor link is left out rather than crashing the poll. Pinned in Task 3 (`test_items_become_entries`) and Task 5 (`test_new_entries_are_stored_once`).
- **Nonsense numbers and URLs on the command line** (`--every 0`, `--limit 0`, `--limit -1`, `add example.com/rss`): refused with a usage error and exit status 2; SQLite would otherwise read `LIMIT -1` as no limit, and a schemeless URL would be stored and fail on every poll. Pinned in Task 6 (`test_bad_arguments_exit_with_usage_status`).

---

## File Structure

| File | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata and the `feedwatch` console script (Task 6). |
| `.gitignore` | Adds `.venv/` and `*.egg-info/` to the existing `__pycache__/` (Task 6). |
| `feedwatch/__init__.py` | Empty; makes `feedwatch` a package. |
| `feedwatch/models.py` | `Feed`, `Entry`: frozen dataclasses. Imports nothing from the package. |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses `DuplicateFeedError`, `UnknownEntryError`, `FetchError`, `ParseError`. |
| `feedwatch/store.py` | The **store** component: `connect`, `SCHEMA_STEPS`, feeds and entries. The only module that touches SQLite. |
| `feedwatch/parse.py` | The **parse** component: `parse_feed`, RSS bytes to `Entry` values. |
| `feedwatch/fetch.py` | The **fetch** component: `fetch`, URL to bytes. The only module that touches the network. |
| `feedwatch/poller.py` | The **poller** component: `is_due`, `poll_once`, and the `python -m feedwatch.poller` loop. |
| `feedwatch/cli.py` | The **cli** component: `run` (testable) and `main` (the console script). |
| `tests/__init__.py`, `tests/test_*.py` | One `unittest` module per component. |

Run every test from the repository root with `python -m unittest discover -s tests -t . -v`. Timestamps are timezone-aware UTC `datetime`s everywhere; `store` writes them as ISO 8601 text at second precision.

---

### Task 1: Domain types, errors, and the store's feeds

**Files:**
- Create: `feedwatch/__init__.py` (empty), `feedwatch/models.py`, `feedwatch/errors.py`, `feedwatch/store.py`
- Test: `tests/__init__.py` (empty), `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)`
  - `models.Entry(feed_id: int, guid: str, title: str | None, link: str | None, published: datetime | None)`
  - `errors.FeedwatchError`, `DuplicateFeedError`, `UnknownEntryError`, `FetchError`, `ParseError`
  - `store.Connection` (alias of `sqlite3.Connection`), `store.DEFAULT_PATH: Path`, `store.SCHEMA_STEPS: tuple[str, ...]`
  - `store.connect(path: Path) -> Connection`
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed` — raises `DuplicateFeedError("already subscribed: <url>")`
  - `store.list_feeds(conn: Connection) -> list[Feed]`
  - `store.record_poll(conn: Connection, feed_id: int, *, at: datetime) -> None`

- [ ] **Step 1: Create the empty package markers**

```bash
mkdir -p feedwatch tests
touch feedwatch/__init__.py tests/__init__.py
```

- [ ] **Step 2: Write the failing tests** in `tests/test_store.py`

```python
import tempfile
import unittest
from contextlib import closing
from datetime import UTC, datetime
from pathlib import Path

from feedwatch import store
from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "nested" / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))


class FeedsTest(StoreTestCase):
    def test_connect_creates_directory_and_empty_database(self) -> None:
        self.assertTrue(self.path.exists())
        self.assertEqual(store.list_feeds(self.conn), [])

    def test_add_feed_is_listed(self) -> None:
        feed = store.add_feed(self.conn, "https://example.com/rss", title="Example", every_minutes=30)
        self.assertEqual(
            store.list_feeds(self.conn),
            [Feed(id=feed.id, url="https://example.com/rss", title="Example", every_minutes=30, last_polled_at=None)],
        )

    def test_add_feed_twice_is_refused_naming_the_url(self) -> None:
        store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        with self.assertRaisesRegex(DuplicateFeedError, "https://example.com/rss"):
            store.add_feed(self.conn, "https://example.com/rss", title="Again", every_minutes=5)
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_record_poll_sets_last_polled_at(self) -> None:
        feed = store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, feed.id, at=NOW)
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled_at, NOW)

    def test_reconnecting_keeps_existing_data(self) -> None:
        store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        with closing(store.connect(self.path)) as again:
            self.assertEqual([feed.url for feed in store.list_feeds(again)], ["https://example.com/rss"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run them to verify they fail**

Run: `python -m unittest discover -s tests -t . -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.store'`.

- [ ] **Step 4: Write `feedwatch/models.py`**

```python
"""Feedwatch's domain values."""
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    """A subscribed feed. `last_polled_at` is None until the poller first reaches it."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None


@dataclass(frozen=True)
class Entry:
    """One item of a feed. `guid` is the item's guid, or its link when it has none."""

    feed_id: int
    guid: str
    title: str | None
    link: str | None
    published: datetime | None
```

- [ ] **Step 5: Write `feedwatch/errors.py`**

```python
"""The failures feedwatch raises; only `poller` and `cli` catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class DuplicateFeedError(FeedwatchError):
    """A feed with this URL is already subscribed."""


class UnknownEntryError(FeedwatchError):
    """No stored entry has this guid."""


class FetchError(FeedwatchError):
    """A feed's URL could not be downloaded."""


class ParseError(FeedwatchError):
    """A feed's XML is not an RSS feed."""
```

- [ ] **Step 6: Write `feedwatch/store.py`**

```python
"""The SQLite database. The only module that touches it."""
import sqlite3
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Every step runs on every connect, so each must be idempotent. Append new
# steps; never edit one, since existing databases have already run it.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled_at TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT,
        link TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
)


def connect(path: Path) -> Connection:
    """Open the database at `path`, creating it and its directory if absent, with every schema step applied."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, timeout=5.0)
    # The poller and the CLI open this file at once; WAL lets one read while the other writes.
    conn.execute("PRAGMA journal_mode=WAL")
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`. Raises DuplicateFeedError if it is already subscribed."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise DuplicateFeedError(f"already subscribed: {url}") from error
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled_at=None)


def list_feeds(conn: Connection) -> list[Feed]:
    """Return every subscribed feed, oldest subscription first."""
    rows = conn.execute(
        "SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id"
    ).fetchall()
    return [
        Feed(id=row[0], url=row[1], title=row[2], every_minutes=row[3], last_polled_at=_from_text(row[4]))
        for row in rows
    ]


def record_poll(conn: Connection, feed_id: int, *, at: datetime) -> None:
    """Record that feed `feed_id` was polled at `at`, whether or not the poll succeeded."""
    with conn:
        conn.execute("UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(at), feed_id))


def _to_text(moment: datetime) -> str:
    # One fixed format in UTC, so that ORDER BY on the text sorts by time.
    return moment.astimezone(UTC).isoformat(timespec="seconds")


def _from_text(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 5 tests, OK.

- [ ] **Step 8: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch tests
git commit -m "feat: domain types, errors and the store's feeds"
```

---

### Task 2: The store's entries

**Files:**
- Modify: `feedwatch/store.py` (imports; new functions between `record_poll` and `_to_text`)
- Test: `tests/test_store.py` (imports; new class `EntriesTest` before `if __name__ == "__main__":`)

**Interfaces:**
- Consumes: Task 1's `store.connect`, `store.add_feed`, `models.Entry`, `errors.UnknownEntryError`.
- Produces:
  - `store.add_entries(conn: Connection, entries: Sequence[Entry], *, seen_at: datetime) -> int` — inserts entries not already stored (same `feed_id` and `guid`), returns how many were new
  - `store.unread(conn: Connection, limit: int) -> list[Entry]` — newest first by `published`, or by `seen_at` when undated
  - `store.mark_read(conn: Connection, guids: Sequence[str]) -> None` — raises `UnknownEntryError("no such entry: <guid>")` and marks none if any guid is not stored; a guid stored under two feeds marks both

- [ ] **Step 1: Write the failing tests.** In `tests/test_store.py`, replace the three import lines

```python
from datetime import UTC, datetime
from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed
```

with

```python
from datetime import UTC, datetime, timedelta
from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Entry, Feed
```

and add this class before `if __name__ == "__main__":`

```python
class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)

    def entry(self, guid: str, *, published: datetime | None) -> Entry:
        return Entry(feed_id=self.feed.id, guid=guid, title=f"title {guid}", link=None, published=published)

    def test_an_entry_is_stored_once_however_often_it_is_seen(self) -> None:
        entries = [self.entry("a", published=NOW), self.entry("b", published=NOW)]
        self.assertEqual(store.add_entries(self.conn, entries, seen_at=NOW), 2)
        self.assertEqual(store.add_entries(self.conn, entries, seen_at=NOW + timedelta(hours=1)), 0)
        self.assertEqual(len(store.unread(self.conn, 20)), 2)

    def test_same_guid_in_another_feed_is_a_different_entry(self) -> None:
        other = store.add_feed(self.conn, "https://example.org/rss", title=None, every_minutes=30)
        store.add_entries(self.conn, [self.entry("a", published=NOW)], seen_at=NOW)
        stored = store.add_entries(
            self.conn, [Entry(feed_id=other.id, guid="a", title=None, link=None, published=NOW)], seen_at=NOW
        )
        self.assertEqual(stored, 1)

    def test_unread_is_newest_first_and_limited(self) -> None:
        store.add_entries(
            self.conn,
            [self.entry("old", published=NOW - timedelta(days=2)), self.entry("new", published=NOW), self.entry("mid", published=NOW - timedelta(days=1))],
            seen_at=NOW,
        )
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["new", "mid", "old"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 2)], ["new", "mid"])

    def test_an_undated_entry_counts_from_when_it_was_seen(self) -> None:
        store.add_entries(self.conn, [self.entry("dated", published=NOW - timedelta(days=1))], seen_at=NOW)
        store.add_entries(self.conn, [self.entry("undated", published=None)], seen_at=NOW - timedelta(days=3))
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["dated", "undated"])

    def test_published_survives_the_round_trip_in_utc(self) -> None:
        store.add_entries(self.conn, [self.entry("a", published=NOW)], seen_at=NOW)
        self.assertEqual(store.unread(self.conn, 20)[0].published, NOW)

    def test_mark_read_removes_entries_from_unread(self) -> None:
        store.add_entries(self.conn, [self.entry("a", published=NOW), self.entry("b", published=NOW)], seen_at=NOW)
        store.mark_read(self.conn, ["a"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["b"])

    def test_mark_read_with_an_unknown_guid_names_it_and_marks_nothing(self) -> None:
        store.add_entries(self.conn, [self.entry("a", published=NOW)], seen_at=NOW)
        with self.assertRaisesRegex(UnknownEntryError, "nope"):
            store.mark_read(self.conn, ["a", "nope"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["a"])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the 7 `EntriesTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'`; the 5 `FeedsTest` tests pass.

- [ ] **Step 3: Implement.** In `feedwatch/store.py`, replace the import block

```python
import sqlite3
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed
```

with

```python
import sqlite3
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Entry, Feed
```

and add these functions after `record_poll`, before `_to_text`:

```python
def add_entries(conn: Connection, entries: Sequence[Entry], *, seen_at: datetime) -> int:
    """Store the entries not stored before and return how many that was."""
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    entry.feed_id,
                    entry.guid,
                    entry.title,
                    entry.link,
                    None if entry.published is None else _to_text(entry.published),
                    _to_text(seen_at),
                )
                for entry in entries
            ],
        )
        return conn.total_changes - before


def unread(conn: Connection, limit: int) -> list[Entry]:
    """Return up to `limit` unread entries, newest first; an entry without a date counts from when it was seen."""
    rows = conn.execute(
        "SELECT feed_id, guid, title, link, published FROM entries WHERE read = 0"
        " ORDER BY COALESCE(published, seen_at) DESC, id DESC LIMIT ?",
        (limit,),
    ).fetchall()
    return [
        Entry(feed_id=row[0], guid=row[1], title=row[2], link=row[3], published=_from_text(row[4]))
        for row in rows
    ]


def mark_read(conn: Connection, guids: Sequence[str]) -> None:
    """Mark every entry with one of `guids` read.

    Raises UnknownEntryError, naming the guid, if one is not stored; then none is marked.
    """
    with conn:
        for guid in guids:
            if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None:
                raise UnknownEntryError(f"no such entry: {guid}")
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 12 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once, list unread, mark read"
```

---

### Task 3: Parse RSS into entries

**Files:**
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: `models.Entry`, `errors.ParseError` (Task 1).
- Produces: `parse.parse_feed(feed_id: int, xml: bytes) -> list[Entry]` — raises `ParseError` when `xml` is not well-formed or its root is not `<rss>` with a `<channel>`. Guid and link are whitespace-stripped; `guid` falls back to `link`; an item with neither is left out; `published` is UTC or `None` when `pubDate` is missing or unparseable.

- [ ] **Step 1: Write the failing tests** in `tests/test_parse.py`

```python
import unittest
from datetime import UTC, datetime

from feedwatch.errors import ParseError
from feedwatch.models import Entry
from feedwatch.parse import parse_feed

RSS = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Example</title>
  <item>
    <guid> a-1 </guid><title>First</title><link>https://example.com/1</link>
    <pubDate>Sun, 01 Mar 2026 10:00:00 +0100</pubDate>
  </item>
  <item><title>No guid</title><link>https://example.com/2</link><pubDate>yesterday</pubDate></item>
  <item><title>Nothing identifies this one</title></item>
</channel></rss>"""


class ParseFeedTest(unittest.TestCase):
    def test_items_become_entries(self) -> None:
        self.assertEqual(
            parse_feed(7, RSS),
            [
                Entry(
                    feed_id=7,
                    guid="a-1",
                    title="First",
                    link="https://example.com/1",
                    published=datetime(2026, 3, 1, 9, 0, tzinfo=UTC),
                ),
                Entry(feed_id=7, guid="https://example.com/2", title="No guid", link="https://example.com/2", published=None),
            ],
        )

    def test_a_date_without_a_zone_is_utc(self) -> None:
        xml = b"<rss><channel><item><guid>g</guid><pubDate>01 Mar 2026 10:00:00</pubDate></item></channel></rss>"
        self.assertEqual(parse_feed(1, xml)[0].published, datetime(2026, 3, 1, 10, 0, tzinfo=UTC))

    def test_a_channel_without_items_has_no_entries(self) -> None:
        self.assertEqual(parse_feed(1, b"<rss><channel><title>Quiet</title></channel></rss>"), [])

    def test_malformed_xml_is_refused(self) -> None:
        with self.assertRaises(ParseError):
            parse_feed(1, b"<rss><channel>")

    def test_xml_that_is_not_rss_is_refused(self) -> None:
        atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><title>Atom</title></feed>'
        for xml in (atom, b"<html><body>Not found</body></html>", b"<rss version='2.0'></rss>"):
            with self.subTest(xml=xml), self.assertRaises(ParseError):
                parse_feed(1, xml)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 3: Write `feedwatch/parse.py`**

`email.utils.parsedate_tz` returns `None` for a date it cannot read, so no `except` is needed for a garbled `pubDate` (the Errors rule allows an `except` here only to convert a library exception into a `FeedwatchError`).

```python
"""Turns RSS XML into entries."""
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from email.utils import mktime_tz, parsedate_tz

from feedwatch.errors import ParseError
from feedwatch.models import Entry


def parse_feed(feed_id: int, xml: bytes) -> list[Entry]:
    """Return the items of RSS document `xml` as entries of feed `feed_id`.

    An item with neither a guid nor a link is left out, since nothing identifies it.
    Raises ParseError if `xml` is not well-formed or is not RSS.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        raise ParseError(f"not well-formed XML: {error}") from error
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise ParseError(f"not an RSS feed: the root element is <{root.tag}>")
    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            Entry(
                feed_id=feed_id,
                guid=guid,
                title=_text(item, "title"),
                link=link,
                published=_published(_text(item, "pubDate")),
            )
        )
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    text = item.findtext(tag)
    if text is None or not text.strip():
        return None
    return text.strip()


def _published(text: str | None) -> datetime | None:
    parts = None if text is None else parsedate_tz(text)
    if parts is None:
        return None
    # A date without a zone is read as UTC, not as this machine's local time.
    return datetime.fromtimestamp(mktime_tz(parts[:9] + (parts[9] or 0,)), UTC)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 17 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS items into entries"
```

---

### Task 4: Fetch a feed's XML

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `errors.FetchError` (Task 1).
- Produces: `fetch.fetch(url: str, *, timeout: float = 10.0) -> bytes` — raises `FetchError("cannot fetch <url>: <reason>")` on any network, HTTP-status, timeout or malformed-URL failure.

The tests use a `file://` URL for success and three URLs that fail without a network (missing file, not a URL, a refused local port), so no test server or thread is needed.

- [ ] **Step 1: Write the failing tests** in `tests/test_fetch.py`

```python
import re
import tempfile
import unittest
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch


class FetchTest(unittest.TestCase):
    def test_returns_the_body(self) -> None:
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        (directory / "feed.xml").write_bytes(b"<rss/>")
        self.assertEqual(fetch((directory / "feed.xml").as_uri()), b"<rss/>")

    def test_failures_raise_fetch_error_naming_the_url(self) -> None:
        for url in ("file:///nonexistent/feed.xml", "not a url", "http://127.0.0.1:9/feed.xml"):
            with self.subTest(url=url), self.assertRaisesRegex(FetchError, re.escape(url)):
                fetch(url, timeout=2.0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 3: Write `feedwatch/fetch.py`**

`urllib.error.URLError` and `HTTPError` are `OSError`s, as are timeouts and connection resets; `ValueError` is a URL urllib cannot read; `HTTPException` is a malformed or truncated HTTP response.

```python
"""Downloads a feed's XML. The only module that touches the network."""
import urllib.request
from http.client import HTTPException

from feedwatch.errors import FetchError


def fetch(url: str, *, timeout: float = 10.0) -> bytes:
    """Return the body at `url`. Raises FetchError if it cannot be downloaded within `timeout` seconds."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    except (OSError, ValueError, HTTPException) as error:
        raise FetchError(f"cannot fetch {url}: {error}") from error
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 19 tests, OK.

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch a feed's XML"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.list_feeds`, `store.add_entries`, `store.record_poll`, `store.connect`, `store.DEFAULT_PATH`, `store.Connection` (Tasks 1–2); `parse.parse_feed` (Task 3); `fetch.fetch` (Task 4); `errors.FetchError`, `errors.ParseError`.
- Produces:
  - `poller.is_due(feed: Feed, now: datetime) -> bool`
  - `poller.poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> int` — returns how many new entries were stored
  - `poller.main() -> None`, run by `python -m feedwatch.poller`

`record_poll` runs after a failed poll as well as a successful one: that is what makes a failing feed wait for its next interval. A `sqlite3` error is not caught, so it stops the poller, as `ARCHITECTURE.md` requires.

- [ ] **Step 1: Write the failing tests** in `tests/test_poller.py`

```python
import tempfile
import unittest
from collections.abc import Callable
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchError
from feedwatch.models import Feed
from feedwatch.poller import is_due, poll_once

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)
GOOD = b"<rss><channel><item><guid>g1</guid><title>Hello</title></item></channel></rss>"


def fetcher(bodies: dict[str, bytes], calls: list[str]) -> Callable[[str], bytes]:
    def fetch_feed(url: str) -> bytes:
        calls.append(url)
        if url not in bodies:
            raise FetchError(f"cannot fetch {url}: unreachable")
        return bodies[url]

    return fetch_feed


class IsDueTest(unittest.TestCase):
    def feed(self, last_polled_at: datetime | None) -> Feed:
        return Feed(id=1, url="https://example.com/rss", title=None, every_minutes=30, last_polled_at=last_polled_at)

    def test_a_feed_never_polled_is_due(self) -> None:
        self.assertTrue(is_due(self.feed(None), NOW))

    def test_a_feed_is_due_once_its_interval_is_up(self) -> None:
        self.assertFalse(is_due(self.feed(NOW - timedelta(minutes=29)), NOW))
        self.assertTrue(is_due(self.feed(NOW - timedelta(minutes=30)), NOW))


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(path)))
        self.calls: list[str] = []

    def test_new_entries_are_stored_once(self) -> None:
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        fetch_feed = fetcher({"https://good.example/rss": GOOD}, self.calls)
        self.assertEqual(poll_once(self.conn, NOW, fetch_feed=fetch_feed), 1)
        self.assertEqual(poll_once(self.conn, NOW + timedelta(minutes=30), fetch_feed=fetch_feed), 0)
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["g1"])

    def test_a_feed_not_due_is_not_fetched(self) -> None:
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        fetch_feed = fetcher({"https://good.example/rss": GOOD}, self.calls)
        poll_once(self.conn, NOW, fetch_feed=fetch_feed)
        poll_once(self.conn, NOW + timedelta(minutes=10), fetch_feed=fetch_feed)
        self.assertEqual(self.calls, ["https://good.example/rss"])

    def test_a_failing_feed_is_skipped_and_the_others_still_polled(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://broken.example/rss", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        fetch_feed = fetcher(
            {"https://broken.example/rss": b"<html>oops</html>", "https://good.example/rss": GOOD}, self.calls
        )
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            self.assertEqual(poll_once(self.conn, NOW, fetch_feed=fetch_feed), 1)
        self.assertEqual(len(logs.records), 2)
        self.assertIn("https://down.example/rss", logs.output[0])

    def test_a_failing_feed_waits_for_its_next_interval(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        fetch_feed = fetcher({}, self.calls)
        with self.assertLogs("feedwatch.poller", level="WARNING"):
            poll_once(self.conn, NOW, fetch_feed=fetch_feed)
        poll_once(self.conn, NOW + timedelta(minutes=1), fetch_feed=fetch_feed)
        self.assertEqual(self.calls, ["https://down.example/rss"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Write `feedwatch/poller.py`**

```python
"""The long-running worker: polls each feed when its interval is up."""
import logging
import time
from collections.abc import Callable
from contextlib import closing
from datetime import UTC, datetime, timedelta

from feedwatch import fetch, parse, store
from feedwatch.errors import FetchError, ParseError
from feedwatch.models import Feed

log = logging.getLogger(__name__)

# Intervals are whole minutes, so checking once a minute never makes a feed late by more than one.
TICK_SECONDS = 60


def is_due(feed: Feed, now: datetime) -> bool:
    """Whether `feed`'s interval has run out at `now`. A feed never polled is due."""
    if feed.last_polled_at is None:
        return True
    return now - feed.last_polled_at >= timedelta(minutes=feed.every_minutes)


def poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> int:
    """Poll every feed due at `now` and return how many new entries were stored.

    A feed that cannot be fetched or parsed is logged and waits for its next interval.
    A database error propagates.
    """
    stored = 0
    for feed in store.list_feeds(conn):
        if not is_due(feed, now):
            continue
        try:
            entries = parse.parse_feed(feed.id, fetch_feed(feed.url))
        except (FetchError, ParseError) as error:
            log.warning("skipping %s until its next interval: %s", feed.url, error)
        else:
            stored += store.add_entries(conn, entries, seen_at=now)
        store.record_poll(conn, feed.id, at=now)
    return stored


def main() -> None:
    """Poll forever against the default database."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with closing(store.connect(store.DEFAULT_PATH)) as conn:
        while True:
            stored = poll_once(conn, datetime.now(UTC), fetch_feed=fetch.fetch)
            if stored:
                log.info("stored %d new entries", stored)
            time.sleep(TICK_SECONDS)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 25 tests, OK.

- [ ] **Step 5: Smoke-test the loop against a throwaway home directory**

Run: `HOME="$(mktemp -d)" timeout 5 python -m feedwatch.poller; echo "exit $?"`
Expected: no traceback, `exit 124` (stopped by `timeout`, with no feeds to poll).

- [ ] **Step 6: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller stores new entries and skips failing feeds"
```

---

### Task 6: The command line

**Files:**
- Create: `feedwatch/cli.py`, `pyproject.toml`
- Modify: `.gitignore`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.DEFAULT_PATH`, `store.Connection`, `store.add_feed`, `store.unread`, `store.mark_read` (Tasks 1–2); `models.Entry`; `errors.FeedwatchError`.
- Produces:
  - `cli.run(argv: Sequence[str], conn: store.Connection, *, out: TextIO, err: TextIO) -> int` — `0` on success, `1` on a refused command (message `feedwatch: <reason>` on `err`); a malformed command line exits through argparse with `SystemExit(2)`
  - `cli.main() -> None`, installed as the `feedwatch` console script
  - `unread` prints one line per entry: `<guid>\t<YYYY-MM-DD HH:MM in UTC, or ->\t<title, else link, else empty>`, or `no unread entries`

- [ ] **Step 1: Write the failing tests** in `tests/test_cli.py`

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr
from datetime import UTC, datetime
from pathlib import Path

from feedwatch import store
from feedwatch.cli import run
from feedwatch.models import Entry

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(path)))

    def feedwatch(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        status = run(list(argv), self.conn, out=out, err=err)
        return status, out.getvalue(), err.getvalue()

    def test_add_subscribes_with_a_30_minute_default(self) -> None:
        status, out, _ = self.feedwatch("add", "https://example.com/rss", "--title", "Example")
        self.assertEqual(status, 0)
        self.assertIn("https://example.com/rss", out)
        feed = store.list_feeds(self.conn)[0]
        self.assertEqual((feed.title, feed.every_minutes), ("Example", 30))

    def test_add_takes_an_interval(self) -> None:
        self.feedwatch("add", "https://example.com/rss", "--every", "5")
        self.assertEqual(store.list_feeds(self.conn)[0].every_minutes, 5)

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        self.feedwatch("add", "https://example.com/rss")
        status, _, err = self.feedwatch("add", "https://example.com/rss")
        self.assertEqual(status, 1)
        self.assertIn("https://example.com/rss", err)

    def test_bad_arguments_exit_with_usage_status(self) -> None:
        for argv in (
            ["add", "example.com/rss"],
            ["add", "https://example.com/rss", "--every", "0"],
            ["add", "https://example.com/rss", "--every", "soon"],
            ["unread", "--limit", "0"],
            ["unread", "--limit", "-1"],
            ["read"],
        ):
            with self.subTest(argv=argv), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                self.feedwatch(*argv)
            self.assertEqual(caught.exception.code, 2)
        self.assertEqual(store.list_feeds(self.conn), [])

    def test_unread_lists_newest_first_up_to_the_limit(self) -> None:
        feed = store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        store.add_entries(
            self.conn,
            [
                Entry(feed_id=feed.id, guid=f"g{day}", title=f"Day {day}", link=None, published=NOW.replace(day=day))
                for day in range(1, 26)
            ],
            seen_at=NOW,
        )
        status, out, _ = self.feedwatch("unread")
        lines = out.splitlines()
        self.assertEqual(status, 0)
        self.assertEqual(len(lines), 20)
        self.assertEqual(lines[0], "g25\t2026-03-25 12:00\tDay 25")
        self.assertEqual(len(self.feedwatch("unread", "--limit", "3")[1].splitlines()), 3)

    def test_unread_says_so_when_there_is_nothing(self) -> None:
        self.assertEqual(self.feedwatch("unread")[1], "no unread entries\n")

    def test_read_marks_entries_and_refuses_an_unknown_guid_naming_it(self) -> None:
        feed = store.add_feed(self.conn, "https://example.com/rss", title=None, every_minutes=30)
        store.add_entries(
            self.conn,
            [Entry(feed_id=feed.id, guid=guid, title=None, link=None, published=NOW) for guid in ("a", "b", "c")],
            seen_at=NOW,
        )
        self.assertEqual(self.feedwatch("read", "a", "b")[0], 0)
        status, _, err = self.feedwatch("read", "c", "missing")
        self.assertEqual(status, 1)
        self.assertIn("missing", err)
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["c"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR, `ModuleNotFoundError: No module named 'feedwatch.cli'`.

- [ ] **Step 3: Write `feedwatch/cli.py`**

Argument checks go through `parser.error`, which prints usage and exits with status 2 like argparse's own errors, rather than through a `raise` that would need an exception class outside `FeedwatchError`.

```python
"""The user's commands: add, unread and read."""
import argparse
import sys
from collections.abc import Sequence
from contextlib import closing
from typing import TextIO

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import Entry


def run(argv: Sequence[str], conn: store.Connection, *, out: TextIO, err: TextIO) -> int:
    """Carry out the command in `argv` against `conn` and return the exit status.

    A malformed command line exits through argparse with status 2.
    """
    parser = _parser()
    args = parser.parse_args(argv)
    _validate(parser, args)
    try:
        if args.command == "add":
            feed = store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
            print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes", file=out)
        elif args.command == "unread":
            _print_unread(store.unread(conn, args.limit), out)
        else:
            store.mark_read(conn, args.guids)
            print(f"marked {len(args.guids)} read", file=out)
    except FeedwatchError as error:
        print(f"feedwatch: {error}", file=err)
        return 1
    return 0


def main() -> None:
    """Entry point of the `feedwatch` command."""
    with closing(store.connect(store.DEFAULT_PATH)) as conn:
        status = run(sys.argv[1:], conn, out=sys.stdout, err=sys.stderr)
    sys.exit(status)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _validate(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    # parser.error exits with argparse's usage message and status 2.
    if args.command == "add" and not args.url.startswith(("http://", "https://")):
        parser.error(f"not an http or https URL: {args.url}")
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1")
    # SQLite reads a negative LIMIT as no limit at all.
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")


def _print_unread(entries: Sequence[Entry], out: TextIO) -> None:
    if not entries:
        print("no unread entries", file=out)
    for entry in entries:
        date = "-" if entry.published is None else entry.published.strftime("%Y-%m-%d %H:%M")
        print(f"{entry.guid}\t{date}\t{entry.title or entry.link or ''}", file=out)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 32 tests, OK.

- [ ] **Step 5: Write `pyproject.toml`**

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Polls RSS feeds into SQLite and reads them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

- [ ] **Step 6: Extend `.gitignore`** so it reads

```
__pycache__/
.venv/
*.egg-info/
```

- [ ] **Step 7: Install the command into a Python 3.11 virtualenv and run it end to end**

With `uv` (the system Python may have no `ensurepip`):

```bash
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -e .
.venv/bin/python -m unittest discover -s tests -t .
export HOME="$(mktemp -d)"
.venv/bin/feedwatch add https://example.com/rss
.venv/bin/feedwatch add https://example.com/rss; echo "exit $?"
.venv/bin/feedwatch unread
.venv/bin/feedwatch read nope; echo "exit $?"
```

Expected: 32 tests OK on Python 3.11; `subscribed to https://example.com/rss, polled every 30 minutes`; then `feedwatch: already subscribed: https://example.com/rss` and `exit 1`; `no unread entries`; `feedwatch: no such entry: nope` and `exit 1`.

- [ ] **Step 8: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/cli.py tests/test_cli.py pyproject.toml .gitignore
git commit -m "feat: feedwatch command line: add, unread, read"
```
````


## p010

#### Final message

I wrote the feedwatch v1 implementation plan and committed it on `master` as `136a08b` ("plan: feedwatch v1 implementation"). Nothing in the repo is implemented. To check the plan's code before committing, I ran every task in a throwaway directory outside the repo: each one fails first, then passes. The full suite of 45 tests passes on Python 3.12 and 3.14, and the PROGRAM-DESIGN greps come back clean. I also installed the `feedwatch` command and ran it end to end against a local HTTP feed, with the poller running.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

**The tasks:**
1. Package, error types, the `Feed` type, and the store's feeds table with `connect`, `add_feed` and `list_feeds`.
2. Entries in the store: a second schema step, plus `save_poll`, `unread` and `mark_read`.
3. Parsing RSS into items. Anything that isn't RSS, Atom included, is refused.
4. Fetching over HTTP, with a 30-second timeout.
5. The poller: `poll_once` with the fetch function passed in, and the `main` loop.
6. The command line: `add`, `unread` and `read`.
7. An end-to-end smoke test, the PROGRAM-DESIGN checks over the branch, then the `dopamine:finishing-work` sweep.

**PROGRAM-DESIGN:** Global Constraints copies every rule from `docs/PROGRAM-DESIGN.md` with its check, and I ran each check over the plan's own code. The document left no structural choice open, so I had nothing to put to you. Reading the checks literally changed four things:
- **Connection type:** `store` exports a `Connection` alias, so `poller` and `cli` never import `sqlite3`.
- **Closing connections:** `cli` uses `contextlib.closing` instead of calling `conn.close()`.
- **URL check:** `cli` checks the URL scheme without `urllib`, which is allowed only in `fetch.py`.
- **Keyword-only reason:** `FetchFailed` takes `reason` as a keyword-only argument.

The plan also says how the checks apply to tests: tests may import `cli` and `poller`, and the test HTTP server runs in a `ThreadPoolExecutor` rather than a thread.

**Choices the spec doesn't make, recorded in the plan:**
- **Tests:** `unittest`, since the design puts the standard library first.
- **Ordering:** `unread` orders by publication date. An entry with no usable date takes the time it was first seen.
- **Reading by guid:** `read GUID` marks the entry in every feed that has that guid. If any guid is unknown, the command is refused and nothing is marked.
- **Refused before storing:** `add` rejects URLs that aren't http or https, and both commands reject `--every 0` and `--limit 0`.

I didn't run the `finishing-work` sweep for this planning session, because writing the plan changed nothing the living documents describe. Task 7 runs it after execution. `docs/ROADMAP.md` is declared in `.dopamine/config` but doesn't exist; the sweep will report it absent rather than create it.

Plan complete and saved to `docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Please review the plan. Does it capture what you want?

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** One package, `feedwatch/`, holding the five components from `docs/ARCHITECTURE.md`, one module each: `fetch.py`, `parse.py`, `store.py`, `poller.py` and `cli.py`. `models.py` holds the domain dataclasses and `errors.py` the exception hierarchy. `poller` calls `fetch`, `parse` and `store`. `cli` calls only `store`. Both processes open `~/.feedwatch/feeds.db`.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`), with `unittest` for tests. `setuptools` is used only as the build backend that installs the `feedwatch` command.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Also read `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`.

## Global Constraints

From the spec and `docs/DESIGN.md`:

- Python 3.11 or newer (`requires-python = ">=3.11"`). Runtime code uses the standard library only ("Standard library first; a dependency has to earn its place").
- Commands: `feedwatch add URL [--title TITLE] [--every MINUTES]` (default 30), `feedwatch unread [--limit N]` (default 20, newest first), `feedwatch read GUID [GUID ...]`, and `python -m feedwatch.poller`.
- Refusals name what was refused. Subscribing again names the URL. Reading an unknown guid names that guid.
- An entry is identified by its feed and its guid, or by its link when it has no guid. Each entry is stored once, however often it is seen.
- A feed that cannot be fetched, or that is not RSS, is logged and skipped until its next interval. The other feeds are still polled. A database error stops the poller (`docs/ARCHITECTURE.md`).
- The database is one SQLite file at `~/.feedwatch/feeds.db` with the tables `feeds` and `entries`, and a database that already exists has to keep working.
- Out of scope: Atom feeds (they are refused as "not RSS"), importing or exporting subscription lists, and more than one user.

These rules come from `docs/PROGRAM-DESIGN.md`, copied with their checks. Every task's code must pass every check:

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them. Past that module, nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them. Test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter, and nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout (inherited default).** Split by responsibility, not technical layer. Files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions. A helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`. A connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`, and an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How these apply to this plan:

- **Scope of the checks.** The checks apply in full to `feedwatch/`. Test modules sit outside the package's layering, so they may import `cli` and `poller` and may use a connection to set up and inspect state (`conn.close()`, a `SELECT COUNT(*)`). The Signatures and Concurrency checks also hold in `tests/`. That is why the test HTTP server runs in a `ThreadPoolExecutor` and not a `threading.Thread`.
- **Type annotations.** Other modules name the connection type as `store.Connection`, an alias of `sqlite3.Connection`, so `poller.py` and `cli.py` never import `sqlite3`. `cli` closes connections with `contextlib.closing`, never `conn.close()`.
- **URL check in `cli`.** `cli` checks the URL scheme with `str.partition`, because `urllib` is allowed only in `fetch.py`.
- **`None` returns.** `parse._text` and `parse._published` return `None` to mean "this item states no such value". That is an answer about the item, not a failure: the store dates an undated entry by when it was first seen.
- **Concurrency.** The poller polls its feeds one after another on its one thread. Each fetch has a 30-second timeout, and a handful of feeds needs no executor.
- **Code comments.** They follow `dopamine:writing-code-comments`: a why, a contract or a warning, and nothing else.
- **Living documents.** Do not edit `docs/DESIGN.md`, `docs/ARCHITECTURE.md` or `docs/PROGRAM-DESIGN.md` during execution. Record anything they should learn in the ledger. Task 7's sweep places it.

Run every test command from the repository root with a Python 3.11+ interpreter (`python3 --version`).

## Review Focus

1. **A pubDate that is missing, unreadable, out of range or in another time zone.** `unread` still orders by the actual instant. An entry without a usable date is dated by when it was first seen, and a bad date never makes the feed fail. Tests: `test_parse.py::test_a_missing_or_unreadable_date_is_none` (Task 3), and `test_unread_orders_by_instant_across_time_zones` and `test_an_undated_entry_is_dated_by_when_it_was_first_seen` (Task 2).
2. **`feedwatch read` with several guids, one of them unknown.** The command is refused, naming the unknown guid, and none of the guids is marked read. Tests: `test_an_unknown_guid_is_refused_naming_it_and_marks_nothing` (Task 2) and `test_read_refuses_an_unknown_guid_naming_it` (Task 6).
3. **A URL the poller could never fetch, or a nonsensical number.** A URL with no scheme (`example.org/rss`), a `file://` URL, `--every 0` and `--limit 0` are all refused when the command runs. They are never stored to fail at every interval. Tests: `test_add_refuses_a_url_that_is_not_http`, `test_add_refuses_an_interval_below_one_minute` and `test_unread_refuses_a_limit_below_one` (Task 6).
4. **A server that answers with something other than an RSS feed:** an HTML error page, an Atom feed, an empty body, a 404 or a closed port. The feed is logged and skipped until its next interval, and the other feeds are still polled. Tests: `test_parse.py` NotRSS cases (Task 3), `test_fetch.py` failure cases (Task 4) and `test_a_failing_feed_is_skipped_until_its_next_interval_and_others_still_polled` (Task 5).
5. **The same guid in two feeds.** It is stored as two entries, and `feedwatch read GUID` marks both read. Tests: `test_the_same_guid_in_two_feeds_is_two_entries` and `test_reading_a_guid_two_feeds_share_marks_both` (Task 2).

## File Structure

| File | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata and the `feedwatch` console script (`feedwatch.cli:main`) |
| `feedwatch/__init__.py` | Empty package marker |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses, one for each way something fails |
| `feedwatch/models.py` | Frozen dataclasses: `Feed`, `Item` (parsed, not yet stored) and `Entry` (stored, as listed) |
| `feedwatch/store.py` | The SQLite schema (`SCHEMA_STEPS`), `connect`, and every read and write |
| `feedwatch/parse.py` | RSS XML → `list[Item]` |
| `feedwatch/fetch.py` | URL → bytes over HTTP(S) |
| `feedwatch/poller.py` | Schedule: `poll_once` and the `main` loop |
| `feedwatch/cli.py` | argparse commands, validation of arguments and output formatting |
| `tests/test_store.py`, `tests/test_parse.py`, `tests/test_fetch.py`, `tests/test_poller.py`, `tests/test_cli.py` | One `unittest` module per component |

## Interfaces (whole program)

```python
# feedwatch/models.py
Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)
Item(guid: str, link: str | None, title: str | None, published: datetime | None)
Entry(guid: str, title: str | None, link: str | None, published: datetime, feed: str)

# feedwatch/errors.py
FeedwatchError(Exception)
AlreadySubscribed(url: str)            # store.add_feed
UnknownEntry(guid: str)                # store.mark_read
NotRSS(message: str)                   # parse.parse_items
FetchFailed(url: str, *, reason: str)  # fetch.fetch_xml
InvalidArgument(message: str)          # cli

# feedwatch/store.py
Connection = sqlite3.Connection
DEFAULT_PATH: Path                     # ~/.feedwatch/feeds.db
SCHEMA_STEPS: tuple[str, ...]
connect(path: Path) -> Connection
add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed
list_feeds(conn: Connection) -> list[Feed]
save_poll(conn: Connection, feed_id: int, *, items: Iterable[Item], polled_at: datetime) -> None
unread(conn: Connection, limit: int) -> list[Entry]
mark_read(conn: Connection, guids: Sequence[str]) -> None

# feedwatch/parse.py
parse_items(xml: bytes) -> list[Item]

# feedwatch/fetch.py
fetch_xml(url: str) -> bytes

# feedwatch/poller.py
poll_once(conn: store.Connection, now: datetime, *, fetch_xml: Callable[[str], bytes]) -> None
main() -> None

# feedwatch/cli.py
main(argv: Sequence[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int
```

All datetimes are timezone-aware. The store writes them as UTC ISO-8601 text to the second, so ordering the text orders the instants.

---

### Task 1: Package, feeds table and subscribing in the store

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/errors.py`, `feedwatch/models.py`, `feedwatch/store.py`
- Test: `tests/__init__.py`, `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `FeedwatchError`, `AlreadySubscribed(url)`, `Feed`, `store.Connection`, `store.DEFAULT_PATH`, `store.SCHEMA_STEPS`, `store.connect(path)`, `store.add_feed(conn, url, *, title, every_minutes) -> Feed` and `store.list_feeds(conn) -> list[Feed]`.

- [ ] **Step 1: Write the failing test**

Create `tests/__init__.py` and `feedwatch/__init__.py` as empty files. Create `tests/test_store.py`:

```python
import sqlite3
import tempfile
import unittest
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribed


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "nested" / "feeds.db"
        self.conn = store.connect(self.path)
        self.addCleanup(self.conn.close)


class FeedsTest(StoreTestCase):
    def test_connect_creates_the_file_and_its_directory(self) -> None:
        self.assertTrue(self.path.exists())

    def test_added_feed_is_listed(self) -> None:
        feed = store.add_feed(self.conn, "https://example.org/rss", title="Example", every_minutes=15)
        self.assertEqual(store.list_feeds(self.conn), [feed])
        self.assertEqual(feed.url, "https://example.org/rss")
        self.assertEqual(feed.title, "Example")
        self.assertEqual(feed.every_minutes, 15)
        self.assertIsNone(feed.last_polled)

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        store.add_feed(self.conn, "https://example.org/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribed) as caught:
            store.add_feed(self.conn, "https://example.org/rss", title="Again", every_minutes=5)
        self.assertIn("https://example.org/rss", str(caught.exception))
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_an_existing_database_keeps_its_feeds_when_reopened(self) -> None:
        store.add_feed(self.conn, "https://example.org/rss", title=None, every_minutes=30)
        self.conn.close()
        reopened = store.connect(self.path)
        self.addCleanup(reopened.close)
        self.assertEqual([feed.url for feed in store.list_feeds(reopened)], ["https://example.org/rss"])


class SchemaTest(unittest.TestCase):
    def test_every_step_is_idempotent(self) -> None:
        conn = sqlite3.connect(":memory:")
        self.addCleanup(conn.close)
        for step in store.SCHEMA_STEPS + store.SCHEMA_STEPS:
            conn.execute(step)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_store -v`
Expected: FAIL. The error is `ImportError: cannot import name 'store' from 'feedwatch'`, or `ModuleNotFoundError: No module named 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/errors.py`:

```python
class FeedwatchError(Exception):
    """Base of every failure feedwatch raises on purpose."""


class AlreadySubscribed(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url
```

`feedwatch/models.py`:

```python
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None
```

`feedwatch/store.py`:

```python
import sqlite3
from datetime import datetime
from pathlib import Path

from feedwatch.errors import AlreadySubscribed
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Every connect runs every step, so each must be idempotent. Append new steps
# and never edit one: existing databases have already run it.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
)


def connect(path: Path) -> Connection:
    """Open the database at `path`, creating it and bringing its schema up to date."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and the CLI share the file; wait out the other's write.
    conn = sqlite3.connect(path, timeout=10)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`; raise AlreadySubscribed if it is subscribed already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as exc:
        raise AlreadySubscribed(url) from exc
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def list_feeds(conn: Connection) -> list[Feed]:
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id")
    return [
        Feed(
            id=row[0],
            url=row[1],
            title=row[2],
            every_minutes=row[3],
            last_polled=None if row[4] is None else datetime.fromisoformat(row[4]),
        )
        for row in rows
    ]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_store -v`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add pyproject.toml feedwatch tests
git commit -m "feat: store subscribes to feeds"
```

### Task 2: Entries in the store: saving a poll, listing unread, marking read

**Files:**
- Modify: `feedwatch/errors.py` (append `UnknownEntry`), `feedwatch/models.py` (append `Item` and `Entry`), `feedwatch/store.py` (imports, a second schema step, and new functions)
- Test: `tests/test_store.py` (replace the import header and append `EntriesTest`)

**Interfaces:**
- Consumes: Task 1's `store.connect`, `store.add_feed`, `store.list_feeds` and `Feed`.
- Produces: `Item(guid, link, title, published)`, `Entry(guid, title, link, published, feed)`, `UnknownEntry(guid)`, `store.save_poll(conn, feed_id, *, items, polled_at) -> None`, `store.unread(conn, limit) -> list[Entry]` and `store.mark_read(conn, guids) -> None`. `save_poll` sets `Feed.last_polled`.

- [ ] **Step 1: Write the failing test**

In `tests/test_store.py`, replace everything above `class StoreTestCase` with:

```python
import sqlite3
import tempfile
import unittest
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribed, UnknownEntry
from feedwatch.models import Item

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)
```

Append to the end of `tests/test_store.py`:

```python
class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, "https://example.org/rss", title="Example", every_minutes=30)

    def item(self, guid: str, *, published: datetime | None = None) -> Item:
        return Item(guid=guid, link=f"https://example.org/{guid}", title=f"Title {guid}", published=published)

    def test_save_poll_records_when_the_feed_was_polled(self) -> None:
        store.save_poll(self.conn, self.feed.id, items=[], polled_at=NOON)
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled, NOON)

    def test_an_entry_seen_twice_is_stored_once_and_stays_read(self) -> None:
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON + timedelta(hours=1))
        self.assertEqual(store.unread(self.conn, 20), [])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM entries").fetchone()[0], 1)

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        other = store.add_feed(self.conn, "https://other.org/rss", title=None, every_minutes=30)
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON)
        store.save_poll(self.conn, other.id, items=[self.item("a")], polled_at=NOON)
        self.assertEqual(
            sorted(entry.feed for entry in store.unread(self.conn, 20)),
            ["Example", "https://other.org/rss"],
        )

    def test_unread_lists_newest_first_up_to_the_limit(self) -> None:
        items = [
            self.item("old", published=NOON - timedelta(days=2)),
            self.item("new", published=NOON),
            self.item("mid", published=NOON - timedelta(days=1)),
        ]
        store.save_poll(self.conn, self.feed.id, items=items, polled_at=NOON)
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["new", "mid", "old"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 2)], ["new", "mid"])

    def test_unread_orders_by_instant_across_time_zones(self) -> None:
        plus_two = timezone(timedelta(hours=2))
        items = [
            self.item("earlier", published=datetime(2026, 3, 1, 13, 0, tzinfo=plus_two)),
            self.item("later", published=datetime(2026, 3, 1, 12, 30, tzinfo=UTC)),
        ]
        store.save_poll(self.conn, self.feed.id, items=items, polled_at=NOON)
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["later", "earlier"])

    def test_an_undated_entry_is_dated_by_when_it_was_first_seen(self) -> None:
        dated = self.item("dated", published=NOON - timedelta(hours=1))
        store.save_poll(self.conn, self.feed.id, items=[dated], polled_at=NOON)
        store.save_poll(self.conn, self.feed.id, items=[self.item("undated")], polled_at=NOON + timedelta(hours=1))
        entries = store.unread(self.conn, 20)
        self.assertEqual([entry.guid for entry in entries], ["undated", "dated"])
        self.assertEqual(entries[0].published, NOON + timedelta(hours=1))
        self.assertEqual(entries[0].feed, "Example")

    def test_mark_read_hides_the_entry(self) -> None:
        store.save_poll(self.conn, self.feed.id, items=[self.item("a"), self.item("b")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["b"])

    def test_marking_an_already_read_entry_is_not_refused(self) -> None:
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        store.mark_read(self.conn, ["a"])

    def test_an_unknown_guid_is_refused_naming_it_and_marks_nothing(self) -> None:
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON)
        with self.assertRaises(UnknownEntry) as caught:
            store.mark_read(self.conn, ["a", "nope"])
        self.assertIn("nope", str(caught.exception))
        self.assertEqual([entry.guid for entry in store.unread(self.conn, 20)], ["a"])

    def test_reading_a_guid_two_feeds_share_marks_both(self) -> None:
        other = store.add_feed(self.conn, "https://other.org/rss", title=None, every_minutes=30)
        store.save_poll(self.conn, self.feed.id, items=[self.item("a")], polled_at=NOON)
        store.save_poll(self.conn, other.id, items=[self.item("a")], polled_at=NOON)
        store.mark_read(self.conn, ["a"])
        self.assertEqual(store.unread(self.conn, 20), [])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_store -v`
Expected: FAIL with `ImportError: cannot import name 'UnknownEntry' from 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/errors.py`:

```python
class UnknownEntry(FeedwatchError):
    def __init__(self, guid: str) -> None:
        super().__init__(f"no stored entry has guid {guid}")
        self.guid = guid
```

Append to `feedwatch/models.py`:

```python
@dataclass(frozen=True)
class Item:
    """An entry as a feed states it, before it is stored."""

    # Identifies the item within its feed: its guid, or its link when it has none.
    guid: str
    link: str | None
    title: str | None
    published: datetime | None


@dataclass(frozen=True)
class Entry:
    """A stored entry as the command line lists it."""

    guid: str
    title: str | None
    link: str | None
    # The feed's pubDate, or when the poller first saw the entry if it had none.
    published: datetime
    # The feed's title, or its URL when it was subscribed without one.
    feed: str
```

In `feedwatch/store.py`, replace the import block (everything above `Connection =`) with:

```python
import sqlite3
from collections.abc import Iterable, Sequence
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import AlreadySubscribed, UnknownEntry
from feedwatch.models import Entry, Feed, Item
```

Append this second step inside the `SCHEMA_STEPS` tuple, after the `feeds` step and before the closing `)`. Do not edit the `feeds` step:

```python
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        link TEXT,
        title TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
```

Append to the end of `feedwatch/store.py`:

```python
def save_poll(conn: Connection, feed_id: int, *, items: Iterable[Item], polled_at: datetime) -> None:
    """Store the items this feed has not stored before, and record it polled at `polled_at`."""
    seen_at = _to_text(polled_at)
    rows = [
        (feed_id, item.guid, item.link, item.title, None if item.published is None else _to_text(item.published), seen_at)
        for item in items
    ]
    with conn:
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, link, title, published, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            rows,
        )
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (seen_at, feed_id))


def unread(conn: Connection, limit: int) -> list[Entry]:
    """Return up to `limit` unread entries, newest first."""
    rows = conn.execute(
        "SELECT e.guid, e.title, e.link, COALESCE(e.published, e.seen_at), COALESCE(f.title, f.url)"
        " FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id"
        " WHERE e.read = 0"
        " ORDER BY COALESCE(e.published, e.seen_at) DESC, e.id DESC"
        " LIMIT ?",
        (limit,),
    )
    return [
        Entry(guid=row[0], title=row[1], link=row[2], published=datetime.fromisoformat(row[3]), feed=row[4])
        for row in rows
    ]


def mark_read(conn: Connection, guids: Sequence[str]) -> None:
    """Mark every entry with one of `guids` read.

    Raises UnknownEntry for the first guid no entry has, and then marks none.
    """
    with conn:
        for guid in guids:
            if conn.execute("UPDATE entries SET read = 1 WHERE guid = ?", (guid,)).rowcount == 0:
                raise UnknownEntry(guid)


def _to_text(moment: datetime) -> str:
    # One offset and one precision, so that text order is time order in ORDER BY.
    return moment.astimezone(UTC).isoformat(timespec="seconds")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_store -v`
Expected: PASS (15 tests).

- [ ] **Step 5: Commit**

```bash
git add feedwatch tests
git commit -m "feat: store keeps entries once, lists unread, marks read"
```

### Task 3: Parse RSS into items

**Files:**
- Modify: `feedwatch/errors.py` (append `NotRSS`)
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: `Item` (Task 2).
- Produces: `parse.parse_items(xml: bytes) -> list[Item]`, which raises `NotRSS` for malformed XML or a document whose root is not `<rss>` holding a `<channel>`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_parse.py`:

```python
import unittest
from datetime import UTC, datetime

from feedwatch.errors import NotRSS
from feedwatch.models import Item
from feedwatch.parse import parse_items


def rss(items: str) -> bytes:
    return f'<?xml version="1.0"?><rss version="2.0"><channel><title>T</title>{items}</channel></rss>'.encode()


class ParseItemsTest(unittest.TestCase):
    def test_an_item_with_guid_link_title_and_date(self) -> None:
        xml = rss(
            "<item><guid>tag:x,1</guid><link>https://x.org/1</link><title> One </title>"
            "<pubDate>Sun, 01 Mar 2026 14:00:00 +0200</pubDate></item>"
        )
        self.assertEqual(
            parse_items(xml),
            [Item(guid="tag:x,1", link="https://x.org/1", title="One", published=datetime(2026, 3, 1, 12, 0, tzinfo=UTC))],
        )

    def test_an_item_without_guid_is_identified_by_its_link(self) -> None:
        self.assertEqual(parse_items(rss("<item><link>https://x.org/2</link></item>"))[0].guid, "https://x.org/2")

    def test_an_item_with_neither_guid_nor_link_is_left_out(self) -> None:
        self.assertEqual(parse_items(rss("<item><title>orphan</title></item><item><guid>g</guid></item>"))[0].guid, "g")
        self.assertEqual(len(parse_items(rss("<item><title>orphan</title></item>"))), 0)

    def test_a_feed_with_no_items_has_none(self) -> None:
        self.assertEqual(parse_items(rss("")), [])

    def test_a_missing_or_unreadable_date_is_none(self) -> None:
        for date in ["", "<pubDate>yesterday</pubDate>", "<pubDate>Mon, 31 Feb 2026 10:00:00 GMT</pubDate>",
                     "<pubDate>Mon, 01 Jan 99999 10:00:00 GMT</pubDate>", "<pubDate>Mon, 01 Jan 2026 25:00:00 GMT</pubDate>",
                     "<pubDate>Mon, 01 Jan 2026 10:00:00 +9999</pubDate>"]:
            with self.subTest(date=date):
                self.assertIsNone(parse_items(rss(f"<item><guid>g</guid>{date}</item>"))[0].published)

    def test_malformed_xml_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse_items(b"<rss><channel>")

    def test_an_empty_body_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse_items(b"")

    def test_an_atom_feed_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse_items(b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><id>1</id></entry></feed>')

    def test_an_html_page_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse_items(b"<html><body><p>Moved</p></body></html>")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_parse -v`
Expected: FAIL with `ImportError: cannot import name 'NotRSS' from 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/errors.py`:

```python
class NotRSS(FeedwatchError):
    """The document is not an RSS feed."""
```

Create `feedwatch/parse.py`:

```python
import calendar
import email.utils
import xml.etree.ElementTree as ET
from datetime import UTC, datetime, timedelta, timezone

from feedwatch.errors import NotRSS
from feedwatch.models import Item


def parse_items(xml: bytes) -> list[Item]:
    """Return the items of an RSS document; raise NotRSS if `xml` is not one.

    An item with neither a guid nor a link is left out: nothing identifies it.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise NotRSS(f"not well-formed XML: {exc}") from exc
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise NotRSS(f"root element is <{root.tag}>, not <rss> holding a <channel>")
    items = []
    for element in channel.findall("item"):
        link = _text(element, "link")
        guid = _text(element, "guid") or link
        if guid is None:
            continue
        items.append(
            Item(guid=guid, link=link, title=_text(element, "title"), published=_published(_text(element, "pubDate")))
        )
    return items


def _text(element: ET.Element, tag: str) -> str | None:
    child = element.find(tag)
    if child is None or child.text is None or not child.text.strip():
        return None
    return child.text.strip()


def _published(text: str | None) -> datetime | None:
    # None means the item carries no date that can be read; the store then
    # dates it by when it was first seen.
    parts = None if text is None else email.utils.parsedate_tz(text)
    if parts is None or not _in_range(parts):
        return None
    year, month, day, hour, minute, second = parts[:6]
    offset = timezone(timedelta(seconds=parts[9] or 0))
    # datetime has no leap second; the second before it sorts the same.
    return datetime(year, month, day, hour, minute, min(second, 59), tzinfo=offset).astimezone(UTC)


def _in_range(parts: tuple[int | None, ...]) -> bool:
    # parsedate_tz accepts out-of-range fields that datetime would reject.
    year, month, day, hour, minute, second = parts[:6]
    return (
        1 < year < 9999
        and 1 <= month <= 12
        and 1 <= day <= calendar.monthrange(year, month)[1]
        and 0 <= hour < 24
        and 0 <= minute < 60
        and 0 <= second <= 60
        and abs(parts[9] or 0) < 86400
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_parse -v`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add feedwatch tests
git commit -m "feat: parse RSS items, refusing what is not RSS"
```

### Task 4: Fetch a feed over HTTP

**Files:**
- Modify: `feedwatch/errors.py` (append `FetchFailed`)
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `fetch.fetch_xml(url: str) -> bytes`, which raises `FetchFailed(url, *, reason)` for an HTTP error status, an unreachable host, a timeout (`TIMEOUT_SECONDS = 30`) or a malformed URL.

- [ ] **Step 1: Write the failing test**

Create `tests/test_fetch.py`. The local server runs in a `ThreadPoolExecutor` to satisfy the Concurrency check:

```python
import unittest
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, HTTPServer

from feedwatch.errors import FetchFailed
from feedwatch.fetch import fetch_xml


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/feed":
            body = b"<rss/>"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, format: str, *args: object) -> None:
        pass


class FetchXmlTest(unittest.TestCase):
    def setUp(self) -> None:
        server = HTTPServer(("127.0.0.1", 0), _Handler)
        executor = ThreadPoolExecutor(max_workers=1)
        executor.submit(server.serve_forever)
        self.addCleanup(executor.shutdown)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.base = f"http://127.0.0.1:{server.server_port}"

    def test_returns_the_body(self) -> None:
        self.assertEqual(fetch_xml(f"{self.base}/feed"), b"<rss/>")

    def test_an_http_error_status_fails_naming_the_url(self) -> None:
        with self.assertRaises(FetchFailed) as caught:
            fetch_xml(f"{self.base}/missing")
        self.assertIn(f"{self.base}/missing", str(caught.exception))

    def test_an_unreachable_host_fails(self) -> None:
        with self.assertRaises(FetchFailed):
            fetch_xml("http://127.0.0.1:9/feed")

    def test_a_malformed_url_fails(self) -> None:
        with self.assertRaises(FetchFailed):
            fetch_xml("http://[::1/feed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: FAIL with `ImportError: cannot import name 'FetchFailed' from 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/errors.py`:

```python
class FetchFailed(FeedwatchError):
    def __init__(self, url: str, *, reason: str) -> None:
        super().__init__(f"could not fetch {url}: {reason}")
        self.url = url
```

Create `feedwatch/fetch.py`. The `Request` is built inside the `try`, because a malformed URL raises `ValueError` there:

```python
import http.client
import urllib.request

from feedwatch.errors import FetchFailed

TIMEOUT_SECONDS = 30


def fetch_xml(url: str) -> bytes:
    """Return the body served at `url`; raise FetchFailed if it cannot be had."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1.0"})
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as exc:
        raise FetchFailed(url, reason=str(exc)) from exc
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_fetch -v`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add feedwatch tests
git commit -m "feat: fetch feed XML over HTTP"
```

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.list_feeds` and `store.save_poll` (Tasks 1 and 2), `parse.parse_items` (Task 3), `fetch.fetch_xml` (Task 4), and `FetchFailed` and `NotRSS`.
- Produces: `poller.poll_once(conn, now, *, fetch_xml) -> None` and `poller.main()`, run as `python -m feedwatch.poller`. A feed is due when `last_polled` is `None` or `now >= last_polled + every_minutes`. The loop checks every `TICK_SECONDS = 60`.

`fetch_xml` is passed in so tests use a fake web instead of mocking `urllib` (the Effects inherited default). A failed feed is still recorded as polled, so it waits for its next interval. Only `FetchFailed` and `NotRSS` are caught. Anything else, a database error included, propagates and stops the poller.

- [ ] **Step 1: Write the failing test**

Create `tests/test_poller.py`:

```python
import sqlite3
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchFailed
from feedwatch.poller import poll_once

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid></item>" for guid in guids)
    return f"<rss><channel>{items}</channel></rss>".encode()


class FakeWeb:
    def __init__(self, pages: dict[str, bytes]) -> None:
        self.pages = pages
        self.requested: list[str] = []

    def fetch_xml(self, url: str) -> bytes:
        self.requested.append(url)
        if url not in self.pages:
            raise FetchFailed(url, reason="404")
        return self.pages[url]


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.conn = store.connect(Path(directory.name) / "feeds.db")
        self.addCleanup(self.conn.close)

    def unread_guids(self) -> list[str]:
        return sorted(entry.guid for entry in store.unread(self.conn, 100))

    def test_a_new_feed_is_polled_and_its_entries_stored(self) -> None:
        store.add_feed(self.conn, "https://a.org/rss", title=None, every_minutes=30)
        poll_once(self.conn, NOON, fetch_xml=FakeWeb({"https://a.org/rss": rss("1", "2")}).fetch_xml)
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_a_feed_is_polled_again_only_when_its_interval_is_up(self) -> None:
        store.add_feed(self.conn, "https://a.org/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://a.org/rss": rss("1")})
        poll_once(self.conn, NOON, fetch_xml=web.fetch_xml)
        poll_once(self.conn, NOON + timedelta(minutes=29), fetch_xml=web.fetch_xml)
        poll_once(self.conn, NOON + timedelta(minutes=30), fetch_xml=web.fetch_xml)
        self.assertEqual(web.requested, ["https://a.org/rss", "https://a.org/rss"])

    def test_entries_seen_again_are_not_stored_again(self) -> None:
        store.add_feed(self.conn, "https://a.org/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://a.org/rss": rss("1")})
        poll_once(self.conn, NOON, fetch_xml=web.fetch_xml)
        web.pages["https://a.org/rss"] = rss("1", "2")
        poll_once(self.conn, NOON + timedelta(minutes=30), fetch_xml=web.fetch_xml)
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_a_failing_feed_is_skipped_until_its_next_interval_and_others_still_polled(self) -> None:
        store.add_feed(self.conn, "https://down.org/rss", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://atom.org/feed", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://up.org/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://atom.org/feed": b'<feed xmlns="http://www.w3.org/2005/Atom"/>', "https://up.org/rss": rss("1")})
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            poll_once(self.conn, NOON, fetch_xml=web.fetch_xml)
        self.assertEqual(self.unread_guids(), ["1"])
        self.assertEqual(len(logs.records), 2)
        self.assertIn("https://down.org/rss", logs.output[0])
        self.assertIn("https://atom.org/feed", logs.output[1])
        poll_once(self.conn, NOON + timedelta(minutes=1), fetch_xml=web.fetch_xml)
        self.assertEqual(len(web.requested), 3)

    def test_a_database_error_propagates(self) -> None:
        store.add_feed(self.conn, "https://a.org/rss", title=None, every_minutes=30)
        self.conn.close()
        with self.assertRaises(sqlite3.Error):
            poll_once(self.conn, NOON, fetch_xml=FakeWeb({"https://a.org/rss": rss("1")}).fetch_xml)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_poller -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Write minimal implementation**

Create `feedwatch/poller.py`:

```python
import logging
import time
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from feedwatch import fetch, parse, store
from feedwatch.errors import FetchFailed, NotRSS
from feedwatch.models import Feed

TICK_SECONDS = 60

log = logging.getLogger("feedwatch.poller")


def poll_once(conn: store.Connection, now: datetime, *, fetch_xml: Callable[[str], bytes]) -> None:
    """Poll every feed whose interval is up at `now` and store the entries it has not seen.

    A feed that cannot be fetched or is not RSS is logged and waits for its next
    interval. Any other error, a database error included, propagates.
    """
    for feed in store.list_feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            items = parse.parse_items(fetch_xml(feed.url))
        except (FetchFailed, NotRSS) as exc:
            log.warning("skipping %s until its next interval: %s", feed.url, exc)
            items = []
        store.save_poll(conn, feed.id, items=items, polled_at=now)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    conn = store.connect(store.DEFAULT_PATH)
    while True:
        poll_once(conn, datetime.now(UTC), fetch_xml=fetch.fetch_xml)
        time.sleep(TICK_SECONDS)


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled is None or now >= feed.last_polled + timedelta(minutes=feed.every_minutes)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_poller -v`
Expected: PASS (5 tests). The test with the failing feed prints no log noise, because `assertLogs` captures it.

- [ ] **Step 5: Commit**

```bash
git add feedwatch tests
git commit -m "feat: poller stores new entries and skips failing feeds"
```

### Task 6: The command line

**Files:**
- Modify: `feedwatch/errors.py` (append `InvalidArgument`)
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store.unread`, `store.mark_read` and `store.DEFAULT_PATH`, plus `Entry`.
- Produces: `cli.main(argv=None, *, db_path=store.DEFAULT_PATH) -> int`. It returns 0 on success and 1 on a `FeedwatchError`, which it prints to stderr as `feedwatch: <message>`. argparse usage errors exit with 2. `unread` prints one line per entry, `GUID<TAB>YYYY-MM-DD HH:MM (local time)<TAB>FEED<TAB>TITLE`, so a guid can be copied straight into `feedwatch read`. With nothing unread it prints `no unread entries`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import store
from feedwatch.cli import main
from feedwatch.models import Feed, Item

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.db_path = Path(directory.name) / "feeds.db"

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = main(list(argv), db_path=self.db_path)
        return status, out.getvalue(), err.getvalue()

    def feeds(self) -> list[Feed]:
        conn = store.connect(self.db_path)
        self.addCleanup(conn.close)
        return store.list_feeds(conn)

    def stored(self, *guids: str) -> None:
        conn = store.connect(self.db_path)
        self.addCleanup(conn.close)
        feed = store.list_feeds(conn)[0]
        items = [
            Item(guid=guid, link=None, title=f"Title\t{guid}\n", published=NOON + timedelta(hours=index))
            for index, guid in enumerate(guids)
        ]
        store.save_poll(conn, feed.id, items=items, polled_at=NOON)

    def test_add_subscribes_with_the_default_interval(self) -> None:
        status, out, _ = self.run_cli("add", "https://a.org/rss")
        self.assertEqual(status, 0)
        self.assertIn("https://a.org/rss", out)
        [feed] = self.feeds()
        self.assertEqual((feed.url, feed.title, feed.every_minutes), ("https://a.org/rss", None, 30))

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.run_cli("add", "https://a.org/rss", "--title", "A", "--every", "5")
        [feed] = self.feeds()
        self.assertEqual((feed.title, feed.every_minutes), ("A", 5))

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        self.run_cli("add", "https://a.org/rss")
        status, _, err = self.run_cli("add", "https://a.org/rss")
        self.assertEqual(status, 1)
        self.assertIn("https://a.org/rss", err)

    def test_add_refuses_a_url_that_is_not_http(self) -> None:
        for url in ["a.org/rss", "file:///etc/passwd", "https:///rss"]:
            with self.subTest(url=url):
                status, _, err = self.run_cli("add", url)
                self.assertEqual(status, 1)
                self.assertIn(url, err)
        self.assertFalse(self.db_path.exists())

    def test_add_refuses_an_interval_below_one_minute(self) -> None:
        for every in ["0", "-5"]:
            with self.subTest(every=every):
                status, _, err = self.run_cli("add", "https://a.org/rss", "--every", every)
                self.assertEqual(status, 1)
                self.assertIn("--every", err)

    def test_a_non_numeric_interval_is_a_usage_error(self) -> None:
        with self.assertRaises(SystemExit) as caught, redirect_stderr(io.StringIO()):
            main(["add", "https://a.org/rss", "--every", "soon"], db_path=self.db_path)
        self.assertEqual(caught.exception.code, 2)

    def test_unread_lists_newest_first_one_line_each(self) -> None:
        self.run_cli("add", "https://a.org/rss", "--title", "A")
        self.stored("old", "new")
        status, out, _ = self.run_cli("unread")
        self.assertEqual(status, 0)
        lines = out.splitlines()
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[0].startswith("new\t"))
        self.assertTrue(lines[0].endswith("\tA\tTitle new"))
        self.assertTrue(lines[1].startswith("old\t"))

    def test_unread_respects_the_limit(self) -> None:
        self.run_cli("add", "https://a.org/rss")
        self.stored(*[f"g{index}" for index in range(25)])
        self.assertEqual(len(self.run_cli("unread")[1].splitlines()), 20)
        self.assertEqual(len(self.run_cli("unread", "--limit", "3")[1].splitlines()), 3)

    def test_unread_refuses_a_limit_below_one(self) -> None:
        status, _, err = self.run_cli("unread", "--limit", "0")
        self.assertEqual(status, 1)
        self.assertIn("--limit", err)

    def test_unread_says_so_when_there_is_nothing(self) -> None:
        self.assertEqual(self.run_cli("unread")[1], "no unread entries\n")

    def test_read_marks_entries_read(self) -> None:
        self.run_cli("add", "https://a.org/rss")
        self.stored("a", "b", "c")
        status, _, _ = self.run_cli("read", "a", "c")
        self.assertEqual(status, 0)
        self.assertEqual([line.split("\t")[0] for line in self.run_cli("unread")[1].splitlines()], ["b"])

    def test_read_refuses_an_unknown_guid_naming_it(self) -> None:
        self.run_cli("add", "https://a.org/rss")
        self.stored("a")
        status, _, err = self.run_cli("read", "a", "zzz")
        self.assertEqual(status, 1)
        self.assertIn("zzz", err)
        self.assertEqual(len(self.run_cli("unread")[1].splitlines()), 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_cli -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'feedwatch.cli'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/errors.py`:

```python
class InvalidArgument(FeedwatchError):
    """A command-line value is outside what the command accepts."""
```

Create `feedwatch/cli.py`:

```python
import argparse
import sys
from collections.abc import Sequence
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError, InvalidArgument
from feedwatch.models import Entry


def main(argv: Sequence[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
    """Run one feedwatch command and return its exit status."""
    args = _parser().parse_args(argv)
    try:
        args.run(args, db_path)
    except FeedwatchError as exc:
        print(f"feedwatch: {exc}", file=sys.stderr)
        return 1
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Subscribe to RSS feeds and read what they bring.")
    commands = parser.add_subparsers(required=True, metavar="COMMAND")

    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES", help="poll interval (default: 30)")
    add.set_defaults(run=_add)

    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N", help="how many to list (default: 20)")
    unread.set_defaults(run=_unread)

    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    read.set_defaults(run=_read)
    return parser


def _add(args: argparse.Namespace, db_path: Path) -> None:
    url = _http_url(args.url)
    if args.every < 1:
        raise InvalidArgument(f"--every must be at least 1 minute, not {args.every}")
    with closing(store.connect(db_path)) as conn:
        store.add_feed(conn, url, title=args.title, every_minutes=args.every)
    print(f"subscribed to {url}")


def _unread(args: argparse.Namespace, db_path: Path) -> None:
    if args.limit < 1:
        raise InvalidArgument(f"--limit must be at least 1, not {args.limit}")
    with closing(store.connect(db_path)) as conn:
        entries = store.unread(conn, args.limit)
    if not entries:
        print("no unread entries")
    for entry in entries:
        print(_line(entry))


def _read(args: argparse.Namespace, db_path: Path) -> None:
    with closing(store.connect(db_path)) as conn:
        store.mark_read(conn, args.guids)


def _http_url(text: str) -> str:
    # Refused here, a URL the poller could never fetch is never stored to fail every interval.
    scheme, _, rest = text.partition("://")
    if scheme.lower() not in ("http", "https") or not rest.split("/", 1)[0]:
        raise InvalidArgument(f"not an http or https URL: {text}")
    return text


def _line(entry: Entry) -> str:
    # Feed text can hold tabs and newlines; one entry must stay one line.
    title = " ".join((entry.title or "(no title)").split())
    feed = " ".join(entry.feed.split())
    return f"{entry.guid}\t{entry.published.astimezone():%Y-%m-%d %H:%M}\t{feed}\t{title}"


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m unittest tests.test_cli -v`
Expected: PASS (12 tests).

- [ ] **Step 5: Run the whole suite**

Run: `python3 -m unittest -v`
Expected: PASS (45 tests).

- [ ] **Step 6: Commit**

```bash
git add feedwatch tests
git commit -m "feat: feedwatch add, unread and read commands"
```

### Task 7: End-to-end check, program-design check and sweep

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Consumes: everything above.
- Produces: an installed `feedwatch` command that has been verified end to end, and the sweep commit.

- [ ] **Step 1: Ignore build and install output**

Append to `.gitignore`:

```
*.egg-info/
.venv/
```

- [ ] **Step 2: Install the package and drive it against a local feed**

Run these from the repository root. `HOME` is pointed at a temporary directory so the real `~/.feedwatch` is untouched. If `python3 -m venv` fails for lack of `ensurepip`, run `uv venv .venv && uv pip install --python .venv/bin/python -e .` in its place.

```bash
python3 -m venv .venv && .venv/bin/pip install -e .
export HOME=$(mktemp -d) SITE=$(mktemp -d)
printf '<rss><channel><item><guid>g1</guid><title>Hello</title><pubDate>Sun, 01 Mar 2026 10:00:00 GMT</pubDate></item></channel></rss>' > "$SITE/feed.xml"
python3 -m http.server 8765 --directory "$SITE" >/dev/null 2>&1 & SERVER=$!
sleep 1
.venv/bin/feedwatch add http://127.0.0.1:8765/feed.xml --every 1
.venv/bin/feedwatch add http://127.0.0.1:8765/feed.xml; echo "exit $?"
.venv/bin/feedwatch add http://127.0.0.1:8765/missing.xml
timeout 3 .venv/bin/python -m feedwatch.poller
.venv/bin/feedwatch unread
.venv/bin/feedwatch read g1 && .venv/bin/feedwatch unread
.venv/bin/feedwatch read nope; echo "exit $?"
kill $SERVER
```

Expected output, in order:
- `subscribed to http://127.0.0.1:8765/feed.xml`
- `feedwatch: already subscribed to http://127.0.0.1:8765/feed.xml`, then `exit 1`
- `subscribed to http://127.0.0.1:8765/missing.xml`
- one `WARNING skipping http://127.0.0.1:8765/missing.xml until its next interval: could not fetch … HTTP Error 404 …` line from the poller
- `g1<TAB>2026-03-01 HH:MM<TAB>http://127.0.0.1:8765/feed.xml<TAB>Hello`, with the hour in local time
- `no unread entries`
- `feedwatch: no stored entry has guid nope`, then `exit 1`

- [ ] **Step 3: Run the program-design checks over the branch**

Run `git diff master...HEAD -- feedwatch tests`, replacing `master` with the branch this work started from if it differs. Judge every added line against each *Check* in Global Constraints. These greps find the mechanical violations and should print nothing:

```bash
grep -nE "sqlite3|conn\." feedwatch/*.py | grep -v "^feedwatch/store.py"
grep -n "urllib" feedwatch/*.py | grep -v "^feedwatch/fetch.py"
grep -rnE "threading|asyncio|multiprocessing" feedwatch tests
grep -rnE "(import|from) .*\b(cli|poller)\b" feedwatch
grep -rnE "^\s*def " feedwatch tests | grep -v -- "->"
```

Fix any violation in the task's own module, and commit as `fix: <rule> in <module>`.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore build and virtualenv output"
```

- [ ] **Step 5: Sweep**

Load `dopamine:finishing-work` and follow it. It seals the ledger next to this plan, drains it into the living documents listed in `.dopamine/config`, and makes one `sweep:` commit that carries the line counts. `docs/ROADMAP.md` is declared but does not exist, so the sweep reports it absent and does not create it. Do this before `superpowers:finishing-a-development-branch`.
````


## p011

#### Final message

I've written the implementation plan and committed it as `24bdb2f plan: feedwatch v1`. Nothing was implemented in the repo.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

To check the code before committing the plan, I built it in a scratch directory (`/tmp/fw-proto`) and ran it. All 41 tests pass, and an end-to-end run (subscribe, poll, list unread, mark read) worked. One bug turned up that way and is fixed in the plan: a malformed URL crashed fetching instead of raising the project's fetch error.

**Program design.** `docs/PROGRAM-DESIGN.md` exists and already covers every structural choice the plan needed, so I didn't have to stop and ask you anything. Every rule is copied with its check into the plan's Global Constraints. Two places where meeting the rules wasn't obvious:
- Only `store.py` imports `sqlite3`; the poller refers to the connection type through an alias that `store` provides.
- Unreadable feed dates are detected without catching an exception, so the "no `except` outside the poller and CLI" rule holds.

**The 7 tasks:**
1. Package setup, domain types, errors and storing feeds.
2. Storing entries, listing unread ones and marking them read.
3. RSS parsing.
4. Fetching feeds.
5. The poller.
6. The command line, plus an end-to-end run of both processes.
7. Close-out: run the full suite, check the diff against the rules, and run the documentation sweep (`dopamine:finishing-work`).

**Decisions I made where the spec says nothing.** They're listed in the plan so you can override any of them:
- Only RSS 2.0 counts as an RSS feed; RSS 1.0 is refused like Atom.
- An entry with a missing or unreadable date gets the time it was first stored.
- `read GUID` marks that guid in every feed that has it. If any guid is unknown, the command names each unknown one and marks nothing.
- `unread` prints one tab-separated line per entry: guid, date, feed title, entry title.
- XML is parsed with the standard library rather than `defusedxml`, per the "standard library first" principle. A security warning recommended `defusedxml`; the plan records why the standard parser is enough here.

The plan's Review Focus lists five risky inputs the spec doesn't mention: the same item twice in one feed, bad dates, a `read` mixing known and unknown guids, an item with neither guid nor link, and a zero or negative `--every`/`--limit`. Each has a test in the task that owns it.

I didn't run the documentation sweep now, because writing a plan leaves nothing for it to record. It's the last step of Task 7 instead. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist; the plan notes that for the sweep.

Please review the plan and tell me whether it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line that subscribes to feeds, lists unread entries and marks them read.

**Architecture:** Five components as `docs/ARCHITECTURE.md` names them — `fetch` (HTTP), `parse` (RSS XML to entries), `store` (SQLite, module functions taking a `conn`), `poller` (the schedule, `python -m feedwatch.poller`) and `cli` (`feedwatch add|unread|read`) — plus two type-only modules, `models` (frozen dataclasses) and `errors` (the `FeedwatchError` hierarchy). The poller runs one tick per minute in one thread: it lists feeds, polls those whose interval is up, and records the poll time whether or not the poll succeeded, so a failing feed waits for its next interval.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`), tests with `unittest`, packaging with a `pyproject.toml` on setuptools.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`

## Global Constraints

From the spec and `docs/DESIGN.md`:

- Python 3.11, standard library. "Standard library first; a dependency has to earn its place." — no runtime dependencies; tests use `unittest`, not pytest.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`; the interval defaults to 30 minutes. Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries, newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores the entries it has not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- One SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`, opened by both processes.
- Out of scope: Atom feeds; importing or exporting subscription lists.

From `docs/PROGRAM-DESIGN.md` — every rule with its check; reviewers apply each check to every task's diff:

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan meets them, where it is not obvious:

- `poller` and the tests annotate connections as `store.Connection` (an alias in `store.py`), so no module but `store` imports `sqlite3`.
- v1 polls feeds one after another in the poller's thread; `fetch` has a 30-second timeout, which bounds how long one dead feed holds up the rest. No executor is needed yet.
- `parse._published` and `parse._text` return `None` for "the item has no such value", which `ParsedEntry` models as absent — an answer, not a failure. Unreadable dates are detected with `email.utils.parsedate_tz`, which returns `None` instead of raising, so `parse` needs no `except` beyond its XML one.
- The CLI refuses a non-positive `--every` or `--limit` with `parser.error`, which exits with status 2 without the code raising anything itself.

Decisions this plan makes where the spec is silent:

- Only RSS 2.0 (`<rss><channel>`) is an RSS feed. RSS 1.0 (`<rdf:RDF>`) is refused like Atom.
- XML is parsed with the standard library's `xml.etree.ElementTree`, not `defusedxml`: ElementTree does not resolve external entities, and the expat bundled with Python 3.11+ limits entity expansion, which covers XXE and billion-laughs for a single-user tool without adding a dependency.
- An entry with no `pubDate`, or one that cannot be read, is dated when it is first stored; dates are stored in UTC and shown in local time.
- `read GUID` marks every stored entry with that guid, in whichever feeds hold it. If any guid is unknown, the command names every unknown one and marks none.
- `unread` prints one tab-separated line per entry: guid, published time, feed title (its URL when it has no title), entry title. With nothing unread it prints `no unread entries`.

During execution, do not edit `docs/DESIGN.md`, `docs/ARCHITECTURE.md` or `docs/PROGRAM-DESIGN.md`: record anything they should learn in the ledger, and Task 7's sweep places it.

## Review Focus

- **The same item twice in one document**, or a feed that republishes every old item on each poll: each entry is stored once (Task 2 `test_a_guid_repeated_within_one_document_is_stored_once`, Task 5 `test_entries_seen_again_are_stored_once`).
- **A `pubDate` that is missing, unreadable, has no offset, or names an absurd year**: the entry is still stored, dated when first seen, and neither the feed nor the poller fails (Task 3 `test_a_missing_or_unreadable_date_leaves_the_entry_undated`, `test_a_date_without_an_offset_is_utc`; Task 2 `test_an_undated_entry_is_dated_when_first_seen`).
- **`read` with known and unknown guids mixed**: refused, naming every unknown guid, and nothing marked (Task 2 `test_unknown_guids_are_refused_by_name_and_nothing_is_marked`, Task 6 `test_unknown_guids_are_refused_by_name_and_none_is_marked`).
- **An item with neither a guid nor a link**: left out, and the feed's other items are still stored (Task 3 `test_an_item_with_neither_guid_nor_link_is_left_out`).
- **`--every 0`, `--every -5` or `--limit 0`**: refused with a message naming the option, and nothing stored (Task 6 `test_an_interval_below_one_minute_is_refused`, `test_a_limit_below_one_is_refused`).

---

## File Structure

- `pyproject.toml` — package metadata; the `feedwatch` console script points at `feedwatch.cli:main`.
- `feedwatch/__init__.py` — empty.
- `feedwatch/models.py` — `Feed`, `ParsedEntry`, `Entry` frozen dataclasses.
- `feedwatch/errors.py` — `FeedwatchError` and its subclasses `FetchError`, `ParseError`, `DuplicateFeedError`, `UnknownEntryError`.
- `feedwatch/store.py` — the schema (`SCHEMA_STEPS`), `connect`, and every read and write of `feeds` and `entries`.
- `feedwatch/parse.py` — `parse(document)`: RSS 2.0 bytes to `list[ParsedEntry]`.
- `feedwatch/fetch.py` — `fetch(url)`: URL to bytes.
- `feedwatch/poller.py` — `poll_once` and the `main` loop run by `python -m feedwatch.poller`.
- `feedwatch/cli.py` — `main(argv)`: the `add`, `unread` and `read` commands.
- `tests/test_store.py`, `tests/test_parse.py`, `tests/test_fetch.py`, `tests/test_poller.py`, `tests/test_cli.py` — one test module per component.

Run every test with `python3 -m unittest discover -s tests -v` from the repository root; one module with `python3 -m unittest discover -s tests -p test_store.py -v`.

---

### Task 1: Package, types and feed storage

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py` (empty), `feedwatch/models.py`, `feedwatch/errors.py`, `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)`
  - `models.ParsedEntry(guid: str, title: str, link: str | None, published: datetime | None)`
  - `models.Entry(guid: str, feed_title: str, title: str, link: str | None, published: datetime)`
  - `errors.FeedwatchError`, `errors.FetchError`, `errors.ParseError`, `errors.DuplicateFeedError(url: str)` with `.url`, `errors.UnknownEntryError(guids: list[str])` with `.guids`
  - `store.Connection` (alias of `sqlite3.Connection`), `store.DEFAULT_PATH: Path`, `store.SCHEMA_STEPS: list[str]`
  - `store.connect(path: Path) -> Connection`
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed`
  - `store.list_feeds(conn: Connection) -> list[Feed]`
  - `store.mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None`

- [ ] **Step 1: Write the failing tests**

`tests/test_store.py`:

```python
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

from feedwatch import store
from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / "home" / ".feedwatch" / "feeds.db"
        self.conn = self.open()

    def open(self) -> store.Connection:
        conn = store.connect(self.path)
        self.addCleanup(conn.close)
        return conn


class FeedsTest(StoreTestCase):
    def test_connect_creates_the_missing_directory(self) -> None:
        self.assertTrue(self.path.exists())

    def test_added_feed_is_listed(self) -> None:
        feed = store.add_feed(self.conn, "http://a.example/rss", title="A", every_minutes=30)
        self.assertEqual(
            Feed(id=feed.id, url="http://a.example/rss", title="A", every_minutes=30, last_polled_at=None),
            feed,
        )
        self.assertEqual([feed], store.list_feeds(self.conn))

    def test_reconnecting_keeps_existing_data(self) -> None:
        feed = store.add_feed(self.conn, "http://a.example/rss", title=None, every_minutes=5)
        self.conn.close()
        self.assertEqual([feed], store.list_feeds(self.open()))

    def test_subscribing_twice_is_refused_naming_the_url(self) -> None:
        store.add_feed(self.conn, "http://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(DuplicateFeedError) as raised:
            store.add_feed(self.conn, "http://a.example/rss", title="again", every_minutes=10)
        self.assertIn("http://a.example/rss", str(raised.exception))
        self.assertEqual(1, len(store.list_feeds(self.conn)))

    def test_mark_polled_records_the_time(self) -> None:
        feed = store.add_feed(self.conn, "http://a.example/rss", title=None, every_minutes=30)
        store.mark_polled(self.conn, feed.id, at=NOW)
        self.assertEqual(NOW, store.list_feeds(self.conn)[0].last_polled_at)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_store.py -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch'`.

- [ ] **Step 3: Write the package, the types and the feed half of the store**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py`: an empty file.

`feedwatch/models.py`:

```python
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None


@dataclass(frozen=True)
class ParsedEntry:
    """An RSS item as its feed published it, before it is stored.

    ``guid`` is the item's guid, or its link when it has none.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None


@dataclass(frozen=True)
class Entry:
    """A stored entry, as the command line lists it."""

    guid: str
    feed_title: str
    title: str
    link: str | None
    published: datetime
```

`feedwatch/errors.py`:

```python
class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class FetchError(FeedwatchError):
    """A feed's URL could not be downloaded."""


class ParseError(FeedwatchError):
    """A downloaded document is not an RSS feed."""


class DuplicateFeedError(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url


class UnknownEntryError(FeedwatchError):
    def __init__(self, guids: list[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = guids
```

`feedwatch/store.py`:

```python
import sqlite3
from datetime import UTC, datetime
from pathlib import Path

from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Append only, never edit: an existing database has already run every step
# here, and an edited step would never reach it.
SCHEMA_STEPS: list[str] = [
    """
    CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled_at TEXT
    )
    """,
]


def connect(path: Path) -> Connection:
    """Open the database at ``path``, creating it and its directory if needed,
    and apply every schema step."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and the CLI open the same file; wait for the other's write
    # instead of failing at once with "database is locked".
    conn = sqlite3.connect(path, timeout=10)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(
    conn: Connection, url: str, *, title: str | None, every_minutes: int
) -> Feed:
    """Subscribe to ``url``. Raises DuplicateFeedError if already subscribed."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise DuplicateFeedError(url) from error
    return Feed(
        id=cursor.lastrowid,
        url=url,
        title=title,
        every_minutes=every_minutes,
        last_polled_at=None,
    )


def list_feeds(conn: Connection) -> list[Feed]:
    rows = conn.execute(
        "SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id"
    ).fetchall()
    return [
        Feed(
            id=row[0],
            url=row[1],
            title=row[2],
            every_minutes=row[3],
            last_polled_at=None if row[4] is None else datetime.fromisoformat(row[4]),
        )
        for row in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    with conn:
        conn.execute(
            "UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(at), feed_id)
        )


def _to_text(moment: datetime) -> str:
    # One fixed format in UTC, so ORDER BY on the text is chronological.
    return moment.astimezone(UTC).isoformat(timespec="seconds")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_store.py -v`
Expected: 5 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add pyproject.toml feedwatch/__init__.py feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store.py
git commit -m "feat: package, domain types and feed storage"
```

---

### Task 2: Entry storage

**Files:**
- Modify: `feedwatch/store.py` (append to `SCHEMA_STEPS`; add `add_entries`, `unread`, `mark_read`; extend imports)
- Test: `tests/test_store.py` (append `EntriesTest`; extend imports)

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store._to_text`, `models.ParsedEntry`, `models.Entry`, `errors.UnknownEntryError` from Task 1.
- Produces:
  - `store.add_entries(conn: Connection, feed_id: int, *, entries: list[ParsedEntry], seen_at: datetime) -> int` — the number newly stored; an entry whose `published` is `None` is dated `seen_at`.
  - `store.unread(conn: Connection, limit: int) -> list[Entry]` — newest first.
  - `store.mark_read(conn: Connection, guids: list[str]) -> None` — raises `UnknownEntryError` naming every unknown guid, and then marks none.

- [ ] **Step 1: Write the failing tests**

In `tests/test_store.py`, change the imports at the top to:

```python
import tempfile
import unittest
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Feed, ParsedEntry
```

and insert this above the closing `if __name__ == "__main__":` block:

```python
def entry(guid: str, published: datetime | None = None) -> ParsedEntry:
    return ParsedEntry(guid=guid, title=f"title {guid}", link=f"http://a.example/{guid}", published=published)


class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, "http://a.example/rss", title="A", every_minutes=30)

    def guids(self) -> list[str]:
        return [e.guid for e in store.unread(self.conn, 100)]

    def test_an_entry_seen_again_is_stored_once(self) -> None:
        first = store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW)], seen_at=NOW)
        again = store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW), entry("g2", NOW)], seen_at=NOW)
        self.assertEqual((1, 1), (first, again))
        self.assertCountEqual(["g1", "g2"], self.guids())

    def test_a_guid_repeated_within_one_document_is_stored_once(self) -> None:
        added = store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW), entry("g1", NOW)], seen_at=NOW)
        self.assertEqual(1, added)
        self.assertEqual(["g1"], self.guids())

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        other = store.add_feed(self.conn, "http://b.example/rss", title=None, every_minutes=30)
        store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW)], seen_at=NOW)
        store.add_entries(self.conn, other.id, entries=[entry("g1", NOW)], seen_at=NOW)
        titles = [e.feed_title for e in store.unread(self.conn, 100)]
        self.assertCountEqual(["A", "http://b.example/rss"], titles)

    def test_an_undated_entry_is_dated_when_first_seen(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("g1")], seen_at=NOW)
        self.assertEqual(NOW, store.unread(self.conn, 1)[0].published)

    def test_unread_is_newest_first_and_limited(self) -> None:
        dated = [entry(f"g{i}", NOW + timedelta(hours=i)) for i in range(5)]
        store.add_entries(self.conn, self.feed.id, entries=dated, seen_at=NOW)
        self.assertEqual(["g4", "g3", "g2"], [e.guid for e in store.unread(self.conn, 3)])

    def test_dates_in_other_offsets_order_by_instant(self) -> None:
        plus_two = timezone(timedelta(hours=2))
        early = entry("early", datetime(2026, 3, 1, 13, 0, tzinfo=plus_two))
        late = entry("late", datetime(2026, 3, 1, 12, 0, tzinfo=UTC))
        store.add_entries(self.conn, self.feed.id, entries=[early, late], seen_at=NOW)
        self.assertEqual(["late", "early"], self.guids())

    def test_marked_entries_leave_the_unread_list(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW), entry("g2", NOW)], seen_at=NOW)
        store.mark_read(self.conn, ["g1"])
        store.mark_read(self.conn, ["g1"])
        self.assertEqual(["g2"], self.guids())

    def test_unknown_guids_are_refused_by_name_and_nothing_is_marked(self) -> None:
        store.add_entries(self.conn, self.feed.id, entries=[entry("g1", NOW)], seen_at=NOW)
        with self.assertRaises(UnknownEntryError) as raised:
            store.mark_read(self.conn, ["g1", "nope", "gone"])
        self.assertEqual(["nope", "gone"], raised.exception.guids)
        self.assertIn("nope", str(raised.exception))
        self.assertIn("gone", str(raised.exception))
        self.assertEqual(["g1"], self.guids())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_store.py -v`
Expected: the 8 `EntriesTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'`; the 5 `FeedsTest` tests still pass.

- [ ] **Step 3: Implement entry storage**

In `feedwatch/store.py`, change the imports to:

```python
from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Entry, Feed, ParsedEntry
```

Append three steps to the end of `SCHEMA_STEPS`, after the `feeds` step, leaving that step unchanged:

```python
    """
    CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )
    """,
    "CREATE INDEX IF NOT EXISTS entries_by_guid ON entries (guid)",
    "CREATE INDEX IF NOT EXISTS entries_unread ON entries (read, published)",
```

Add these functions after `mark_polled`, above `_to_text`:

```python
def add_entries(
    conn: Connection,
    feed_id: int,
    *,
    entries: list[ParsedEntry],
    seen_at: datetime,
) -> int:
    """Store the entries this feed has not stored before; return how many.

    An entry with no publication date is dated ``seen_at``.
    """
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published)"
            " VALUES (?, ?, ?, ?, ?)",
            [
                (feed_id, e.guid, e.title, e.link, _to_text(e.published or seen_at))
                for e in entries
            ],
        )
        return conn.total_changes - before


def unread(conn: Connection, limit: int) -> list[Entry]:
    """Return up to ``limit`` unread entries, newest first."""
    rows = conn.execute(
        """
        SELECT e.guid, COALESCE(f.title, f.url), e.title, e.link, e.published
        FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id
        WHERE e.read = 0
        ORDER BY e.published DESC, e.id DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [
        Entry(
            guid=row[0],
            feed_title=row[1],
            title=row[2],
            link=row[3],
            published=datetime.fromisoformat(row[4]),
        )
        for row in rows
    ]


def mark_read(conn: Connection, guids: list[str]) -> None:
    """Mark every entry with one of ``guids`` read, in every feed.

    Raises UnknownEntryError naming each guid that is not stored, and then
    marks none.
    """
    with conn:
        unknown = [
            guid
            for guid in dict.fromkeys(guids)
            if conn.execute(
                "SELECT 1 FROM entries WHERE guid = ? LIMIT 1", (guid,)
            ).fetchone()
            is None
        ]
        if unknown:
            raise UnknownEntryError(unknown)
        conn.executemany(
            "UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids]
        )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_store.py -v`
Expected: 13 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once, list unread newest first, mark read"
```

---

### Task 3: RSS parsing

**Files:**
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: `models.ParsedEntry`, `errors.ParseError` from Task 1.
- Produces: `parse.parse(document: bytes) -> list[ParsedEntry]` — raises `ParseError` when the document is not well-formed XML or not RSS 2.0. Every `published` it returns is timezone-aware, or `None`.

- [ ] **Step 1: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import UTC, datetime

from feedwatch.errors import ParseError
from feedwatch.models import ParsedEntry
from feedwatch.parse import parse


def rss(*items: str) -> bytes:
    return (
        '<?xml version="1.0"?><rss version="2.0"><channel><title>A</title>'
        + "".join(f"<item>{item}</item>" for item in items)
        + "</channel></rss>"
    ).encode()


class ParseTest(unittest.TestCase):
    def test_an_item_with_a_guid(self) -> None:
        document = rss(
            "<guid> g1 </guid><title>First</title><link>http://a.example/1</link>"
            "<pubDate>Sun, 01 Mar 2026 09:00:00 +0100</pubDate>"
        )
        self.assertEqual(
            [
                ParsedEntry(
                    guid="g1",
                    title="First",
                    link="http://a.example/1",
                    published=datetime(2026, 3, 1, 8, 0, tzinfo=UTC),
                )
            ],
            parse(document),
        )

    def test_an_item_without_a_guid_is_identified_by_its_link(self) -> None:
        [entry] = parse(rss("<title>T</title><link>http://a.example/2</link>"))
        self.assertEqual("http://a.example/2", entry.guid)

    def test_an_item_with_neither_guid_nor_link_is_left_out(self) -> None:
        entries = parse(rss("<title>Nothing to know it by</title>", "<guid>g2</guid>"))
        self.assertEqual(["g2"], [e.guid for e in entries])

    def test_a_missing_title_is_empty(self) -> None:
        [entry] = parse(rss("<guid>g1</guid>"))
        self.assertEqual("", entry.title)

    def test_a_date_without_an_offset_is_utc(self) -> None:
        [entry] = parse(rss("<guid>g1</guid><pubDate>Sun, 01 Mar 2026 09:00:00 -0000</pubDate>"))
        self.assertEqual(datetime(2026, 3, 1, 9, 0, tzinfo=UTC), entry.published)

    def test_a_missing_or_unreadable_date_leaves_the_entry_undated(self) -> None:
        entries = parse(
            rss(
                "<guid>none</guid>",
                "<guid>words</guid><pubDate>yesterday</pubDate>",
                "<guid>far</guid><pubDate>Sun, 01 Mar 99999999 09:00:00 GMT</pubDate>",
            )
        )
        self.assertEqual([None, None, None], [e.published for e in entries])

    def test_a_channel_without_items_has_no_entries(self) -> None:
        self.assertEqual([], parse(rss()))

    def test_malformed_xml_is_refused(self) -> None:
        for document in [b"", b"<rss><channel>", b"not xml at all"]:
            with self.subTest(document=document), self.assertRaises(ParseError):
                parse(document)

    def test_xml_that_is_not_rss_is_refused(self) -> None:
        atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><title>A</title></feed>'
        for document in [atom, b"<rss/>", b"<html><body/></html>"]:
            with self.subTest(document=document), self.assertRaises(ParseError):
                parse(document)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_parse.py -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 3: Implement the parser**

`feedwatch/parse.py`:

```python
import calendar
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from email.utils import parsedate_tz

from feedwatch.errors import ParseError
from feedwatch.models import ParsedEntry


def parse(document: bytes) -> list[ParsedEntry]:
    """Return the items of an RSS 2.0 document, in document order.

    An item with neither a guid nor a link is left out, since nothing
    identifies it. Raises ParseError when ``document`` is not well-formed XML
    or not an RSS feed.
    """
    try:
        root = ET.fromstring(document)
    except ET.ParseError as error:
        raise ParseError(f"not well-formed XML: {error}") from error
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise ParseError(f"not an RSS feed: the root element is <{root.tag}>")
    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            ParsedEntry(
                guid=guid,
                title=_text(item, "title") or "",
                link=link,
                published=_published(_text(item, "pubDate")),
            )
        )
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    return (item.findtext(tag) or "").strip() or None


def _published(text: str | None) -> datetime | None:
    # An unreadable date leaves the entry undated rather than failing the feed.
    parts = parsedate_tz(text or "")
    # Outside these years the UTC conversion below overflows datetime.
    if parts is None or not 2 <= parts[0] <= 9998:
        return None
    # timegm, not mktime: a date without an offset is UTC, not local time.
    timestamp = calendar.timegm(parts[:9]) - (parts[9] or 0)
    return datetime.fromtimestamp(timestamp, UTC)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_parse.py -v`
Expected: 9 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS 2.0 items into entries"
```

---

### Task 4: Fetching

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `errors.FetchError` from Task 1.
- Produces: `fetch.fetch(url: str) -> bytes` — raises `FetchError` whose message names the URL; `fetch.TIMEOUT_SECONDS = 30`.

- [ ] **Step 1: Write the failing tests**

`tests/test_fetch.py` (it uses `file://` URLs, which `urllib` serves without a network or a server thread):

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch


class FetchTest(unittest.TestCase):
    def test_returns_the_body(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "feed.xml"
            path.write_bytes(b"<rss/>")
            self.assertEqual(b"<rss/>", fetch(path.as_uri()))

    def test_an_unreachable_url_raises_fetch_error_naming_it(self) -> None:
        url = Path("/nonexistent/feedwatch/feed.xml").as_uri()
        with self.assertRaises(FetchError) as raised:
            fetch(url)
        self.assertIn(url, str(raised.exception))

    def test_a_malformed_url_raises_fetch_error(self) -> None:
        for url in ["not a url", "gopher://a.example/feed", ""]:
            with self.subTest(url=url), self.assertRaises(FetchError):
                fetch(url)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_fetch.py -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 3: Implement fetch**

`feedwatch/fetch.py` — the `Request` is built inside the `try` because its constructor is what raises `ValueError` for a malformed URL:

```python
import http.client
import urllib.request

from feedwatch.errors import FetchError

TIMEOUT_SECONDS = 30


def fetch(url: str) -> bytes:
    """Download ``url`` and return the response body.

    Raises FetchError when the URL is malformed, unreachable or answers with
    an HTTP error status, or when it does not answer within TIMEOUT_SECONDS.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1"})
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as error:
        raise FetchError(f"{url}: {error}") from error
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_fetch.py -v`
Expected: 3 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch a feed's document, failing with FetchError"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.Connection`, `store.connect`, `store.DEFAULT_PATH`, `store.list_feeds`, `store.add_entries`, `store.mark_polled`, `store.unread`, `store.add_feed` (Tasks 1–2); `parse.parse` (Task 3); `fetch.fetch` (Task 4); `errors.FetchError`, `errors.ParseError`, `models.Feed`.
- Produces:
  - `poller.poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> None` — `fetch_feed` is passed in so tests supply documents without a network.
  - `poller.main() -> None`, run by `python -m feedwatch.poller`; logs to the `feedwatch.poller` logger.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchError
from feedwatch.poller import poll_once

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)
A = "http://a.example/rss"
B = "http://b.example/rss"


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid><title>{guid}</title></item>" for guid in guids)
    return f"<rss><channel>{items}</channel></rss>".encode()


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.conn = store.connect(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.conn.close)
        self.documents: dict[str, bytes] = {}
        self.fetched: list[str] = []

    def fake_fetch(self, url: str) -> bytes:
        self.fetched.append(url)
        if url not in self.documents:
            raise FetchError(f"{url}: unreachable")
        return self.documents[url]

    def poll(self, at: datetime) -> None:
        poll_once(self.conn, at, fetch_feed=self.fake_fetch)

    def unread(self) -> list[str]:
        return [e.guid for e in store.unread(self.conn, 100)]

    def test_a_feed_never_polled_is_polled_at_once(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        self.documents[A] = rss("a1", "a2")
        self.poll(NOW)
        self.assertEqual([A], self.fetched)
        self.assertCountEqual(["a1", "a2"], self.unread())

    def test_a_feed_waits_for_its_interval(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        self.documents[A] = rss("a1")
        self.poll(NOW)
        self.poll(NOW + timedelta(minutes=29))
        self.assertEqual([A], self.fetched)
        self.poll(NOW + timedelta(minutes=30))
        self.assertEqual([A, A], self.fetched)

    def test_each_feed_keeps_its_own_interval(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=5)
        store.add_feed(self.conn, B, title=None, every_minutes=60)
        self.documents.update({A: rss("a1"), B: rss("b1")})
        self.poll(NOW)
        self.poll(NOW + timedelta(minutes=5))
        self.assertEqual([A, B, A], self.fetched)

    def test_entries_seen_again_are_stored_once(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        self.documents[A] = rss("a1")
        self.poll(NOW)
        self.documents[A] = rss("a2", "a1")
        self.poll(NOW + timedelta(minutes=30))
        self.assertCountEqual(["a1", "a2"], self.unread())

    def test_a_feed_that_cannot_be_fetched_is_logged_and_skipped(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        store.add_feed(self.conn, B, title=None, every_minutes=30)
        self.documents[B] = rss("b1")
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            self.poll(NOW)
        self.assertIn(A, logs.output[0])
        self.assertEqual(["b1"], self.unread())
        self.poll(NOW + timedelta(minutes=1))
        self.assertEqual([A, B], self.fetched)

    def test_a_document_that_is_not_rss_is_logged_and_skipped(self) -> None:
        store.add_feed(self.conn, A, title=None, every_minutes=30)
        store.add_feed(self.conn, B, title=None, every_minutes=30)
        self.documents.update({A: b"<html><body>moved</body></html>", B: rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            self.poll(NOW)
        self.assertIn(A, logs.output[0])
        self.assertEqual(["b1"], self.unread())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_poller.py -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Implement the poller**

`feedwatch/poller.py`:

```python
import logging
import time
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from feedwatch import fetch, parse, store
from feedwatch.errors import FetchError, ParseError
from feedwatch.models import Feed

log = logging.getLogger("feedwatch.poller")

TICK_SECONDS = 60


def poll_once(
    conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]
) -> None:
    """Poll every feed whose interval is up at ``now`` and store the entries
    it has not stored before.

    A feed that cannot be fetched or parsed is logged and waits for its next
    interval. A database error propagates and stops the poller.
    """
    for feed in store.list_feeds(conn):
        if not _due(feed, now):
            continue
        try:
            entries = parse.parse(fetch_feed(feed.url))
        except (FetchError, ParseError) as error:
            log.warning("skipping %s until its next interval: %s", feed.url, error)
        else:
            added = store.add_entries(conn, feed.id, entries=entries, seen_at=now)
            log.info("%s: %d new entries", feed.url, added)
        store.mark_polled(conn, feed.id, at=now)


def _due(feed: Feed, now: datetime) -> bool:
    if feed.last_polled_at is None:
        return True
    return now - feed.last_polled_at >= timedelta(minutes=feed.every_minutes)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    conn = store.connect(store.DEFAULT_PATH)
    while True:
        poll_once(conn, datetime.now(UTC), fetch_feed=fetch.fetch)
        time.sleep(TICK_SECONDS)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_poller.py -v`
Expected: 6 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller polls due feeds and skips failing ones"
```

---

### Task 6: The command line

**Files:**
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.DEFAULT_PATH`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.list_feeds`, `store.add_entries` (Tasks 1–2); `errors.FeedwatchError`; `models.Entry`, `models.ParsedEntry`.
- Produces: `cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int` — exit status 0 on success, 1 when a `FeedwatchError` was reported on stderr as `feedwatch: <message>`; argparse refusals exit with status 2. `pyproject.toml`'s `feedwatch` script calls it.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import UTC, datetime, timedelta
from pathlib import Path

from feedwatch import cli, store
from feedwatch.models import ParsedEntry

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / ".feedwatch" / "feeds.db"
        self.conn = store.connect(self.path)
        self.addCleanup(self.conn.close)

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = cli.main(list(argv), db_path=self.path)
        return status, out.getvalue(), err.getvalue()

    def refused_by_argparse(self, *argv: str) -> str:
        err = io.StringIO()
        with redirect_stderr(err), self.assertRaises(SystemExit) as raised:
            cli.main(list(argv), db_path=self.path)
        self.assertEqual(2, raised.exception.code)
        return err.getvalue()

    def seed(self, count: int) -> None:
        feed = store.add_feed(self.conn, "http://a.example/rss", title="A", every_minutes=30)
        entries = [
            ParsedEntry(guid=f"g{i}", title=f"entry {i}", link=None, published=NOW + timedelta(hours=i))
            for i in range(count)
        ]
        store.add_entries(self.conn, feed.id, entries=entries, seen_at=NOW)

    def unread_guids(self, *argv: str) -> list[str]:
        status, out, _ = self.run_cli("unread", *argv)
        self.assertEqual(0, status)
        return [line.split("\t")[0] for line in out.splitlines()]

    def test_add_defaults_to_thirty_minutes_and_no_title(self) -> None:
        status, out, _ = self.run_cli("add", "http://a.example/rss")
        self.assertEqual(0, status)
        self.assertIn("http://a.example/rss", out)
        [feed] = store.list_feeds(self.conn)
        self.assertEqual((None, 30), (feed.title, feed.every_minutes))

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.run_cli("add", "http://a.example/rss", "--title", "A", "--every", "5")
        [feed] = store.list_feeds(self.conn)
        self.assertEqual(("A", 5), (feed.title, feed.every_minutes))

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        self.run_cli("add", "http://a.example/rss")
        status, _, err = self.run_cli("add", "http://a.example/rss")
        self.assertEqual(1, status)
        self.assertIn("http://a.example/rss", err)

    def test_an_interval_below_one_minute_is_refused(self) -> None:
        for every in ["0", "-5"]:
            with self.subTest(every=every):
                err = self.refused_by_argparse("add", "http://a.example/rss", "--every", every)
                self.assertIn("--every", err)
        self.assertEqual([], store.list_feeds(self.conn))

    def test_unread_lists_twenty_newest_first(self) -> None:
        self.seed(25)
        guids = self.unread_guids()
        self.assertEqual(20, len(guids))
        self.assertEqual(["g24", "g23", "g22"], guids[:3])

    def test_unread_takes_a_limit(self) -> None:
        self.seed(5)
        self.assertEqual(["g4", "g3"], self.unread_guids("--limit", "2"))

    def test_a_limit_below_one_is_refused(self) -> None:
        self.assertIn("--limit", self.refused_by_argparse("unread", "--limit", "0"))

    def test_unread_says_when_there_is_nothing(self) -> None:
        status, out, _ = self.run_cli("unread")
        self.assertEqual((0, "no unread entries\n"), (status, out))

    def test_read_marks_entries(self) -> None:
        self.seed(3)
        status, _, _ = self.run_cli("read", "g0", "g2")
        self.assertEqual(0, status)
        self.assertEqual(["g1"], self.unread_guids())

    def test_unknown_guids_are_refused_by_name_and_none_is_marked(self) -> None:
        self.seed(1)
        status, _, err = self.run_cli("read", "g0", "nope", "gone")
        self.assertEqual(1, status)
        self.assertIn("nope", err)
        self.assertIn("gone", err)
        self.assertEqual(["g0"], self.unread_guids())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s tests -p test_cli.py -v`
Expected: ERROR — `ImportError: cannot import name 'cli' from 'feedwatch'`.

- [ ] **Step 3: Implement the command line**

`feedwatch/cli.py`:

```python
import argparse
import sys
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import Entry


def main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
    """Run one feedwatch command and return the process exit status."""
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")
    conn = store.connect(db_path)
    try:
        if args.command == "add":
            feed = store.add_feed(
                conn, args.url, title=args.title, every_minutes=args.every
            )
            print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes")
        elif args.command == "unread":
            entries = store.unread(conn, args.limit)
            for entry in entries:
                print(_line(entry))
            if not entries:
                print("no unread entries")
        else:
            store.mark_read(conn, args.guids)
            print("marked read: " + ", ".join(dict.fromkeys(args.guids)))
    except FeedwatchError as error:
        print(f"feedwatch: {error}", file=sys.stderr)
        return 1
    finally:
        conn.close()
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", metavar="URL")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _line(entry: Entry) -> str:
    published = entry.published.astimezone().strftime("%Y-%m-%d %H:%M")
    return "\t".join(
        [entry.guid, published, entry.feed_title, entry.title or "(untitled)"]
    )


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -p test_cli.py -v`
Expected: 10 tests, OK.

- [ ] **Step 5: Run the whole suite and the two processes end to end**

Run: `python3 -m unittest discover -s tests -v`
Expected: 41 tests, OK.

Then, from the repository root, against a throwaway home directory and a `file://` feed:

```bash
export HOME=$(mktemp -d)
printf '<rss><channel><item><guid>x1</guid><title>Hello</title></item></channel></rss>' > "$HOME/feed.xml"
python3 -m feedwatch.cli add "file://$HOME/feed.xml" --title Local
timeout 5 python3 -m feedwatch.poller; echo "poller exit $?"
python3 -m feedwatch.cli unread
python3 -m feedwatch.cli read x1 && python3 -m feedwatch.cli unread
python3 -m feedwatch.cli read zz; echo "exit $?"
```

Expected, in order: `subscribed to file:///…/feed.xml, polled every 30 minutes`; a log line ending `: 1 new entries`; `poller exit 124` (killed by `timeout` while sleeping, as intended); a line `x1<TAB><date><TAB>Local<TAB>Hello`; `marked read: x1`; `no unread entries`; `feedwatch: no stored entry with guid zz`; `exit 1`. Open a new shell afterwards so `HOME` is restored.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```

---

### Task 7: Close the work

**Files:** none of the code; the sweep decides which documents it touches.

- [ ] **Step 1: Run the whole suite once more**

Run: `python3 -m unittest discover -s tests -v`
Expected: 41 tests, OK.

- [ ] **Step 2: Check the diff against the Global Constraints**

Run: `git diff $(git merge-base HEAD master)...HEAD -- feedwatch | grep -nE '^\+.*(sqlite3|urllib|threading|asyncio|multiprocessing|except |import .*(cli|poller))'`
Expected: `sqlite3` only in `feedwatch/store.py`; `urllib` only in `feedwatch/fetch.py`; no `threading`, `asyncio` or `multiprocessing`; `except` only in `store.py`, `parse.py` and `fetch.py` (each turning a library exception into a `FeedwatchError`) and in `poller.py` and `cli.py`; no import of `cli` or `poller`.

- [ ] **Step 3: Sweep**

Invoke `dopamine:finishing-work`, before `superpowers:finishing-a-development-branch` and before the workspace is cleaned up. It seals the ledger beside this plan, drains it into the living documents and commits `sweep: 2026-10-12-feedwatch-v1 — …`. Note for it: `docs/ROADMAP.md` is declared in `.dopamine/config` and does not exist.
````


## p012

#### Final message

I wrote the feedwatch v1 implementation plan and committed it as `8f92e12`. Nothing was implemented in the repository.

**Plan:** `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

It has six test-first tasks, built from the bottom up:
1. Package skeleton and `parse` (RSS 2.0 into `Item`s)
2. `fetch`
3. `store`: the database and its feeds
4. `store`: entries
5. `poller`
6. `cli`, then a check of the whole package against `PROGRAM-DESIGN.md` and an end-to-end run

The code is tested. I built all of it outside the repository first. On Python 3.14 the 46 tests pass, the rule checks find nothing, and an end-to-end run works: add, refuse a duplicate, poll, list unread, mark read, refuse an unknown guid. Task 3's in-between state also passes on its own. The `feedwatch` command installs and runs.

**Global Constraints** list the spec's requirements and every `PROGRAM-DESIGN.md` rule word for word, each with its check. `PROGRAM-DESIGN.md` left no structural choice open, so I didn't stop to ask you anything. Some choices I made within the rules, which you may want to look at:
- **Tests and the rules:** the rules cover the `feedwatch/` package. Test files import the modules they test, and otherwise follow the same rules.
- **Poller:** it fetches feeds one at a time, with no thread pool. A 30-second fetch timeout limits how long one slow feed holds up the others.
- **No extra modules:** the only pure logic (which XML item is which entry, whether a feed is due) is private inside `parse` and `poller`.
- **`store.Connection`:** an alias of `sqlite3.Connection`, so `poller` can annotate a connection without importing `sqlite3`.
- **Missing dates:** an entry with no readable publication date is dated by when it was first stored. This needed no `except`.

**Review Focus**, the five likeliest things to go wrong, each tied to a task:
- A URL that isn't fetchable as written.
- A guid padded with whitespace, or an item with no guid and no link.
- A missing or malformed date.
- The command line running while the poller writes to the database. WAL mode is tested, but the 10-second wait has no test, so a reviewer has to check it by eye.
- The same guid appearing in two feeds.

**Finishing-work:** I also ran the end-of-work step. It added a reconstructed ledger at `docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md` and a commit `e13e001`, "sweep: … nothing to drain". `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist, and I didn't create it.

The plan is ready for you to review.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1-planning.reconstructed-ledger.md (added)

````
# Ledger — 2026-10-12-feedwatch-v1-planning

Reconstructed 2026-10-12 from the planning conversation; no superpowers ledger existed, since this unit wrote a plan and executed none of it.

- Read the spec `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`.
- Every `PROGRAM-DESIGN.md` rule copied, with its check, into the plan's Global Constraints. No structural choice was left open by the document, so nothing was put to the human.
- Prototyped the plan's code outside the repository (46 tests passing, rule checks clean, end-to-end run) before writing it into the plan.
- Wrote and committed `docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. No code in the repository changed.
- `docs/ROADMAP.md` is declared in `.dopamine/config` and absent.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** The five components of `docs/ARCHITECTURE.md`, one module each in the `feedwatch` package: `fetch` (HTTP), `parse` (RSS XML into `Item`s), `store` (the SQLite file `~/.feedwatch/feeds.db`), `poller` (`python -m feedwatch.poller`, the long-running worker) and `cli` (the `feedwatch` command). Domain values live in `feedwatch/models.py` and failures in `feedwatch/errors.py`, as `docs/PROGRAM-DESIGN.md` requires. Tasks build bottom-up: parse, fetch, store, poller, cli.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`), `unittest` for tests, setuptools only to install the `feedwatch` console script.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`

## Global Constraints

From the spec:

- `feedwatch add URL [--title TITLE] [--every MINUTES]`; interval default **30** minutes. Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries, newest first, **20** unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores entries it has not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller (`ARCHITECTURE.md`).
- Out of scope: Atom feeds; importing or exporting subscription lists.
- Database: `~/.feedwatch/feeds.db`, tables `feeds` and `entries`, owned by `store`. An existing database has to keep working.
- Standard library first; a dependency has to earn its place. Tests use `unittest`: `python3 -m unittest discover -s tests -v`.

From `docs/PROGRAM-DESIGN.md` — every rule applies to this plan, copied with its check. They govern the `feedwatch/` package; files under `tests/` import the modules they test and otherwise follow the same rules.

- **Types — Rule:** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors — Rule:** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects — Inherited default:** dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Effects — Rule:** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures — Rule:** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout — Inherited default:** split by responsibility, not technical layer; files that change together live together.
- **Layout — Rule:** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules — Rule:** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency — Rule:** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
  In v1 the poller fetches feeds one after another and owns no executor; the 30-second fetch timeout bounds how long one slow feed delays the rest.
- **Persistence — Rule:** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan meets them, so no task has to re-decide:

- Logic needs no module of its own: the only pure decisions — which XML item is which entry, whether a feed is due — sit privately in `parse` and `poller`.
- `store.Connection` is an alias of `sqlite3.Connection`, so `poller` can annotate `conn` without importing `sqlite3`. Connections are closed with `contextlib.closing(...)`, never `conn.close()`, outside `store`.
- `Item.published is None` means the feed gave no readable date: a value, not a failure. `store` dates such an entry by when it was first seen.
- Bad `--every`/`--limit` values are refused with `parser.error(...)`, not an argparse `type=` function that would have to raise a non-`FeedwatchError`.
- Time is passed in (`now`, `seen_at`, `at`) and stored as UTC ISO-8601 text at microsecond width, so text order is time order.

## Review Focus

1. **A subscription whose URL is not fetchable as written** (`feedwatch add example.com/feed`, a typo'd scheme): `urllib` raises `ValueError`, not `URLError`; it must become `FetchError` so the poller logs it and keeps polling the other feeds. Pinned in Task 2 (`test_text_that_is_not_a_url_is_a_fetch_error_naming_it`) and Task 5 (`test_failing_feeds_are_logged_and_skipped_and_the_others_still_polled`).
2. **Items with a padded guid, or no guid and no link**: a guid wrapped in whitespace must compare equal on every poll or the entry is stored again; an item with neither guid nor link is left out, not stored under an empty key or allowed to fail the feed. Pinned in Task 1.
3. **Missing, malformed or absurd `pubDate`** (`yesterday`, year 99999, `-0000`): the entry is still stored, dated when first seen, and never fails the whole feed. Pinned in Task 1 and Task 4 (`test_item_without_a_date_is_dated_when_seen`).
4. **The CLI running while the poller writes**: a command must wait for the poller's short transaction, not fail with "database is locked" — WAL mode and a 10-second busy timeout in `store.connect`. Task 3 pins WAL (`test_database_runs_in_wal_mode`); the timeout has no test, since one would have to race two writers, so a reviewer checks `timeout=10` by eye.
5. **The same guid in two feeds** (two feeds linking one article): stored once per feed, as the spec's identity says, and `feedwatch read GUID` marks both read; a list of guids containing one unknown marks none. Pinned in Task 4.

---

## File Structure

| File | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata; the `feedwatch` console script → `feedwatch.cli:main` |
| `feedwatch/__init__.py` | Empty package marker |
| `feedwatch/models.py` | Frozen dataclasses `Item`, `Feed`, `Entry` |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses `NotRssError`, `FetchError`, `AlreadySubscribedError`, `UnknownEntryError` |
| `feedwatch/parse.py` | `parse(xml) -> list[Item]`; RSS 2.0 only |
| `feedwatch/fetch.py` | `fetch(url, *, timeout) -> bytes`; the only `urllib` user |
| `feedwatch/store.py` | `SCHEMA_STEPS`, `connect`, feed and entry functions taking `conn` first; the only `sqlite3` user |
| `feedwatch/poller.py` | `poll_once(conn, now, *, fetch_feed)` and the `python -m feedwatch.poller` loop |
| `feedwatch/cli.py` | `main(argv, *, db_path) -> int`: `add`, `unread`, `read` |
| `tests/test_parse.py`, `tests/test_fetch.py`, `tests/test_store_feeds.py`, `tests/test_store_entries.py`, `tests/test_poller.py`, `tests/test_cli.py` | One test file per component; `store` split in two along its tables |

---

### Task 1: Package skeleton and `parse`

**Files:**
- Create: `pyproject.toml`
- Modify: `.gitignore` (append `.venv/` and `*.egg-info/`)
- Create: `feedwatch/__init__.py` (empty)
- Create: `feedwatch/models.py`
- Create: `feedwatch/errors.py`
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Item(guid: str, title: str, link: str | None, published: datetime | None)` — frozen dataclass; `published` is timezone-aware UTC or `None`.
  - `feedwatch.errors.FeedwatchError(Exception)`, `feedwatch.errors.NotRssError(FeedwatchError)`.
  - `feedwatch.parse.parse(xml: bytes) -> list[Item]` — items in document order; raises `NotRssError`.

- [ ] **Step 1: Create the package files**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

`feedwatch/__init__.py`: an empty file.

Append to `.gitignore`, which already holds `__pycache__/`:

```
.venv/
*.egg-info/
```

`feedwatch/models.py`:

```python
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Item:
    """One entry as a feed's XML presents it, before it is stored.

    `guid` is the item's guid, or its link when it has no guid.
    `published` is None when the item carries no readable date.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None
```

`feedwatch/errors.py`:

```python
class FeedwatchError(Exception):
    """Base of every failure feedwatch raises; its message is fit to show the user."""


class NotRssError(FeedwatchError):
    """A feed's body is not well-formed RSS 2.0."""
```

- [ ] **Step 2: Write the failing test**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import NotRssError
from feedwatch.models import Item
from feedwatch.parse import parse


def rss(items: str) -> bytes:
    return f'<?xml version="1.0"?><rss version="2.0"><channel><title>Example</title>{items}</channel></rss>'.encode()


class ParseTest(unittest.TestCase):
    def test_reads_guid_title_link_and_date(self) -> None:
        items = parse(rss(
            "<item><guid>urn:1</guid><title>Hello</title><link>https://example.com/1</link>"
            "<pubDate>Sun, 01 Mar 2026 09:00:00 +0100</pubDate></item>"
        ))
        self.assertEqual(items, [
            Item(
                guid="urn:1",
                title="Hello",
                link="https://example.com/1",
                published=datetime(2026, 3, 1, 8, 0, tzinfo=timezone.utc),
            )
        ])

    def test_keeps_document_order(self) -> None:
        items = parse(rss("<item><guid>urn:1</guid></item><item><guid>urn:2</guid></item>"))
        self.assertEqual([item.guid for item in items], ["urn:1", "urn:2"])

    def test_link_stands_in_for_a_missing_guid(self) -> None:
        [item] = parse(rss("<item><title>T</title><link>https://example.com/1</link></item>"))
        self.assertEqual(item.guid, "https://example.com/1")

    def test_item_with_neither_guid_nor_link_is_left_out(self) -> None:
        items = parse(rss("<item><title>orphan</title></item><item><guid>urn:2</guid></item>"))
        self.assertEqual([item.guid for item in items], ["urn:2"])

    def test_whitespace_around_and_inside_text_is_collapsed(self) -> None:
        [item] = parse(rss("<item><guid>\n  urn:1  \n</guid><title> Hello\n   world </title></item>"))
        self.assertEqual((item.guid, item.title), ("urn:1", "Hello world"))

    def test_missing_title_is_empty(self) -> None:
        [item] = parse(rss("<item><guid>urn:1</guid></item>"))
        self.assertEqual(item.title, "")

    def test_missing_or_unreadable_date_is_none(self) -> None:
        items = parse(rss(
            "<item><guid>urn:1</guid></item>"
            "<item><guid>urn:2</guid><pubDate>yesterday</pubDate></item>"
            "<item><guid>urn:3</guid><pubDate>Sun, 01 Mar 99999 09:00:00 +0000</pubDate></item>"
        ))
        self.assertEqual([item.published for item in items], [None, None, None])

    def test_date_without_a_zone_is_utc(self) -> None:
        [item] = parse(rss("<item><guid>urn:1</guid><pubDate>Sun, 01 Mar 2026 09:00:00 -0000</pubDate></item>"))
        self.assertEqual(item.published, datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc))

    def test_empty_channel_has_no_items(self) -> None:
        self.assertEqual(parse(rss("")), [])

    def test_malformed_xml_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b"<rss><channel>")

    def test_atom_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError) as caught:
            parse(b'<feed xmlns="http://www.w3.org/2005/Atom"></feed>')
        self.assertIn("feed", str(caught.exception))

    def test_html_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b"<html><body>Not found</body></html>")

    def test_rss_without_a_channel_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b'<rss version="2.0"></rss>')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.parse'`

- [ ] **Step 4: Write the implementation**

`feedwatch/parse.py`:

```python
import calendar
import email.utils
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

from feedwatch.errors import NotRssError
from feedwatch.models import Item

_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def parse(xml: bytes) -> list[Item]:
    """Return the items of an RSS 2.0 document, in document order.

    An item with neither a guid nor a link is left out. Raises NotRssError
    when `xml` is not well-formed or its root is not `<rss>` with a `<channel>`.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        raise NotRssError(f"not well-formed XML: {error}") from error
    channel = root.find("channel") if root.tag == "rss" else None
    if channel is None:
        raise NotRssError(f"root element is <{root.tag}>, not <rss> with a <channel>")
    items = []
    for element in channel.findall("item"):
        link = _text(element, "link")
        guid = _text(element, "guid") or link
        if guid is None:
            continue
        items.append(
            Item(
                guid=guid,
                title=_text(element, "title") or "",
                link=link,
                published=_published(_text(element, "pubDate")),
            )
        )
    return items


def _text(element: ET.Element, tag: str) -> str | None:
    # Feeds pad and wrap text freely, and a guid must compare equal on every poll.
    text = " ".join((element.findtext(tag) or "").split())
    return text or None


def _published(text: str | None) -> datetime | None:
    parts = email.utils.parsedate_tz(text) if text else None
    # A year outside this range is a typo, and would overflow datetime arithmetic.
    if parts is None or not 1900 <= parts[0] <= 9000:
        return None
    seconds = calendar.timegm(parts[:6]) - (parts[9] or 0)
    return _EPOCH + timedelta(seconds=seconds)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 13 tests, `OK`

- [ ] **Step 6: Commit**

```bash
git add .gitignore pyproject.toml feedwatch tests/test_parse.py
git commit -m "feat: parse RSS 2.0 items"
```

---

### Task 2: `fetch`

**Files:**
- Modify: `feedwatch/errors.py` (append `FetchError`)
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FeedwatchError`.
- Produces:
  - `feedwatch.errors.FetchError(FeedwatchError)` — message starts with the URL.
  - `feedwatch.fetch.fetch(url: str, *, timeout: float = 30.0) -> bytes` — raises `FetchError` for a malformed URL, an unreachable host, an HTTP error status or a broken response.

- [ ] **Step 1: Write the failing test**

`tests/test_fetch.py` (the HTTP-status test serves from a `ThreadPoolExecutor`, the one way to run a background server the Concurrency rule allows):

```python
import http.server
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch


class _NotFound(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self.send_error(404)

    def log_message(self, format: str, *args: object) -> None:
        # Silences the per-request line http.server writes to stderr.
        pass


class FetchTest(unittest.TestCase):
    def test_returns_the_body(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "feed.xml"
            path.write_bytes(b"<rss/>")
            self.assertEqual(fetch(path.as_uri()), b"<rss/>")

    def test_missing_file_is_a_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch(Path("/nonexistent/feed.xml").as_uri())

    def test_text_that_is_not_a_url_is_a_fetch_error_naming_it(self) -> None:
        with self.assertRaises(FetchError) as caught:
            fetch("example.com/feed")
        self.assertIn("example.com/feed", str(caught.exception))

    def test_unreachable_host_is_a_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch("http://127.0.0.1:9/feed", timeout=2)

    def test_http_error_status_is_a_fetch_error(self) -> None:
        server = http.server.HTTPServer(("127.0.0.1", 0), _NotFound)
        with ThreadPoolExecutor(max_workers=1) as pool:
            pool.submit(server.serve_forever)
            try:
                with self.assertRaises(FetchError) as caught:
                    fetch(f"http://127.0.0.1:{server.server_port}/feed")
            finally:
                server.shutdown()
                server.server_close()
        self.assertIn("404", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ImportError: cannot import name 'FetchError'`

- [ ] **Step 3: Write the implementation**

Append to `feedwatch/errors.py`:

```python
class FetchError(FeedwatchError):
    """A feed's URL could not be downloaded."""
```

`feedwatch/fetch.py`:

```python
import http.client
import urllib.request

from feedwatch.errors import FetchError


def fetch(url: str, *, timeout: float = 30.0) -> bytes:
    """Return the body served at `url`.

    Raises FetchError when the URL is malformed or unreachable, or answers
    with an HTTP error status.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1.0"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    # urllib reports a malformed URL as ValueError and a broken response as
    # HTTPException; only the rest arrive as URLError.
    except (OSError, ValueError, http.client.HTTPException) as error:
        raise FetchError(f"{url}: {error}") from error
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 18 tests, `OK`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/errors.py feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch a feed's body over HTTP"
```

---

### Task 3: `store` — the database and its feeds

**Files:**
- Modify: `feedwatch/models.py` (append `Feed`)
- Modify: `feedwatch/errors.py` (append `AlreadySubscribedError`)
- Create: `feedwatch/store.py`
- Test: `tests/test_store_feeds.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FeedwatchError`.
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)`.
  - `feedwatch.errors.AlreadySubscribedError(FeedwatchError)` — message names the URL.
  - `store.DEFAULT_PATH: Path` — `~/.feedwatch/feeds.db`.
  - `store.Connection` — alias of `sqlite3.Connection`, for annotations outside `store`.
  - `store.SCHEMA_STEPS: tuple[str, ...]` — idempotent statements, run in order by `connect`.
  - `store.connect(path: Path) -> Connection` — creates parent directories, WAL mode, 10 s busy timeout, applies `SCHEMA_STEPS`.
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed` — raises `AlreadySubscribedError`.
  - `store.feeds(conn: Connection) -> list[Feed]` — in the order added.
  - `store.mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None`.

- [ ] **Step 1: Write the failing test**

`tests/test_store_feeds.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribedError
from feedwatch.models import Feed

NOW = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


class StoreFeedsTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.path = Path(directory) / "nested" / "feeds.db"
        self.conn = self.enterContext(closing(store.connect(self.path)))

    def test_added_feed_is_listed(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        self.assertEqual(
            feed,
            Feed(id=feed.id, url="https://a.example/rss", title="A", every_minutes=30, last_polled=None),
        )
        self.assertEqual(store.feeds(self.conn), [feed])

    def test_adding_a_subscribed_url_again_is_refused_naming_it(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribedError) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=5)
        self.assertIn("https://a.example/rss", str(caught.exception))
        self.assertEqual(len(store.feeds(self.conn)), 1)

    def test_last_polled_is_read_back(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.mark_polled(self.conn, feed.id, at=NOW)
        [polled] = store.feeds(self.conn)
        self.assertEqual(polled.last_polled, NOW)

    def test_reopening_an_existing_database_keeps_its_feeds(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with closing(store.connect(self.path)) as again:
            self.assertEqual([feed.url for feed in store.feeds(again)], ["https://a.example/rss"])

    def test_database_runs_in_wal_mode(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        self.assertTrue(self.path.with_name("feeds.db-wal").exists())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ImportError: cannot import name 'store' from 'feedwatch'` (or `AlreadySubscribedError`)

- [ ] **Step 3: Write the implementation**

Append to `feedwatch/models.py`:

```python
@dataclass(frozen=True)
class Feed:
    """A subscription. `last_polled` is None until the poller first tries it."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None
```

Append to `feedwatch/errors.py`:

```python
class AlreadySubscribedError(FeedwatchError):
    """The URL is already subscribed to."""
```

`feedwatch/store.py`:

```python
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribedError
from feedwatch.models import Feed

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Lets poller and cli annotate a connection without importing sqlite3.
Connection = sqlite3.Connection

# Existing databases have already run every step here: append a new step,
# never edit one.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
)


def connect(path: Path) -> Connection:
    """Open the database at `path`, creating it and applying any schema step it lacks."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # The poller and a CLI command can write at once: WAL keeps readers
    # unblocked, and the timeout makes a writer wait rather than fail.
    conn = sqlite3.connect(path, timeout=10)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`. Raises AlreadySubscribedError if it is subscribed to already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise AlreadySubscribedError(f"already subscribed to {url}") from error
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def feeds(conn: Connection) -> list[Feed]:
    """Every subscribed feed, in the order they were added."""
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id")
    return [
        Feed(
            id=feed_id,
            url=url,
            title=title,
            every_minutes=every_minutes,
            last_polled=None if last_polled is None else datetime.fromisoformat(last_polled),
        )
        for feed_id, url, title, every_minutes, last_polled in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    """Record that the feed was polled at `at`, whether or not the poll succeeded."""
    with conn:
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (_iso(at), feed_id))


def _iso(moment: datetime) -> str:
    # Dates are compared and sorted as text, which holds only in one zone at one width.
    return moment.astimezone(timezone.utc).isoformat(timespec="microseconds")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 23 tests, `OK`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store_feeds.py
git commit -m "feat: store subscriptions in SQLite"
```

---

### Task 4: `store` — entries

**Files:**
- Modify: `feedwatch/models.py` (append `Entry`)
- Modify: `feedwatch/errors.py` (append `UnknownEntryError`)
- Modify: `feedwatch/store.py` (imports; append to `SCHEMA_STEPS`; add three functions)
- Test: `tests/test_store_entries.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store._iso` (private, same module), `models.Item`.
- Produces:
  - `feedwatch.models.Entry(guid: str, title: str, link: str | None, published: datetime, feed_name: str)` — `feed_name` is the feed's title, or its URL.
  - `feedwatch.errors.UnknownEntryError(FeedwatchError)` — message names every unknown guid.
  - `store.add_items(conn: Connection, feed_id: int, *, items: list[Item], seen_at: datetime) -> int` — number of entries new to that feed; an item without a date is dated `seen_at`.
  - `store.unread(conn: Connection, *, limit: int) -> list[Entry]` — newest first.
  - `store.mark_read(conn: Connection, guids: list[str]) -> None` — every entry with that guid, in any feed; raises `UnknownEntryError` and marks nothing if any guid is unknown.

- [ ] **Step 1: Write the failing test**

`tests/test_store_entries.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import UnknownEntryError
from feedwatch.models import Item

NOW = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


def item(guid: str, published: datetime | None = None) -> Item:
    return Item(guid=guid, title=f"title of {guid}", link=f"https://a.example/{guid}", published=published)


class StoreEntriesTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.conn = self.enterContext(closing(store.connect(Path(directory) / "feeds.db")))
        self.feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)

    def test_only_new_items_are_counted_and_stored(self) -> None:
        self.assertEqual(store.add_items(self.conn, self.feed.id, items=[item("1"), item("2")], seen_at=NOW), 2)
        self.assertEqual(store.add_items(self.conn, self.feed.id, items=[item("1"), item("2")], seen_at=NOW), 0)
        self.assertEqual(store.add_items(self.conn, self.feed.id, items=[item("2"), item("3")], seen_at=NOW), 1)
        self.assertEqual(len(store.unread(self.conn, limit=20)), 3)

    def test_unread_is_newest_first_and_limited(self) -> None:
        items = [item(str(hours), NOW + timedelta(hours=hours)) for hours in (1, 3, 2)]
        store.add_items(self.conn, self.feed.id, items=items, seen_at=NOW)
        entries = store.unread(self.conn, limit=2)
        self.assertEqual([entry.guid for entry in entries], ["3", "2"])
        self.assertEqual(entries[0].published, NOW + timedelta(hours=3))
        self.assertEqual(entries[0].feed_name, "A")
        self.assertEqual(entries[0].link, "https://a.example/3")

    def test_item_without_a_date_is_dated_when_seen(self) -> None:
        store.add_items(self.conn, self.feed.id, items=[item("1")], seen_at=NOW)
        [entry] = store.unread(self.conn, limit=20)
        self.assertEqual(entry.published, NOW)

    def test_feed_without_a_title_is_named_by_its_url(self) -> None:
        untitled = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.add_items(self.conn, untitled.id, items=[item("1")], seen_at=NOW)
        [entry] = store.unread(self.conn, limit=20)
        self.assertEqual(entry.feed_name, "https://b.example/rss")

    def test_read_entries_are_no_longer_unread(self) -> None:
        store.add_items(self.conn, self.feed.id, items=[item("1"), item("2")], seen_at=NOW)
        store.mark_read(self.conn, ["1"])
        self.assertEqual([entry.guid for entry in store.unread(self.conn, limit=20)], ["2"])

    def test_unknown_guid_is_refused_naming_it_and_nothing_is_marked(self) -> None:
        store.add_items(self.conn, self.feed.id, items=[item("1")], seen_at=NOW)
        with self.assertRaises(UnknownEntryError) as caught:
            store.mark_read(self.conn, ["1", "urn:missing"])
        self.assertIn("urn:missing", str(caught.exception))
        self.assertEqual([entry.guid for entry in store.unread(self.conn, limit=20)], ["1"])

    def test_same_guid_in_two_feeds_is_stored_for_each_and_read_together(self) -> None:
        other = store.add_feed(self.conn, "https://b.example/rss", title="B", every_minutes=30)
        self.assertEqual(store.add_items(self.conn, self.feed.id, items=[item("shared")], seen_at=NOW), 1)
        self.assertEqual(store.add_items(self.conn, other.id, items=[item("shared")], seen_at=NOW), 1)
        self.assertEqual(len(store.unread(self.conn, limit=20)), 2)
        store.mark_read(self.conn, ["shared"])
        self.assertEqual(store.unread(self.conn, limit=20), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ImportError: cannot import name 'UnknownEntryError'`

- [ ] **Step 3: Write the implementation**

Append to `feedwatch/models.py`:

```python
@dataclass(frozen=True)
class Entry:
    """A stored entry as the reader sees it; `feed_name` is the feed's title, or its URL."""

    guid: str
    title: str
    link: str | None
    published: datetime
    feed_name: str
```

Append to `feedwatch/errors.py`:

```python
class UnknownEntryError(FeedwatchError):
    """A guid names no stored entry."""
```

In `feedwatch/store.py`, widen the two package imports to:

```python
from feedwatch.errors import AlreadySubscribedError, UnknownEntryError
from feedwatch.models import Entry, Feed, Item
```

Append these three steps to `SCHEMA_STEPS`, after the `feeds` step and before the closing `)`. Do not touch the `feeds` step:

```python
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
    "CREATE INDEX IF NOT EXISTS entries_by_guid ON entries (guid)",
    "CREATE INDEX IF NOT EXISTS entries_unread ON entries (read, published)",
```

Add these functions between `mark_polled` and `_iso`:

```python
def add_items(conn: Connection, feed_id: int, *, items: list[Item], seen_at: datetime) -> int:
    """Store the items the feed has not stored before; return how many were new.

    An item without a date is dated `seen_at`.
    """
    new = 0
    with conn:
        for item in items:
            cursor = conn.execute(
                "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published)"
                " VALUES (?, ?, ?, ?, ?)",
                (feed_id, item.guid, item.title, item.link, _iso(item.published or seen_at)),
            )
            new += cursor.rowcount
    return new


def unread(conn: Connection, *, limit: int) -> list[Entry]:
    """The `limit` newest unread entries, newest first."""
    rows = conn.execute(
        """SELECT e.guid, e.title, e.link, e.published, coalesce(f.title, f.url)
           FROM entries e JOIN feeds f ON f.id = e.feed_id
           WHERE e.read = 0
           ORDER BY e.published DESC, e.id DESC
           LIMIT ?""",
        (limit,),
    )
    return [
        Entry(
            guid=guid,
            title=title,
            link=link,
            published=datetime.fromisoformat(published),
            feed_name=feed_name,
        )
        for guid, title, link, published, feed_name in rows
    ]


def mark_read(conn: Connection, guids: list[str]) -> None:
    """Mark read every entry, in any feed, whose guid is in `guids`.

    Raises UnknownEntryError naming each guid no entry has, and then marks none.
    """
    unknown = [
        guid
        for guid in dict.fromkeys(guids)
        if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None
    ]
    if unknown:
        raise UnknownEntryError(f"no stored entry has guid {', '.join(unknown)}")
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 30 tests, `OK`

- [ ] **Step 5: Commit**

```bash
git add feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store_entries.py
git commit -m "feat: store entries once per feed and track what is read"
```

---

### Task 5: `poller`

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.feeds`, `store.add_items`, `store.mark_polled`, `store.connect`, `store.DEFAULT_PATH`, `store.Connection`; `parse.parse`; `fetch.fetch`; `FetchError`, `NotRssError`; `models.Feed`.
- Produces:
  - `poller.poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> int` — polls every feed due at `now`, returns the number of new entries. Tests pass a fake `fetch_feed`; `main` passes `fetch.fetch`.
  - `poller.main() -> None` — the `python -m feedwatch.poller` loop, polling once a minute until interrupted. Logs to the `feedwatch.poller` logger.

- [ ] **Step 1: Write the failing test**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FetchError
from feedwatch.poller import poll_once

NOW = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid><title>{guid}</title></item>" for guid in guids)
    return f'<rss version="2.0"><channel>{items}</channel></rss>'.encode()


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.conn = self.enterContext(closing(store.connect(Path(directory) / "feeds.db")))
        self.bodies: dict[str, bytes] = {}
        self.fetched: list[str] = []

    def fake_fetch(self, url: str) -> bytes:
        self.fetched.append(url)
        if url not in self.bodies:
            raise FetchError(f"{url}: connection refused")
        return self.bodies[url]

    def subscribe(self, url: str, body: bytes | None) -> None:
        store.add_feed(self.conn, url, title=None, every_minutes=30)
        if body is not None:
            self.bodies[url] = body

    def test_a_feed_never_polled_is_polled_and_its_entries_stored(self) -> None:
        self.subscribe("https://a.example/rss", rss("urn:1", "urn:2"))
        self.assertEqual(poll_once(self.conn, NOW, fetch_feed=self.fake_fetch), 2)
        self.assertEqual({entry.guid for entry in store.unread(self.conn, limit=20)}, {"urn:1", "urn:2"})

    def test_a_feed_is_polled_again_only_when_its_interval_is_up(self) -> None:
        self.subscribe("https://a.example/rss", rss("urn:1"))
        poll_once(self.conn, NOW, fetch_feed=self.fake_fetch)
        poll_once(self.conn, NOW + timedelta(minutes=29), fetch_feed=self.fake_fetch)
        self.assertEqual(len(self.fetched), 1)
        poll_once(self.conn, NOW + timedelta(minutes=30), fetch_feed=self.fake_fetch)
        self.assertEqual(len(self.fetched), 2)

    def test_entries_seen_again_are_not_stored_again(self) -> None:
        self.subscribe("https://a.example/rss", rss("urn:1"))
        poll_once(self.conn, NOW, fetch_feed=self.fake_fetch)
        self.bodies["https://a.example/rss"] = rss("urn:2", "urn:1")
        self.assertEqual(poll_once(self.conn, NOW + timedelta(minutes=30), fetch_feed=self.fake_fetch), 1)
        self.assertEqual(len(store.unread(self.conn, limit=20)), 2)

    def test_failing_feeds_are_logged_and_skipped_and_the_others_still_polled(self) -> None:
        self.subscribe("https://down.example/rss", None)
        self.subscribe("https://html.example/", b"<html><body>Not found</body></html>")
        self.subscribe("https://ok.example/rss", rss("urn:1"))
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            self.assertEqual(poll_once(self.conn, NOW, fetch_feed=self.fake_fetch), 1)
        output = "\n".join(logs.output)
        self.assertIn("https://down.example/rss", output)
        self.assertIn("https://html.example/", output)
        self.assertEqual([entry.guid for entry in store.unread(self.conn, limit=20)], ["urn:1"])

    def test_a_failed_feed_waits_for_its_next_interval(self) -> None:
        self.subscribe("https://down.example/rss", None)
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poll_once(self.conn, NOW, fetch_feed=self.fake_fetch)
        poll_once(self.conn, NOW + timedelta(minutes=10), fetch_feed=self.fake_fetch)
        self.assertEqual(self.fetched, ["https://down.example/rss"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.poller'`

- [ ] **Step 3: Write the implementation**

`feedwatch/poller.py`:

```python
import logging
import time
from collections.abc import Callable
from contextlib import closing
from datetime import datetime, timedelta, timezone

from feedwatch import fetch, parse, store
from feedwatch.errors import FetchError, NotRssError
from feedwatch.models import Feed

log = logging.getLogger(__name__)

# Intervals are whole minutes, so a feed is never polled more than a minute late.
TICK_SECONDS = 60


def poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes]) -> int:
    """Poll each feed whose interval is up at `now`; return how many entries were new.

    A feed that cannot be fetched or is not RSS is logged and waits for its
    next interval. A database error propagates, and stops the poller.
    """
    new = 0
    for feed in store.feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            items = parse.parse(fetch_feed(feed.url))
        except (FetchError, NotRssError) as error:
            log.warning("skipping %s until its next interval: %s", feed.url, error)
        else:
            new += store.add_items(conn, feed.id, items=items, seen_at=now)
        store.mark_polled(conn, feed.id, at=now)
    return new


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled is None or now - feed.last_polled >= timedelta(minutes=feed.every_minutes)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    log.info("polling the feeds in %s", store.DEFAULT_PATH)
    with closing(store.connect(store.DEFAULT_PATH)) as conn:
        try:
            while True:
                new = poll_once(conn, datetime.now(timezone.utc), fetch_feed=fetch.fetch)
                if new:
                    log.info("stored %d new entries", new)
                time.sleep(TICK_SECONDS)
        except KeyboardInterrupt:
            log.info("stopped")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 35 tests, `OK`

- [ ] **Step 5: Check the loop starts against a fresh home directory**

Run: `HOME=$(mktemp -d) timeout 3 python3 -m feedwatch.poller; echo "exit $?"`
Expected: one `INFO polling the feeds in /tmp/.../.feedwatch/feeds.db` line, no traceback, then `exit 124` (stopped by `timeout`).

- [ ] **Step 6: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poll due feeds and keep going past failing ones"
```

---

### Task 6: `cli`, and the whole of v1 checked

**Files:**
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.DEFAULT_PATH`; `FeedwatchError`; `models.Entry`.
- Produces: `cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int` — exit status 0 on success, 1 on a refused command (message on stderr, prefixed `feedwatch: `); argparse exits 2 on bad arguments. Wired to the `feedwatch` console script by `pyproject.toml`.

Each unread entry prints as:

```
2026-03-01 10:00  Example Blog  Hello world
  https://example.com/1
  feedwatch read urn:1
```

— local time, the feed's title or URL, the title or `(untitled)`; the link line only when there is a link; the last line is the exact command to mark it read, the guid shell-quoted.

- [ ] **Step 1: Write the failing test**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.cli import main
from feedwatch.models import Feed, Item

NOW = datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = self.enterContext(tempfile.TemporaryDirectory())
        self.db = Path(directory) / "feeds.db"

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = main(list(argv), db_path=self.db)
        return status, out.getvalue(), err.getvalue()

    def seed(self, *guids: str) -> None:
        with closing(store.connect(self.db)) as conn:
            feed = store.add_feed(conn, "https://a.example/rss", title="A", every_minutes=30)
            items = [
                Item(guid=guid, title=f"title of {guid}", link=None, published=NOW + timedelta(minutes=number))
                for number, guid in enumerate(guids)
            ]
            store.add_items(conn, feed.id, items=items, seen_at=NOW)

    def stored_feeds(self) -> list[Feed]:
        with closing(store.connect(self.db)) as conn:
            return store.feeds(conn)

    def test_add_subscribes_every_30_minutes_by_default(self) -> None:
        status, out, _ = self.run_cli("add", "https://a.example/rss")
        self.assertEqual(status, 0)
        self.assertIn("https://a.example/rss", out)
        [feed] = self.stored_feeds()
        self.assertEqual((feed.url, feed.title, feed.every_minutes), ("https://a.example/rss", None, 30))

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.run_cli("add", "https://a.example/rss", "--title", "A", "--every", "5")
        [feed] = self.stored_feeds()
        self.assertEqual((feed.url, feed.title, feed.every_minutes), ("https://a.example/rss", "A", 5))

    def test_adding_a_subscribed_url_again_is_refused_naming_it(self) -> None:
        self.run_cli("add", "https://a.example/rss")
        status, _, err = self.run_cli("add", "https://a.example/rss")
        self.assertEqual(status, 1)
        self.assertIn("https://a.example/rss", err)

    def test_an_interval_below_one_minute_is_refused(self) -> None:
        with self.assertRaises(SystemExit) as caught, redirect_stderr(io.StringIO()):
            main(["add", "https://a.example/rss", "--every", "0"], db_path=self.db)
        self.assertEqual(caught.exception.code, 2)

    def test_unread_lists_20_newest_first_by_default(self) -> None:
        self.seed(*(f"urn:{number}" for number in range(25)))
        status, out, _ = self.run_cli("unread")
        self.assertEqual(status, 0)
        self.assertEqual(out.count("feedwatch read "), 20)
        self.assertLess(out.index("feedwatch read urn:24"), out.index("feedwatch read urn:23"))
        self.assertNotIn("feedwatch read urn:4\n", out)

    def test_unread_takes_a_limit(self) -> None:
        self.seed("urn:1", "urn:2", "urn:3")
        _, out, _ = self.run_cli("unread", "--limit", "2")
        self.assertEqual(out.count("feedwatch read "), 2)

    def test_a_limit_below_one_is_refused(self) -> None:
        with self.assertRaises(SystemExit) as caught, redirect_stderr(io.StringIO()):
            main(["unread", "--limit", "0"], db_path=self.db)
        self.assertEqual(caught.exception.code, 2)

    def test_unread_says_so_when_nothing_is_unread(self) -> None:
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out, "nothing unread\n")

    def test_unread_quotes_a_guid_the_shell_would_split(self) -> None:
        self.seed("urn:a b")
        _, out, _ = self.run_cli("unread")
        self.assertIn("feedwatch read 'urn:a b'", out)

    def test_read_marks_entries_read(self) -> None:
        self.seed("urn:1", "urn:2", "urn:3")
        status, _, _ = self.run_cli("read", "urn:1", "urn:3")
        self.assertEqual(status, 0)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out.count("feedwatch read "), 1)
        self.assertIn("feedwatch read urn:2", out)

    def test_reading_an_unknown_guid_is_refused_naming_it(self) -> None:
        self.seed("urn:1")
        status, _, err = self.run_cli("read", "urn:1", "urn:nope")
        self.assertEqual(status, 1)
        self.assertIn("urn:nope", err)
        _, out, _ = self.run_cli("unread")
        self.assertIn("feedwatch read urn:1", out)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest discover -s tests -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.cli'`

- [ ] **Step 3: Write the implementation**

`feedwatch/cli.py`:

```python
import argparse
import shlex
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import Entry


def main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
    """Run one feedwatch command; return the process's exit status.

    Bad arguments exit through argparse with status 2.
    """
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")
    with closing(store.connect(db_path)) as conn:
        try:
            if args.command == "add":
                feed = store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
                print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes")
            elif args.command == "unread":
                entries = store.unread(conn, limit=args.limit)
                print("\n".join(_format(entry) for entry in entries) or "nothing unread")
            else:
                store.mark_read(conn, args.guids)
        except FeedwatchError as error:
            print(f"feedwatch: {error}", file=sys.stderr)
            return 1
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _format(entry: Entry) -> str:
    when = entry.published.astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [f"{when}  {entry.feed_name}  {entry.title or '(untitled)'}"]
    if entry.link:
        lines.append(f"  {entry.link}")
    lines.append(f"  feedwatch read {shlex.quote(entry.guid)}")
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 46 tests, `OK`

- [ ] **Step 5: Check the package against `PROGRAM-DESIGN.md`**

Each command below must print nothing unless stated.

```bash
grep -nE "sqlite3|conn\." feedwatch/*.py | grep -v "^feedwatch/store.py"   # Effects: database only in store
grep -n "urllib" feedwatch/*.py | grep -v "^feedwatch/fetch.py"            # Effects: network only in fetch
grep -rnE "threading|asyncio|multiprocessing" feedwatch tests               # Concurrency
grep -nE "^(from|import) feedwatch" feedwatch/models.py feedwatch/errors.py # Layout: models and errors import nothing from the package
grep -nE "^from feedwatch(\.| import )(cli|poller)" feedwatch/*.py          # Layout: nothing imports cli or poller
grep -nE "^from feedwatch(\.| import )(store|fetch|parse)" feedwatch/store.py feedwatch/fetch.py feedwatch/parse.py  # Layout: no imports between store, fetch, parse
grep -nE "^\s*class " feedwatch/store.py                                    # Effects: no class in store
```

Then:

```bash
grep -n "except" feedwatch/*.py
```

Expected exactly six lines: `cli.py` (`FeedwatchError`), `poller.py` (`FetchError, NotRssError` and `KeyboardInterrupt`), and the three library-to-`FeedwatchError` conversions in `fetch.py`, `parse.py` and `store.py`.

```bash
grep -n "raise" feedwatch/*.py | grep -v errors.py
```

Expected: every line raises `FetchError`, `NotRssError`, `AlreadySubscribedError` or `UnknownEntryError`.

```bash
grep -n "CREATE" feedwatch/store.py
```

Expected: every statement says `IF NOT EXISTS`.

Signatures — save as `/tmp/sigcheck.py` (outside the repository) and run `python3 /tmp/sigcheck.py feedwatch && python3 /tmp/sigcheck.py tests`:

```python
import ast
import pathlib
import sys

violations = 0
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.py")):
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.FunctionDef):
            positional = [p for p in node.args.posonlyargs + node.args.args if p.arg not in ("self", "cls")]
            unannotated = [p.arg for p in positional + node.args.kwonlyargs if p.annotation is None]
            if len(positional) > 2 or unannotated or node.returns is None:
                print(f"{path}:{node.lineno} {node.name}")
                violations += 1
print(f"{violations} signature violations")
```

Expected: `0 signature violations`, twice.

- [ ] **Step 6: Run v1 end to end**

```bash
demo=$(mktemp -d)
printf '<rss version="2.0"><channel><item><guid>urn:x</guid><title>Smoke</title><pubDate>Sun, 01 Mar 2026 09:00:00 +0000</pubDate></item></channel></rss>' > "$demo/feed.xml"
HOME="$demo" python3 -m feedwatch.cli add "file://$demo/feed.xml" --every 1
HOME="$demo" python3 -m feedwatch.cli add "file://$demo/feed.xml"; echo "exit $?"
HOME="$demo" timeout 3 python3 -m feedwatch.poller
HOME="$demo" python3 -m feedwatch.cli unread
HOME="$demo" python3 -m feedwatch.cli read urn:x
HOME="$demo" python3 -m feedwatch.cli read urn:x urn:nope; echo "exit $?"
HOME="$demo" python3 -m feedwatch.cli unread
```

Expected, in order: `subscribed to file://…/feed.xml, polled every 1 minutes`; `feedwatch: already subscribed to file://…/feed.xml` and `exit 1`; poller log lines including `stored 1 new entries`; the `Smoke` entry ending `feedwatch read urn:x`; nothing; `feedwatch: no stored entry has guid urn:nope` and `exit 1`; `nothing unread`.

Then install the console script into a virtual environment and check it answers: `python3 -m venv .venv && .venv/bin/pip install -e . && .venv/bin/feedwatch --help` (where `python3 -m venv` lacks `ensurepip`, `uv venv .venv && uv pip install --python .venv/bin/python -e .` does the same) — expected: usage listing `add`, `unread`, `read`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch command line: add, unread, read"
```
````


## p013

#### Final message

I wrote the implementation plan for feedwatch v1 and committed it as `43b6713` ("plan: feedwatch v1"). Nothing is implemented in the repo. To check the plan's code, I put it together in a scratch directory outside the repo: all 37 tests pass, the end-to-end check works (add, poll a `file://` feed, unread, read, unknown guid refused) and the design-rule greps come back clean.

Plan: `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`

**Shape:** six test-first tasks, standard library only, tests in `unittest`.
1. Package setup and storing feeds (`models`, `errors`, `store`, `pyproject.toml`).
2. Storing entries: each entry stored once, the unread list, marking read.
3. `parse`: RSS to entries.
4. `fetch`: download with a 10-second timeout.
5. `poller`: `poll_due(conn, *, now, fetch_xml)` and the loop behind `python -m feedwatch.poller`.
6. `cli`: `add`, `unread` and `read`, plus the end-to-end check and a pass over the program-design rules.

**Program design:** every rule in `PROGRAM-DESIGN.md` is copied into Global Constraints with its check. Nothing it leaves open blocked the plan, so I didn't need to ask you anything. Three things the plan settles within the rules:
- **Scope of the checks:** they apply to the code in `feedwatch/`; the tests import `cli` and `poller` to test them.
- **No `conn.` outside `store`:** `poller` and `cli` use the type name `store.Connection` and close the connection with `contextlib.closing`.
- **No thread pool yet:** v1 polls feeds one after another, and the fetch timeout stops one slow feed from holding up the rest.

**Where the spec is silent, the plan decides:**
- Only documents with an `<rss>` root and a `<channel>` count as RSS; badly formed XML counts as "not RSS".
- "Newest first" uses the item's `pubDate`; an entry without a readable date sorts by when it was first stored.
- A failed poll still counts as a poll, so a broken feed waits its full interval before the next try.
- `read GUID` marks that guid in every feed that has it. If any guid is unknown, nothing is marked.

**Review Focus lists five risks, each with a test in the task that owns it:**
- an item with neither a guid nor a link
- a missing or unreadable `pubDate`
- a feed URL that returns an HTML error page
- `read` given one known and one unknown guid
- `--every` or `--limit` of zero or less

I didn't run the `finishing-work` sweep: it belongs at the end of carrying out the plan, and writing it changed no code. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist; the plan doesn't need it.

As instructed, I stopped at the handoff and didn't ask which way to carry out the plan.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** Five components from `docs/ARCHITECTURE.md`, as modules of one `feedwatch` package: `fetch` downloads, `parse` turns RSS XML into `Entry` values, `store` owns the SQLite file, `poller` runs the schedule, `cli` presents. Domain values live in `models.py`, failures in `errors.py`. `poller` calls `fetch`, `parse` and `store`; `cli` calls only `store`.

**Tech Stack:** Python 3.11, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `argparse`, `logging`, `unittest`). `pyproject.toml` with setuptools only to install the `feedwatch` console script.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md` (read with `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`).

## Global Constraints

From the spec and `docs/ARCHITECTURE.md`:

- Python 3.11, standard library only; no runtime dependency. Tests use `unittest`, run from the repo root with `python -m unittest discover -s tests -t . -v`.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`: interval defaults to **30** minutes. Subscribing to an already-subscribed URL is refused, with a message naming the URL.
- `feedwatch unread [--limit N]`: unread entries, newest first, **20** unless set otherwise.
- `feedwatch read GUID [GUID ...]`: marks entries read; a guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores entries not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- Database: one SQLite file, `~/.feedwatch/feeds.db`, tables `feeds` and `entries`; an existing database has to keep working.
- Out of scope: Atom feeds; importing or exporting subscription lists.

Interpretations this plan makes where the spec is silent (flag in review if wrong):

- "An RSS feed" is a document whose root is `<rss>` with a `<channel>` (RSS 0.9x/2.0). Anything else, including not-well-formed XML, is "not an RSS feed".
- "Newest first" orders by the item's `pubDate`; an entry without a readable date sorts by when it was first stored.
- A failed poll counts as a poll: the feed waits its full interval before the next attempt.
- `read GUID` marks that guid read in every feed that has it. If any guid is unknown, nothing is marked.

From `docs/PROGRAM-DESIGN.md`, each rule with its check. The checks apply to modules under `feedwatch/`; tests may import the module they test, including `cli` and `poller`.

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. (Here: `poll_due` takes `now` and `fetch_xml`; `cli.main` takes `db_path`.)
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection. (`poller` and `cli` annotate with the alias `store.Connection`, so neither imports `sqlite3`, and close the connection with `contextlib.closing`, so neither writes `conn.`.)
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated (test methods included: `-> None`).
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function. (This plan adds no module beyond the five components, `models` and `errors`; the due-check lives privately in `poller`, which owns the schedule.)
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor. (v1 polls feeds one after another, each fetch bounded by a 10-second timeout; no executor yet.)
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.
- **Not this.** No result types or `(ok, reason)` pairs; no `asyncio`.

## Review Focus

1. **An RSS item with neither `<guid>` nor `<link>`** — it is skipped (it cannot be recognised on the next poll) and its siblings are still stored. Test: Task 3 `test_item_with_neither_guid_nor_link_is_skipped`.
2. **An item with no `pubDate`, or one that does not parse** — the entry is stored with no date and still listed, ordered by when it was first stored, rather than crashing or sinking to the bottom. Tests: Task 3 `test_missing_or_unreadable_pub_date_is_none`, Task 2 `test_undated_entry_sorts_by_when_it_was_seen`.
3. **A feed URL that returns an HTML error page or other not-well-formed XML** — treated like a non-RSS feed: logged, skipped until its next interval, other feeds still polled. Tests: Task 3 `test_html_page_is_not_rss`, Task 5 `test_unreachable_and_non_rss_feeds_are_logged_and_others_still_polled`.
4. **`feedwatch read` with one known and one unknown guid** — refused naming only the unknown guid, and the known one is not marked either. Tests: Task 2 `test_mark_read_with_an_unknown_guid_marks_nothing`, Task 6 `test_read_with_an_unknown_guid_is_refused_and_marks_nothing`.
5. **`--every 0`, a negative `--every`, or `--limit 0`** — refused as a usage error, nothing stored, rather than a feed polled every tick or an empty listing. Test: Task 6 `test_non_positive_every_or_limit_is_a_usage_error`.

---

## File Structure

| File | Responsibility |
|---|---|
| `pyproject.toml` | Package metadata; `feedwatch` console script → `feedwatch.cli:main`. |
| `feedwatch/__init__.py` | Empty package marker. |
| `feedwatch/models.py` | Frozen dataclasses `Feed`, `Entry`, `UnreadEntry`. Imports nothing from the package. |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses. Imports nothing from the package. |
| `feedwatch/store.py` | The SQLite file: `SCHEMA_STEPS`, `connect`, feed and entry functions taking `conn` first. |
| `feedwatch/parse.py` | `parse_feed`: RSS bytes → `list[Entry]`. |
| `feedwatch/fetch.py` | `fetch_feed`: URL → bytes over `urllib`. |
| `feedwatch/poller.py` | `poll_due` (one pass) and `main` (the loop); `python -m feedwatch.poller`. |
| `feedwatch/cli.py` | `main(argv)`: `add`, `unread`, `read`. |
| `tests/__init__.py` | Empty; makes `tests` importable for `python -m unittest tests.test_x`. |
| `tests/test_store.py`, `tests/test_parse.py`, `tests/test_fetch.py`, `tests/test_poller.py`, `tests/test_cli.py` | One test module per component. |

---

### Task 1: Package skeleton and feed storage

**Files:**
- Create: `pyproject.toml`, `feedwatch/__init__.py`, `feedwatch/models.py`, `feedwatch/errors.py`, `feedwatch/store.py`, `tests/__init__.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled_at: datetime | None)` — frozen dataclass.
  - `feedwatch.errors.FeedwatchError(Exception)`; `feedwatch.errors.DuplicateFeedError(url: str)` with `.url`, message `"already subscribed to {url}"`.
  - `feedwatch.store.Connection` (alias of `sqlite3.Connection`), `store.DEFAULT_PATH: Path` (`~/.feedwatch/feeds.db`), `store.SCHEMA_STEPS: list[str]`.
  - `store.connect(path: Path) -> Connection`
  - `store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed` — raises `DuplicateFeedError`.
  - `store.list_feeds(conn: Connection) -> list[Feed]` — ordered by id.
  - `store.record_poll(conn: Connection, feed_id: int, *, at: datetime) -> None`
  - All datetimes passed in are timezone-aware; datetimes returned are UTC-aware.

- [ ] **Step 1: Create the package skeleton**

`pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

Create `feedwatch/__init__.py` and `tests/__init__.py` as empty files.

`feedwatch/models.py`:

```python
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled_at: datetime | None
```

`feedwatch/errors.py`:

```python
class FeedwatchError(Exception):
    """Base of every failure feedwatch raises; only poller and cli catch it."""


class DuplicateFeedError(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url
```

- [ ] **Step 2: Write the failing tests**

`tests/test_store.py`:

```python
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import DuplicateFeedError

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = Path(tmp.name) / "not-yet-created" / "feeds.db"
        self.conn = store.connect(self.path)
        self.addCleanup(self.conn.close)


class FeedTests(StoreTestCase):
    def test_connect_creates_the_missing_directory_and_file(self) -> None:
        self.assertTrue(self.path.is_file())

    def test_reconnecting_keeps_existing_feeds(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        self.conn.close()
        again = store.connect(self.path)
        self.addCleanup(again.close)
        self.assertEqual([f.url for f in store.list_feeds(again)], ["https://a.example/rss"])

    def test_add_feed_returns_the_stored_feed(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=5)
        self.assertEqual(feed.url, "https://a.example/rss")
        self.assertEqual(feed.title, "A")
        self.assertEqual(feed.every_minutes, 5)
        self.assertIsNone(feed.last_polled_at)
        self.assertEqual(store.list_feeds(self.conn), [feed])

    def test_adding_a_subscribed_url_again_is_refused_naming_it(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(DuplicateFeedError) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=10)
        self.assertIn("https://a.example/rss", str(caught.exception))
        self.assertEqual(len(store.list_feeds(self.conn)), 1)

    def test_record_poll_sets_last_polled_at(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.record_poll(self.conn, feed.id, at=NOW)
        self.assertEqual(store.list_feeds(self.conn)[0].last_polled_at, NOW)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: ERROR — `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 4: Write the implementation**

`feedwatch/store.py`:

```python
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import DuplicateFeedError
from feedwatch.models import Feed

Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Every step runs on every connect, so each must be idempotent; append new
# steps and never edit a released one, or existing databases diverge.
SCHEMA_STEPS: list[str] = [
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled_at TEXT
    )""",
]


def connect(path: Path) -> Connection:
    """Open the database at path, creating it and its directory if absent, with every schema step applied."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to url. Raises DuplicateFeedError if url is already subscribed."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as e:
        raise DuplicateFeedError(url) from e
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled_at=None)


def list_feeds(conn: Connection) -> list[Feed]:
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled_at FROM feeds ORDER BY id")
    return [
        Feed(id=row[0], url=row[1], title=row[2], every_minutes=row[3], last_polled_at=_from_text(row[4]))
        for row in rows
    ]


def record_poll(conn: Connection, feed_id: int, *, at: datetime) -> None:
    with conn:
        conn.execute("UPDATE feeds SET last_polled_at = ? WHERE id = ?", (_to_text(at), feed_id))


def _to_text(moment: datetime) -> str:
    # One fixed UTC format, so stored timestamps sort in time order as text in SQL.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _from_text(text: str | None) -> datetime | None:
    return None if text is None else datetime.fromisoformat(text)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 5 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add pyproject.toml feedwatch/__init__.py feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/__init__.py tests/test_store.py
git commit -m "feat: package skeleton and feed storage"
```

---

### Task 2: Entry storage — store once, list unread, mark read

**Files:**
- Modify: `feedwatch/models.py` (append `Entry`, `UnreadEntry`), `feedwatch/errors.py` (append `UnknownEntryError`), `feedwatch/store.py` (append an `entries` schema step and three functions)
- Test: `tests/test_store.py` (append `EntryTests`)

**Interfaces:**
- Consumes: Task 1's `store.connect`, `store.add_feed`, `store._to_text`, `store._from_text`, `Feed`.
- Produces:
  - `feedwatch.models.Entry(guid: str, title: str | None, link: str | None, published: datetime | None)` — `guid` is the item's guid, or its link when it has none.
  - `feedwatch.models.UnreadEntry(entry: Entry, feed_name: str)` — `feed_name` is the feed's title, or its URL when untitled.
  - `feedwatch.errors.UnknownEntryError(guids: list[str])` with `.guids`, message `"no stored entry with guid {g1}, {g2}"`.
  - `store.add_entries(conn: Connection, entries: list[Entry], *, feed_id: int, seen_at: datetime) -> int` — number newly stored.
  - `store.unread(conn: Connection, limit: int) -> list[UnreadEntry]` — newest first.
  - `store.mark_read(conn: Connection, guids: list[str]) -> None` — raises `UnknownEntryError`, marking nothing, if any guid is not stored.

- [ ] **Step 1: Add the domain types and error**

Append to `feedwatch/models.py`:

```python
@dataclass(frozen=True)
class Entry:
    guid: str
    """The item's guid, or its link when it has none; unique within its feed."""
    title: str | None
    link: str | None
    published: datetime | None


@dataclass(frozen=True)
class UnreadEntry:
    entry: Entry
    feed_name: str
    """The feed's title, or its URL when it has none."""
```

Append to `feedwatch/errors.py`:

```python
class UnknownEntryError(FeedwatchError):
    def __init__(self, guids: list[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = guids
```

- [ ] **Step 2: Write the failing tests**

In `tests/test_store.py`, extend the imports:

```python
from datetime import datetime, timedelta, timezone

from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Entry
```

Append above the `if __name__` block:

```python
def entry(guid: str, *, published: datetime | None = None) -> Entry:
    return Entry(guid=guid, title=f"Title {guid}", link=f"https://a.example/{guid}", published=published)


class EntryTests(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)

    def test_entries_are_stored_once_however_often_seen(self) -> None:
        batch = [entry("1", published=NOW), entry("2", published=NOW)]
        self.assertEqual(store.add_entries(self.conn, batch, feed_id=self.feed.id, seen_at=NOW), 2)
        self.assertEqual(store.add_entries(self.conn, batch, feed_id=self.feed.id, seen_at=NOW), 0)
        self.assertEqual(len(store.unread(self.conn, 20)), 2)

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        other = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.add_entries(self.conn, [entry("1")], feed_id=self.feed.id, seen_at=NOW)
        store.add_entries(self.conn, [entry("1")], feed_id=other.id, seen_at=NOW)
        names = sorted(item.feed_name for item in store.unread(self.conn, 20))
        self.assertEqual(names, ["A", "https://b.example/rss"])

    def test_unread_is_newest_first_and_limited(self) -> None:
        batch = [entry(str(hour), published=NOW.replace(hour=hour)) for hour in (9, 11, 10)]
        store.add_entries(self.conn, batch, feed_id=self.feed.id, seen_at=NOW)
        listed = store.unread(self.conn, 2)
        self.assertEqual([item.entry.guid for item in listed], ["11", "10"])
        self.assertEqual(listed[0].entry, batch[1])

    def test_undated_entry_sorts_by_when_it_was_seen(self) -> None:
        store.add_entries(self.conn, [entry("old", published=NOW - timedelta(hours=2))], feed_id=self.feed.id, seen_at=NOW)
        store.add_entries(self.conn, [entry("undated")], feed_id=self.feed.id, seen_at=NOW - timedelta(hours=1))
        store.add_entries(self.conn, [entry("new", published=NOW)], feed_id=self.feed.id, seen_at=NOW)
        self.assertEqual([item.entry.guid for item in store.unread(self.conn, 20)], ["new", "undated", "old"])

    def test_mark_read_removes_entries_from_unread(self) -> None:
        store.add_entries(self.conn, [entry("1"), entry("2")], feed_id=self.feed.id, seen_at=NOW)
        store.mark_read(self.conn, ["1"])
        self.assertEqual([item.entry.guid for item in store.unread(self.conn, 20)], ["2"])

    def test_mark_read_with_an_unknown_guid_marks_nothing(self) -> None:
        store.add_entries(self.conn, [entry("1")], feed_id=self.feed.id, seen_at=NOW)
        with self.assertRaises(UnknownEntryError) as caught:
            store.mark_read(self.conn, ["1", "nope"])
        self.assertEqual(caught.exception.guids, ["nope"])
        self.assertIn("nope", str(caught.exception))
        self.assertEqual([item.entry.guid for item in store.unread(self.conn, 20)], ["1"])
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the six `EntryTests` ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'`; the five `FeedTests` still pass.

- [ ] **Step 4: Write the implementation**

In `feedwatch/store.py`, extend the imports:

```python
from feedwatch.errors import DuplicateFeedError, UnknownEntryError
from feedwatch.models import Entry, Feed, UnreadEntry
```

Append a second step to `SCHEMA_STEPS` (after the `feeds` step, inside the list):

```python
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT,
        link TEXT,
        published_at TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
```

Add these functions after `record_poll`:

```python
def add_entries(conn: Connection, entries: list[Entry], *, feed_id: int, seen_at: datetime) -> int:
    """Store the entries feed_id has not stored before; return how many were new."""
    before = conn.total_changes
    with conn:
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published_at, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    feed_id,
                    e.guid,
                    e.title,
                    e.link,
                    None if e.published is None else _to_text(e.published),
                    _to_text(seen_at),
                )
                for e in entries
            ],
        )
    return conn.total_changes - before


def unread(conn: Connection, limit: int) -> list[UnreadEntry]:
    """At most limit unread entries, newest first; an undated entry counts from when it was first stored."""
    rows = conn.execute(
        "SELECT e.guid, e.title, e.link, e.published_at, COALESCE(f.title, f.url)"
        " FROM entries e JOIN feeds f ON f.id = e.feed_id"
        " WHERE e.read = 0"
        " ORDER BY COALESCE(e.published_at, e.seen_at) DESC, e.id DESC"
        " LIMIT ?",
        (limit,),
    )
    return [
        UnreadEntry(
            entry=Entry(guid=row[0], title=row[1], link=row[2], published=_from_text(row[3])),
            feed_name=row[4],
        )
        for row in rows
    ]


def mark_read(conn: Connection, guids: list[str]) -> None:
    """Mark read every entry carrying one of guids. Raises UnknownEntryError, marking nothing, if any is not stored."""
    unique = list(dict.fromkeys(guids))
    placeholders = ", ".join("?" * len(unique))
    with conn:
        stored = {row[0] for row in conn.execute(f"SELECT guid FROM entries WHERE guid IN ({placeholders})", unique)}
        missing = [guid for guid in unique if guid not in stored]
        if missing:
            raise UnknownEntryError(missing)
        conn.execute(f"UPDATE entries SET read = 1 WHERE guid IN ({placeholders})", unique)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 11 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once, list unread, mark read"
```

---

### Task 3: Parse RSS into entries

**Files:**
- Create: `feedwatch/parse.py`
- Modify: `feedwatch/errors.py` (append `FeedError`, `NotRssError`)
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: Task 2's `Entry`; Task 1's `FeedwatchError`.
- Produces:
  - `feedwatch.errors.FeedError(FeedwatchError)` — a feed could not be polled this time; the poller catches exactly this.
  - `feedwatch.errors.NotRssError(FeedError)`.
  - `feedwatch.parse.parse_feed(xml: bytes) -> list[Entry]` — each identity once, in document order; raises `NotRssError`.

- [ ] **Step 1: Add the errors**

Append to `feedwatch/errors.py`:

```python
class FeedError(FeedwatchError):
    """A feed could not be polled this time; the poller skips it until its next interval."""


class NotRssError(FeedError):
    pass
```

- [ ] **Step 2: Write the failing tests**

`tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import NotRssError
from feedwatch.models import Entry
from feedwatch.parse import parse_feed


def rss(*items: str) -> bytes:
    return (
        '<?xml version="1.0"?><rss version="2.0"><channel><title>Feed</title>'
        + "".join(items)
        + "</channel></rss>"
    ).encode()


class ParseFeedTests(unittest.TestCase):
    def test_item_with_guid(self) -> None:
        xml = rss(
            "<item><guid>g1</guid><title> Hello </title><link>https://a.example/1</link>"
            "<pubDate>Sun, 01 Mar 2026 12:00:00 +0100</pubDate></item>"
        )
        self.assertEqual(
            parse_feed(xml),
            [
                Entry(
                    guid="g1",
                    title="Hello",
                    link="https://a.example/1",
                    published=datetime(2026, 3, 1, 11, 0, tzinfo=timezone.utc),
                )
            ],
        )

    def test_item_without_guid_is_identified_by_its_link(self) -> None:
        [only] = parse_feed(rss("<item><title>T</title><link>https://a.example/1</link></item>"))
        self.assertEqual(only.guid, "https://a.example/1")

    def test_item_with_neither_guid_nor_link_is_skipped(self) -> None:
        entries = parse_feed(rss("<item><title>orphan</title></item>", "<item><guid>g2</guid></item>"))
        self.assertEqual([e.guid for e in entries], ["g2"])

    def test_an_identity_repeated_in_one_document_is_kept_once(self) -> None:
        entries = parse_feed(rss("<item><guid>g1</guid><title>first</title></item>", "<item><guid>g1</guid></item>"))
        self.assertEqual([(e.guid, e.title) for e in entries], [("g1", "first")])

    def test_missing_or_unreadable_pub_date_is_none(self) -> None:
        entries = parse_feed(rss("<item><guid>a</guid></item>", "<item><guid>b</guid><pubDate>yesterday-ish</pubDate></item>"))
        self.assertEqual([e.published for e in entries], [None, None])

    def test_channel_without_items_is_empty(self) -> None:
        self.assertEqual(parse_feed(rss()), [])

    def test_atom_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse_feed(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>x</title></feed>')

    def test_rss_root_without_channel_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse_feed(b'<rss version="2.0"></rss>')

    def test_html_page_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse_feed(b"<html><body><p>502 Bad Gateway<br></body></html>")

    def test_empty_body_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse_feed(b"")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.parse'`.

- [ ] **Step 4: Write the implementation**

`feedwatch/parse.py`:

```python
import email.utils
from datetime import datetime, timezone
from xml.etree import ElementTree

from feedwatch.errors import NotRssError
from feedwatch.models import Entry


def parse_feed(xml: bytes) -> list[Entry]:
    """The entries of an RSS document, each identity once. Raises NotRssError for anything that is not RSS."""
    try:
        root = ElementTree.fromstring(xml)
    except ElementTree.ParseError as e:
        raise NotRssError(f"not well-formed XML: {e}") from e
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise NotRssError(f"a <{root.tag}> document is not an RSS feed")
    entries: dict[str, Entry] = {}
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        # Without a guid or a link the item cannot be recognised on the next poll.
        if guid is None:
            continue
        entries.setdefault(guid, Entry(guid=guid, title=_text(item, "title"), link=link, published=_published(item)))
    return list(entries.values())


def _text(item: ElementTree.Element, tag: str) -> str | None:
    element = item.find(tag)
    text = "" if element is None or element.text is None else element.text.strip()
    return text or None


def _published(item: ElementTree.Element) -> datetime | None:
    raw = _text(item, "pubDate")
    parts = None if raw is None else email.utils.parsedate_tz(raw)
    # An unreadable date counts as absent: the entry is still stored and sorts by when it was first seen.
    if parts is None:
        return None
    return datetime.fromtimestamp(email.utils.mktime_tz(parts), tz=timezone.utc)
```

`xml.etree` in Python 3.11 does not resolve external entities, and the bundled expat (≥ 2.4.1) limits entity expansion, so `defusedxml` is not needed; the spec's standard-library constraint rules it out anyway.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 10 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/errors.py feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS documents into entries"
```

---

### Task 4: Fetch a feed

**Files:**
- Create: `feedwatch/fetch.py`
- Modify: `feedwatch/errors.py` (append `FetchError`)
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: Task 3's `FeedError`.
- Produces:
  - `feedwatch.errors.FetchError(FeedError)`.
  - `feedwatch.fetch.fetch_feed(url: str) -> bytes` — raises `FetchError` with a message naming `url`. Matches the `Callable[[str], bytes]` that `poller.poll_due` takes.

- [ ] **Step 1: Add the error**

Append to `feedwatch/errors.py`:

```python
class FetchError(FeedError):
    pass
```

- [ ] **Step 2: Write the failing tests**

`file://` URLs exercise the same `urlopen` path as HTTP without a server or thread in the test.

`tests/test_fetch.py`:

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch_feed


class FetchFeedTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)

    def test_returns_the_body(self) -> None:
        path = self.dir / "feed.xml"
        path.write_bytes(b"<rss/>")
        self.assertEqual(fetch_feed(path.as_uri()), b"<rss/>")

    def test_unreachable_url_raises_fetch_error_naming_it(self) -> None:
        url = (self.dir / "missing.xml").as_uri()
        with self.assertRaises(FetchError) as caught:
            fetch_feed(url)
        self.assertIn(url, str(caught.exception))

    def test_malformed_url_raises_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch_feed("not a url")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR — `ModuleNotFoundError: No module named 'feedwatch.fetch'`.

- [ ] **Step 4: Write the implementation**

`feedwatch/fetch.py`:

```python
import http.client
import urllib.request

from feedwatch.errors import FetchError

# The poller is one thread: a feed that never answers would hold up every other feed.
TIMEOUT_SECONDS = 10.0


def fetch_feed(url: str) -> bytes:
    """The body served at url. Raises FetchError when it cannot be downloaded."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1.0"})
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as e:
        raise FetchError(f"could not fetch {url}: {e}") from e
```

`OSError` covers `URLError`, `HTTPError`, timeouts and dropped connections; `ValueError` covers an unknown URL type, which `Request` itself raises, hence its place inside the `try`; `HTTPException` covers a truncated body.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 3 tests, OK.

- [ ] **Step 6: Commit**

```bash
git add feedwatch/errors.py feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feeds over urllib"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `store.connect`, `store.DEFAULT_PATH`, `store.Connection`, `store.list_feeds`, `store.add_entries`, `store.record_poll`, `store.add_feed`, `store.unread` (Tasks 1–2); `parse.parse_feed` and `FeedError` (Task 3); `fetch.fetch_feed` and `FetchError` (Task 4); `Feed` (Task 1).
- Produces:
  - `feedwatch.poller.poll_due(conn: store.Connection, *, now: datetime, fetch_xml: Callable[[str], bytes]) -> None` — one pass over the due feeds.
  - `feedwatch.poller.main() -> None` — the loop; `python -m feedwatch.poller`.
  - Logger name `"feedwatch.poller"`; a skipped feed logs at WARNING with its URL.

- [ ] **Step 1: Write the failing tests**

`tests/test_poller.py`:

```python
import tempfile
import unittest
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import poller, store
from feedwatch.errors import FetchError

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{g}</guid><title>{g}</title></item>" for g in guids)
    return f'<rss version="2.0"><channel><title>F</title>{items}</channel></rss>'.encode()


class PollDueTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.conn = store.connect(Path(tmp.name) / "feeds.db")
        self.addCleanup(self.conn.close)
        self.bodies: dict[str, bytes] = {}
        self.fetched: list[str] = []

    def fetch_xml(self, url: str) -> bytes:
        self.fetched.append(url)
        if url not in self.bodies:
            raise FetchError(f"could not fetch {url}: connection refused")
        return self.bodies[url]

    def poll(self, now: datetime) -> None:
        poller.poll_due(self.conn, now=now, fetch_xml=self.fetch_xml)

    def unread_guids(self) -> list[str]:
        return sorted(item.entry.guid for item in store.unread(self.conn, 100))

    def test_a_new_feed_is_polled_and_its_entries_stored(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        self.bodies["https://a.example/rss"] = rss("1", "2")
        self.poll(NOW)
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_a_feed_is_polled_again_only_when_its_interval_is_up(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        self.bodies["https://a.example/rss"] = rss("1")
        self.poll(NOW)
        self.poll(NOW + timedelta(minutes=29))
        self.assertEqual(len(self.fetched), 1)
        self.bodies["https://a.example/rss"] = rss("1", "2")
        self.poll(NOW + timedelta(minutes=30))
        self.assertEqual(len(self.fetched), 2)
        self.assertEqual(self.unread_guids(), ["1", "2"])

    def test_unreachable_and_non_rss_feeds_are_logged_and_others_still_polled(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://html.example/", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://ok.example/rss", title=None, every_minutes=30)
        self.bodies["https://html.example/"] = b"<html><body>Not found<br></body></html>"
        self.bodies["https://ok.example/rss"] = rss("1")
        with self.assertLogs("feedwatch.poller", level="WARNING") as logs:
            self.poll(NOW)
        warnings = "\n".join(logs.output)
        self.assertIn("https://down.example/rss", warnings)
        self.assertIn("https://html.example/", warnings)
        self.assertEqual(self.unread_guids(), ["1"])

    def test_a_failed_feed_waits_its_interval_before_the_next_attempt(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        with self.assertLogs("feedwatch.poller", level="WARNING"):
            self.poll(NOW)
        self.poll(NOW + timedelta(minutes=10))
        self.assertEqual(self.fetched, ["https://down.example/rss"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR — `ImportError: cannot import name 'poller' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`feedwatch/poller.py`:

```python
import logging
import time
from collections.abc import Callable
from contextlib import closing
from datetime import datetime, timedelta, timezone

from feedwatch import fetch, parse, store
from feedwatch.errors import FeedError
from feedwatch.models import Feed

log = logging.getLogger("feedwatch.poller")

TICK_SECONDS = 60


def poll_due(conn: store.Connection, *, now: datetime, fetch_xml: Callable[[str], bytes]) -> None:
    """Poll each feed whose interval is up at now and store the entries it has not seen before."""
    for feed in store.list_feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            entries = parse.parse_feed(fetch_xml(feed.url))
        except FeedError as e:
            log.warning("skipping %s until its next interval: %s", feed.url, e)
        else:
            added = store.add_entries(conn, entries, feed_id=feed.id, seen_at=now)
            log.info("%s: %d new entries", feed.url, added)
        # A failed attempt counts as a poll, so a broken feed waits its interval instead of retrying every tick.
        store.record_poll(conn, feed.id, at=now)


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled_at is None or now - feed.last_polled_at >= timedelta(minutes=feed.every_minutes)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with closing(store.connect(store.DEFAULT_PATH)) as conn:
        try:
            while True:
                poll_due(conn, now=datetime.now(timezone.utc), fetch_xml=fetch.fetch_feed)
                time.sleep(TICK_SECONDS)
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
```

A database error is not a `FeedError`, so it propagates out of `main` and stops the poller, as `ARCHITECTURE.md` requires.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 4 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poll due feeds and skip the ones that fail"
```

---

### Task 6: The command line, and an end-to-end check

**Files:**
- Create: `feedwatch/cli.py`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.DEFAULT_PATH`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.list_feeds`, `store.add_entries` (Tasks 1–2); `FeedwatchError`, `UnreadEntry`, `Entry`.
- Produces:
  - `feedwatch.cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int` — exit status: 0 on success, 1 when a command is refused (message on stderr, prefixed `feedwatch: `); argparse usage errors exit 2 via `SystemExit`.
  - Output of `unread`, per entry: `<local YYYY-MM-DD HH:MM or "undated">  <feed_name>: <title or "(untitled)">` then an indented line with the guid (the value `read` takes), then an indented line with the link when it differs from the guid. With nothing unread: `no unread entries`.

- [ ] **Step 1: Write the failing tests**

`tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import cli, store
from feedwatch.models import Entry

NOW = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class CliTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.db = Path(tmp.name) / "feeds.db"

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = cli.main(list(argv), db_path=self.db)
        return status, out.getvalue(), err.getvalue()

    def seed(self, count: int) -> None:
        conn = store.connect(self.db)
        self.addCleanup(conn.close)
        feed = store.add_feed(conn, "https://a.example/rss", title="A", every_minutes=30)
        entries = [
            Entry(guid=f"g{i}", title=f"T{i}", link=f"https://a.example/{i}", published=NOW + timedelta(minutes=i))
            for i in range(count)
        ]
        store.add_entries(conn, entries, feed_id=feed.id, seen_at=NOW)

    def stored_feeds(self) -> list[tuple[str, str | None, int]]:
        conn = store.connect(self.db)
        self.addCleanup(conn.close)
        return [(f.url, f.title, f.every_minutes) for f in store.list_feeds(conn)]

    def guid_lines(self, out: str) -> list[str]:
        return [line.strip() for line in out.splitlines() if line.strip().startswith("g")]

    def test_add_subscribes_every_30_minutes_by_default(self) -> None:
        status, out, _ = self.run_cli("add", "https://a.example/rss")
        self.assertEqual(status, 0)
        self.assertIn("https://a.example/rss", out)
        self.assertEqual(self.stored_feeds(), [("https://a.example/rss", None, 30)])

    def test_add_with_title_and_interval(self) -> None:
        self.run_cli("add", "https://a.example/rss", "--title", "A", "--every", "5")
        self.assertEqual(self.stored_feeds(), [("https://a.example/rss", "A", 5)])

    def test_adding_a_subscribed_url_is_refused_naming_it(self) -> None:
        self.run_cli("add", "https://a.example/rss")
        status, _, err = self.run_cli("add", "https://a.example/rss")
        self.assertEqual(status, 1)
        self.assertIn("https://a.example/rss", err)

    def test_non_positive_every_or_limit_is_a_usage_error(self) -> None:
        for argv in (["add", "https://a.example/rss", "--every", "0"], ["add", "https://a.example/rss", "--every", "-5"], ["unread", "--limit", "0"]):
            with self.subTest(argv=argv), self.assertRaises(SystemExit) as caught:
                self.run_cli(*argv)
            self.assertEqual(caught.exception.code, 2)
        self.assertFalse(self.db.exists())

    def test_unread_lists_20_newest_first_by_default(self) -> None:
        self.seed(25)
        status, out, _ = self.run_cli("unread")
        self.assertEqual(status, 0)
        self.assertEqual(self.guid_lines(out), [f"g{i}" for i in range(24, 4, -1)])
        self.assertIn("A: T24", out)

    def test_unread_honours_limit(self) -> None:
        self.seed(5)
        _, out, _ = self.run_cli("unread", "--limit", "2")
        self.assertEqual(self.guid_lines(out), ["g4", "g3"])

    def test_unread_with_nothing_unread_says_so(self) -> None:
        _, out, _ = self.run_cli("unread")
        self.assertEqual(out.strip(), "no unread entries")

    def test_read_marks_entries_read(self) -> None:
        self.seed(3)
        status, _, _ = self.run_cli("read", "g0", "g2")
        self.assertEqual(status, 0)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(self.guid_lines(out), ["g1"])

    def test_read_with_an_unknown_guid_is_refused_and_marks_nothing(self) -> None:
        self.seed(1)
        status, _, err = self.run_cli("read", "g0", "nope")
        self.assertEqual(status, 1)
        self.assertIn("nope", err)
        _, out, _ = self.run_cli("unread")
        self.assertEqual(self.guid_lines(out), ["g0"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR — `ImportError: cannot import name 'cli' from 'feedwatch'`.

- [ ] **Step 3: Write the implementation**

`feedwatch/cli.py`:

```python
import argparse
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import UnreadEntry


def main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH) -> int:
    """Run one feedwatch command and return its exit status."""
    parser = _parser()
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        parser.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        parser.error("--limit must be at least 1")
    with closing(store.connect(db_path)) as conn:
        try:
            if args.command == "add":
                feed = store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
                print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes")
            elif args.command == "unread":
                items = store.unread(conn, args.limit)
                print("\n".join(_format(item) for item in items) if items else "no unread entries")
            else:
                store.mark_read(conn, args.guids)
        except FeedwatchError as e:
            print(f"feedwatch: {e}", file=sys.stderr)
            return 1
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _format(item: UnreadEntry) -> str:
    entry = item.entry
    when = "undated" if entry.published is None else entry.published.astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [f"{when}  {item.feed_name}: {entry.title or '(untitled)'}", f"    {entry.guid}"]
    if entry.link is not None and entry.link != entry.guid:
        lines.append(f"    {entry.link}")
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 9 tests, OK.

- [ ] **Step 5: Run the whole suite**

Run: `python -m unittest discover -s tests -t . -v`
Expected: 37 tests, OK.

- [ ] **Step 6: End-to-end check against a real database and a `file://` feed**

`HOME` points at a scratch directory so `~/.feedwatch/feeds.db` is created there, not in the real home.

```bash
SMOKE=$(mktemp -d)
cat > "$SMOKE/feed.xml" <<'EOF'
<?xml version="1.0"?>
<rss version="2.0"><channel><title>Smoke</title>
<item><guid>smoke-1</guid><title>It works</title><pubDate>Sun, 01 Mar 2026 12:00:00 +0000</pubDate></item>
</channel></rss>
EOF
HOME="$SMOKE" python -m feedwatch.cli add "file://$SMOKE/feed.xml" --title Smoke
HOME="$SMOKE" timeout 3 python -m feedwatch.poller; echo "poller exit $?"
HOME="$SMOKE" python -m feedwatch.cli unread
HOME="$SMOKE" python -m feedwatch.cli read smoke-1
HOME="$SMOKE" python -m feedwatch.cli unread
HOME="$SMOKE" python -m feedwatch.cli read smoke-1 nope; echo "read exit $?"
ls "$SMOKE/.feedwatch/feeds.db"
```

Expected: `subscribed to file://…/feed.xml, polled every 30 minutes`; an INFO log line `…/feed.xml: 1 new entries` and `poller exit 124` (killed by `timeout`); then `… Smoke: It works` with `    smoke-1` beneath it; after `read`, `no unread entries`; then `feedwatch: no stored entry with guid nope` and `read exit 1`; the database file exists.

If `pip` can reach an index, also check the console script: `python -m venv "$SMOKE/venv" && "$SMOKE/venv/bin/pip" install -e . && HOME="$SMOKE" "$SMOKE/venv/bin/feedwatch" unread` — expected `no unread entries`.

- [ ] **Step 7: Check the added lines against `docs/PROGRAM-DESIGN.md`**

Run each rule's check from Global Constraints over `git diff <base>...HEAD -- feedwatch/`. Quick greps for the mechanical ones, each expected to print nothing:

```bash
git grep -nE 'sqlite3|conn\.' -- feedwatch/ ':!feedwatch/store.py' | grep -v 'store\.'
git grep -n 'urllib' -- feedwatch/ ':!feedwatch/fetch.py'
git grep -nE 'feedwatch(\.| import .*)(cli|poller)\b' -- feedwatch/
git grep -nE 'threading\.Thread|asyncio|multiprocessing' -- feedwatch/
git grep -nE '^from feedwatch|^import feedwatch' -- feedwatch/models.py feedwatch/errors.py
```

- [ ] **Step 8: Commit**

```bash
git add feedwatch/cli.py tests/test_cli.py
git commit -m "feat: feedwatch add, unread and read commands"
```
````


## p014

#### Final message

The implementation plan is written and committed as `5a5b374` ("plan: feedwatch v1"), at `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md`. Nothing is implemented in the repository.

**The plan.** It has six test-first tasks in the `feedwatch/` package:
1. `parse`, plus the `Entry` model and the base errors.
2. `fetch`.
3. `store` for subscriptions.
4. `store` for entries: unread and read.
5. `poller`.
6. `cli`, plus `pyproject.toml` and an end-to-end smoke test.

It uses Python 3.11 and the standard library only, with `unittest` for tests.

**Program design.** Every rule in `PROGRAM-DESIGN.md` is copied into Global Constraints with its check. The document left no structural choice open for this plan, so I had no question for you. Where the plan had to interpret a rule, it says so in Global Constraints:
- **No thread pool in v1.** The poller fetches due feeds one after another, and a 30-second fetch timeout limits how long one feed can hold up the rest.
- **Only `store.py` imports `sqlite3`.** Other modules annotate a connection as `store.Connection`.
- **No `except` for bad dates.** An unreadable `pubDate` is handled without one, because the Errors rule forbids one there.
- **Out-of-range options.** `--every` or `--limit` below 1 is refused as a usage error.
- **Stdlib XML.** The plan uses the standard library parser rather than `defusedxml`, to keep to the standard library. Its built-in protections are noted there.

**Review Focus.** The five inputs most likely to bite are listed, and each has a test in the task that owns the code:
- an item with no guid, or with neither guid nor link;
- a missing or unreadable date;
- `feedwatch read` with one unknown guid, which marks nothing;
- `--every` or `--limit` below 1;
- a first run with no `~/.feedwatch` directory.

**Checked outside the repo.** I built the plan's code in a scratch directory and the full suite passed: 49 tests. A manual run of the two processes against a local feed file also worked. I could not check the `pip install -e .` step for the `feedwatch` command, because this machine can't create a virtual environment.

**Closing step.** I also ran `dopamine:finishing-work`. It added a reconstructed ledger beside the plan (`2026-10-12-feedwatch-v1.reconstructed-ledger.md`) and a commit, "sweep: … nothing to drain", with the line counts. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist, and I did not create it.

Please review the plan and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller process that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** One package, `feedwatch/`, holding the five components of `docs/ARCHITECTURE.md` (`fetch`, `parse`, `store`, `poller`, `cli`) plus `models` (frozen dataclasses) and `errors` (the `FeedwatchError` hierarchy). `poller` and `cli` sit on top and call the others; `fetch`, `parse` and `store` import only `models` and `errors`. The poller polls due feeds one after another on its single thread, waking once a minute.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `argparse`, `logging`, `unittest`). `setuptools` only as the build backend that installs the `feedwatch` command.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Also read `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md`.

## Global Constraints

From the spec, `DESIGN.md` and `ARCHITECTURE.md`:

- Python 3.11, standard library. No runtime dependency; `pyproject.toml` declares `dependencies = []`.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`; the interval defaults to 30 minutes. Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries, newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores the entries it has not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- One SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`; `store` is authoritative for both, and an existing database has to keep working.
- Out of scope: Atom feeds; importing or exporting subscription lists. Do not add them.

From `docs/PROGRAM-DESIGN.md`, every rule with its check. Each check is applied to every added line, tests included:

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects (inherited default).** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Effects.** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout (inherited default).** Split by responsibility, not technical layer; files that change together live together.
- **Layout.** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

How this plan applies them:

- Callers outside `store` annotate a connection as `store.Connection`, so only `store.py` imports `sqlite3`; tests close connections with `contextlib.closing`, never `conn.close()`.
- No executor in v1: the poller fetches due feeds in turn, and `fetch`'s 30-second timeout bounds how long one feed holds up the rest. The tests start their HTTP server as a subprocess, not a thread.
- `Entry.published is None` means the item states no readable date. It is a value the store sorts by, not a failure signal.
- A malformed `pubDate` is handled without an `except`. `email.utils.parsedate_tz` returns `None` for unreadable text, and `calendar.timegm` rolls out-of-range fields over instead of raising.
- `--every` and `--limit` below 1 are refused with `ArgumentParser.error` (usage message, exit status 2), not a `raise`.
- XML is parsed with the standard library's `xml.etree.ElementTree`, not `defusedxml`, because the project uses the standard library only. Its expat parser does not fetch external entities. Python 3.11's bundled expat (2.4.1 or later) also limits entity expansion ("billion laughs").
- Tests use `unittest` and run with `python -m unittest discover -s tests -v` from the repository root.

## Review Focus

- **An item with no `<guid>`, or with neither guid nor link.** The link stands in for a missing guid. An item with neither is left out and the rest of the feed is still stored. Tests in Task 1.
- **A missing, empty or unreadable `<pubDate>`, including out-of-range fields or a five-digit year.** The entry is still stored and is ordered by when it was first stored. A bad date never stops a feed or crashes the poller. Tests in Task 1 and Task 4.
- **`feedwatch read` with several guids, one of them unknown.** Nothing is marked, the exit status is 1, and the message names only the unknown guid. Tests in Task 4 and Task 6.
- **`--every 0`, a negative `--every`, or `--limit 0`.** Refused as a usage error before anything is written. Tests in Task 6.
- **The first command on a machine with no `~/.feedwatch` directory.** The directory and database are created. Tests in Task 3.

## File Structure

| File | Responsibility |
|---|---|
| `feedwatch/__init__.py` | Empty; marks the package. |
| `feedwatch/models.py` | `Entry`, `Feed`, `UnreadEntry`: frozen dataclasses. |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses. |
| `feedwatch/parse.py` | `parse(xml) -> list[Entry]`: RSS 2.0 only. |
| `feedwatch/fetch.py` | `fetch(url, timeout) -> bytes`: HTTP via `urllib`. |
| `feedwatch/store.py` | `connect`, `SCHEMA_STEPS`, and the module functions on `feeds` and `entries`. |
| `feedwatch/poller.py` | `poll_due` and the `main` loop behind `python -m feedwatch.poller`. |
| `feedwatch/cli.py` | `main(argv, db_path) -> int` and the `run` console-script entry point. |
| `pyproject.toml` | Package metadata and the `feedwatch` script. |
| `tests/test_parse.py`, `tests/test_fetch.py`, `tests/test_store_feeds.py`, `tests/test_store_entries.py`, `tests/test_poller.py`, `tests/test_cli.py` | One test module per unit of behaviour. |

---

### Task 1: Parse RSS into entries

**Files:**
- Create: `feedwatch/__init__.py` (empty)
- Create: `feedwatch/models.py`
- Create: `feedwatch/errors.py`
- Create: `feedwatch/parse.py`
- Test: `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.models.Entry(guid: str, title: str, link: str | None, published: datetime | None)`, frozen. `published` is aware and in UTC.
  - `feedwatch.errors.FeedwatchError(Exception)`, `FeedUnavailable(FeedwatchError)`, `NotRSS(FeedUnavailable)`.
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]`, in document order; raises `NotRSS`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_parse.py`:

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import NotRSS
from feedwatch.models import Entry
from feedwatch.parse import parse


def rss(*items: str) -> bytes:
    return (
        "<?xml version='1.0'?><rss version='2.0'><channel><title>Example</title>"
        + "".join(items)
        + "</channel></rss>"
    ).encode()


class ParseTest(unittest.TestCase):
    def test_reads_guid_title_link_and_date_in_utc(self) -> None:
        [entry] = parse(rss(
            "<item><guid> g1 </guid><title>One</title><link>https://example.com/1</link>"
            "<pubDate>Tue, 10 Mar 2026 10:00:00 +0100</pubDate></item>"
        ))
        self.assertEqual(
            entry,
            Entry(
                guid="g1",
                title="One",
                link="https://example.com/1",
                published=datetime(2026, 3, 10, 9, 0, tzinfo=timezone.utc),
            ),
        )

    def test_keeps_document_order(self) -> None:
        entries = parse(rss("<item><guid>a</guid></item>", "<item><guid>b</guid></item>"))
        self.assertEqual([entry.guid for entry in entries], ["a", "b"])

    def test_an_item_without_a_guid_is_identified_by_its_link(self) -> None:
        [entry] = parse(rss("<item><link>https://example.com/2</link></item>"))
        self.assertEqual(entry.guid, "https://example.com/2")

    def test_an_item_with_neither_guid_nor_link_is_left_out_and_the_rest_kept(self) -> None:
        entries = parse(rss("<item><title>Nameless</title></item>", "<item><guid>g2</guid></item>"))
        self.assertEqual([entry.guid for entry in entries], ["g2"])

    def test_an_item_without_a_title_is_untitled(self) -> None:
        [entry] = parse(rss("<item><guid>g</guid></item>"))
        self.assertEqual(entry.title, "(untitled)")

    def test_a_missing_or_unreadable_date_is_none(self) -> None:
        for date in (
            "",
            "<pubDate></pubDate>",
            "<pubDate>yesterday</pubDate>",
            "<pubDate>Tue, 10 Mar 99999 10:00:00 GMT</pubDate>",
        ):
            with self.subTest(date=date):
                [entry] = parse(rss(f"<item><guid>g</guid>{date}</item>"))
                self.assertIsNone(entry.published)

    def test_out_of_range_date_fields_roll_over(self) -> None:
        [entry] = parse(rss("<item><guid>g</guid><pubDate>Mon, 31 Feb 2026 25:00:00 +0000</pubDate></item>"))
        self.assertEqual(entry.published, datetime(2026, 3, 4, 1, 0, tzinfo=timezone.utc))

    def test_a_date_without_a_zone_is_utc(self) -> None:
        [entry] = parse(rss("<item><guid>g</guid><pubDate>Tue, 10 Mar 2026 10:00:00</pubDate></item>"))
        self.assertEqual(entry.published, datetime(2026, 3, 10, 10, 0, tzinfo=timezone.utc))

    def test_malformed_xml_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse(b"<rss><channel>")

    def test_an_html_page_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse(b"<html><body>Moved</body></html>")

    def test_an_atom_feed_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse(b"<feed xmlns='http://www.w3.org/2005/Atom'><title>x</title></feed>")

    def test_rss_without_a_channel_is_not_rss(self) -> None:
        with self.assertRaises(NotRSS):
            parse(b"<rss version='2.0'/>")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_parse -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch'`.

- [ ] **Step 3: Write minimal implementation**

Create `feedwatch/__init__.py` as an empty file.

Create `feedwatch/models.py`:

```python
"""Feedwatch's domain values."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Entry:
    """One feed item. `guid` is the item's guid, or its link when it has none.

    `published` is in UTC, or None when the item states no readable date.
    """

    guid: str
    title: str
    link: str | None
    published: datetime | None
```

Create `feedwatch/errors.py`:

```python
"""Every failure feedwatch raises. Only `poller` and `cli` catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class FeedUnavailable(FeedwatchError):
    """A feed could not be polled this time; the poller skips it until its next interval."""


class NotRSS(FeedUnavailable):
    """The document is not well-formed XML with an `<rss>` root holding a `<channel>`."""
```

Create `feedwatch/parse.py`:

```python
"""Turns RSS 2.0 XML into entries."""

import calendar
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_tz

from feedwatch.errors import NotRSS
from feedwatch.models import Entry

_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
# parsedate_tz accepts any year; datetime holds only years 1 to 9999.
_YEARS = range(1900, 9999)


def parse(xml: bytes) -> list[Entry]:
    """Return the entries of an RSS document, in document order.

    An item with neither a guid nor a link is left out: nothing identifies it.
    Raises NotRSS when `xml` is not well-formed or its root is not `<rss>` holding a `<channel>`.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        raise NotRSS(f"not well-formed XML: {error}") from error
    channel = root.find("channel") if root.tag == "rss" else None
    if channel is None:
        raise NotRSS(f"root element is <{root.tag}>, not <rss> holding a <channel>")
    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            Entry(
                guid=guid,
                title=_text(item, "title") or "(untitled)",
                link=link,
                published=_published(_text(item, "pubDate")),
            )
        )
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    text = (item.findtext(tag) or "").strip()
    return text or None


def _published(value: str | None) -> datetime | None:
    fields = parsedate_tz(value) if value else None
    if fields is None or fields[0] not in _YEARS:
        return None
    # timegm rolls out-of-range days and hours over instead of raising; a date with no zone is read as UTC.
    seconds = calendar.timegm(fields[:6] + (0, 0, 0)) - (fields[9] or 0)
    return _EPOCH + timedelta(seconds=seconds)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_parse -v`
Expected: 12 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/__init__.py feedwatch/models.py feedwatch/errors.py feedwatch/parse.py tests/test_parse.py
git commit -m "feat: parse RSS 2.0 into entries"
```

---

### Task 2: Fetch a feed's XML

**Files:**
- Modify: `feedwatch/errors.py` (append one class)
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FeedUnavailable` (Task 1).
- Produces:
  - `feedwatch.errors.FetchFailed(FeedUnavailable)`.
  - `feedwatch.fetch.fetch(url: str, timeout: float = 30.0) -> bytes`; raises `FetchFailed`, with the URL in its message.

- [ ] **Step 1: Write the failing test**

Create `tests/test_fetch.py`. The HTTP server runs as a subprocess so the tests start no threads of their own (Concurrency rule):

```python
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from feedwatch.errors import FetchFailed
from feedwatch.fetch import fetch


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def wait_until_listening(port: int) -> None:
    # Gives up after five seconds; the tests that need the server then fail on their own.
    for _ in range(100):
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", port)) == 0:
                return
        time.sleep(0.05)


class FetchTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        directory = cls.enterClassContext(tempfile.TemporaryDirectory())
        Path(directory, "feed.xml").write_bytes(b"<rss version='2.0'/>")
        port = free_port()
        # A separate process, so the test needs no threads of its own.
        server = subprocess.Popen(
            [sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1", "--directory", directory],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        cls.addClassCleanup(server.wait)
        cls.addClassCleanup(server.terminate)
        wait_until_listening(port)
        cls.base = f"http://127.0.0.1:{port}"

    def test_returns_the_body(self) -> None:
        self.assertEqual(fetch(f"{self.base}/feed.xml"), b"<rss version='2.0'/>")

    def test_an_error_status_is_a_fetch_failure_naming_the_url(self) -> None:
        url = f"{self.base}/missing.xml"
        with self.assertRaises(FetchFailed) as caught:
            fetch(url)
        self.assertIn(url, str(caught.exception))

    def test_a_refused_connection_is_a_fetch_failure(self) -> None:
        with self.assertRaises(FetchFailed):
            fetch(f"http://127.0.0.1:{free_port()}/feed.xml")

    def test_a_server_that_never_answers_is_a_fetch_failure(self) -> None:
        with socket.socket() as silent:
            silent.bind(("127.0.0.1", 0))
            silent.listen()
            with self.assertRaises(FetchFailed):
                fetch(f"http://127.0.0.1:{silent.getsockname()[1]}/feed.xml", timeout=0.5)

    def test_a_malformed_url_is_a_fetch_failure(self) -> None:
        with self.assertRaises(FetchFailed):
            fetch("not a url")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_fetch -v`
Expected: ERROR with `ImportError: cannot import name 'FetchFailed' from 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/errors.py`:

```python


class FetchFailed(FeedUnavailable):
    """The feed's URL could not be downloaded."""
```

Create `feedwatch/fetch.py`:

```python
"""Downloads a feed's XML; the only module that touches the network."""

import http.client
import urllib.request

from feedwatch.errors import FetchFailed

USER_AGENT = "feedwatch/1.0"


def fetch(url: str, timeout: float = 30.0) -> bytes:
    """Return the body served at `url`.

    Raises FetchFailed when the URL is malformed, the server cannot be reached,
    answers with an error status, or sends nothing for `timeout` seconds.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except (OSError, ValueError, http.client.HTTPException) as error:
        raise FetchFailed(f"{url}: {error}") from error
```

`OSError` covers `URLError`, `HTTPError`, refused connections and `TimeoutError`; `ValueError` is what `Request` raises for a malformed URL.

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_fetch -v`
Expected: 5 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/errors.py feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch a feed's XML over HTTP"
```

---

### Task 3: Store subscriptions

**Files:**
- Modify: `feedwatch/models.py` (append `Feed`)
- Modify: `feedwatch/errors.py` (append `AlreadySubscribed`)
- Create: `feedwatch/store.py`
- Test: `tests/test_store_feeds.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FeedwatchError` (Task 1).
- Produces:
  - `feedwatch.models.Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)`, frozen.
  - `feedwatch.errors.AlreadySubscribed(FeedwatchError)`, built as `AlreadySubscribed(url: str)`, with `.url`. Its message is `already subscribed to <url>`.
  - `feedwatch.store.Connection`: the type callers annotate a connection with.
  - `feedwatch.store.DEFAULT_PATH: Path`, which is `~/.feedwatch/feeds.db`.
  - `feedwatch.store.SCHEMA_STEPS: tuple[str, ...]`
  - `feedwatch.store.connect(path: Path) -> Connection`
  - `feedwatch.store.add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed`; raises `AlreadySubscribed`.
  - `feedwatch.store.feeds(conn: Connection) -> list[Feed]`, oldest subscription first.
  - `feedwatch.store.mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None`

- [ ] **Step 1: Write the failing test**

Create `tests/test_store_feeds.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribed
from feedwatch.models import Feed

T0 = datetime(2026, 3, 10, 12, 0, tzinfo=timezone.utc)


class StoreFeedsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.conn = self.enterContext(closing(store.connect(self.directory / "feeds.db")))

    def test_a_new_feed_is_listed(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        self.assertEqual(
            feed,
            Feed(id=feed.id, url="https://a.example/rss", title="A", every_minutes=30, last_polled=None),
        )
        self.assertEqual(store.feeds(self.conn), [feed])

    def test_subscribing_to_a_subscribed_url_is_refused_naming_it(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribed) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=5)
        self.assertIn("https://a.example/rss", str(caught.exception))
        self.assertEqual(len(store.feeds(self.conn)), 1)

    def test_mark_polled_records_the_time_on_that_feed_only(self) -> None:
        a = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        b = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)
        store.mark_polled(self.conn, a.id, at=T0)
        self.assertEqual(
            [feed.last_polled for feed in store.feeds(self.conn)],
            [T0, None],
        )
        self.assertEqual(store.feeds(self.conn)[1].id, b.id)

    def test_connect_creates_a_missing_directory(self) -> None:
        path = self.directory / "home" / ".feedwatch" / "feeds.db"
        with closing(store.connect(path)) as conn:
            self.assertEqual(store.feeds(conn), [])
        self.assertTrue(path.exists())

    def test_an_existing_database_keeps_its_feeds(self) -> None:
        path = self.directory / "kept.db"
        with closing(store.connect(path)) as conn:
            store.add_feed(conn, "https://a.example/rss", title=None, every_minutes=30)
        with closing(store.connect(path)) as conn:
            self.assertEqual([feed.url for feed in store.feeds(conn)], ["https://a.example/rss"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_store_feeds -v`
Expected: ERROR with `ImportError: cannot import name 'store' from 'feedwatch'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/models.py`:

```python


@dataclass(frozen=True)
class Feed:
    """A subscription. `last_polled` is None until the poller first reaches it."""

    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None
```

Append to `feedwatch/errors.py`:

```python


class AlreadySubscribed(FeedwatchError):
    """The URL is subscribed to already."""

    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url
```

Create `feedwatch/store.py`:

```python
"""The SQLite database; the only module that touches it."""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribed
from feedwatch.models import Feed

# Callers annotate with this, so that only store imports sqlite3.
Connection = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# The schema only grows: append a new idempotent step, never edit one already here.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
)


def connect(path: Path) -> Connection:
    """Open the database at `path`, creating it and its directory if needed, with its schema up to date."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    with conn:
        for step in SCHEMA_STEPS:
            conn.execute(step)
    return conn


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to `url`. Raises AlreadySubscribed when it is subscribed to already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as error:
        raise AlreadySubscribed(url) from error
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def feeds(conn: Connection) -> list[Feed]:
    """Every subscription, oldest first."""
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id")
    return [
        Feed(
            id=id_,
            url=url,
            title=title,
            every_minutes=every_minutes,
            last_polled=None if last_polled is None else _from_text(last_polled),
        )
        for id_, url, title, every_minutes, last_polled in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    """Record that the feed was polled at `at`, whether or not the poll succeeded."""
    with conn:
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (_to_text(at), feed_id))


def _to_text(moment: datetime) -> str:
    # UTC at whole seconds, so that text order is time order.
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")


def _from_text(text: str) -> datetime:
    return datetime.fromisoformat(text)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_store_feeds -v`
Expected: 5 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store_feeds.py
git commit -m "feat: store subscriptions in SQLite"
```

---

### Task 4: Store entries, list unread, mark read

**Files:**
- Modify: `feedwatch/models.py` (append `UnreadEntry`)
- Modify: `feedwatch/errors.py` (add an import and append `UnknownEntry`)
- Modify: `feedwatch/store.py` (imports, two appended schema steps, three functions)
- Test: `tests/test_store_entries.py`

**Interfaces:**
- Consumes: `Entry` (Task 1); `Connection`, `connect`, `add_feed`, `_to_text`, `_from_text` (Task 3).
- Produces:
  - `feedwatch.models.UnreadEntry(entry: Entry, feed_name: str)`, frozen. `feed_name` is the feed's title, or its URL when it has none.
  - `feedwatch.errors.UnknownEntry(FeedwatchError)`, built as `UnknownEntry(guids: Sequence[str])`, with `.guids: tuple[str, ...]`. Its message is `no stored entry with guid <g1>, <g2>`.
  - `feedwatch.store.add_entries(conn: Connection, feed_id: int, *, entries: Iterable[Entry], seen_at: datetime) -> int`: the number of entries that were new.
  - `feedwatch.store.unread(conn: Connection, limit: int) -> list[UnreadEntry]`, newest first, where an undated entry is dated by its `seen_at`.
  - `feedwatch.store.mark_read(conn: Connection, guids: Sequence[str]) -> None`; raises `UnknownEntry` and then marks nothing.

- [ ] **Step 1: Write the failing test**

Create `tests/test_store_entries.py`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import UnknownEntry
from feedwatch.models import Entry

T0 = datetime(2026, 3, 10, 12, 0, tzinfo=timezone.utc)


def entry(guid: str, published: datetime | None = None) -> Entry:
    return Entry(guid=guid, title=f"Title {guid}", link=None, published=published)


class StoreEntriesTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.conn = self.enterContext(closing(store.connect(directory / "feeds.db")))
        self.a = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        self.b = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)

    def unread_guids(self) -> list[str]:
        return [item.entry.guid for item in store.unread(self.conn, 100)]

    def test_returns_how_many_entries_were_new(self) -> None:
        self.assertEqual(store.add_entries(self.conn, self.a.id, entries=[entry("g1"), entry("g2")], seen_at=T0), 2)
        self.assertEqual(store.add_entries(self.conn, self.a.id, entries=[entry("g2"), entry("g3")], seen_at=T0), 1)

    def test_an_entry_seen_again_is_stored_once(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("g1")], seen_at=T0)
        store.add_entries(self.conn, self.a.id, entries=[entry("g1")], seen_at=T0 + timedelta(hours=1))
        self.assertEqual(self.unread_guids(), ["g1"])

    def test_the_same_guid_in_two_feeds_is_two_entries(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("g1")], seen_at=T0)
        store.add_entries(self.conn, self.b.id, entries=[entry("g1")], seen_at=T0)
        self.assertEqual(self.unread_guids(), ["g1", "g1"])

    def test_unread_lists_newest_first_up_to_the_limit(self) -> None:
        entries = [entry("old", T0 - timedelta(days=2)), entry("new", T0), entry("mid", T0 - timedelta(days=1))]
        store.add_entries(self.conn, self.a.id, entries=entries, seen_at=T0)
        self.assertEqual(self.unread_guids(), ["new", "mid", "old"])
        self.assertEqual([item.entry.guid for item in store.unread(self.conn, 2)], ["new", "mid"])

    def test_an_undated_entry_is_dated_by_when_it_was_first_stored(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("dated", T0)], seen_at=T0)
        store.add_entries(self.conn, self.a.id, entries=[entry("undated")], seen_at=T0 + timedelta(hours=1))
        self.assertEqual(self.unread_guids(), ["undated", "dated"])

    def test_unread_round_trips_the_entry_and_names_its_feed(self) -> None:
        stored = Entry(guid="g1", title="One", link="https://a.example/1", published=T0)
        store.add_entries(self.conn, self.a.id, entries=[stored], seen_at=T0)
        store.add_entries(self.conn, self.b.id, entries=[entry("g2", T0 - timedelta(hours=1))], seen_at=T0)
        [first, second] = store.unread(self.conn, 10)
        self.assertEqual(first.entry, stored)
        self.assertEqual(first.feed_name, "A")
        self.assertEqual(second.feed_name, "https://b.example/rss")

    def test_a_read_entry_is_no_longer_unread(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("g1"), entry("g2")], seen_at=T0)
        store.mark_read(self.conn, ["g1"])
        store.mark_read(self.conn, ["g1"])
        self.assertEqual(self.unread_guids(), ["g2"])

    def test_marking_a_guid_read_marks_it_in_every_feed(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("g1")], seen_at=T0)
        store.add_entries(self.conn, self.b.id, entries=[entry("g1")], seen_at=T0)
        store.mark_read(self.conn, ["g1"])
        self.assertEqual(self.unread_guids(), [])

    def test_an_unstored_guid_is_refused_naming_it_and_nothing_is_marked(self) -> None:
        store.add_entries(self.conn, self.a.id, entries=[entry("g1")], seen_at=T0)
        with self.assertRaises(UnknownEntry) as caught:
            store.mark_read(self.conn, ["g1", "nope"])
        self.assertIn("nope", str(caught.exception))
        self.assertNotIn("g1", str(caught.exception))
        self.assertEqual(self.unread_guids(), ["g1"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_store_entries -v`
Expected: ERROR with `ImportError: cannot import name 'UnknownEntry' from 'feedwatch.errors'`.

- [ ] **Step 3: Write minimal implementation**

Append to `feedwatch/models.py`:

```python


@dataclass(frozen=True)
class UnreadEntry:
    """An unread entry with the name of its feed: its title, or its URL when untitled."""

    entry: Entry
    feed_name: str
```

In `feedwatch/errors.py`, add this import below the module docstring:

```python
from collections.abc import Sequence
```

and append:

```python


class UnknownEntry(FeedwatchError):
    """No stored entry has one of these guids."""

    def __init__(self, guids: Sequence[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = tuple(guids)
```

In `feedwatch/store.py`, replace the imports with:

```python
import sqlite3
from collections.abc import Iterable, Sequence
from datetime import datetime, timezone
from pathlib import Path

from feedwatch.errors import AlreadySubscribed, UnknownEntry
from feedwatch.models import Entry, Feed, UnreadEntry
```

Append two steps to `SCHEMA_STEPS`, after the `feeds` step and leaving it untouched, so the tuple ends:

```python
    """CREATE TABLE IF NOT EXISTS entries (
        id INTEGER PRIMARY KEY,
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        UNIQUE (feed_id, guid)
    )""",
    "CREATE INDEX IF NOT EXISTS entries_by_guid ON entries (guid)",
)
```

Add these functions after `mark_polled`, before `_to_text`:

```python
def add_entries(conn: Connection, feed_id: int, *, entries: Iterable[Entry], seen_at: datetime) -> int:
    """Store the entries this feed has not stored before; return how many were new."""
    rows = [
        (
            feed_id,
            entry.guid,
            entry.title,
            entry.link,
            None if entry.published is None else _to_text(entry.published),
            _to_text(seen_at),
        )
        for entry in entries
    ]
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            rows,
        )
        return conn.total_changes - before


def unread(conn: Connection, limit: int) -> list[UnreadEntry]:
    """The `limit` newest unread entries, newest first.

    An entry without a date is dated by when it was first stored.
    """
    rows = conn.execute(
        """SELECT e.guid, e.title, e.link, e.published, COALESCE(f.title, f.url)
           FROM entries AS e JOIN feeds AS f ON f.id = e.feed_id
           WHERE e.read = 0
           ORDER BY COALESCE(e.published, e.seen_at) DESC, e.id
           LIMIT ?""",
        (limit,),
    )
    return [
        UnreadEntry(
            entry=Entry(
                guid=guid,
                title=title,
                link=link,
                published=None if published is None else _from_text(published),
            ),
            feed_name=feed_name,
        )
        for guid, title, link, published, feed_name in rows
    ]


def mark_read(conn: Connection, guids: Sequence[str]) -> None:
    """Mark read every stored entry, in any feed, whose guid is one of `guids`.

    Raises UnknownEntry, marking nothing, when any of them is not stored.
    """
    wanted = list(dict.fromkeys(guids))
    marks = ", ".join("?" * len(wanted))
    with conn:
        stored = {guid for (guid,) in conn.execute(f"SELECT DISTINCT guid FROM entries WHERE guid IN ({marks})", wanted)}
        unknown = [guid for guid in wanted if guid not in stored]
        if unknown:
            raise UnknownEntry(unknown)
        conn.execute(f"UPDATE entries SET read = 1 WHERE guid IN ({marks})", wanted)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_store_entries tests.test_store_feeds -v`
Expected: 14 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/models.py feedwatch/errors.py feedwatch/store.py tests/test_store_entries.py
git commit -m "feat: store entries once, list unread, mark read"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch.fetch` (Task 2); `parse.parse` (Task 1); `store.Connection`, `store.DEFAULT_PATH`, `store.connect`, `store.feeds`, `store.add_entries`, `store.mark_polled` (Tasks 3–4); `FeedUnavailable` (Task 1); `Feed` (Task 3).
- Produces:
  - `feedwatch.poller.poll_due(conn: store.Connection, *, fetch_xml: Callable[[str], bytes], now: datetime) -> None`
  - `feedwatch.poller.main() -> None`, run by `python -m feedwatch.poller`.
  - Log records on the logger `feedwatch.poller`: a skipped feed at WARNING, with the feed's URL in the message.

- [ ] **Step 1: Write the failing test**

Create `tests/test_poller.py`. `fetch_xml` is passed in, so the test hands it a fake rather than patching `fetch`:

```python
import tempfile
import unittest
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError, FetchFailed
from feedwatch.poller import poll_due

T0 = datetime(2026, 3, 10, 12, 0, tzinfo=timezone.utc)
A = "https://a.example/rss"
B = "https://b.example/rss"


def rss(*guids: str) -> bytes:
    items = "".join(f"<item><guid>{guid}</guid></item>" for guid in guids)
    return f"<rss version='2.0'><channel><title>t</title>{items}</channel></rss>".encode()


class FakeFetch:
    """Serves canned documents by URL, raises canned failures, and records each URL asked for."""

    def __init__(self, responses: dict[str, bytes | FeedwatchError]) -> None:
        self.responses = responses
        self.asked: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.asked.append(url)
        response = self.responses[url]
        if isinstance(response, FeedwatchError):
            raise response
        return response


class PollDueTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.conn = self.enterContext(closing(store.connect(directory / "feeds.db")))

    def subscribe(self, url: str, every: int = 30) -> None:
        store.add_feed(self.conn, url, title=None, every_minutes=every)

    def unread_guids(self) -> list[str]:
        return sorted(item.entry.guid for item in store.unread(self.conn, 100))

    def test_a_new_feed_is_polled_and_its_entries_stored(self) -> None:
        self.subscribe(A)
        poll_due(self.conn, fetch_xml=FakeFetch({A: rss("a1", "a2")}), now=T0)
        self.assertEqual(self.unread_guids(), ["a1", "a2"])

    def test_a_feed_is_polled_again_only_once_its_interval_is_up(self) -> None:
        self.subscribe(A, every=30)
        fake = FakeFetch({A: rss("a1")})
        poll_due(self.conn, fetch_xml=fake, now=T0)
        poll_due(self.conn, fetch_xml=fake, now=T0 + timedelta(minutes=29))
        poll_due(self.conn, fetch_xml=fake, now=T0 + timedelta(minutes=30))
        self.assertEqual(fake.asked, [A, A])

    def test_each_feed_keeps_its_own_interval(self) -> None:
        self.subscribe(A, every=5)
        self.subscribe(B, every=60)
        fake = FakeFetch({A: rss("a1"), B: rss("b1")})
        poll_due(self.conn, fetch_xml=fake, now=T0)
        poll_due(self.conn, fetch_xml=fake, now=T0 + timedelta(minutes=5))
        self.assertEqual(fake.asked, [A, B, A])

    def test_an_entry_seen_on_every_poll_is_stored_once(self) -> None:
        self.subscribe(A, every=1)
        fake = FakeFetch({A: rss("a1")})
        poll_due(self.conn, fetch_xml=fake, now=T0)
        poll_due(self.conn, fetch_xml=fake, now=T0 + timedelta(minutes=1))
        self.assertEqual(self.unread_guids(), ["a1"])

    def test_an_unfetchable_feed_is_logged_and_the_others_still_polled(self) -> None:
        self.subscribe(A)
        self.subscribe(B)
        fake = FakeFetch({A: FetchFailed("connection refused"), B: rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poll_due(self.conn, fetch_xml=fake, now=T0)
        self.assertEqual(self.unread_guids(), ["b1"])
        self.assertIn(A, logs.output[0])

    def test_a_document_that_is_not_rss_is_logged_and_the_others_still_polled(self) -> None:
        self.subscribe(A)
        self.subscribe(B)
        fake = FakeFetch({A: b"<html><body>Moved</body></html>", B: rss("b1")})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poll_due(self.conn, fetch_xml=fake, now=T0)
        self.assertEqual(self.unread_guids(), ["b1"])
        self.assertIn(A, logs.output[0])

    def test_a_failed_feed_waits_for_its_next_interval(self) -> None:
        self.subscribe(A, every=30)
        fake = FakeFetch({A: FetchFailed("timed out")})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poll_due(self.conn, fetch_xml=fake, now=T0)
        poll_due(self.conn, fetch_xml=fake, now=T0 + timedelta(minutes=10))
        self.assertEqual(fake.asked, [A])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_poller -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.poller'`.

- [ ] **Step 3: Write minimal implementation**

Create `feedwatch/poller.py`:

```python
"""The long-running worker: `python -m feedwatch.poller` polls each feed when its interval is up."""

import logging
import time
from collections.abc import Callable
from contextlib import closing
from datetime import datetime, timedelta, timezone

from feedwatch import fetch, parse, store
from feedwatch.errors import FeedUnavailable
from feedwatch.models import Feed

TICK_SECONDS = 60

log = logging.getLogger("feedwatch.poller")


def poll_due(conn: store.Connection, *, fetch_xml: Callable[[str], bytes], now: datetime) -> None:
    """Poll every feed whose interval is up at `now` and store the entries it has not seen before.

    A feed that cannot be fetched or parsed is logged and counts as polled, so it waits for its next interval.
    """
    for feed in store.feeds(conn):
        if not _is_due(feed, now):
            continue
        try:
            entries = parse.parse(fetch_xml(feed.url))
        except FeedUnavailable as error:
            log.warning("skipped %s: %s", feed.url, error)
        else:
            added = store.add_entries(conn, feed.id, entries=entries, seen_at=now)
            log.info("%s: %d new", feed.url, added)
        store.mark_polled(conn, feed.id, at=now)


def _is_due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled is None or now - feed.last_polled >= timedelta(minutes=feed.every_minutes)


def main() -> None:
    """Poll forever, until interrupted. A database error stops the poller."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    with closing(store.connect(store.DEFAULT_PATH)) as conn:
        try:
            while True:
                poll_due(conn, fetch_xml=fetch.fetch, now=datetime.now(timezone.utc))
                time.sleep(TICK_SECONDS)
        except KeyboardInterrupt:
            log.info("stopped")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_poller -v`
Expected: 7 tests, OK.

- [ ] **Step 5: Commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller stores new entries of due feeds"
```

---

### Task 6: The command line

**Files:**
- Create: `feedwatch/cli.py`
- Create: `pyproject.toml`
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.DEFAULT_PATH`, `store.connect`, `store.add_feed`, `store.feeds`, `store.add_entries`, `store.unread`, `store.mark_read` (Tasks 3–4); `FeedwatchError` (Task 1); `Entry`, `Feed`, `UnreadEntry` (Tasks 1, 3, 4).
- Produces:
  - `feedwatch.cli.main(argv: list[str], db_path: Path = store.DEFAULT_PATH) -> int`: 0 on success and 1 on a `FeedwatchError`, whose message goes to stderr as `feedwatch: <message>`. A usage error is `SystemExit(2)` from argparse.
  - `feedwatch.cli.run() -> None`, the console-script entry point `feedwatch`.
  - `unread` prints one line per entry, `<guid>  <feed name>: <title>`, followed by `  <<link>>` when the entry has a link that differs from its guid. With nothing unread it prints `no unread entries`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_cli.py`:

```python
import io
import tempfile
import unittest
from contextlib import closing, redirect_stderr, redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.cli import main
from feedwatch.models import Entry, Feed

T0 = datetime(2026, 3, 10, 12, 0, tzinfo=timezone.utc)
URL = "https://example.com/rss"


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"

    def feedwatch(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = main(list(argv), self.db)
        return status, out.getvalue(), err.getvalue()

    def refused_usage(self, *argv: str) -> None:
        with self.assertRaises(SystemExit) as caught, redirect_stderr(io.StringIO()):
            main(list(argv), self.db)
        self.assertEqual(caught.exception.code, 2)

    def feeds(self) -> list[Feed]:
        with closing(store.connect(self.db)) as conn:
            return store.feeds(conn)

    def store_entries(self, *guids: str) -> None:
        """Store one entry per guid in a feed titled Example, the first guid newest."""
        with closing(store.connect(self.db)) as conn:
            feed = store.add_feed(conn, URL, title="Example", every_minutes=30)
            entries = [
                Entry(guid=guid, title=f"Title {guid}", link=None, published=T0 - timedelta(minutes=age))
                for age, guid in enumerate(guids)
            ]
            store.add_entries(conn, feed.id, entries=entries, seen_at=T0)

    def unread_guids(self) -> list[str]:
        _, out, _ = self.feedwatch("unread")
        return [line.split()[0] for line in out.splitlines()]

    def test_add_subscribes_every_30_minutes_by_default(self) -> None:
        status, out, _ = self.feedwatch("add", URL)
        self.assertEqual(status, 0)
        self.assertIn(URL, out)
        self.assertEqual(self.feeds(), [Feed(id=1, url=URL, title=None, every_minutes=30, last_polled=None)])

    def test_add_takes_a_title_and_an_interval(self) -> None:
        self.feedwatch("add", URL, "--title", "News", "--every", "5")
        [feed] = self.feeds()
        self.assertEqual((feed.title, feed.every_minutes), ("News", 5))

    def test_adding_a_subscribed_url_again_is_refused_naming_it(self) -> None:
        self.feedwatch("add", URL)
        status, _, err = self.feedwatch("add", URL, "--every", "5")
        self.assertEqual(status, 1)
        self.assertIn(URL, err)
        self.assertEqual(len(self.feeds()), 1)

    def test_an_interval_below_one_minute_is_refused(self) -> None:
        for every in ("0", "-5", "soon"):
            with self.subTest(every=every):
                self.refused_usage("add", URL, f"--every={every}")
        self.assertEqual(self.feeds(), [])

    def test_unread_lists_twenty_newest_first_by_default(self) -> None:
        self.store_entries(*[f"g{n:02}" for n in range(25)])
        self.assertEqual(self.unread_guids(), [f"g{n:02}" for n in range(20)])

    def test_unread_takes_a_limit(self) -> None:
        self.store_entries("g1", "g2", "g3", "g4")
        _, out, _ = self.feedwatch("unread", "--limit", "3")
        self.assertEqual(len(out.splitlines()), 3)

    def test_a_limit_below_one_is_refused(self) -> None:
        for limit in ("0", "-1"):
            with self.subTest(limit=limit):
                self.refused_usage("unread", f"--limit={limit}")

    def test_unread_shows_guid_feed_and_title(self) -> None:
        self.store_entries("g1")
        self.assertEqual(self.feedwatch("unread"), (0, "g1  Example: Title g1\n", ""))

    def test_unread_says_when_nothing_is_unread(self) -> None:
        self.assertEqual(self.feedwatch("unread"), (0, "no unread entries\n", ""))

    def test_read_marks_entries_read(self) -> None:
        self.store_entries("g1", "g2", "g3")
        self.assertEqual(self.feedwatch("read", "g1", "g3"), (0, "", ""))
        self.assertEqual(self.unread_guids(), ["g2"])

    def test_reading_an_unstored_guid_is_refused_naming_it_and_marks_nothing(self) -> None:
        self.store_entries("g1")
        status, _, err = self.feedwatch("read", "g1", "nope")
        self.assertEqual(status, 1)
        self.assertIn("nope", err)
        self.assertEqual(self.unread_guids(), ["g1"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_cli -v`
Expected: ERROR with `ModuleNotFoundError: No module named 'feedwatch.cli'`.

- [ ] **Step 3: Write minimal implementation**

Create `feedwatch/cli.py`:

```python
"""The user's commands: `feedwatch add`, `feedwatch unread` and `feedwatch read`."""

import argparse
import sys
from contextlib import closing
from pathlib import Path

from feedwatch import store
from feedwatch.errors import FeedwatchError
from feedwatch.models import UnreadEntry


def main(argv: list[str], db_path: Path = store.DEFAULT_PATH) -> int:
    """Run the command in `argv` against the database at `db_path`; return the exit status."""
    args = _parse(argv)
    with closing(store.connect(db_path)) as conn:
        try:
            if args.command == "add":
                feed = store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
                print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes")
            elif args.command == "unread":
                items = store.unread(conn, args.limit)
                for item in items:
                    print(_line(item))
                if not items:
                    print("no unread entries")
            else:
                store.mark_read(conn, args.guids)
        except FeedwatchError as error:
            print(f"feedwatch: {error}", file=sys.stderr)
            return 1
    return 0


def run() -> None:
    """Console-script entry point for `feedwatch`."""
    sys.exit(main(sys.argv[1:]))


def _parse(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="feedwatch", description="Read your RSS feeds from the command line.")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url", metavar="URL")
    add.add_argument("--title", metavar="TITLE")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES", help="poll interval (default 30)")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N", help="list at most N (default 20)")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    args = parser.parse_args(argv)
    if args.command == "add" and args.every < 1:
        add.error("--every must be at least 1 minute")
    if args.command == "unread" and args.limit < 1:
        unread.error("--limit must be at least 1")
    return args


def _line(item: UnreadEntry) -> str:
    entry = item.entry
    line = f"{entry.guid}  {item.feed_name}: {entry.title}"
    return f"{line}  <{entry.link}>" if entry.link and entry.link != entry.guid else line


if __name__ == "__main__":
    run()
```

Create `pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
description = "Poll RSS feeds into SQLite and read them from the command line."
requires-python = ">=3.11"
dependencies = []

[project.scripts]
feedwatch = "feedwatch.cli:run"

[tool.setuptools]
packages = ["feedwatch"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m unittest tests.test_cli -v`
Expected: 11 tests, OK.

- [ ] **Step 5: Run the whole suite**

Run: `python -m unittest discover -s tests -v`
Expected: 49 tests, OK.

- [ ] **Step 6: Smoke-test the two processes end to end**

Use a throwaway `HOME`, so the real `~/.feedwatch` is untouched. A `file://` feed stands in for a server:

```bash
export HOME=$(mktemp -d)
printf '<rss version="2.0"><channel><title>Local</title><item><guid>local-1</guid><title>Hello</title></item></channel></rss>' > "$HOME/feed.xml"
python -m feedwatch.cli add "file://$HOME/feed.xml" --title Local
timeout 3 python -m feedwatch.poller
python -m feedwatch.cli unread
python -m feedwatch.cli read local-1
python -m feedwatch.cli unread
python -m feedwatch.cli read nope; echo "exit $?"
```

Expected, in order:
- `subscribed to file://…/feed.xml, polled every 30 minutes`
- a poller log line ending `feed.xml: 1 new`, followed by `timeout` killing the poller
- `local-1  Local: Hello`
- `no unread entries`
- `feedwatch: no stored entry with guid nope` and `exit 1`

Where `pip` and network access are available, also check the installed script. Run `python -m pip install -e .`, then `feedwatch --help`; it should list `add`, `unread` and `read`.

- [ ] **Step 7: Commit**

```bash
git add feedwatch/cli.py pyproject.toml tests/test_cli.py
git commit -m "feat: feedwatch command line: add, unread, read"
```

---

After the last task, run `dopamine:finishing-work` before `superpowers:finishing-a-development-branch`.
````

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.reconstructed-ledger.md (added)

````
Reconstructed ledger, written 2026-10-12 from the planning conversation. No superpowers ledger existed: this unit of work wrote a plan and executed none of it.

- Wrote `docs/superpowers/plans/2026-10-12-feedwatch-v1.md` from `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`, and copied every `PROGRAM-DESIGN.md` rule into its Global Constraints along with its check.
- `PROGRAM-DESIGN.md` left no structural choice open for this plan, so no question went to the human. The plan's own application choices are stated in its Global Constraints: no executor in v1, `store.Connection` as the annotation type, and an `except`-free reading of `pubDate`.
- The plan's code was compiled and its 49 tests run in a scratch directory outside the repository. Nothing was implemented in the repository.
- No living-document consequence: the plan does not change what the design, architecture or program design say.
````


## p015

#### Final message

I wrote the implementation plan, saved it to `<repo>/docs/superpowers/plans/2026-10-12-feedwatch-v1.md` and committed it as `ad37360` ("plan: feedwatch v1"). The working tree is clean and no implementation was done.

**Does it work?** Before committing, I applied the plan task by task in a scratch repository. Every "fails first" step failed with the message the plan predicts, every "passes" step passed, and the full suite (38 tests) passes on Python 3.14 and 3.11. The command-line and poller trial runs, and the rule checks in the last task, also gave the expected results.

**The tasks:**
1. Shared types and errors (`models.py`, `errors.py`) and the RSS parser.
2. Fetching a feed, with a 30-second timeout.
3. The store: database tables, `store.connect()` and feeds.
4. The store: saving entries, `unread` and `read`.
5. The poller (`poll_once` takes the fetch function as a parameter so tests can replace it, plus the main loop).
6. The command line and `pyproject.toml`.
7. Run all tests, run the `PROGRAM-DESIGN.md` checks over the branch, then `dopamine:finishing-work`.

**Program design:** Global Constraints lists every rule from `PROGRAM-DESIGN.md` with its check, and I ran each check over the plan's code. No structural choice was left open, so I had no question for you. Notes on how I read three rules:
- **Imports:** the "nothing imports `cli` or `poller`" rule applies to the `feedwatch/` package. Their own test files do import them.
- **Concurrency:** feeds are polled one after another, so there is no thread pool yet. A dead feed holds up the others by at most the 30-second timeout.
- **Error handling:** range checks on arguments run after parsing, so every error raised is a `FeedwatchError`, as the rule requires. For the same reason, an unreadable date uses `parsedate_tz`, which returns `None` instead of raising.

**Choices the spec left open:**
- `store.connect()` opens and closes the connection itself (it is a context manager), so no module outside `store` touches the connection.
- `read GUID` marks that guid in every feed that has it. If any guid you give is unknown, none are marked.
- `unread` prints tab-separated lines: guid, local time, feed, title, link.
- Refusals print `feedwatch: <message>` to stderr and exit with status 1.

**Review Focus:** five risky inputs the spec doesn't mention, each with a test in the task that owns the code:
- an item with neither guid nor link
- a missing or garbled `pubDate`
- a server that accepts the connection and never answers
- the same guid in two feeds
- `--every 0`, a negative `--limit`, or a URL without `http(s)://`

**Not run now:** I did not run `dopamine:finishing-work`. Writing the plan opens the work rather than finishing it, so the sweep is Task 7. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist; the plan has the sweep report that rather than create the file.

**Shared scratch space:** my first scratch directories under `/tmp` (`/tmp/fwcheck`, `/tmp/fwparts`, `/tmp/fwhome`) were overwritten by another process running at the same time, probably a parallel run. I rebuilt everything in a uniquely named directory, `/tmp/fw-F1r1-1-lW206w`, and the committed plan comes only from there. If other runs use fixed `/tmp` names, they may be overwriting each other's files.

Please review the plan and confirm it captures what you want.

#### docs/superpowers/plans/2026-10-12-feedwatch-v1.md (added)

````
# Feedwatch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build feedwatch v1: a poller that stores new RSS entries in SQLite, and a `feedwatch` command line to subscribe to feeds, list unread entries and mark them read.

**Architecture:** One package, `feedwatch/`, holding the five components of `docs/ARCHITECTURE.md` as five modules (`fetch`, `parse`, `store`, `poller`, `cli`) over two shared leaf modules (`models` for frozen dataclasses, `errors` for the `FeedwatchError` family). `poller` calls `fetch`, `parse` and `store`; `cli` calls only `store`; both open the same SQLite file through `store.connect()`.

**Tech Stack:** Python 3.11+, standard library only (`sqlite3`, `urllib.request`, `xml.etree.ElementTree`, `argparse`, `logging`, `unittest`). `setuptools` appears only as the build backend that installs the `feedwatch` command; nothing imports it.

**Spec:** `docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md`. Also read `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/PROGRAM-DESIGN.md` before starting.

## Global Constraints

From the spec and design:

- Python 3.11, standard library. No runtime dependency.
- `feedwatch add URL [--title TITLE] [--every MINUTES]`; the interval defaults to **30** minutes. A URL already subscribed to is refused with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries newest first, **20** unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read; a guid that is not stored is refused with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores entries not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not RSS, is logged and skipped until its next interval; the other feeds are still polled. A database error stops the poller.
- One SQLite file, `~/.feedwatch/feeds.db`, tables `feeds` and `entries`; an existing database has to keep working.
- Out of scope: Atom feeds; importing or exporting subscription lists.

From `docs/PROGRAM-DESIGN.md` — every rule, with its check. Run each check over every added line, the tests included, before committing a task:

- **Types.** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.
- **Errors.** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added function reports that it could not do its job by returning `None`, `False` or an `(ok, reason)` pair, though a predicate's `False` is an answer, not a failure; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.
- **Effects.** Dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules. Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values. `store` is module functions that take a `conn` as their first parameter; nothing wraps the connection in a class.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`; no added class in `store.py` holding a connection.
- **Signatures.** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.
- **Layout.** Split by responsibility, not technical layer. Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules. (Read as a rule about `feedwatch/`: `tests/test_cli.py` and `tests/test_poller.py` import the module they test.)
- **Modules.** A new module that is not one of `ARCHITECTURE.md`'s components hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Check:* a new module other than a component has at most two public functions, types aside; no added function whose body only forwards its parameters to another function. (This plan adds no logic module: the one piece of scheduling logic, `_due`, is private to `poller`.)
- **Concurrency.** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor. (v1 polls feeds one after another; `fetch` gives up after 30 seconds, so a dead feed delays the rest by at most that. No executor yet.)
- **Persistence.** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

Plan-level decisions the spec leaves to the implementation:

- `store.connect(path)` is a context manager that yields the connection and closes it on exit, so callers outside `store` never write `conn.close()`. `store.Connection` is the type alias the other modules annotate with.
- Every time is stored as UTC ISO 8601 text at seconds precision. An entry without a readable `pubDate` sorts by when the poller first stored it.
- `read GUID` marks that guid read in every feed that has it. If any guid given is unknown, none is marked.
- `unread` prints one tab-separated line per entry: guid, local time `YYYY-MM-DD HH:MM`, feed title (its URL when added without `--title`), entry title (`(untitled)` when empty), link. With nothing unread it prints `no unread entries`.
- Refusals print `feedwatch: <message>` to stderr and exit 1; argparse's own usage errors keep its exit status 2.
- Tests use `unittest` and run from the repository root with `python -m unittest -v`.

## Review Focus

1. **An item with neither `<guid>` nor `<link>`, or with no `<title>`** — real feeds have them; such an item cannot be identified, so it is left out rather than crashing the poll, and an untitled one lists as `(untitled)`. Pinned in Task 1 (`test_item_without_guid_or_link_is_left_out`, `test_missing_title_is_empty`) and Task 6 (`test_unread_line_shows_guid_time_feed_title_and_link`).
2. **A missing, garbled or absurd `pubDate`** — the entry is still stored and sorts by when it was first seen. Pinned in Task 1 (`test_missing_or_unreadable_pubdate_is_none`) and Task 4 (`test_unread_is_newest_first_and_limited`).
3. **A server that accepts the connection and never answers** — the poller must not hang on it forever. Pinned in Task 2 (`test_silent_server_times_out_as_fetch_error`).
4. **The same guid in two feeds** (feeds that syndicate each other, or guids like `1`, `2`) — stored once per feed; `read` marks it in both. Pinned in Task 4 (`test_same_guid_in_two_feeds_is_two_entries`, `test_mark_read_hides_entry_in_every_feed`).
5. **`--every 0`, a negative `--limit`, or a URL without `http(s)://`** — refused with a message instead of a feed polled every minute or an empty listing. Pinned in Task 6 (`test_non_positive_numbers_are_refused`, `test_non_http_url_is_refused`).

## File Structure

| File | Responsibility |
|---|---|
| `feedwatch/__init__.py` | Marks the package; empty. |
| `feedwatch/errors.py` | `FeedwatchError` and its subclasses, one per kind of failure. |
| `feedwatch/models.py` | Frozen dataclasses `Feed`, `Entry`, `UnreadEntry`. |
| `feedwatch/parse.py` | RSS bytes → `list[Entry]`. |
| `feedwatch/fetch.py` | URL → bytes over HTTP. |
| `feedwatch/store.py` | Schema, connection, every SQL statement. |
| `feedwatch/poller.py` | The schedule: which feed is due, fetch → parse → store, logging failures. |
| `feedwatch/cli.py` | argparse, argument checks, output formatting. |
| `pyproject.toml` | Installs the `feedwatch` command. |
| `tests/__init__.py`, `tests/test_*.py` | One test module per component. |

---

### Task 1: Domain vocabulary and the RSS parser

**Files:**
- Create: `feedwatch/__init__.py` (empty), `feedwatch/errors.py`, `feedwatch/models.py`, `feedwatch/parse.py`
- Create: `tests/__init__.py` (empty), `tests/test_parse.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `feedwatch.errors`: `FeedwatchError(Exception)`; `FetchError`, `NotRssError`, `UsageError` (plain message); `AlreadySubscribedError(url: str)` with `.url`; `UnknownGuidError(guids: list[str])` with `.guids`.
  - `feedwatch.models`: `Feed(id: int, url: str, title: str | None, every_minutes: int, last_polled: datetime | None)`; `Entry(guid: str, title: str, link: str | None, published: datetime | None)`; `UnreadEntry(guid: str, title: str, link: str | None, published: datetime, feed_title: str)`. All `@dataclass(frozen=True)`; every `datetime` is timezone-aware.
  - `feedwatch.parse.parse(xml: bytes) -> list[Entry]`, raising `NotRssError`.

- [ ] **Step 1: Create the empty package and test package**

```bash
mkdir -p feedwatch tests
touch feedwatch/__init__.py tests/__init__.py
```

- [ ] **Step 2: Write `feedwatch/errors.py`**

```python
class FeedwatchError(Exception):
    """Base of every failure feedwatch raises; only poller and cli catch it."""


class FetchError(FeedwatchError):
    """A feed's URL could not be downloaded."""


class NotRssError(FeedwatchError):
    """Downloaded bytes are not an RSS document."""


class AlreadySubscribedError(FeedwatchError):
    def __init__(self, url: str) -> None:
        super().__init__(f"already subscribed to {url}")
        self.url = url


class UnknownGuidError(FeedwatchError):
    def __init__(self, guids: list[str]) -> None:
        super().__init__("no stored entry with guid " + ", ".join(guids))
        self.guids = guids


class UsageError(FeedwatchError):
    """A command-line argument parsed but has a value feedwatch cannot use."""
```

- [ ] **Step 3: Write `feedwatch/models.py`**

```python
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str | None
    every_minutes: int
    last_polled: datetime | None


@dataclass(frozen=True)
class Entry:
    """An item as read from a feed, before it is stored."""

    # The item's <guid>, or its <link> when it has none.
    guid: str
    title: str
    link: str | None
    published: datetime | None


@dataclass(frozen=True)
class UnreadEntry:
    guid: str
    title: str
    link: str | None
    # The item's pubDate, or when the poller first stored it.
    published: datetime
    # The feed's --title, or its URL when it was added without one.
    feed_title: str
```

- [ ] **Step 4: Write the failing parser tests in `tests/test_parse.py`**

```python
import unittest
from datetime import datetime, timezone

from feedwatch.errors import NotRssError
from feedwatch.models import Entry
from feedwatch.parse import parse


def rss(items: str) -> bytes:
    return f"""<?xml version="1.0"?>
<rss version="2.0"><channel><title>Example</title>{items}</channel></rss>""".encode()


class ParseTest(unittest.TestCase):
    def test_item_with_guid(self) -> None:
        xml = rss(
            "<item><guid>g-1</guid><title>Hello</title>"
            "<link>https://example.org/1</link>"
            "<pubDate>Sun, 01 Mar 2026 10:00:00 +0100</pubDate></item>"
        )
        self.assertEqual(
            parse(xml),
            [
                Entry(
                    guid="g-1",
                    title="Hello",
                    link="https://example.org/1",
                    published=datetime(2026, 3, 1, 9, 0, tzinfo=timezone.utc),
                )
            ],
        )

    def test_link_stands_in_for_missing_guid(self) -> None:
        [entry] = parse(rss("<item><title>T</title><link>https://example.org/2</link></item>"))
        self.assertEqual(entry.guid, "https://example.org/2")

    def test_item_without_guid_or_link_is_left_out(self) -> None:
        xml = rss("<item><title>Lost</title></item><item><guid>g-2</guid></item>")
        self.assertEqual([e.guid for e in parse(xml)], ["g-2"])

    def test_missing_title_is_empty(self) -> None:
        [entry] = parse(rss("<item><guid>g-3</guid></item>"))
        self.assertEqual(entry.title, "")

    def test_missing_or_unreadable_pubdate_is_none(self) -> None:
        xml = rss(
            "<item><guid>a</guid></item>"
            "<item><guid>b</guid><pubDate>yesterday-ish</pubDate></item>"
            "<item><guid>c</guid><pubDate>Mon, 01 Jan 99999 00:00:00 GMT</pubDate></item>"
        )
        self.assertEqual([e.published for e in parse(xml)], [None, None, None])

    def test_malformed_xml_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b"<rss><channel>")

    def test_atom_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b'<feed xmlns="http://www.w3.org/2005/Atom"><title>A</title></feed>')

    def test_html_is_not_rss(self) -> None:
        with self.assertRaises(NotRssError):
            parse(b"<html><body>Not found</body></html>")
```

- [ ] **Step 5: Run them to verify they fail**

Run: `python -m unittest tests.test_parse -v`
Expected: the module fails to import — `ModuleNotFoundError: No module named 'feedwatch.parse'`

- [ ] **Step 6: Write `feedwatch/parse.py`**

The date is read with `email.utils.parsedate_tz`, which answers `None` for an unreadable date rather than raising, so `parse` needs no `except` beyond the one that turns `ET.ParseError` into `NotRssError`. `ElementTree` never fetches external entities, and the expat bundled with Python 3.11+ caps entity expansion, so feed XML is parsed without `defusedxml`, which would be a dependency.

```python
import xml.etree.ElementTree as ET
from calendar import timegm
from datetime import datetime, timezone
from email.utils import parsedate_tz

from feedwatch.errors import NotRssError
from feedwatch.models import Entry


def parse(xml: bytes) -> list[Entry]:
    """Return the items of an RSS document, in document order.

    Raises NotRssError when xml is not well-formed or its root is not <rss>.
    An item with neither <guid> nor <link> is left out: nothing identifies it.
    """
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as e:
        raise NotRssError(f"not well-formed XML: {e}") from e
    channel = root.find("channel")
    if root.tag != "rss" or channel is None:
        raise NotRssError(f"root element is <{root.tag}>, not an RSS <rss>")
    entries = []
    for item in channel.findall("item"):
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        if guid is None:
            continue
        entries.append(
            Entry(
                guid=guid,
                title=_text(item, "title") or "",
                link=link,
                published=_published(_text(item, "pubDate")),
            )
        )
    return entries


def _text(item: ET.Element, tag: str) -> str | None:
    text = (item.findtext(tag) or "").strip()
    return text or None


def _published(text: str | None) -> datetime | None:
    # parsedate_tz answers None for an unreadable date instead of raising; the
    # year bound keeps fromtimestamp from overflowing on a nonsense year.
    parts = parsedate_tz(text) if text else None
    if parts is None or not 1970 <= parts[0] <= 9999:
        return None
    offset = parts[9] or 0
    return datetime.fromtimestamp(timegm(parts[:6]) - offset, timezone.utc)
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `python -m unittest tests.test_parse -v`
Expected: 8 tests, OK

- [ ] **Step 8: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/__init__.py feedwatch/errors.py feedwatch/models.py feedwatch/parse.py tests/__init__.py tests/test_parse.py
git commit -m "feat: domain types, errors and RSS parser"
```

---

### Task 2: Fetching a feed

**Files:**
- Create: `feedwatch/fetch.py`
- Test: `tests/test_fetch.py`

**Interfaces:**
- Consumes: `feedwatch.errors.FetchError`.
- Produces: `feedwatch.fetch.fetch(url: str, *, timeout: float = 30.0) -> bytes`, raising `FetchError` on any network or HTTP failure, a timeout included.

- [ ] **Step 1: Write the failing tests in `tests/test_fetch.py`**

These need no network: a `file://` URL stands in for a served feed, a closed port for a dead server, and a socket that listens but never accepts for a server that never answers.

```python
import socket
import tempfile
import unittest
from pathlib import Path

from feedwatch.errors import FetchError
from feedwatch.fetch import fetch


class FetchTest(unittest.TestCase):
    def test_returns_body(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "feed.xml"
            path.write_bytes(b"<rss/>")
            self.assertEqual(fetch(path.as_uri()), b"<rss/>")

    def test_missing_resource_is_fetch_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FetchError):
                fetch((Path(tmp) / "absent.xml").as_uri())

    def test_refused_connection_is_fetch_error(self) -> None:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        with self.assertRaises(FetchError):
            fetch(f"http://127.0.0.1:{port}/feed.xml")

    def test_silent_server_times_out_as_fetch_error(self) -> None:
        # The kernel completes the handshake from the listen backlog; nothing
        # ever answers, so only the timeout ends the read.
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            sock.listen(1)
            port = sock.getsockname()[1]
            with self.assertRaises(FetchError):
                fetch(f"http://127.0.0.1:{port}/feed.xml", timeout=0.5)

    def test_unsplittable_url_is_fetch_error(self) -> None:
        with self.assertRaises(FetchError):
            fetch("not a url")
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_fetch -v`
Expected: the module fails to import — `ModuleNotFoundError: No module named 'feedwatch.fetch'`

- [ ] **Step 3: Write `feedwatch/fetch.py`**

The `Request` is built inside the `try`: it is what raises `ValueError` for a URL urllib cannot split.

```python
import http.client
import urllib.request

from feedwatch.errors import FetchError


def fetch(url: str, *, timeout: float = 30.0) -> bytes:
    """Return the body served at url.

    Raises FetchError for any network or HTTP failure, including no response
    within timeout seconds.
    """
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "feedwatch/1"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    # URLError, HTTPError and timeouts are OSErrors; ValueError is a URL urllib
    # cannot even split; HTTPException is a server breaking the protocol.
    except (OSError, ValueError, http.client.HTTPException) as e:
        raise FetchError(f"{url}: {e}") from e
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_fetch -v`
Expected: 5 tests, OK (the timeout test takes about half a second)

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/fetch.py tests/test_fetch.py
git commit -m "feat: fetch feeds over HTTP with a timeout"
```

---

### Task 3: The store — schema, connection and feeds

**Files:**
- Create: `feedwatch/store.py`
- Test: `tests/test_store.py`

**Interfaces:**
- Consumes: `feedwatch.errors.AlreadySubscribedError`, `feedwatch.models.Feed`.
- Produces:
  - `store.Connection` — type alias of `sqlite3.Connection`, for annotations in `poller` and `cli`.
  - `store.DEFAULT_PATH: Path` — `~/.feedwatch/feeds.db`.
  - `store.SCHEMA_STEPS: tuple[str, ...]`.
  - `store.connect(path: Path = DEFAULT_PATH)` — context manager yielding a `Connection`; creates the parent directory and runs every schema step; closes on exit.
  - `store.add_feed(conn, url: str, *, title: str | None, every_minutes: int) -> Feed`, raising `AlreadySubscribedError`.
  - `store.list_feeds(conn) -> list[Feed]`, in the order they were added.
  - `store.mark_polled(conn, feed_id: int, *, at: datetime) -> None`.

- [ ] **Step 1: Write the failing tests in `tests/test_store.py`**

```python
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribedError

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class StoreTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "sub" / "feeds.db"
        self.conn = self.enterContext(store.connect(self.path))


class FeedsTest(StoreTestCase):
    def test_add_then_list(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        self.assertEqual(store.list_feeds(self.conn), [feed])
        self.assertIsNone(feed.last_polled)

    def test_same_url_twice_is_refused(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with self.assertRaises(AlreadySubscribedError) as caught:
            store.add_feed(self.conn, "https://a.example/rss", title="again", every_minutes=5)
        self.assertIn("https://a.example/rss", str(caught.exception))

    def test_mark_polled(self) -> None:
        feed = store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        store.mark_polled(self.conn, feed.id, at=T0)
        [stored] = store.list_feeds(self.conn)
        self.assertEqual(stored.last_polled, T0)

    def test_reopening_keeps_data(self) -> None:
        store.add_feed(self.conn, "https://a.example/rss", title=None, every_minutes=30)
        with store.connect(self.path) as again:
            self.assertEqual([f.url for f in store.list_feeds(again)], ["https://a.example/rss"])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the module fails to import — `ImportError: cannot import name 'store' from 'feedwatch'`

- [ ] **Step 3: Write `feedwatch/store.py`**

Both tables are created now, `entries` included: the schema only grows by appended steps, and Task 4 should add functions, not a step.

```python
import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import TypeAlias

from feedwatch.errors import AlreadySubscribedError
from feedwatch.models import Feed

Connection: TypeAlias = sqlite3.Connection

DEFAULT_PATH = Path.home() / ".feedwatch" / "feeds.db"

# Append only, never edit: connect() runs every step on every open, and an
# existing database has already run the old ones.
SCHEMA_STEPS: tuple[str, ...] = (
    """CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL UNIQUE,
        title TEXT,
        every_minutes INTEGER NOT NULL,
        last_polled TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS entries (
        feed_id INTEGER NOT NULL REFERENCES feeds (id),
        guid TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT,
        published TEXT,
        seen_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (feed_id, guid)
    )""",
    "CREATE INDEX IF NOT EXISTS entries_by_guid ON entries (guid)",
)


@contextmanager
def connect(path: Path = DEFAULT_PATH) -> Iterator[Connection]:
    """Open the database at path, creating it and its schema if needed, and close it on exit."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    try:
        with conn:
            for step in SCHEMA_STEPS:
                conn.execute(step)
        yield conn
    finally:
        conn.close()


def add_feed(conn: Connection, url: str, *, title: str | None, every_minutes: int) -> Feed:
    """Subscribe to url. Raises AlreadySubscribedError if it is subscribed already."""
    try:
        with conn:
            cursor = conn.execute(
                "INSERT INTO feeds (url, title, every_minutes) VALUES (?, ?, ?)",
                (url, title, every_minutes),
            )
    except sqlite3.IntegrityError as e:
        raise AlreadySubscribedError(url) from e
    return Feed(id=cursor.lastrowid, url=url, title=title, every_minutes=every_minutes, last_polled=None)


def list_feeds(conn: Connection) -> list[Feed]:
    rows = conn.execute("SELECT id, url, title, every_minutes, last_polled FROM feeds ORDER BY id")
    return [
        Feed(
            id=id_,
            url=url,
            title=title,
            every_minutes=every,
            last_polled=datetime.fromisoformat(last) if last else None,
        )
        for id_, url, title, every, last in rows
    ]


def mark_polled(conn: Connection, feed_id: int, *, at: datetime) -> None:
    with conn:
        conn.execute("UPDATE feeds SET last_polled = ? WHERE id = ?", (_text(at), feed_id))


# Every stored time is UTC ISO 8601 at one precision, so ORDER BY on the text
# sorts chronologically.
def _text(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).isoformat(timespec="seconds")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 4 tests, OK

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: SQLite store with schema steps and feed subscriptions"
```

---

### Task 4: The store — entries, unread and read

**Files:**
- Modify: `feedwatch/store.py` (imports; three functions above `_text`)
- Test: `tests/test_store.py` (imports; `entry` helper; `EntriesTest`)

**Interfaces:**
- Consumes: Task 3's `store` module; `feedwatch.models.Entry`, `UnreadEntry`; `feedwatch.errors.UnknownGuidError`.
- Produces:
  - `store.add_entries(conn, feed_id: int, entries: list[Entry], *, seen_at: datetime) -> int` — stores the entries not already stored for that feed, returns how many were new.
  - `store.unread(conn, limit: int) -> list[UnreadEntry]` — newest first by `published`, falling back to when first seen.
  - `store.mark_read(conn, guids: list[str]) -> None` — marks every entry with those guids, in any feed; raises `UnknownGuidError` naming each unknown guid and then marks none.

- [ ] **Step 1: Write the failing tests**

In `tests/test_store.py`, replace the import block with:

```python
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import store
from feedwatch.errors import AlreadySubscribedError, UnknownGuidError
from feedwatch.models import Entry
```

Add this helper between `T0` and `class StoreTestCase`:

```python
def entry(guid: str, published: datetime | None = None) -> Entry:
    return Entry(guid=guid, title=f"title {guid}", link=f"https://example.org/{guid}", published=published)
```

Append at the end of the file:

```python
class EntriesTest(StoreTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.a = store.add_feed(self.conn, "https://a.example/rss", title="A", every_minutes=30)
        self.b = store.add_feed(self.conn, "https://b.example/rss", title=None, every_minutes=30)

    def test_entry_is_stored_once(self) -> None:
        self.assertEqual(store.add_entries(self.conn, self.a.id, [entry("1"), entry("1")], seen_at=T0), 1)
        self.assertEqual(store.add_entries(self.conn, self.a.id, [entry("1"), entry("2")], seen_at=T0), 1)
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["2", "1"])

    def test_same_guid_in_two_feeds_is_two_entries(self) -> None:
        store.add_entries(self.conn, self.a.id, [entry("x")], seen_at=T0)
        self.assertEqual(store.add_entries(self.conn, self.b.id, [entry("x")], seen_at=T0), 1)

    def test_unread_is_newest_first_and_limited(self) -> None:
        store.add_entries(
            self.conn,
            self.a.id,
            [entry("old", T0 - timedelta(days=2)), entry("new", T0), entry("undated")],
            seen_at=T0 - timedelta(days=1),
        )
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["new", "undated", "old"])
        self.assertEqual([e.guid for e in store.unread(self.conn, 2)], ["new", "undated"])

    def test_unread_names_the_feed(self) -> None:
        store.add_entries(self.conn, self.a.id, [entry("1", T0)], seen_at=T0)
        store.add_entries(self.conn, self.b.id, [entry("2", T0 - timedelta(hours=1))], seen_at=T0)
        self.assertEqual(
            [(e.guid, e.feed_title, e.published) for e in store.unread(self.conn, 20)],
            [("1", "A", T0), ("2", "https://b.example/rss", T0 - timedelta(hours=1))],
        )

    def test_mark_read_hides_entry_in_every_feed(self) -> None:
        store.add_entries(self.conn, self.a.id, [entry("x"), entry("y")], seen_at=T0)
        store.add_entries(self.conn, self.b.id, [entry("x")], seen_at=T0)
        store.mark_read(self.conn, ["x"])
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["y"])

    def test_unknown_guid_is_refused_and_nothing_is_marked(self) -> None:
        store.add_entries(self.conn, self.a.id, [entry("x")], seen_at=T0)
        with self.assertRaises(UnknownGuidError) as caught:
            store.mark_read(self.conn, ["x", "nope"])
        self.assertIn("nope", str(caught.exception))
        self.assertEqual([e.guid for e in store.unread(self.conn, 20)], ["x"])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_store -v`
Expected: the 4 `FeedsTest` tests pass; the 6 `EntriesTest` tests ERROR with `AttributeError: module 'feedwatch.store' has no attribute 'add_entries'`

- [ ] **Step 3: Implement**

In `feedwatch/store.py`, replace the two package imports with:

```python
from feedwatch.errors import AlreadySubscribedError, UnknownGuidError
from feedwatch.models import Entry, Feed, UnreadEntry
```

Insert above the `# Every stored time is UTC ISO 8601…` comment:

```python
def add_entries(conn: Connection, feed_id: int, entries: list[Entry], *, seen_at: datetime) -> int:
    """Store the entries feed_id has not stored before; return how many were new."""
    with conn:
        cursor = conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published, seen_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            [
                (
                    feed_id,
                    e.guid,
                    e.title,
                    e.link,
                    _text(e.published) if e.published else None,
                    _text(seen_at),
                )
                for e in entries
            ],
        )
    return cursor.rowcount


def unread(conn: Connection, limit: int) -> list[UnreadEntry]:
    """Return up to limit unread entries, newest first."""
    rows = conn.execute(
        """SELECT e.guid, e.title, e.link, COALESCE(e.published, e.seen_at) AS shown,
                  COALESCE(f.title, f.url)
           FROM entries e JOIN feeds f ON f.id = e.feed_id
           WHERE e.read = 0
           ORDER BY shown DESC, e.rowid DESC
           LIMIT ?""",
        (limit,),
    )
    return [
        UnreadEntry(
            guid=guid,
            title=title,
            link=link,
            published=datetime.fromisoformat(shown),
            feed_title=feed_title,
        )
        for guid, title, link, shown, feed_title in rows
    ]


def mark_read(conn: Connection, guids: list[str]) -> None:
    """Mark read every entry with one of guids, in any feed.

    Raises UnknownGuidError naming each guid no entry has, and then marks none.
    """
    unknown = [
        guid
        for guid in dict.fromkeys(guids)
        if conn.execute("SELECT 1 FROM entries WHERE guid = ?", (guid,)).fetchone() is None
    ]
    if unknown:
        raise UnknownGuidError(unknown)
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(guid,) for guid in guids])
```

`executemany`'s `rowcount` is the total over all rows, so with `INSERT OR IGNORE` it counts exactly the new entries. `e.rowid DESC` breaks ties between entries with the same time, newest stored first.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_store -v`
Expected: 10 tests, OK

- [ ] **Step 5: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/store.py tests/test_store.py
git commit -m "feat: store entries once per feed, list unread, mark read"
```

---

### Task 5: The poller

**Files:**
- Create: `feedwatch/poller.py`
- Test: `tests/test_poller.py`

**Interfaces:**
- Consumes: `fetch.fetch`, `parse.parse`, `store.connect`, `store.list_feeds`, `store.add_entries`, `store.mark_polled`, `store.Connection`; `models.Feed`; `errors.FeedwatchError`.
- Produces:
  - `poller.poll_once(conn: store.Connection, now: datetime, *, fetch_feed: Callable[[str], bytes] = fetch.fetch) -> None` — one pass over the feeds; `fetch_feed` is the dependency tests replace.
  - `poller.main() -> None` — the loop behind `python -m feedwatch.poller`; returns on Ctrl-C.
  - Logger `feedwatch.poller`: a skipped feed is logged at WARNING with its URL.

- [ ] **Step 1: Write the failing tests in `tests/test_poller.py`**

```python
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import poller, store
from feedwatch.errors import FetchError

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)

GOOD = b"""<rss version="2.0"><channel><title>Good</title>
<item><guid>g-1</guid><title>One</title></item>
<item><link>https://good.example/2</link><title>Two</title></item>
</channel></rss>"""


class FakeWeb:
    def __init__(self, pages: dict[str, bytes]) -> None:
        self.pages = pages
        self.asked: list[str] = []

    def fetch(self, url: str) -> bytes:
        self.asked.append(url)
        if url not in self.pages:
            raise FetchError(f"{url}: connection refused")
        return self.pages[url]


class PollOnceTest(unittest.TestCase):
    def setUp(self) -> None:
        path = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"
        self.conn = self.enterContext(store.connect(path))

    def test_new_feed_is_polled_and_its_entries_stored(self) -> None:
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://good.example/rss": GOOD})
        poller.poll_once(self.conn, T0, fetch_feed=web.fetch)
        self.assertEqual(
            sorted(e.guid for e in store.unread(self.conn, 20)),
            ["g-1", "https://good.example/2"],
        )

    def test_feed_waits_for_its_interval(self) -> None:
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://good.example/rss": GOOD})
        poller.poll_once(self.conn, T0, fetch_feed=web.fetch)
        poller.poll_once(self.conn, T0 + timedelta(minutes=29), fetch_feed=web.fetch)
        self.assertEqual(len(web.asked), 1)
        poller.poll_once(self.conn, T0 + timedelta(minutes=30), fetch_feed=web.fetch)
        self.assertEqual(len(web.asked), 2)

    def test_repolling_stores_nothing_twice(self) -> None:
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://good.example/rss": GOOD})
        poller.poll_once(self.conn, T0, fetch_feed=web.fetch)
        poller.poll_once(self.conn, T0 + timedelta(minutes=30), fetch_feed=web.fetch)
        self.assertEqual(len(store.unread(self.conn, 20)), 2)

    def test_failing_feeds_are_logged_and_others_still_polled(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://html.example/", title=None, every_minutes=30)
        store.add_feed(self.conn, "https://good.example/rss", title=None, every_minutes=30)
        web = FakeWeb({"https://html.example/": b"<html></html>", "https://good.example/rss": GOOD})
        with self.assertLogs("feedwatch.poller", "WARNING") as logs:
            poller.poll_once(self.conn, T0, fetch_feed=web.fetch)
        self.assertEqual(len(logs.records), 2)
        self.assertIn("https://down.example/rss", logs.output[0])
        self.assertIn("https://html.example/", logs.output[1])
        self.assertEqual(len(store.unread(self.conn, 20)), 2)

    def test_failed_feed_is_skipped_until_its_next_interval(self) -> None:
        store.add_feed(self.conn, "https://down.example/rss", title=None, every_minutes=30)
        web = FakeWeb({})
        with self.assertLogs("feedwatch.poller", "WARNING"):
            poller.poll_once(self.conn, T0, fetch_feed=web.fetch)
        poller.poll_once(self.conn, T0 + timedelta(minutes=1), fetch_feed=web.fetch)
        self.assertEqual(len(web.asked), 1)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_poller -v`
Expected: the module fails to import — `ImportError: cannot import name 'poller' from 'feedwatch'`

- [ ] **Step 3: Write `feedwatch/poller.py`**

A feed is marked polled whether or not it failed: that is what makes a failed feed wait for its next interval. Only `FeedwatchError` is caught, so a `sqlite3` error propagates and stops the poller, as `ARCHITECTURE.md` requires.

```python
import logging
import time
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from feedwatch import fetch, parse, store
from feedwatch.errors import FeedwatchError
from feedwatch.models import Feed

log = logging.getLogger("feedwatch.poller")


def poll_once(
    conn: store.Connection,
    now: datetime,
    *,
    fetch_feed: Callable[[str], bytes] = fetch.fetch,
) -> None:
    """Poll every feed whose interval is up at now and store the entries it has not seen.

    A feed that cannot be fetched, or is not RSS, is logged and waits for its next
    interval. A database error propagates and stops the poller.
    """
    for feed in store.list_feeds(conn):
        if not _due(feed, now):
            continue
        try:
            entries = parse.parse(fetch_feed(feed.url))
        except FeedwatchError as e:
            log.warning("skipping %s until its next interval: %s", feed.url, e)
        else:
            added = store.add_entries(conn, feed.id, entries, seen_at=now)
            log.info("%s: %d new entries", feed.url, added)
        store.mark_polled(conn, feed.id, at=now)


def _due(feed: Feed, now: datetime) -> bool:
    return feed.last_polled is None or now - feed.last_polled >= timedelta(minutes=feed.every_minutes)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        with store.connect() as conn:
            while True:
                poll_once(conn, datetime.now(timezone.utc))
                # Intervals are whole minutes, so checking once a minute polls each
                # feed at most a minute late.
                time.sleep(60)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_poller -v`
Expected: 5 tests, OK

- [ ] **Step 5: Smoke-run the loop against a throwaway home**

```bash
export HOME="$(mktemp -d)"
timeout -s INT 3 python -m feedwatch.poller; echo "exit $?"
```

Expected: no traceback; `exit 124` (timeout's status after it sent Ctrl-C, which `main` absorbs).

- [ ] **Step 6: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/poller.py tests/test_poller.py
git commit -m "feat: poller polls due feeds and skips failing ones"
```

---

### Task 6: The command line

**Files:**
- Create: `feedwatch/cli.py`, `pyproject.toml`
- Modify: `.gitignore` (add `*.egg-info/`)
- Test: `tests/test_cli.py`

**Interfaces:**
- Consumes: `store.connect`, `store.add_feed`, `store.unread`, `store.mark_read`, `store.DEFAULT_PATH`, `store.Connection`; `models.UnreadEntry`; `errors.FeedwatchError`, `errors.UsageError`.
- Produces: `cli.main(argv: list[str] | None = None, *, db_path: Path = store.DEFAULT_PATH, out: TextIO | None = None, err: TextIO | None = None) -> int` — runs one command and returns its exit status; the `feedwatch` console script calls it with no arguments.

- [ ] **Step 1: Write the failing tests in `tests/test_cli.py`**

```python
import io
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from feedwatch import cli, store
from feedwatch.models import Entry

T0 = datetime(2026, 3, 1, 12, 0, tzinfo=timezone.utc)


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = Path(self.enterContext(tempfile.TemporaryDirectory())) / "feeds.db"

    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        status = cli.main(list(argv), db_path=self.db, out=out, err=err)
        return status, out.getvalue(), err.getvalue()

    def seed(self, *entries: Entry) -> None:
        with store.connect(self.db) as conn:
            feed = store.add_feed(conn, "https://a.example/rss", title="A", every_minutes=30)
            store.add_entries(conn, feed.id, list(entries), seen_at=T0)

    def test_add_defaults_to_30_minutes(self) -> None:
        self.assertEqual(self.run_cli("add", "https://a.example/rss")[0], 0)
        with store.connect(self.db) as conn:
            [feed] = store.list_feeds(conn)
        self.assertEqual((feed.url, feed.title, feed.every_minutes), ("https://a.example/rss", None, 30))

    def test_add_with_title_and_interval(self) -> None:
        self.run_cli("add", "https://a.example/rss", "--title", "A", "--every", "5")
        with store.connect(self.db) as conn:
            [feed] = store.list_feeds(conn)
        self.assertEqual((feed.title, feed.every_minutes), ("A", 5))

    def test_adding_twice_is_refused_naming_the_url(self) -> None:
        self.run_cli("add", "https://a.example/rss")
        status, _, err = self.run_cli("add", "https://a.example/rss")
        self.assertEqual(status, 1)
        self.assertIn("https://a.example/rss", err)

    def test_non_http_url_is_refused(self) -> None:
        status, _, err = self.run_cli("add", "a.example/rss")
        self.assertEqual(status, 1)
        self.assertIn("a.example/rss", err)

    def test_non_positive_numbers_are_refused(self) -> None:
        self.assertEqual(self.run_cli("add", "https://a.example/rss", "--every", "0")[0], 1)
        self.assertEqual(self.run_cli("unread", "--limit", "-1")[0], 1)

    def test_unread_lists_newest_first_up_to_the_limit(self) -> None:
        self.seed(
            *(
                Entry(guid=f"g{i}", title=f"t{i}", link=None, published=T0 + timedelta(minutes=i))
                for i in range(25)
            )
        )
        status, out, _ = self.run_cli("unread")
        lines = out.splitlines()
        self.assertEqual(status, 0)
        self.assertEqual(len(lines), 20)
        self.assertEqual(lines[0].split("\t")[0], "g24")
        self.assertEqual(len(self.run_cli("unread", "--limit", "3")[1].splitlines()), 3)

    def test_unread_line_shows_guid_time_feed_title_and_link(self) -> None:
        self.seed(Entry(guid="g", title="", link="https://a.example/1", published=T0))
        when = T0.astimezone().strftime("%Y-%m-%d %H:%M")
        self.assertEqual(self.run_cli("unread")[1], f"g\t{when}\tA\t(untitled)\thttps://a.example/1\n")

    def test_nothing_unread_says_so(self) -> None:
        self.assertEqual(self.run_cli("unread")[1], "no unread entries\n")

    def test_read_marks_entries(self) -> None:
        self.seed(*(Entry(guid=g, title=g, link=None, published=T0) for g in ("x", "y", "z")))
        self.assertEqual(self.run_cli("read", "x", "z")[0], 0)
        self.assertEqual([line.split("\t")[0] for line in self.run_cli("unread")[1].splitlines()], ["y"])

    def test_read_unknown_guid_is_refused_naming_it(self) -> None:
        self.seed(Entry(guid="x", title="x", link=None, published=T0))
        status, _, err = self.run_cli("read", "x", "nope")
        self.assertEqual(status, 1)
        self.assertIn("nope", err)
        self.assertEqual(self.run_cli("unread")[1].split("\t")[0], "x")
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python -m unittest tests.test_cli -v`
Expected: the module fails to import — `ImportError: cannot import name 'cli' from 'feedwatch'`

- [ ] **Step 3: Write `feedwatch/cli.py`**

The range checks are made after parsing rather than as argparse `type=` functions, because those would have to raise `argparse.ArgumentTypeError`, which is not a `FeedwatchError`. The URL check uses `str.startswith`, since `urllib` belongs to `fetch`.

```python
import argparse
import sys
from pathlib import Path
from typing import TextIO

from feedwatch import store
from feedwatch.errors import FeedwatchError, UsageError
from feedwatch.models import UnreadEntry


def main(
    argv: list[str] | None = None,
    *,
    db_path: Path = store.DEFAULT_PATH,
    out: TextIO | None = None,
    err: TextIO | None = None,
) -> int:
    """Run one feedwatch command and return its exit status.

    argv defaults to sys.argv[1:]; out and err default to sys.stdout and sys.stderr.
    """
    out = sys.stdout if out is None else out
    err = sys.stderr if err is None else err
    args = _parser().parse_args(argv)
    try:
        _check(args)
        with store.connect(db_path) as conn:
            _run(conn, args, out=out)
    except FeedwatchError as e:
        print(f"feedwatch: {e}", file=err)
        return 1
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to an RSS feed")
    add.add_argument("url")
    add.add_argument("--title")
    add.add_argument("--every", type=int, default=30, metavar="MINUTES")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20, metavar="N")
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+", metavar="GUID")
    return parser


def _check(args: argparse.Namespace) -> None:
    if args.command == "add" and not args.url.startswith(("http://", "https://")):
        raise UsageError(f"not an http(s) URL: {args.url}")
    for flag in ("every", "limit"):
        value = getattr(args, flag, None)
        if value is not None and value < 1:
            raise UsageError(f"--{flag} must be at least 1, got {value}")


def _run(conn: store.Connection, args: argparse.Namespace, *, out: TextIO) -> None:
    if args.command == "add":
        feed = store.add_feed(conn, args.url, title=args.title, every_minutes=args.every)
        print(f"subscribed to {feed.url}, polled every {feed.every_minutes} minutes", file=out)
    elif args.command == "unread":
        entries = store.unread(conn, args.limit)
        for entry in entries:
            print(_line(entry), file=out)
        if not entries:
            print("no unread entries", file=out)
    else:
        store.mark_read(conn, args.guids)


def _line(entry: UnreadEntry) -> str:
    when = entry.published.astimezone().strftime("%Y-%m-%d %H:%M")
    return "\t".join([entry.guid, when, entry.feed_title, entry.title or "(untitled)", entry.link or ""])


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python -m unittest tests.test_cli -v`
Expected: 10 tests, OK

- [ ] **Step 5: Write `pyproject.toml` and ignore build metadata**

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "feedwatch"
version = "1.0.0"
requires-python = ">=3.11"

[project.scripts]
feedwatch = "feedwatch.cli:main"

[tool.setuptools]
packages = ["feedwatch"]
```

```bash
printf '*.egg-info/\n' >> .gitignore
```

- [ ] **Step 6: Smoke-run the command**

```bash
export HOME="$(mktemp -d)"
python -m feedwatch.cli add https://example.org/rss; echo "exit $?"
python -m feedwatch.cli add https://example.org/rss; echo "exit $?"
python -m feedwatch.cli unread
python -m feedwatch.cli read nope; echo "exit $?"
```

Expected:

```
subscribed to https://example.org/rss, polled every 30 minutes
exit 0
feedwatch: already subscribed to https://example.org/rss
exit 1
no unread entries
feedwatch: no stored entry with guid nope
exit 1
```

If `pip` is available, also run `pip install -e .` in a virtualenv and confirm `feedwatch --help` prints `usage: feedwatch [-h] {add,unread,read} ...`.

- [ ] **Step 7: Run the Global Constraints checks over the added lines, then commit**

```bash
git add feedwatch/cli.py tests/test_cli.py pyproject.toml .gitignore
git commit -m "feat: feedwatch command line: add, unread, read"
```

---

### Task 7: Whole-branch verification and the documentation sweep

**Files:** none created by hand; `dopamine:finishing-work` decides what it touches.

- [ ] **Step 1: Run the whole suite**

Run: `python -m unittest -v`
Expected: 38 tests, OK

- [ ] **Step 2: Run the mechanical parts of the Global Constraints checks over the branch**

```bash
base=$(git log -1 --format=%H -- docs/superpowers/plans/2026-10-12-feedwatch-v1.md)  # the plan commit, just before Task 1
# Effects: sqlite3 or conn. only in store.py — expect no output
git diff "$base"...HEAD -U0 -- feedwatch tests ':!feedwatch/store.py' | grep -E '^\+[^+].*(sqlite3|conn\.)'
# Effects: urllib only in fetch.py — expect no output
git diff "$base"...HEAD -U0 -- feedwatch tests ':!feedwatch/fetch.py' | grep -E '^\+[^+].*urllib'
# Concurrency — expect no output
git diff "$base"...HEAD -U0 -- feedwatch tests | grep -E '^\+[^+].*(threading\.Thread|asyncio|multiprocessing)'
# Layout: nothing in the package imports cli or poller — expect no output
grep -nE '^(from|import) .*\b(cli|poller)\b' feedwatch/*.py
# Signatures: every one-line def annotated — expect no output; check the multi-line ones by eye
grep -nE '^\s*def ' feedwatch/*.py tests/*.py | grep -v -- '->' | grep -v '($'
```

Then read the remaining checks (keyword-only third parameters, `except` placement, no `None`/`False` failure returns, no forwarding functions, schema steps) against `git diff "$base"...HEAD` by eye.

- [ ] **Step 3: Close the work**

Invoke `dopamine:finishing-work` (`/home/wogi/projects/dopamine/.dopamine/run/program-design/green/plugin/skills/finishing-work/SKILL.md`) before the workspace is cleaned up. `docs/ROADMAP.md` is declared in `.dopamine/config` but absent; the sweep reports it absent and does not create it.
````



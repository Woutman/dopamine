## p001

#### Final message

I wrote `docs/PROGRAM-DESIGN.md`, working from DESIGN.md and ARCHITECTURE.md and checking each statement against the code in `feedwatch/*.py`. The 4 unit tests still pass. Nothing in the code changed.

**What the document covers:**
- **Modules:** which module implements each architecture component, and what each imports. `models.py` is listed as a module for shared values, not a component.
- **The values:** `Feed`, `Entry`, and the entry dict that `parse` produces and `store.save_entries` consumes.
- **Interfaces:** every public function's signature and contract.
- **How the requirements are met:** each DESIGN requirement traced to the code that meets it.
- **Conventions:** expected failures are returned as values, and only `fetch` raises; schema changes are steps appended to the end of `SCHEMA_STEPS`; dates are stored as ISO text; only `cli` prints.
- **Not this:** one rejected approach, a third-party feed parser, ruled out by DESIGN's "standard library first" principle.

**Decisions and findings:**
- **No template for this document:** the dopamine writing guide has section layouts only for DESIGN, ARCHITECTURE and ROADMAP, so I chose the sections above myself.
- **Approved but not built:** keyword filters (2026-03-02) and retrying failed feeds (2026-03-09) are left out, because the document describes only what the code does now.
- **Possible bug:** `store.mark_read` marks entries read by guid alone, but entries are keyed by feed and guid. The same guid in two feeds would be marked read in both. The document states this as current behaviour; I didn't fix it.
- **Poller restarts:** the record of when each feed was last polled is kept in memory, so a restarted poller polls every feed straight away. It is documented, not changed.
- **ARCHITECTURE.md and `models.py`:** ARCHITECTURE.md doesn't mention `models.py`. I left that document unchanged.

**Commits (on `master` in the fixture repo):**
- `e80274a` adds the document.
- `d652e94` is the end-of-work sweep: "nothing to drain", with the line counts in its message. ROADMAP.md is reported absent.

Since this was ad-hoc work with no plan, the sweep needed a ledger, so I wrote a reconstructed one: `/home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/docs/superpowers/plans/2026-10-12-program-design-doc.reconstructed-ledger.md`.

The document is at `/home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/docs/PROGRAM-DESIGN.md`.

#### docs/PROGRAM-DESIGN.md (added)

````
# Feedwatch — program design

How the components in `ARCHITECTURE.md` are written as Python: the modules, the values passed between them, the functions each exposes, and the conventions they share. What the system is for is `DESIGN.md`; which component owns what is `ARCHITECTURE.md`.

## Modules

One module per component, plus one for shared values, all in the `feedwatch` package.

| Module | Component | Imports from feedwatch |
|---|---|---|
| `fetch.py` | fetch | nothing |
| `parse.py` | parse | nothing |
| `models.py` | shared values, not a component | nothing |
| `store.py` | store | `models` |
| `poller.py` | poller | `fetch`, `parse`, `store` |
| `cli.py` | cli | `store` |

Only the standard library is used: `urllib.request`, `xml.etree.ElementTree`, `sqlite3`, `argparse`, `logging`.

## The values

- **`Feed`** (`models.py`) — `id`, `url`, `title`, `interval_minutes` (default 30). Returned by `store.feeds`.
- **`Entry`** (`models.py`) — `feed_id`, `guid`, `title`, `link`, `published` (`datetime | None`), `read`. Returned by `store.unread`.
- **An entry dict** — `{"guid", "title", "link", "published"}`, with `published` a `datetime` or `None`. This is what `parse` produces and `store.save_entries` consumes. It carries no `feed_id`, because `parse` does not know which feed it is reading; `poller` supplies that when it saves.

## Interfaces

- **`fetch.fetch(url, timeout=10) -> bytes`** — raises `FetchError` for any `OSError` (network, HTTP, timeout).
- **`parse.parse_feed(xml_bytes) -> list[dict] | None`** — `None` when the bytes are not XML or have no `<channel>`. RSS 2.0 only.
- **`parse.parse_item(item) -> dict | None`** — an item's identity is its `<guid>`, falling back to its `<link>`; an item with neither is dropped, since it could not be recognised when seen again.
- **`store.connect(path=DEFAULT_PATH) -> sqlite3.Connection`** — creates the directory and brings the schema up to date.
- **`store.add_feed(conn, url, title, interval_minutes=30) -> (bool, str | None)`** — `(False, reason)` when the URL is already subscribed.
- **`store.feeds(conn) -> list[Feed]`**, in id order.
- **`store.save_entries(conn, feed_id, entries) -> int`** — inserts the entries not already stored and returns how many were new.
- **`store.unread(conn, limit=20) -> list[Entry]`** — newest `published` first.
- **`store.mark_read(conn, guids)`** — marks every entry with one of those guids read, whichever feed it came from.
- **`poller.poll_once(conn, last_polled, now)`** — one pass over the feeds; `last_polled` maps feed id to the time it was last polled and is updated in place. `now` is passed in so a test controls time.
- **`poller.main()`** and **`cli.main(argv=None) -> int`** — the two entry points. `cli` has the subcommands `add URL [--title] [--every MINUTES]`, `unread [--limit N]` and `read GUID...`.

## How the requirements are met

- **Each entry stored once** — `entries` has the primary key `(feed_id, guid)`, and `save_entries` uses `INSERT OR IGNORE`. The new-entry count is the change in `conn.total_changes`.
- **Each feed on its own interval** — `poller.main` wakes every 60 seconds and `poll_once` skips a feed whose `interval_minutes` have not passed since `last_polled`. `last_polled` lives in memory, so a restarted poller polls every feed on its first pass.
- **One failing feed does not stop the others** — `poll_once` catches `FetchError` and a `None` from `parse_feed`, logs a warning, and moves to the next feed. A feed is marked as polled before it is fetched, so a failed feed waits its full interval. `sqlite3` errors are not caught, so a database error ends the poller.

## Conventions

- **Expected failures cross a module boundary as values; unexpected ones as exceptions.** "Not a feed" is `None`, "already subscribed" is `(False, reason)`. `fetch` is the one module that raises, with its own `FetchError`, so callers never see `urllib` exceptions.
- **Every function in `store` takes the connection as its first argument.** Each process opens one connection at start-up and passes it down; tests open one on a temporary file.
- **Writes run inside `with conn:`**, one transaction per call.
- **The schema is `store.SCHEMA_STEPS`**, a list of idempotent statements run in order on every connect. A schema change is a new step appended to the list, never an edit to an existing one, so a database made by an older version keeps working.
- **Datetimes are stored as ISO 8601 text** and converted back to `datetime` on the way out of `store`.
- **Only `cli` prints.** `poller` reports through the `feedwatch.poller` logger.

## Not this

- **A third-party feed parser such as `feedparser`.** RSS 2.0 is within reach of `ElementTree`, and a dependency has to earn its place.
````

#### docs/superpowers/plans/2026-10-12-program-design-doc.reconstructed-ledger.md (added)

````
Reconstructed ledger, written 2026-10-12 from the conversation that did the work; not a sealed superpowers ledger.

# 2026-10-12-program-design-doc

- Task: derive docs/PROGRAM-DESIGN.md from docs/DESIGN.md and docs/ARCHITECTURE.md.
- No schema for PROGRAM-DESIGN.md exists in dopamine:writing-living-documents (it covers DESIGN, ARCHITECTURE, ROADMAP only). Slots chosen by judgment: Modules, The values, Interfaces, How the requirements are met, Conventions, Not this.
- Every statement was checked against feedwatch/*.py; tests pass (4, unittest).
- Specs 2026-03-02 keyword filters and 2026-03-09 retry failed feeds are approved but not implemented; they are not described in PROGRAM-DESIGN.md, which states the present.
- Observed in code, not changed: store.mark_read marks by guid alone, across feeds, although entries are keyed (feed_id, guid). Recorded in PROGRAM-DESIGN.md as current behaviour.
- Observed in code, not changed: models.py is a shared-values module absent from ARCHITECTURE.md's assembly. Left out of ARCHITECTURE.md as below its altitude.
- No edits to DESIGN.md or ARCHITECTURE.md; nothing else to drain.
````


## p002

#### Final message

I haven't written anything yet. The recipe has me ask you one slot at a time and write nothing until every slot is answered.

**How I'm treating this:** as architectural work. The output is `docs/PROGRAM-DESIGN.md`, the path declared in `.dopamine/config`. It doesn't exist yet. The inputs are `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, plus the code in `feedwatch/` (about 280 lines, which I read in full). The language is Python, standard library only, because DESIGN.md says "Standard library first".

**Which slots I'll ask about** (you can add or drop any):
- **Core, always asked:** Types, Errors, Effects, Signatures, Layout, Modules.
- **Concurrency: asked.** ARCHITECTURE.md describes two processes, the poller and the CLI, that open the same SQLite file.
- **Persistence: asked.** ARCHITECTURE.md says "the schema gains tables and columns as features land, and an existing database has to keep working".
- **Public surface: not asked.** DESIGN.md describes a command-line tool for one person, not a library or an API.

---

### Slot 1 of 8: Types

*How are domain concepts like a feed or an entry represented in code, and where is raw input (feed XML, CLI arguments, database rows) turned into them?*

**Superpowers' default:** none.

**What the code does now:** two different things.
- **Dataclasses:** `Feed` and `Entry` are mutable `@dataclass`es (`feedwatch/models.py:7` and `feedwatch/models.py:15`). `store` builds them from database rows (`store.py:55`, `store.py:81`).
- **Plain dicts:** `parse` returns each entry as a dict (`parse.py:31`), and `store.save_entries` reads it by key (`store.py:66`). The `Entry` dataclass is never used on the way into the store.

**My recommendation: frozen dataclasses everywhere, converted in the module that owns the format.**
- Every domain concept is a frozen dataclass in `models.py`.
- Raw input becomes a model in the module that owns its format: `parse` for XML, `store` for rows, `cli` for arguments.
- No dict carrying domain data passes between modules.
- Pydantic is out, because DESIGN.md says "Standard library first".

```python
@dataclass(frozen=True)
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None

def parse_feed(xml_bytes: bytes) -> list[Entry]: ...
```

*How a diff would be checked:* no added or changed function that takes or returns domain data between modules uses a `dict`; every new model class is `@dataclass(frozen=True)` in `models.py`.

**Alternatives:**
1. **Use dataclasses, but leave them mutable as they are now.** Smaller change to existing code. The cost is that a value can be changed after it has been handed to another module, for example `Entry.read`.
2. **Allow `TypedDict` for data passed between modules.** The data stays a plain dict, so it is lighter and closer to what `parse` does now. The cost is two conventions instead of one, and nothing checks the types at runtime.

Which do you want for Types: my recommendation, one of the alternatives, or your own rule?


## p003

#### Final message

I wrote `docs/PROGRAM-DESIGN.md` (47 lines) and committed it. It covers how the code inside each component is built, which ARCHITECTURE.md doesn't go into.

**Where it comes from:** DESIGN.md and ARCHITECTURE.md alone don't say much at the code level. A living document has to describe the present, so I also read every module in `feedwatch/` and the tests. The two approved specs (keyword filters, retry failed feeds) aren't implemented, so they're left out.

**What it covers, in order:**
- **The values:** `Feed`/`Entry`, the dict a parsed entry is passed as, entry identity `(feed_id, guid)` with the link used when there's no guid, and `published`.
- **Each module's interface:** a table of each module's functions and what callers can rely on, for example `parse_feed` returning `None` for anything that isn't RSS, and `poll_once` taking the schedule and `now` from its caller.
- **How failure is signalled:** `FetchError` for network failures, `None` for input that isn't a feed, `(False, reason)` for a refusal the user should read, and anything else, database errors included, stops the process.
- **Persistence conventions:** schema changes are appended to `SCHEMA_STEPS` and never edit an existing step; each write is one `with conn:` transaction; duplicates are dropped by `INSERT OR IGNORE`; datetimes are stored as ISO text.
- **Dependencies:** standard library only.
- **How it is tested.**

**Decision for you:** dopamine's writing-living-documents skill has slot schemas only for DESIGN, ARCHITECTURE and ROADMAP, not PROGRAM-DESIGN. I chose the sections above myself. If there's a set order you want instead, I'll restructure it.

**Two possible bugs in the code.** I left both unchanged and the document describes them as current behaviour:
1. `store.mark_read` matches on guid alone, even though an entry's identity is `(feed_id, guid)`. A guid that appears in two feeds gets marked read in both.
2. `store.unread` sorts by the stored ISO text. That isn't chronological when entries carry different UTC offsets.

**Commits on `master`:**
- `ddef62a`: the document, plus a reconstructed ledger at `docs/superpowers/plans/2026-10-12-derive-program-design.reconstructed-ledger.md`, since this was ad-hoc work with no superpowers ledger.
- `32ae2b2`: `sweep: … — nothing to drain`, with line counts DESIGN 33, ARCHITECTURE 29, PROGRAM-DESIGN 47. ROADMAP.md is declared in `.dopamine/config` but doesn't exist, and I didn't create it.

All 4 existing tests pass (`python3 -m unittest tests.test_feedwatch`).

File: /home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/docs/PROGRAM-DESIGN.md

#### docs/PROGRAM-DESIGN.md (added)

````
# Feedwatch — program design

How the code inside the components of `ARCHITECTURE.md` is shaped: the values passed between them, the interface of each module, and the conventions a change has to keep.

## The values

- **`Feed`** and **`Entry`** (`feedwatch/models.py`) are plain dataclasses. `store` returns them; nothing else constructs them.
- **A parsed entry** travels from `parse` to `store` as a dict with the keys `guid`, `title`, `link` and `published`. It carries no feed: `parse` does not know which feed it is reading, and `store.save_entries` is told.
- **An entry's identity** is `(feed_id, guid)`. The guid is the item's `<guid>`, or its `<link>` when it has none; an item with neither is dropped by `parse`, because it could not be recognised when seen again.
- **`published`** is a `datetime` parsed from `<pubDate>`, or `None` when the item has no `<pubDate>`.

## Each module's interface

| Module | Interface | Contract |
|---|---|---|
| `fetch` | `fetch(url, timeout=10) -> bytes` | Raises `FetchError` for any network failure; returns the response body otherwise. |
| `parse` | `parse_feed(xml_bytes) -> list[dict] \| None` | `None` when the bytes are not RSS: unparseable XML, or no `<channel>`. RSS is the only format read. |
| `store` | `connect(path=DEFAULT_PATH)`, `add_feed`, `feeds`, `save_entries`, `unread`, `mark_read` | Every function after `connect` takes the connection as its first argument; the module keeps no state of its own. `DEFAULT_PATH` is `~/.feedwatch/feeds.db`. |
| `poller` | `poll_once(conn, last_polled, now)`, `main()` | `poll_once` is one pass over the feeds that are due. The schedule is the caller's `last_polled` dict of feed id to time, and `now` is passed in rather than read. `main` calls it once a minute, so a minute is the finest interval that is honoured. |
| `cli` | `main(argv=None) -> int` | Subcommands `add URL [--title] [--every MINUTES]`, `unread [--limit N]` and `read GUID...`. Returns the process exit code. |

## How failure is signalled

Each kind of failure has one shape, and the caller that handles it is fixed:

- **The network failed** — `fetch` raises `FetchError`. `poll_once` logs a warning and moves to the next feed.
- **The bytes are not a feed** — `parse_feed` returns `None`. `poll_once` logs a warning and moves to the next feed.
- **A refusal the user should read** — `store` returns `(False, reason)` instead of `(True, None)`. `cli` prints the reason to stderr and exits 1. Subscribing to a URL twice is refused this way.
- **Anything else**, a database error included, is not caught and stops the process.

A feed is marked polled before it is fetched, so a feed that fails waits its full interval before it is tried again.

## Persistence conventions

- **The schema is `store.SCHEMA_STEPS`**, a list of idempotent statements run in order on every `connect`. A schema change is a new step appended to the list, never an edit to an existing one: that is how a database created by an older version keeps working.
- **Each writing function is one transaction**, under `with conn:`.
- **An entry is stored once** by `INSERT OR IGNORE` against the `(feed_id, guid)` primary key; `save_entries` returns how many rows were new.
- **Datetimes are stored as ISO-8601 text**, and `unread` orders by that text.
- **`mark_read` addresses entries by guid alone**, so it marks a guid read in every feed that holds it.

## Dependencies

The standard library only: `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`, `dataclasses`, and `unittest` for the tests.

## How it is tested

`unittest`, in `tests/test_feedwatch.py`. `store` is tested against a fresh database in a temporary directory, through `connect(path)`; `parse` against byte literals. No test touches the network, and `fetch`, `poller` and `cli` have no tests.
````

#### docs/superpowers/plans/2026-10-12-derive-program-design.reconstructed-ledger.md (added)

````
# 2026-10-12-derive-program-design — reconstructed ledger

Reconstructed on 2026-10-12 from the conversation; ad-hoc work, no superpowers ledger existed.

- Asked to derive `docs/PROGRAM-DESIGN.md` from `docs/DESIGN.md` and `docs/ARCHITECTURE.md`. The document was declared `living:` in `.dopamine/config` and absent.
- No slot schema exists for PROGRAM-DESIGN.md in `dopamine:writing-living-documents` (it has schemas for DESIGN, ARCHITECTURE and ROADMAP only). Chose slots: The values; Each module's interface; How failure is signalled; Persistence conventions; Dependencies; How it is tested.
- Read every module in `feedwatch/` and `tests/test_feedwatch.py` so the document describes the code as it is, not only what DESIGN/ARCHITECTURE say.
- Left out the keyword-filter and retry specs (2026-03-02, 2026-03-09): neither is implemented.
- Observed, recorded in the document as present behaviour and not changed: `store.mark_read` matches guid alone, across feeds, though identity is `(feed_id, guid)`; `unread` orders by ISO text, which is not chronological across differing UTC offsets.
- Tests: `python3 -m unittest tests.test_feedwatch` — 4 passed.
````


## p004

#### Final message

I've started the brainstorm-program-design recipe. Nothing is written yet: the document only gets written once every slot has an answer.

**Setup:**
- **Output:** `docs/PROGRAM-DESIGN.md`, which `.dopamine/config` declares but doesn't exist yet.
- **Inputs:** `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, both present.
- **Language:** Python only, all standard library (the design's principle is "standard library first").

**Slots to ask**
- **Core, always asked:** Types, Errors, Effects, Signatures, Layout, Modules.
- **Concurrency — triggered.** The architecture's "What runs where" has two processes, the poller and the CLI, and both open the same SQLite file.
- **Persistence — triggered.** The architecture's "Where state lives" says the schema gains tables and columns over time and an existing database has to keep working.
- **Public surface — not triggered.** The design describes a command-line tool for one person, not a library or API that others use.

You can add or drop any of these. I'll ask one slot per turn.

---

**Slot 1 of 8: Types.** How are domain concepts represented, and where is input turned into them?

**Superpowers' default:** none.

**What the code does now:** two patterns for the same concept.
- Dataclasses: `Feed` and `Entry` at `feedwatch/models.py:7-22`. `store` returns them (`store.py:55`, `store.py:80-84`) and `cli` reads them by attribute (`cli.py:30`).
- Plain dicts: `parse_item` returns a dict (`parse.py:31-36`). `store.save_entries` reads it by key (`store.py:66-67`), and so does the test (`tests/test_feedwatch.py:24`). So a parsed entry travels from `parse` to `store` as an unchecked dict, even though `models.Entry` exists.

**My recommendation:** every value that crosses a module boundary is a dataclass in `models.py`. The module that owns a format turns raw input into those dataclasses before passing it on: `parse` for XML, `store` for rows, `cli` for arguments. No dicts or tuples cross a boundary. Pydantic is left out because of the standard-library principle.
```python
@dataclass(frozen=True)
class ParsedEntry:          # what parse knows: no feed_id yet
    guid: str
    title: str
    link: str
    published: datetime | None

def parse_feed(xml_bytes: bytes) -> list[ParsedEntry]: ...
def save_entries(conn, feed_id: int, entries: list[ParsedEntry]) -> int: ...
```
*Check:* no added or changed function in one module takes or returns a `dict` or bare tuple that stands for a domain value. Each such value is a type from `models.py`.

**Alternatives:**
1. **Keep dicts from `parse`, dataclasses from `store` onward.** This is the least change. The cost is that a misspelled key only fails at runtime inside `store`, and the codebase keeps two ways of representing one concept.
2. **`TypedDict` for parse output.** A type checker catches the keys, and current call sites (`e["guid"]`) keep working. The cost is that it's still a dict at runtime, so nothing is checked when the code runs, and it adds a third representation alongside the dataclasses.

Also, do you want `NewType` IDs such as `FeedId = NewType("FeedId", int)`? My recommendation is no: there is only one kind of integer ID, so they'd add ceremony without catching anything.

**Which do you choose for Types: my recommendation, alternative 1, alternative 2, or your own rule?**


## p005

#### Final message

I'm working through `dopamine:brainstorm-program-design`, which `superpowers:brainstorming` puts in the **architectural** class. It's limited to the rules for how code is shaped inside feedwatch's components. You choose every rule, one slot at a time. Nothing goes into `docs/PROGRAM-DESIGN.md` until every slot has an answer.

**Inputs.** `.dopamine/config` names `docs/PROGRAM-DESIGN.md` as the output; it doesn't exist yet. The inputs are `docs/DESIGN.md` and `docs/ARCHITECTURE.md`, and both are present. The language is Python, and DESIGN.md sets "standard library first". I read all of the code (`feedwatch/*.py`, `tests/test_feedwatch.py`) because it is only 283 lines.

**Slots I'll ask about.** You can add or drop any of them.
- **Core slots, always asked:** Types, Errors, Effects, Signatures, Layout, Modules.
- **Concurrency is asked.** ARCHITECTURE.md lists two processes, the poller and the CLI, sharing one SQLite file. The approved retry spec (`2026-03-09-retry-failed-feeds-design.md`) also needs retries to run in the background without overlapping.
- **Persistence is asked.** ARCHITECTURE.md says "the schema gains tables and columns as features land, and an existing database has to keep working".
- **Public surface is not asked.** DESIGN.md describes a command-line tool for one user, not a library or an API.

---

### Question 1 of 8: Types
*How are domain concepts represented, and where is input turned into them?*

**Superpowers' default:** none.

**What the code does now:** two patterns.
- **Dataclasses:** `Feed` and `Entry` are mutable dataclasses in `feedwatch/models.py:7-22`, and `store` returns them (`store.py:55`, `store.py:80-84`).
- **Plain dicts:** `parse` returns each entry as a dict (`parse.py:31-36`), and `store.save_entries` reads it by key (`store.py:66-67`). So the same idea, "an entry", crosses `parse → poller → store` as a dict and comes back out of `store` as an `Entry`.

**My recommendation: a frozen dataclass for each domain concept, created in the module that reads the outside world.** That means `parse` for XML, `store` for SQLite rows and `cli` for arguments. Past that point, no domain concept travels as a dict or a tuple. Pydantic would be the usual Python choice at a boundary, but "standard library first" rules it out here.

```python
# models.py
@dataclass(frozen=True)
class ParsedEntry:          # what parse knows; it has no feed id yet
    guid: str
    title: str
    link: str
    published: datetime | None

# parse.py
def parse_item(item) -> ParsedEntry | None: ...
```

- *Why:* the shape a function receives is visible in its signature and checked by the type checker, not discovered at a `KeyError`.
- *Check:* no added function passes a domain concept between modules as a `dict` or a bare tuple. Every new domain type is a dataclass in `models.py`.

**Alternatives:**
- **A. Keep dicts, typed with `TypedDict`, for values that only pass through.** This is lighter and is what `parse` already does. The cost is that nothing stops a misspelled key until runtime, unless you run a type checker.
- **B. My recommendation plus `NewType` for ids**, such as `FeedId = NewType("FeedId", int)`. This stops a feed id being passed where some other integer belongs, at the cost of a little extra ceremony at each `store` call.

Which do you want for Types: my recommendation, A, B, or a rule of your own?


## p006

#### Final message

I'm running `dopamine:brainstorm-program-design`, through `superpowers:brainstorming` with the classification **architectural**. I'll ask one question per slot and write nothing to `docs/PROGRAM-DESIGN.md` until you have answered all of them.

**Setup**
- **Files:** `.dopamine/config` declares `docs/PROGRAM-DESIGN.md`, which doesn't exist yet. `docs/DESIGN.md` and `docs/ARCHITECTURE.md` are both present.
- **Language:** Python, standard library only. The design's principle is "a dependency has to earn its place".

**Slots I'll ask about**
- **Always asked:** Types, Errors, Effects, Signatures, Layout and Modules.
- **Concurrency: asked.** Two processes, the poller and the CLI, open the same SQLite file.
- **Persistence: asked.** `ARCHITECTURE.md` says the schema gains tables and columns over time and an existing database has to keep working.
- **Public surface: not asked.** `DESIGN.md` describes one user at a terminal, with no library or API that others consume.

You can add or drop any slot.

---

**Question 1 of 8: Types.** How should things like feeds and entries be represented in code, and where should raw input become those types?

**Superpowers' default:** none.

**What the code does now (two patterns):**
- `feedwatch/models.py:7-22`: `Feed` and `Entry` are dataclasses. `store.feeds()` and `store.unread()` build them from database rows (`store.py:55`, `store.py:80`).
- `feedwatch/parse.py:31`: `parse_feed` returns plain dicts. `store.save_entries` reads them back by key, as in `e["guid"]` (`store.py:66`). So a parsed entry crosses from parse to poller to store as an untyped dict.

**My recommendation:** use dataclasses from the standard library and no dicts between modules. Every domain value is a `@dataclass(frozen=True)` in `models.py`. Each kind of input becomes one of those types in the module that owns it: XML in `parse`, database rows in `store`, command-line arguments in `cli`.

```python
@dataclass(frozen=True)
class ParsedItem:
    guid: str
    title: str
    link: str
    published: datetime | None

def parse_feed(xml_bytes: bytes) -> list[ParsedItem]: ...
```

*Check:* no added or changed function passes a domain value between modules as a `dict` or a tuple; every new domain type is a dataclass in `models.py`.

**Alternatives:**
- **A. `TypedDict` for the parse output.** The current code barely changes and type checkers catch key typos. The cost is two ways to represent a domain value (dicts from parse, dataclasses from store), and nothing is checked at runtime.
- **B. Pydantic models at the boundaries (XML and command line).** You get validation for free. The cost is the project's first third-party dependency, against the standard-library-first principle.

Which do you want: the recommendation, A, B, or something else? Should `Feed` and `Entry` also become frozen?


## p007

#### Final message

I wrote `docs/PROGRAM-DESIGN.md` (73 lines). I also found a bug: one feed with a bad date in it stops the whole poller.

**The bug.** If a feed's `<pubDate>` can't be read, `parse_item` raises `ValueError` (I checked this on Python 3.14.4). `poll_once` doesn't catch it, so one bad feed kills the poller. That breaks DESIGN.md ("keep polling the other feeds when one fails") and ARCHITECTURE.md ("a feed that cannot be ... parsed is logged and skipped"). PROGRAM-DESIGN.md only describes the failures the code really handles, so the problem is in the code, not the documents. I haven't fixed it.

**What the document covers.** I took it from the two documents and checked every statement against `feedwatch/` and the tests, so it describes what the code does now. The tests pass (4 of 4). Its sections are:
- the modules and what each one exposes;
- the values passed between modules (`Feed`, the entry dict, `Entry`);
- the database: the table layout, and how the schema grows by adding steps to `store.SCHEMA_STEPS` so older databases keep working;
- how each module reports failure, and why a database error stops the poller;
- the poll loop: a 60-second tick, a feed's poll time is recorded before it is fetched, and nothing is saved across restarts;
- the command-line commands;
- the tests.

**Choices you may want to change:**
- **No template existed for this document.** The dopamine writing guide only covers DESIGN, ARCHITECTURE and ROADMAP, so I picked the sections above myself. If you have a set layout in mind, the document needs reshaping to fit it.
- **The two approved specs are left out.** Keyword filters and retrying failed feeds aren't built yet, and the document only describes what exists.
- **`read GUID` marks entries read by guid alone,** but entries are keyed by feed and guid. So the same guid in two feeds gets marked read in both. I wrote this down as how it works today; you may consider it a bug too.

**Wrap-up.** Following the finishing-work skill, I wrote a reconstructed ledger and made one commit, `2267e1e sweep: 2026-10-12-program-design — 1 edit`, with the line counts in its message. It went straight onto `master` without a separate branch. `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist, and I didn't create it.

Should I fix the date bug? The likely fix is to have `parse_item` return no date when it can't read one, plus a regression test.

Files are in `/home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/`:
- `docs/PROGRAM-DESIGN.md`
- `docs/superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md`

#### docs/PROGRAM-DESIGN.md (added)

````
# Feedwatch — program design

How the components in `ARCHITECTURE.md` are built as Python: the modules, the values that cross between them, and the conventions every module follows. What the system is for is `DESIGN.md`; which component owns what is `ARCHITECTURE.md`.

## The modules

One module per component, in the package `feedwatch`, plus one for shared values. Standard library only.

| Module | Component | Public surface |
|---|---|---|
| `fetch.py` | fetch | `fetch(url, timeout=10) -> bytes`; raises `FetchError` |
| `parse.py` | parse | `parse_feed(xml_bytes) -> list[dict] \| None` |
| `store.py` | store | `connect(path=DEFAULT_PATH)`, `add_feed`, `feeds`, `save_entries`, `unread`, `mark_read` |
| `poller.py` | poller | `poll_once(conn, last_polled, now)`, `main()` |
| `cli.py` | cli | `main(argv=None) -> int`, subcommands `add`, `unread`, `read` |
| `models.py` | — | the dataclasses `Feed` and `Entry` |

Imports follow `ARCHITECTURE.md`'s call graph and nothing else: `poller` imports `fetch`, `parse` and `store`; `cli` imports `store`; `store` imports `models`. `fetch` and `parse` import nothing from the package.

## The values that cross between modules

- **`Feed`** — `id`, `url`, `title`, `interval_minutes` (default 30). Built by `store.feeds`.
- **Entry dict** — `{"guid", "title", "link", "published"}`, where `published` is a `datetime` or `None`. Produced by `parse`, consumed by `store.save_entries`. A plain dict, so `parse` knows nothing of the store's model.
- **`Entry`** — `feed_id`, `guid`, `title`, `link`, `published`, `read`. Built by `store.unread` for the CLI.

An entry's identity is its `guid`, falling back to its `link`; `parse` drops an item that has neither, since it could not be recognised when seen again. In the database an entry is keyed by `(feed_id, guid)`.

## The database

`store.SCHEMA_STEPS` is the schema: an ordered list of idempotent statements (`CREATE TABLE IF NOT EXISTS`, and the like), all run on every `connect`. A step that has already been applied is a no-op, so a database created by an older version picks up exactly the steps added since. The schema therefore grows by **appending** a step, never by editing one: an edit would never reach a database that already ran the original. This is how an existing database keeps working as features land.

- `feeds(id, url UNIQUE, title, interval_minutes DEFAULT 30)`
- `entries(feed_id → feeds.id, guid, title, link, published, read DEFAULT 0)`, primary key `(feed_id, guid)`. `published` is ISO-8601 text or `NULL`.

"Store each entry once" is the primary key plus `INSERT OR IGNORE`; `save_entries` reports how many rows were new from `conn.total_changes`. "Subscribed once" is the `UNIQUE` on `feeds.url`.

`store.connect` creates `~/.feedwatch/` if it is missing. Every function after it takes the connection as its first argument, so a caller — the tests included — chooses the file.

## How failure is signalled

Each module signals failure in the shape its caller needs to handle it:

| Where | Failure | Shape |
|---|---|---|
| `fetch` | network or HTTP error (`OSError`) | raises `FetchError` |
| `parse` | not XML, or no `<channel>` | returns `None` |
| `parse` | one item with no identity | that item is left out |
| `store.add_feed` | URL already subscribed | returns `(False, reason)`; `(True, None)` on success |
| `store`, anywhere | any other `sqlite3` error | propagates |

`poller.poll_once` catches `FetchError` and a `None` from `parse`, logs a warning naming the URL, and moves to the next feed. It catches nothing from `store`, so a database error ends the poller, as `ARCHITECTURE.md` requires. `cli` prints `add_feed`'s reason to stderr and exits 1.

Writes run inside `with conn:`, so each call to `add_feed`, `save_entries` or `mark_read` is one transaction.

## The poll loop

`poller.main` wakes every 60 seconds and calls `poll_once` with the current time. `poll_once` walks `store.feeds` and polls each feed whose interval has elapsed since its entry in `last_polled`, a dict of feed id to time held in memory. A feed is stamped **before** it is fetched, so a feed that fails waits for its next interval rather than being retried on the next tick.

`last_polled` is not persisted: a restarted poller polls every feed on its first tick. Intervals are honoured to the resolution of the 60-second tick.

`now` and `last_polled` are parameters rather than read inside `poll_once`, so one pass can be run against a chosen clock.

## The command line

`cli.main` parses `argv` with `argparse`, opens one connection, and dispatches:

- `add URL [--title T] [--every MINUTES]` — the title defaults to the URL, the interval to 30.
- `unread [--limit N]` — newest first by `published`, 20 by default; entries with no date come last. Prints each entry's `guid`, title and link.
- `read GUID [GUID ...]` — marks entries read by `guid` alone, so an identical guid in two feeds is marked read in both.

## Tests

`tests/test_feedwatch.py`, `unittest`, run with `python -m unittest`. Each test opens a fresh database in a temporary directory through `store.connect(path)`. The tests cover `parse` and `store` directly; nothing exercises `fetch` against the network.
````

#### docs/superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md (added)

````
# 2026-10-12-program-design — reconstructed ledger

> Reconstruction, written 2026-10-12 from the conversation that did the work. Ad-hoc unit; no plan file and no superpowers ledger.

## Task

Derive `docs/PROGRAM-DESIGN.md` from `docs/DESIGN.md` and `docs/ARCHITECTURE.md`.

## What was done

- Read both source documents, all of `feedwatch/`, `tests/test_feedwatch.py` and the two specs under `docs/superpowers/specs/`.
- No slot schema for `PROGRAM-DESIGN.md` exists in `dopamine:writing-living-documents` (it covers DESIGN, ARCHITECTURE and ROADMAP only). Chose the sections: modules, values crossing between modules, the database, how failure is signalled, the poll loop, the command line, tests.
- Every statement was checked against the code, not only the two documents. Checked by running: SQLite sorts `NULL` last under `ORDER BY ... DESC`; `email.utils.parsedate_to_datetime("garbage")` raises `ValueError` on Python 3.14.4.
- The two approved specs (keyword filters, retry failed feeds) are not implemented, so the document does not describe them.

## Findings, not drained

- A feed whose `<pubDate>` cannot be parsed makes `parse.parse_feed` raise `ValueError`; `poller.poll_once` does not catch it, so one bad feed stops the poller. This contradicts DESIGN.md ("keep polling the other feeds when one fails") and ARCHITECTURE.md ("a feed that cannot be ... parsed is logged and skipped"). PROGRAM-DESIGN.md describes only the failures the code actually handles; the gap is in the code, not the documents. Reported to the human, not fixed.
- `store.mark_read` matches on `guid` alone although entries are keyed by `(feed_id, guid)`; recorded in PROGRAM-DESIGN.md as present behaviour.

## Living-document consequence

- `docs/PROGRAM-DESIGN.md` created. No edit to DESIGN.md or ARCHITECTURE.md.
````


## p008

#### Final message

I've done the setup steps of the recipe and I'm now asking you one slot at a time. Nothing is written to `docs/PROGRAM-DESIGN.md` yet; it gets written once every slot has an answer.

- **Input and output:** `.dopamine/config` declares `docs/PROGRAM-DESIGN.md`, which doesn't exist yet. `DESIGN.md` and `ARCHITECTURE.md` are both present. `ROADMAP.md` is declared but missing too.
- **Language:** Python, standard library first (from `DESIGN.md`).
- **Code read:** the codebase is about 280 lines, so I read all of it.

**Which slots I'll ask about.** I'll ask about all six core slots (Types, Errors, Effects, Signatures, Layout, Modules). For the optional slots:
- **Concurrency — yes.** `ARCHITECTURE.md` describes two processes, the poller and the CLI, both opening the same SQLite file.
- **Persistence — yes.** The architecture says the schema gains tables and columns over time and an existing database has to keep working.
- **Public surface — no.** `DESIGN.md` describes one user at a terminal, not a library or an API.

You can add or drop any of these.

---

**Slot 1 of 8: Types.** How are domain concepts represented, and where is input turned into them?

- **Superpowers' default:** none.
- **What the code does now (two patterns):**
  - Dataclasses for stored values: `Feed` and `Entry` (`feedwatch/models.py:7`, `:16`), built in `store.py:55` and `:81`.
  - Plain dicts on the parse → store path: `parse_item` returns a dict (`feedwatch/parse.py:31`), and `store.save_entries` reads it by key (`feedwatch/store.py:66`). Tests depend on this too (`tests/test_feedwatch.py:24`).

**My recommendation (A):** domain values are dataclasses in `models.py`. Untrusted input (feed XML, CLI arguments, database rows) is turned into one at the module that owns that input. No dict or tuple carries a domain value between modules. This uses no dependency, and you get one shape per concept.

```python
# parse.py
def parse_item(item: ET.Element) -> Entry | None:
    ...
    return Entry(feed_id=feed_id, guid=guid, title=..., link=..., published=...)
```

*Check:* no added function passes or returns a `dict` or tuple holding a domain value across a module boundary. Each new domain concept is a dataclass in `models.py`.

**Alternatives:**
- **(B) A as well as frozen dataclasses, plus `NewType` for identifiers** (`FeedId`, `Guid`). The type checker catches a swapped `feed_id`/`guid`. The cost is a little ceremony, and it's only worth it if you run a type checker.
- **(C) Keep dicts between parse and store, dataclasses only for what store returns.** This matches the code today and needs no change. The cost is that the shape of an entry is defined twice and key typos only fail at runtime.

Which one do you want: A, B, C, or your own?


## p009

#### Final message

I've written `docs/PROGRAM-DESIGN.md` (52 lines) and committed it. It goes one level below ARCHITECTURE.md, and I checked every statement against the code as well as the two source documents. The 4 tests pass.

**What's in it:**
- **The modules:** which module holds each component and what it exposes.
- **The values that cross:** the raw bytes, the parsed-entry dicts, `Feed`, `Entry`, and the one shared connection.
- **Invariants:** an entry is identified by feed plus guid, saving the same entry twice stores it once, a feed URL can only be subscribed once, every connect brings the schema up to date, how often the poller runs, and the order unread entries come back in.
- **How each boundary signals failure:** what each module raises or returns when something goes wrong, and who handles it.
- **The CLI surface:** the `add`, `unread` and `read` commands.

There's no schema for PROGRAM-DESIGN.md in `dopamine:writing-living-documents`, so I picked those sections myself. Please tell me if you want a different shape. I didn't include a "Not this" section because nothing records a rejected approach at this level, and I'd have had to make one up. Keyword filters and retrying failed feeds are left out too: both have approved specs but aren't built yet.

**Where the code contradicts ARCHITECTURE.md (reported, not fixed):** ARCHITECTURE.md says a feed that can't be fetched or parsed is logged and skipped. In three cases the poller crashes instead:
- **Bad date:** a `<pubDate>` it can't read raises `ValueError` in `parse.parse_item`. I reproduced this.
- **URL with no scheme:** `urlopen` raises `ValueError`, which isn't an `OSError`, so `fetch.fetch` doesn't turn it into a `FetchError`. I reproduced this too.
- **Broken HTTP response:** errors like `IncompleteRead` aren't `OSError`s either, so they escape the same way. I got this from reading the code and didn't reproduce it.

**Smaller problems:**
- **`store.mark_read`** matches on guid alone, so if two feeds share a guid, marking it read marks both.
- **Unread order** compares dates as text, and those dates mix time-zone offsets with some that have no time zone, so the list isn't strictly newest first.
- **One slow feed holds up the rest of a pass**, because feeds are fetched one at a time with a 10-second timeout.

**Housekeeping:** this was ad-hoc work, so I wrote a reconstructed ledger following `dopamine:finishing-work`. It repeats the findings above. One commit, `68665ab sweep: 2026-10-12-program-design — 1 edit`, contains both files and lists line counts: DESIGN 33, ARCHITECTURE 29, PROGRAM-DESIGN 52, ROADMAP absent.

Do you want me to fix the three crash cases so the code matches ARCHITECTURE.md?

Files are in /home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/docs/:
- PROGRAM-DESIGN.md
- superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md

#### docs/PROGRAM-DESIGN.md (added)

````
# Feedwatch — program design

The code that realises `ARCHITECTURE.md`: each component's module, what it exposes, the values that cross between them, and how failure is signalled at each boundary. Component boundaries and dependency directions are `ARCHITECTURE.md`'s; this document does not restate them.

## The modules

| Component | Module | Exposes |
|---|---|---|
| fetch | `feedwatch/fetch.py` | `fetch(url, timeout=10) -> bytes`; `FetchError` |
| parse | `feedwatch/parse.py` | `parse_feed(xml_bytes) -> list[dict] \| None` |
| store | `feedwatch/store.py` | `connect(path=DEFAULT_PATH)`, `add_feed`, `feeds`, `save_entries`, `unread`, `mark_read` |
| poller | `feedwatch/poller.py` | `poll_once(conn, last_polled, now)`, `main()` |
| cli | `feedwatch/cli.py` | `main(argv=None) -> int` |
| — | `feedwatch/models.py` | `Feed`, `Entry` dataclasses |

Standard library only: `urllib.request`, `xml.etree.ElementTree`, `email.utils`, `sqlite3`, `argparse`, `logging`.

## The values that cross

- **Raw feed** — `bytes`, from `fetch` to `parse`. `fetch` never inspects them.
- **Parsed entry** — a `dict` with `guid`, `title`, `link`, `published` (aware or naive `datetime`, or `None`), from `parse` to `store.save_entries`. `parse` does not know the feed's id; the poller supplies it.
- **`Feed`** — `id`, `url`, `title`, `interval_minutes`; returned by `store.feeds`.
- **`Entry`** — `feed_id`, `guid`, `title`, `link`, `published`, `read`; returned by `store.unread`.
- **Connection** — one `sqlite3.Connection` per process, opened by `store.connect` and passed to every `store` function. Callers never write SQL.

## Invariants

- **An entry's identity is `(feed_id, guid)`**, the primary key of `entries`. `guid` is the item's `<guid>`, falling back to its `<link>`; an item with neither is dropped by `parse_item`, because it could not be recognised when seen again.
- **Storing is idempotent.** `save_entries` inserts with `INSERT OR IGNORE` and returns the number of rows that were new.
- **A feed URL is subscribed once.** `feeds.url` is `UNIQUE`; `add_feed` reports a duplicate rather than raising.
- **Every connect brings the schema up to date.** `connect` runs `SCHEMA_STEPS` in order; each step is idempotent, so a database made by an older version gains what was added since. A schema change is a new step appended to the list, never an edit to an existing one.
- **Polling cadence.** `poller.main` calls `poll_once` every 60 seconds; `poll_once` fetches a feed when it has never been polled in this process or its `interval_minutes` have elapsed. `last_polled` lives in memory, so a restarted poller polls every feed on its first pass.
- **Unread order** is `published` descending, compared as the stored ISO-8601 text; entries without a date sort last.

## How each boundary signals failure

| Boundary | Signal | Handled by |
|---|---|---|
| `fetch.fetch` | raises `FetchError` for any `OSError` (network, HTTP status, timeout) | `poll_once` logs a warning and moves to the next feed |
| `parse.parse_feed` | returns `None` when the bytes are not XML or have no `<channel>` | `poll_once` logs a warning and moves to the next feed |
| `store.add_feed` | returns `(False, reason)` on a duplicate URL, `(True, None)` otherwise | `cli` prints the reason to stderr and exits 1 |
| any other `store` call | `sqlite3` exceptions propagate | nothing catches them: the poller or the command stops |

A skipped feed keeps its `last_polled` time, so it is next tried when its interval is up.

## The CLI surface

`python -m feedwatch.cli` with one of:

- `add URL [--title T] [--every MINUTES]` — subscribe; title defaults to the URL, interval to 30.
- `unread [--limit N]` — print up to N (default 20) unread entries as `guid  title` and an indented link.
- `read GUID [GUID ...]` — mark entries read.
````

#### docs/superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md (added)

````
# 2026-10-12-program-design — reconstructed ledger

> Reconstructed 2026-10-12 from the conversation that did the work; there was no superpowers ledger (ad-hoc unit of work).

## Task

"Derive docs/PROGRAM-DESIGN.md from docs/DESIGN.md and docs/ARCHITECTURE.md." `docs/PROGRAM-DESIGN.md` was declared `living:` in `.dopamine/config` and absent.

## What was done

- Read `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, every module under `feedwatch/`, `tests/test_feedwatch.py`, and both specs under `docs/superpowers/specs/`.
- `dopamine:writing-living-documents` has no schema for `PROGRAM-DESIGN.md`. Chose slots one level below `ARCHITECTURE.md`: The modules, The values that cross, Invariants, How each boundary signals failure, The CLI surface. Each statement was checked against the code, not only against the two source documents.
- Keyword filters (spec 2026-03-02) and retry of failed feeds (spec 2026-03-09) are not implemented, so they are not in the document.
- Dropped a draft "Not this" slot: no rejected program-level approach is recorded anywhere, and inventing one would be fabrication.
- `python3 -m unittest tests.test_feedwatch`: 4 tests, OK.

## Findings: code contradicts ARCHITECTURE.md (not fixed; reported to the human)

ARCHITECTURE.md "When it fails" says a feed that cannot be fetched or parsed is logged and skipped. Not true in three cases, each of which stops the poller with an uncaught exception:

- A `<pubDate>` that `email.utils.parsedate_to_datetime` cannot parse raises `ValueError` from `parse.parse_item` (verified: `ValueError Invalid date value or format "garbage"`).
- A feed URL with no scheme makes `urllib.request.urlopen` raise `ValueError`, which is not an `OSError`, so `fetch.fetch` does not wrap it in `FetchError` (verified).
- `http.client.HTTPException` subclasses (e.g. `IncompleteRead`) are not `OSError` either.

Smaller findings:

- `store.mark_read` updates by `guid` alone while identity is `(feed_id, guid)`: one guid shared by two feeds marks both read.
- `store.unread` orders by `published` as ISO text; offsets differ between feeds and a zone-less `pubDate` yields a naive datetime, so the order is not strictly chronological.
- Fetches run sequentially with a 10 s timeout, so one slow feed delays the rest of a pass (the motivation of the retry spec).
````


## p010

#### Final message

I wrote `docs/PROGRAM-DESIGN.md` (59 lines) and committed it on `master`. While checking it against the code I found two bugs, each of which can stop the poller. Both go against ARCHITECTURE.md's "When it fails" section, which says a bad feed is logged and skipped. I left both unfixed.

**The bugs**
- **Bad publish date:** `parse.parse_item` reads `<pubDate>` without catching errors. A malformed date raises `ValueError` (I reproduced this), and `poller.poll_once` doesn't catch it.
- **Malformed URL:** `fetch.fetch` only turns `OSError` into `FetchError`. A URL with no scheme raises `ValueError: unknown url type` (also reproduced), and the poller doesn't catch that either. `feedwatch add` accepts any string as a URL.

In the new doc I wrote both rules as requirements ("must not raise", "must surface as FetchError") rather than claiming the code already behaves that way.

**What the document covers**
- **The modules:** one module per ARCHITECTURE component plus `models`, with each one's public functions and how the imports follow ARCHITECTURE's call directions.
- **The values:** `Feed`, `Entry`, and the plain dict `parse` returns. That dict has no `feed_id`, so `parse` stays unaware of storage. An entry is identified by `(feed_id, guid)`.
- **The contracts:** what each public function promises, and three ways errors come back: an exception, `None`, or an `(ok, reason)` pair.
- **The schema in code:** the `SCHEMA_STEPS` list, which is how an existing database keeps working as the schema grows, plus the two tables.
- **The loop:** the poller checks feeds once a minute and remembers poll times only in memory.
- **Not this:** no ORM or feed-parsing library; `parse` doesn't return `Entry` objects.

**Decisions you may want to revisit**
- The installed dopamine skills (0.1.3) have no template for a PROGRAM-DESIGN.md; they only cover DESIGN, ARCHITECTURE and ROADMAP. I picked the section headings myself.
- The two approved specs (keyword filters, retry failed feeds) aren't built yet, so I left them out because the doc describes the code as it is.

**Smaller things I noticed**
- `store.mark_read` matches on guid alone, so a guid that two feeds share gets marked read in both.
- `unread` sorts dates as text with their original time-zone offsets. Entries from feeds in different time zones can come out in the wrong order.

The 4 existing tests pass, but only with `PYTHONPATH=. python3 tests/test_feedwatch.py`. Plain `python3 -m unittest` finds none, because `tests/` has no `__init__.py`.

**Commits and files**
I ran the end-of-work step the project asks for. That added a second commit, `be1c2b0` ("sweep: … nothing to drain"), which holds the work record and the line counts. Nothing needed to go into the other documents; ROADMAP.md is listed in the config but doesn't exist yet. The document itself is in commit `c90de3e`. Both commits are local only and nothing was pushed.

Files are in /home/wogi/projects/dopamine/.dopamine/run/program-design/<stage>/recipe/runs/<run>/docs/:
- PROGRAM-DESIGN.md
- superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md

#### docs/PROGRAM-DESIGN.md (added)

````
# Feedwatch — program design

How the components in `ARCHITECTURE.md` are realised in code: the modules, the values they pass, the functions each exposes and the contracts between them.

## The modules

One module per component, plus one for the shared values. All under `feedwatch/`, standard library only.

| Module | Component | Public surface |
|---|---|---|
| `fetch.py` | fetch | `fetch(url, timeout=10) -> bytes`, `FetchError` |
| `parse.py` | parse | `parse_feed(xml_bytes) -> list[dict] \| None`, `parse_item(item) -> dict \| None` |
| `store.py` | store | `connect(path=DEFAULT_PATH)`, `add_feed`, `feeds`, `save_entries`, `unread`, `mark_read` |
| `poller.py` | poller | `poll_once(conn, last_polled, now)`, `main()` |
| `cli.py` | cli | `main(argv=None) -> int` |
| `models.py` | — | `Feed`, `Entry` |

Imports follow the call directions in `ARCHITECTURE.md`: `poller` imports `fetch`, `parse` and `store`; `cli` imports `store`; `store` imports `models`. `fetch` and `parse` import nothing from the package.

## The values

- **`Feed(id, url, title, interval_minutes=30)`** — a subscription, as `store.feeds` returns it.
- **`Entry(feed_id, guid, title, link, published, read=False)`** — a stored entry, as `store.unread` returns it. `published` is a timezone-aware `datetime` or `None`.
- **A parsed entry** is a plain `dict` with the keys `guid`, `title`, `link` and `published`. It carries no `feed_id`: `parse` does not know which feed it read, and `poller` passes the id to `store.save_entries` alongside the list.

An entry's identity is `(feed_id, guid)`. `parse` takes `guid` from the item's `<guid>`, falling back to its `<link>`; an item with neither is dropped, since it could not be recognised when seen again.

## The contracts

- **`fetch.fetch`** returns the response body. Any failure to get it must surface as `FetchError`, the one exception `poller` catches. It does not look at the bytes.
- **`parse.parse_feed`** returns the entries, or `None` when the bytes are not an RSS 2.0 document with a `<channel>`. Content it cannot use must be reported through that `None` or by dropping the item, never by raising — `poller` relies on this to skip one feed and keep polling the others.
- **`store.add_feed`** returns `(True, None)`, or `(False, reason)` when the URL is already subscribed; `reason` is meant to be shown to the user as-is.
- **`store.save_entries`** inserts the entries not already stored for that feed and returns how many were new. Seeing an entry again is not an error.
- **`store.unread`** returns up to `limit` unread entries, newest `published` first.
- **`store.mark_read`** marks read every entry with one of the given guids, in whichever feed it belongs to: the CLI names entries by guid alone.
- **`poller.poll_once`** polls each feed whose interval is up and records the poll time in `last_polled` (feed id to `datetime`) before fetching, so a failed feed waits its full interval too. It takes the connection, the poll-time map and the current time as arguments rather than reaching for them, which is what makes it testable without a clock or a network.
- **`cli.main`** returns the process exit code: `0`, or `1` when a subscription is refused, with the reason on stderr.

Errors surface in three shapes, each matching what the caller does with them: an exception (`FetchError`) where the caller skips and logs, `None` where the input is simply unusable, and an `(ok, reason)` pair where the user is told why. An `sqlite3` error is not caught anywhere, and so stops the poller, as `ARCHITECTURE.md` requires.

## The schema in code

`store.SCHEMA_STEPS` is an ordered list of statements that `connect` runs on every connection. Each step must be idempotent, so a database created by an older version picks up whatever steps were added since. A new table or column is a new step appended to the list; an existing step is never edited.

| Table | Key | Columns |
|---|---|---|
| `feeds` | `id` | `url` (unique), `title`, `interval_minutes` (default 30) |
| `entries` | `(feed_id, guid)` | `title`, `link`, `published`, `read` (0/1) |

`published` is stored as ISO-8601 text and converted back to `datetime` on the way out; `store` is the only module that sees the row shapes.

## The loop

`poller.main` opens one connection, keeps `last_polled` in memory, and calls `poll_once` once a minute. The one-minute tick bounds how late a feed can be polled past its interval. Restarting the poller forgets `last_polled`, so every feed is polled on the first tick.

## Not this

- **An ORM, or a feed-parsing library.** `sqlite3`, `xml.etree` and `urllib` cover what feedwatch needs, and the design admits a dependency only when it earns its place.
- **Returning `Entry` objects from `parse`.** `Entry` needs a `feed_id`, which `parse` does not have; the dict keeps `parse` ignorant of storage.
````

#### docs/superpowers/plans/2026-10-12-program-design.reconstructed-ledger.md (added)

````
# 2026-10-12-program-design — reconstructed ledger

> Reconstructed on 2026-10-12 from the conversation that did the work; ad-hoc, no plan or superpowers ledger existed.

## Task

Derive `docs/PROGRAM-DESIGN.md` from `docs/DESIGN.md` and `docs/ARCHITECTURE.md`.

## What was done

- Read both source documents, every module under `feedwatch/`, the tests and the two specs under `docs/superpowers/specs/`.
- No `PROGRAM-DESIGN.md` schema exists among the installed dopamine skills (v0.1.3 has schemas for DESIGN, ARCHITECTURE and ROADMAP only); slots were chosen by hand: The modules, The values, The contracts, The schema in code, The loop, Not this.
- The document describes the code as it is. The two approved specs (keyword filters, retry failed feeds) are not implemented and were left out.
- Tests pass: `PYTHONPATH=. python3 tests/test_feedwatch.py` — 4 tests OK. (`python3 -m unittest` discovers none: `tests/` has no `__init__.py`.)

## Findings (not fixed; code contradicts ARCHITECTURE.md "When it fails")

- `parse.parse_item` calls `parsedate_to_datetime` on `<pubDate>` unguarded. A malformed date raises `ValueError: Invalid date value or format "garbage"`, which `poller.poll_once` does not catch, so one bad feed stops the poller.
- `fetch.fetch` catches only `OSError`. A URL with no scheme raises `ValueError: unknown url type: 'notaurl'`, also uncaught by the poller. `cli add` accepts any string as a URL.
- PROGRAM-DESIGN.md states the contracts these violate as prescriptions ("must"), not as present fact.

## Observations

- `store.mark_read` matches on `guid` alone, though an entry's key is `(feed_id, guid)`; a guid shared by two feeds is marked read in both.
- `published` is stored as ISO-8601 text with its source offset, and `unread` orders by that text, so entries from feeds in different time zones sort lexically, not chronologically.
````



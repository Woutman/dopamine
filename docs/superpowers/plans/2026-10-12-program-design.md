# Program design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `PROGRAM-DESIGN.md` as a fourth living document — its schema, the `dopamine:brainstorm-program-design` recipe that has the human choose its rules, the injection sentence that carries those rules into plans, and a seventh exit-gate check — gated on a baseline that shows the problem exists without it.

**Architecture:** A baseline harness (a small Python fixture project with overlays, three scripts, prompt templates, a verdict vocabulary) is built first. Its RED stage decides whether anything else is written. Then the schema, the recipe, the neighbouring skills that point at it, the injection and the gate. The GREEN stage re-runs the arms with all of it in place, judged blind and pooled with the RED controls.

**Tech Stack:** bash, git, markdown. Python 3 standard library for the baseline tooling, the fixture and the test suite only — never shipped runtime.

**Spec:** `docs/superpowers/specs/2026-10-12-program-design-design.md`

## Global Constraints

- **RED gates everything.** If Task 2's controls come back clean against the spec's gate, the plan stops there and no skill is written.
- **Phase 2 is a draft.** It is revised with the human from the RED findings, and does not start until they approve the revision.
- **Skills are written with `superpowers:writing-skills`**: `description` starts with `Use when`, is under 500 characters, states triggers only.
- **Word budgets are ratchets.** One is raised only with a recorded reason in `tests/skills/test-skill-structure.sh` or `tests/hooks/test-session-start.sh`.
- **The injection uses no `never`, `do not` or `don't`** (enforced by `tests/hooks/test-session-start.sh`).
- **Python first.** Recommendations and examples in the schema and the recipe are Python; where general advice and Python idiom disagree, the idiom wins.
- **Specs and sealed plans are immutable.** Nothing under `docs/superpowers/specs/` or an existing `docs/superpowers/plans/*.md` is edited.
- **Scripts are invoked through their interpreter** (`bash setup-run`, `python3 blind`), never by bare path.
- **Comments follow `dopamine:writing-code-comments`**: a why, a contract or a warning.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **Baseline runs and judging are done by the main session**, not an implementer subagent: they dispatch subagents and continue them, and the judge must not have seen which arm produced what.
- **A GREEN arm worse than its control is a regression**: micro-test a fix; never record it as a known gap.
- **No `PROGRAM-DESIGN.md` applies to this plan**: this repository declares none until Task 8.

## Review Focus

1. **A run's output names its own run directory**, whose path contains the arm label and `red`/`green`. Expected: `blind` replaces the run directory with `<repo>`, so the label never reaches the judge. *(Task 1, R0-1 case.)*
2. **A run that only asked a question** changes no file. Expected: it is still an item, carrying its final message, so it is judged rather than dropped. *(Task 1, R0-1 case.)*
3. **A run whose final message was not saved.** Expected: `blind` exits 2 naming the run; judged without it, a run that only asked would read as one that did nothing. *(Task 1, missing-reply case.)*
4. **`PROGRAM-DESIGN.md` declared but absent** when a plan is written. Expected: the author asks once whether to run the recipe; after a decline it plans without gap stops and says so in one line of Global Constraints. *(Task 6 content assertion; Task 7 arm N.)*
5. **The exit gate in a repository without `PROGRAM-DESIGN.md`.** Expected: check 7 does not apply, rather than failing every close. *(Task 6, `declared and present` assertion.)*

## Clarifications of the spec

- **Arm N is added** (three runs, GREEN only) for Review Focus 4: the plan author with the new injection and the document absent. The spec's arms do not exercise §4.3's absent-document paragraph.
- **The injection carries the Global Constraints instruction too.** §4.3 quotes one sentence, but the plan's author learns to copy rules into Global Constraints, and what to do when the document is absent, only from the injection. Both go in one paragraph, and the injection budget is raised from 200 to 240 words with that reason.
- **Every arm has a human on the other end.** The prompts say a final message that ends in a question is answered next turn, identically in control and treatment, so asking is a real option in both. A plan run that asks (P0, P1) is answered `That's your call — write the plan.` and continued once; the stop is recorded.
- **Every run receives the session injection current at its stage.** R0 and P0 get today's hook text; GREEN arms get the edited one. The arms then differ by exactly what this plan adds.
- **Plan compliance is judged against the fixture's full `PROGRAM-DESIGN.md` for P0 too**, so P1's compliance has a control.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `tests/baselines/program-design/fixture/` | `feedwatch`: a small Python project with `DESIGN.md`, `ARCHITECTURE.md` (two processes), two feature specs, and code using two error conventions |
| `tests/baselines/program-design/overlays/program-design/docs/PROGRAM-DESIGN.md` | The full document arms P1 and X work under |
| `tests/baselines/program-design/overlays/gap/docs/PROGRAM-DESIGN.md` | The same without a Concurrency slot, for arm G |
| `tests/baselines/program-design/overlays/work/` | A finished unit of work with one planted violation, for arm X |
| `tests/baselines/program-design/vocab.tsv` | Allowed verdict values per column |
| `tests/baselines/program-design/setup-run` | One run's repository: fixture, optional overlay, tagged starting point, optional work |
| `tests/baselines/program-design/blind` | Pools runs' final messages and changed files into one shuffled, unlabelled list |
| `tests/baselines/program-design/score` | Tallies the judge's verdicts per arm |
| `tests/baselines/program-design/prompts/{session-context,recipe,plan,gate}.md` | Arm prompts |
| `tests/scripts/test-program-design-baseline.sh` | Hermetic tests for the scripts and the fixture |
| `docs/superpowers/plans/2026-10-12-program-design.baseline/` | Committed results: `red/`, `green/` |
| `skills/writing-living-documents/program-design-schema.md` | The slots |
| `skills/brainstorm-program-design/SKILL.md` | The recipe |

**Modified:** `skills/writing-living-documents/SKILL.md`, `skills/writing-living-documents/architecture-schema.md`, `skills/brainstorm-architecture/SKILL.md`, `skills/writing-roadmaps/SKILL.md`, `skills/routing-documentation-updates/SKILL.md`, `skills/adopting-a-repo/SKILL.md`, `skills/adopting-a-repo/survey-prompt.md`, `skills/finishing-work/SKILL.md`, `hooks/session-start-context.md`, `tests/hooks/test-session-start.sh`, `tests/skills/test-skill-structure.sh`, `tests/skills/test-living-documents.sh`, `tests/skills/test-authoring-skills.sh`, `README.md`, `.dopamine/config`, `.claude-plugin/plugin.json`.

**Run scratch** (gitignored by `.dopamine/run/`): `.dopamine/run/program-design/{red,green}/<pool>/`.

**Task order and why:** tooling first, so RED can run; RED next, because it can end the plan; then schema, recipe, neighbours, injection and gate, which GREEN needs in place; GREEN; then the README, config and version that describe the result.

**Two phases.** Phase 1 is Tasks 1–2 and ends at a review with the human. Phase 2 is Tasks 3–8 as drafted below.

---

## Phase 1 — tooling and RED

### Task 1: Baseline tooling

**Files:**
- Create: everything under `tests/baselines/program-design/` except `prompts/`
- Test: `tests/scripts/test-program-design-baseline.sh`

**Interfaces:**
- Produces:
  - `bash setup-run RUNS_DIR LABEL [OVERLAY_DIR [WORK_DIR]]` → prints `RUNS_DIR/LABEL`; exits 1 if it exists, 2 on bad usage. `OVERLAY_DIR` is committed before the tag `baseline-base`; `WORK_DIR` is committed after it.
  - `python3 blind RUNS_DIR OUT_DIR --columns NAME[,NAME...] [--seed N]` → reads each run's final message from `RUNS_DIR/<label>.reply.md`; writes `OUT_DIR/{items.md,key.tsv,verdicts.tsv}`. `key.tsv` columns: `id run`. `verdicts.tsv` columns: `id` then the named columns, cells empty. Exits 2 on a missing reply or bad usage.
  - `python3 score OUT_DIR VOCAB` → markdown table on stdout, one row per arm: `| arm | runs | <each column> | spread |`. A column whose values are only `yes|no|na` shows `yes-count/runs`; any other column lists each run's value, and `spread` counts those columns the arm's runs disagree on. Exits 2 on an empty cell, a value outside the vocabulary, or a column the vocabulary does not declare. A run's arm is its label up to the first `-`.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-program-design-baseline.sh`:

```bash
#!/usr/bin/env bash
# Tests for the tooling behind the program-design baseline. The runs need
# agents and a judge and stay out of this suite; the scripts that set them up
# and score them do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/program-design"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

echo "-- the fixture"
RC=0
(cd "$B/fixture" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it declares the document" \
    "$(cat "$B/fixture/.dopamine/config")" "living: docs/PROGRAM-DESIGN.md"
assert_eq "and the document is absent" no \
    "$([ -e "$B/fixture/docs/PROGRAM-DESIGN.md" ] && echo yes || echo no)"
assert_contains "one module signals failure by raising" \
    "$(cat "$B/fixture/feedwatch/fetch.py")" "raise FetchError"
assert_contains "another by returning a sentinel" \
    "$(cat "$B/fixture/feedwatch/parse.py")" "return None"
assert_contains "and a third by returning a pair" \
    "$(cat "$B/fixture/feedwatch/store.py")" "return False,"
assert_contains "the architecture runs more than one process, so Concurrency fires" \
    "$(cat "$B/fixture/docs/ARCHITECTURE.md")" "Two processes"
assert_contains "the full document has a Concurrency slot" \
    "$(cat "$B/overlays/program-design/docs/PROGRAM-DESIGN.md")" "## Concurrency"
assert_not_contains "the gap variant has none" \
    "$(cat "$B/overlays/gap/docs/PROGRAM-DESIGN.md")" "## Concurrency"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" R0-1)
assert_eq "prints the run directory" "$T/runs/R0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" R0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
run=$(bash "$B/setup-run" "$T/runs" P1-1 "$B/overlays/program-design")
assert_exit "an overlay is part of the starting point" 0 \
    git -C "$run" cat-file -e baseline-base:docs/PROGRAM-DESIGN.md
run=$(bash "$B/setup-run" "$T/runs" X-1 "$B/overlays/program-design" "$B/overlays/work")
changed=$(git -C "$run" diff --name-only baseline-base...HEAD)
assert_contains "the work lands after the tag" "$changed" "feedwatch/filters.py"
assert_not_contains "and the document is not part of the work" "$changed" "PROGRAM-DESIGN.md"
assert_contains "the work carries its planted violation" \
    "$(cat "$run/feedwatch/filters.py")" "return None"
RC=0
(cd "$run" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "the work's tests pass" 0 "$RC"

echo "-- blind"
# R0-1 asked a question and changed nothing; its reply names its own directory.
printf 'Before I write anything: %s/feedwatch raises in fetch but returns None in parse. Which?\n' \
    "$T/runs/R0-1" > "$T/runs/R0-1.reply.md"
# P1-1 wrote and committed a plan.
mkdir -p "$T/runs/P1-1/docs/superpowers/plans"
printf '# Plan\n\nFilters are frozen dataclasses.\n' > "$T/runs/P1-1/docs/superpowers/plans/p.md"
git -C "$T/runs/P1-1" add -A && git -C "$T/runs/P1-1" commit -qm plan
printf 'DONE\n' > "$T/runs/P1-1.reply.md"
printf 'Check 7: parse_keywords returns None.\n' > "$T/runs/X-1.reply.md"
RC=0
python3 "$B/blind" "$T/runs" "$T/out" --columns asked,wrote --seed 1 >/dev/null 2>&1 || RC=$?
assert_eq "exits 0" 0 "$RC"
items=$(cat "$T/out/items.md")
assert_contains "a run that only asked is still an item" "$items" "Which?"
assert_contains "a file the run committed is shown" "$items" "Filters are frozen dataclasses"
assert_contains "the run directory is replaced" "$items" "<repo>/feedwatch"
for label in R0-1 P1-1 X-1; do
    assert_not_contains "no item names run $label" "$items" "$label"
done
assert_eq "one key row per run" 4 "$(wc -l < "$T/out/key.tsv" | tr -d ' ')"
assert_eq "the verdict sheet has the asked columns" \
    "$(printf 'id\tasked\twrote')" "$(head -1 "$T/out/verdicts.tsv")"
python3 "$B/blind" "$T/runs" "$T/again" --columns asked,wrote --seed 1 >/dev/null 2>&1
assert_eq "the same seed gives the same order" \
    "$(cat "$T/out/items.md")" "$(cat "$T/again/items.md")"
rm "$T/runs/X-1.reply.md"
assert_exit "a run with no saved reply exits 2" 2 \
    python3 "$B/blind" "$T/runs" "$T/missing" --columns asked
assert_exit "no columns is bad usage" 2 python3 "$B/blind" "$T/runs" "$T/bad"

echo "-- score"
S="$T/score"
mkdir -p "$S"
printf 'id\trun\np001\tP0-1\np002\tP0-2\np003\tP1-1\np004\tP1-2\n' > "$S/key.tsv"
printf 'id\terrors\tcomplies\np001\traise\tyes\np002\tsentinel\tno\np003\traise\tyes\np004\traise\tyes\n' \
    > "$S/verdicts.tsv"
table=$(python3 "$B/score" "$S" "$B/vocab.tsv")
assert_contains "lists a choice per run and counts the disagreement" \
    "$table" "| P0 | 2 | raise, sentinel | 1/2 | 1 |"
assert_contains "keeps arms apart" "$table" "| P1 | 2 | raise, raise | 2/2 | 0 |"
printf 'id\terrors\tcomplies\np001\traise\tyes\np002\t\tno\np003\traise\tyes\np004\traise\tyes\n' \
    > "$S/verdicts.tsv"
assert_exit "an unjudged cell exits 2" 2 python3 "$B/score" "$S" "$B/vocab.tsv"
printf 'id\terrors\tcomplies\np001\tvague\tyes\np002\traise\tno\np003\traise\tyes\np004\traise\tyes\n' \
    > "$S/verdicts.tsv"
assert_exit "a value outside the vocabulary exits 2" 2 python3 "$B/score" "$S" "$B/vocab.tsv"
printf 'id\tmood\np001\tyes\np002\tyes\np003\tyes\np004\tyes\n' > "$S/verdicts.tsv"
assert_exit "an undeclared column exits 2" 2 python3 "$B/score" "$S" "$B/vocab.tsv"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-program-design-baseline.sh`
Expected: FAIL from `its own tests pass as shipped` onward, because `tests/baselines/program-design/` does not exist.

- [ ] **Step 3: Write the fixture's documents and config**

`tests/baselines/program-design/fixture/.dopamine/config`:

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/PROGRAM-DESIGN.md
living: docs/ROADMAP.md
plans: docs/superpowers/plans
```

`tests/baselines/program-design/fixture/docs/DESIGN.md`:

```markdown
# Feedwatch — design

## What this is

Feedwatch polls one person's list of RSS feeds and keeps every new entry in a local SQLite database, so they can read their feeds from the command line without a feed-reader service.

## The problem

Feed readers that run as services need an account and a server. One reader on one machine needs neither.

## What it must do

- Poll every subscribed feed at its own interval, 30 minutes unless set otherwise.
- Store each entry once, however often it is seen.
- List unread entries, newest first, and mark them read.
- Keep polling the other feeds when one fails.

## The shape of the solution

A poller process and a command-line tool sharing one SQLite file. Rejected: a web interface, since there is one user at one terminal.

## Principles

- Standard library first; a dependency has to earn its place.

## Not this

- Accounts for more than one user.
- Full-text search.

## Open questions

None.
```

`tests/baselines/program-design/fixture/docs/ARCHITECTURE.md`:

```markdown
# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed's XML. Owns HTTP; never parses.
- **parse** — turns feed XML into entries. Owns the format; never stores.
- **store** — the SQLite database. Owns the schema; never touches the network.
- **poller** — the long-running worker. Owns the schedule; never presents anything.
- **cli** — the user's commands. Owns presentation; never polls.

## How they talk

`poller` calls `fetch`, `parse` and `store`. `cli` calls `store`. Nothing calls `poller`, and only `poller` calls `fetch`.

## Where state lives

One SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`. `store` is authoritative for both. The schema gains tables and columns as features land, and an existing database has to keep working.

## When it fails

A feed that cannot be fetched or parsed is logged and skipped until its next interval; the poller keeps running. A database error stops the poller.

## What runs where

Two processes on the user's machine: the poller, started once and left running (`python -m feedwatch.poller`), and the CLI, run once per command. Both open the same SQLite file.

## Not this

- A poller thread inside the CLI: the CLI exits after every command.
```

`tests/baselines/program-design/fixture/docs/superpowers/specs/2026-03-02-keyword-filters-design.md`:

```markdown
# Keyword filters — design

> **Status.** Approved 2026-03-02.

## What

A user can attach keyword filters to a feed. An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. Matching is case-insensitive, on whole words.

## Behaviour

- `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]` adds a filter; `feedwatch filter list FEED_URL` lists a feed's filters with their ids; `feedwatch filter remove FILTER_ID` removes one.
- The poller applies a feed's filters when it saves new entries. An entry a filter drops is never stored.
- A filter for a feed that is not subscribed is refused, with a message naming the URL.
- A filter with no keywords is refused.
- Filters are kept in the same database, and a database created before this feature keeps working.
- Entries already stored are not re-filtered.

## Out of scope

Filtering on an entry's body; regular expressions.
```

`tests/baselines/program-design/fixture/docs/superpowers/specs/2026-03-09-retry-failed-feeds-design.md`:

```markdown
# Retry failed feeds — design

> **Status.** Approved 2026-03-09.

## What

A feed whose fetch fails is retried in the background with exponential backoff — after 1, 2, 4 and 8 minutes, capped at 30 — so that a slow or failing feed never delays polling the others.

## Behaviour

- A failed fetch schedules a retry, and the poller's regular loop carries on, on schedule.
- Retries for one feed never overlap.
- A successful retry saves its entries exactly as a regular poll would, and resets that feed's backoff.
- After five failed retries the feed waits for its next regular interval.
- Stopping the poller with Ctrl-C stops pending retries cleanly.

## Out of scope

Notifying the user of a failing feed.
```

- [ ] **Step 4: Write the fixture's code and tests**

`tests/baselines/program-design/fixture/feedwatch/__init__.py`: empty.

`tests/baselines/program-design/fixture/feedwatch/models.py`:

```python
"""The values feedwatch passes between its modules."""

from dataclasses import dataclass
from datetime import datetime


@dataclass
class Feed:
    id: int
    url: str
    title: str
    interval_minutes: int = 30


@dataclass
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None
    read: bool = False
```

`tests/baselines/program-design/fixture/feedwatch/fetch.py`:

```python
"""Downloads a feed's XML. What the bytes mean is parse's business."""

import urllib.request


class FetchError(Exception):
    """A feed could not be downloaded."""


def fetch(url, timeout=10):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    except OSError as exc:
        raise FetchError(f"{url}: {exc}") from exc
```

`tests/baselines/program-design/fixture/feedwatch/parse.py`:

```python
"""Turns RSS XML into entries."""

import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime


def parse_feed(xml_bytes):
    """Return the feed's entries as dicts, or None if the XML is not an RSS feed."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return None
    channel = root.find("channel")
    if channel is None:
        return None
    entries = []
    for item in channel.findall("item"):
        entry = parse_item(item)
        if entry is not None:
            entries.append(entry)
    return entries


def parse_item(item):
    # An item with neither a guid nor a link cannot be recognised when it is
    # seen again, so storing it would duplicate it on every poll.
    guid = item.findtext("guid") or item.findtext("link")
    if not guid:
        return None
    published = item.findtext("pubDate")
    return {
        "guid": guid,
        "title": item.findtext("title", ""),
        "link": item.findtext("link", ""),
        "published": parsedate_to_datetime(published) if published else None,
    }
```

`tests/baselines/program-design/fixture/feedwatch/store.py`:

```python
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
```

`tests/baselines/program-design/fixture/feedwatch/poller.py`:

```python
"""The long-running worker: polls each feed when its interval is up."""

import logging
import time
from datetime import datetime, timedelta

from feedwatch import fetch, parse, store

log = logging.getLogger("feedwatch.poller")


def poll_once(conn, last_polled, now):
    for feed in store.feeds(conn):
        previous = last_polled.get(feed.id)
        if previous is not None and now - previous < timedelta(minutes=feed.interval_minutes):
            continue
        last_polled[feed.id] = now
        try:
            xml = fetch.fetch(feed.url)
        except fetch.FetchError as exc:
            log.warning("skipping %s: %s", feed.url, exc)
            continue
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))


def main():
    logging.basicConfig(level=logging.INFO)
    conn = store.connect()
    last_polled = {}
    while True:
        poll_once(conn, last_polled, datetime.now())
        time.sleep(60)


if __name__ == "__main__":
    main()
```

`tests/baselines/program-design/fixture/feedwatch/cli.py`:

```python
"""feedwatch's command line: subscribe, list unread entries, mark them read."""

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
    else:
        store.mark_read(conn, args.guids)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`tests/baselines/program-design/fixture/tests/test_feedwatch.py`:

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch import parse, store

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>First</title><link>http://x/a</link>
<pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>
<item><title>Neither guid nor link</title></item>
</channel></rss>"""


class FeedwatchTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_an_item_with_no_identity_is_skipped(self):
        self.assertEqual([e["guid"] for e in parse.parse_feed(RSS)], ["a"])

    def test_xml_that_is_not_a_feed_is_rejected(self):
        self.assertIsNone(parse.parse_feed(b"<html/>"))

    def test_an_entry_seen_twice_is_stored_once(self):
        store.add_feed(self.conn, "http://x/feed", "x")
        feed = store.feeds(self.conn)[0]
        entries = parse.parse_feed(RSS)
        self.assertEqual(store.save_entries(self.conn, feed.id, entries), 1)
        self.assertEqual(store.save_entries(self.conn, feed.id, entries), 0)

    def test_subscribing_twice_is_refused(self):
        store.add_feed(self.conn, "http://x/feed", "x")
        ok, reason = store.add_feed(self.conn, "http://x/feed", "x")
        self.assertFalse(ok)
        self.assertIn("already subscribed", reason)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 5: Write the two program-design documents**

`tests/baselines/program-design/overlays/program-design/docs/PROGRAM-DESIGN.md`:

```markdown
# Feedwatch — program design

Python 3.11, standard library.

## Types

- **Rule:** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Why:* one representation per concept, and a dict's keys are checked nowhere.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.

## Errors

- **Rule:** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Why:* one convention, and the stack trace survives to wherever the failure is handled.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added `return None`, `return False` or `return False, …` on a failure path; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.

## Effects

- **Inherited default:** dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Rule:** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`.

## Signatures

- **Rule:** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.

## Layout

- **Inherited default:** split by responsibility, not technical layer; files that change together live together.
- **Rule:** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.

## Modules

- **Rule:** A new module hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Why:* the code base is small, and shallow layers add files without hiding anything.
  *Check:* a new module has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.

## Concurrency

- **Rule:** The poller is one thread. Work that must not block it runs in a `concurrent.futures.ThreadPoolExecutor` owned by `poller`, and each task opens its own `store.connect()`; a connection never crosses threads.
  *Check:* no added `threading.Thread`, `asyncio` or `multiprocessing`; no `conn` passed to a function submitted to an executor.

## Persistence

- **Rule:** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

## Not this

- **Result types and `(ok, reason)` pairs:** exceptions are Python's idiom, and the stack trace survives.
- **asyncio:** the standard library's `sqlite3` blocks, and a handful of feeds at once is the most this needs.
```

`tests/baselines/program-design/overlays/gap/docs/PROGRAM-DESIGN.md`: the same file with the `## Concurrency` section and the `**asyncio:**` bullet removed. Write it by copying and deleting those two passages; nothing else differs.

- [ ] **Step 6: Write the work overlay**

`tests/baselines/program-design/overlays/work/feedwatch/errors.py`:

```python
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
```

`tests/baselines/program-design/overlays/work/feedwatch/models.py` — the fixture's `models.py` with `Filter` added:

```python
"""The values feedwatch passes between its modules."""

from dataclasses import dataclass
from datetime import datetime
from typing import Literal


@dataclass
class Feed:
    id: int
    url: str
    title: str
    interval_minutes: int = 30


@dataclass
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None
    read: bool = False


@dataclass(frozen=True)
class Filter:
    feed_id: int
    kind: Literal["include", "exclude"]
    keywords: tuple[str, ...]
```

`tests/baselines/program-design/overlays/work/feedwatch/filters.py` — compliant except for the planted `return None`, which breaks the Errors rule:

```python
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...] | None:
    """The keywords in a comma-separated list, lower-cased, or None if there are none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        return None
    return keywords
```

`tests/baselines/program-design/overlays/work/tests/test_filters.py`:

```python
import unittest

from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title):
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self):
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self):
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self):
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self):
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 7: Write the vocabulary**

`tests/baselines/program-design/vocab.tsv` (tab-separated):

```
column	values
asked	yes|no
wrote	yes|no
elements	yes|no|na
stopped	yes|no
types	dataclass|pydantic|dict|tuple|mixed|undecided
errors	raise|sentinel|mixed|undecided
effects	pure|direct|mixed|undecided
signatures	keyword-only|positional|mixed|undecided
layout	new-module|existing-modules|undecided
modules	deep|shallow|undecided
constraints	yes|no
complies	yes|no
concurrency	yes|no
flagged	yes|no
misflagged	yes|no
```

- [ ] **Step 8: Write `setup-run`**

`tests/baselines/program-design/setup-run`:

```bash
#!/usr/bin/env bash
# Set up one baseline run: a fresh repository holding the fixture, with an
# optional overlay committed on top. The starting point is tagged baseline-base
# so blind finds what the run changed even after the run commits its own work.
# A work overlay is committed after the tag: it is the unit of work a gate run
# checks with git diff baseline-base...HEAD.
#
# Usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR [WORK_DIR]]   (prints the run's directory)
set -euo pipefail

USAGE="usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR [WORK_DIR]]"
HERE="$(cd "$(dirname "$0")" && pwd)"
{ [ $# -ge 2 ] && [ $# -le 4 ]; } || { echo "$USAGE" >&2; exit 2; }
run="$1/$2"
[ ! -e "$run" ] || { echo "$run already exists" >&2; exit 1; }

commit() {
    git -C "$run" add -A
    git -C "$run" -c user.name=baseline -c user.email=baseline@localhost commit -qm "$1"
}

mkdir -p "$run"
cp -R "$HERE/fixture/." "$run/"
find "$run" -name __pycache__ -prune -exec rm -rf {} +
git -C "$run" init -q
commit fixture
if [ $# -ge 3 ]; then
    cp -R "$3/." "$run/"
    commit "docs: program design"
fi
git -C "$run" tag baseline-base
if [ $# -eq 4 ]; then
    cp -R "$4/." "$run/"
    commit "feat: keyword filter matching"
fi
cd "$run" && pwd
```

- [ ] **Step 9: Write `blind`**

`tests/baselines/program-design/blind`:

```python
#!/usr/bin/env python3
"""Pool the baseline runs' outputs into one blinded list for the judge.

Usage: blind RUNS_DIR OUT_DIR --columns NAME[,NAME...] [--seed N]

Each subdirectory of RUNS_DIR holding a .git is one run, set up by setup-run.
RUNS_DIR/<label>.reply.md is that run's final message, saved by the main
session. An item is the final message, then every file the run added or
changed since the tag baseline-base, committed or not.

Writes to OUT_DIR:
  items.md      every item, shuffled, with the run's directory replaced by <repo>
  key.tsv       id, run
  verdicts.tsv  one row per id with an empty cell per column, for the judge

Exits 2 when a run has no saved reply: judged without it, a run that only
asked a question would read as one that did nothing.
"""
import os
import random
import subprocess
import sys

USAGE = "usage: blind RUNS_DIR OUT_DIR --columns NAME[,NAME...] [--seed N]"


def git(run, *args):
    return subprocess.run(["git", "-C", run, *args], check=True,
                          capture_output=True, text=True).stdout


def item(run, reply):
    git(run, "add", "-A")
    parts = ["#### Final message", "", reply.strip(), ""]
    for line in git(run, "diff", "--cached", "--name-status", "baseline-base", "--").splitlines():
        fields = line.split("\t")
        status, name = fields[0], fields[-1]
        if status.startswith("D"):
            parts += [f"#### {name} (deleted)", ""]
        elif status.startswith("A"):
            with open(os.path.join(run, name), encoding="utf-8", errors="replace") as f:
                parts += [f"#### {name} (added)", "", "````", f.read().rstrip(), "````", ""]
        else:
            diff = git(run, "diff", "--cached", "--no-color", "baseline-base", "--", name)
            parts += [f"#### {name} (changed)", "", "````diff", diff.rstrip(), "````", ""]
    text = "\n".join(parts)
    # The run's directory contains its label and its stage, either of which
    # would tell the judge which arm wrote this.
    for path in {os.path.realpath(run), os.path.abspath(run)}:
        text = text.replace(path, "<repo>")
    return text


def main():
    args = sys.argv[1:]
    options = {}
    for flag in ("--columns", "--seed"):
        if flag in args:
            at = args.index(flag)
            if at + 1 >= len(args):
                print(USAGE, file=sys.stderr)
                return 2
            options[flag] = args[at + 1]
            del args[at:at + 2]
    if len(args) != 2 or "--columns" not in options:
        print(USAGE, file=sys.stderr)
        return 2
    runs_dir, out = args
    columns = options["--columns"].split(",")
    seed = int(options["--seed"]) if "--seed" in options else None

    labels = sorted(label for label in os.listdir(runs_dir)
                    if os.path.isdir(os.path.join(runs_dir, label, ".git")))
    missing = [label for label in labels
               if not os.path.isfile(os.path.join(runs_dir, label + ".reply.md"))]
    if missing:
        print("no saved reply: " + ", ".join(missing), file=sys.stderr)
        return 2

    entries = []
    for label in labels:
        with open(os.path.join(runs_dir, label + ".reply.md"), encoding="utf-8") as f:
            entries.append((label, item(os.path.join(runs_dir, label), f.read())))
    random.Random(seed).shuffle(entries)

    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "items.md"), "w", encoding="utf-8") as md, \
            open(os.path.join(out, "key.tsv"), "w", encoding="utf-8") as key, \
            open(os.path.join(out, "verdicts.tsv"), "w", encoding="utf-8") as verdicts:
        key.write("id\trun\n")
        verdicts.write("\t".join(["id", *columns]) + "\n")
        for n, (label, text) in enumerate(entries, 1):
            pid = f"p{n:03d}"
            md.write(f"## {pid}\n\n{text}\n\n")
            key.write(f"{pid}\t{label}\n")
            verdicts.write(pid + "\t" * len(columns) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 10: Write `score`**

`tests/baselines/program-design/score`:

```python
#!/usr/bin/env python3
"""Tally the judge's verdicts per arm.

Usage: score OUT_DIR VOCAB

Reads key.tsv and verdicts.tsv from OUT_DIR, and each column's allowed values
from VOCAB. A run's arm is its label up to the first '-', so P0-3 belongs to
arm P0. A column whose values are only yes, no and na is shown as yes-runs out
of runs. Any other column lists each run's value, and an arm's spread is how
many such columns its runs disagree on.

Exits 2 when a cell is empty, holds a value outside its column's vocabulary,
or sits in a column VOCAB does not declare: each would otherwise score silently.
"""
import os
import sys

BINARY = {"yes", "no", "na"}


def table(path):
    with open(path, encoding="utf-8") as f:
        rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    return rows[0], rows[1:]


def main():
    if len(sys.argv) != 3:
        print("usage: score OUT_DIR VOCAB", file=sys.stderr)
        return 2
    out, vocab_path = sys.argv[1:]
    vocab = {row[0]: set(row[1].split("|")) for row in table(vocab_path)[1]}
    owner = {row[0]: row[1] for row in table(os.path.join(out, "key.tsv"))[1]}
    header, rows = table(os.path.join(out, "verdicts.tsv"))
    columns = header[1:]
    verdicts = {row[0]: dict(zip(columns, (cell.strip() for cell in row[1:])))
                for row in rows}

    problems = [f"column {c!r} is not in {vocab_path}" for c in columns if c not in vocab]
    for pid in owner:
        for c in columns:
            value = verdicts.get(pid, {}).get(c, "")
            if not value:
                problems.append(f"unjudged: {pid} {c}")
            elif c in vocab and value not in vocab[c]:
                problems.append(f"unknown value {value!r}: {pid} {c}")
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2

    arms = {}
    for pid, label in sorted(owner.items(), key=lambda pair: pair[1]):
        arms.setdefault(label.split("-", 1)[0], []).append(verdicts[pid])

    print("| arm | runs | " + " | ".join(columns) + " | spread |")
    print("|---" * (len(columns) + 3) + "|")
    for arm, runs in arms.items():
        cells, spread = [], 0
        for c in columns:
            values = [run[c] for run in runs]
            if vocab[c] <= BINARY:
                cells.append(f"{values.count('yes')}/{len(values)}")
            else:
                cells.append(", ".join(values))
                spread += len(set(values)) > 1
        print(f"| {arm} | {len(runs)} | " + " | ".join(cells) + f" | {spread} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Then: `chmod +x tests/baselines/program-design/{setup-run,blind,score}`.

- [ ] **Step 11: Run the test to verify it passes**

Run: `bash tests/scripts/test-program-design-baseline.sh`
Expected: every case `[PASS]`, then `OK`.

- [ ] **Step 12: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`.

- [ ] **Step 13: Commit**

```bash
git add tests/baselines/program-design tests/scripts/test-program-design-baseline.sh
git commit -m "test: baseline harness for program design"
```

---

### Task 2: RED — run the controls, judge them blind, and decide

**Main session only.** This task dispatches subagents, continues them, and judges their output.

**Files:**
- Create: `tests/baselines/program-design/prompts/session-context.md`, `recipe.md`, `plan.md`
- Create: `docs/superpowers/plans/2026-10-12-program-design.baseline/red/` (results)

**Interfaces:**
- Consumes: `setup-run`, `blind`, `score`, `vocab.tsv` from Task 1.
- Produces: `red/recipe/` and `red/plan/` (each `items.md`, `key.tsv`, `verdicts.tsv`, `score.md`), the run directories with their `.reply.md` files at `.dopamine/run/program-design/red/{recipe,plan}/runs/`, and a decision: proceed, or stop the plan here.

- [ ] **Step 1: Write the prompts**

`tests/baselines/program-design/prompts/session-context.md` — `{INJECTION}` is the full text of `hooks/session-start-context.md` as it stands when the run is dispatched; `{SUPERPOWERS}` is `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1`, expanded; `{DOPAMINE}` is this repository's absolute path:

```markdown
This context was injected at the start of your session:

<session-context>
{INJECTION}
</session-context>

Skills are files; to load one, read it. A `superpowers:<name>` skill is at `{SUPERPOWERS}/skills/<name>/SKILL.md`, and a `dopamine:<name>` skill at `{DOPAMINE}/skills/<name>/SKILL.md`.
```

`tests/baselines/program-design/prompts/recipe.md` — `{LOADED_SKILL}` is empty in R0:

```markdown
You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

The human says: "Derive docs/PROGRAM-DESIGN.md from docs/DESIGN.md and docs/ARCHITECTURE.md."

When you need a decision from the human, end your turn with the question: your final message is shown to them, and they reply in the next turn.
{LOADED_SKILL}
```

`tests/baselines/program-design/prompts/plan.md`:

```markdown
You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

The human says: "Write the implementation plan for {SPEC}. Save it under docs/superpowers/plans/ and commit it. Plan only — don't implement it."

When you need a decision from the human, end your turn with the question: your final message is shown to them, and they reply in the next turn. Otherwise end at the plan's handoff, without asking which execution approach to use.
```

- [ ] **Step 2: Set up ten runs**

```bash
B=tests/baselines/program-design
R=.dopamine/run/program-design/red
for n in 1 2 3 4 5; do bash "$B/setup-run" "$R/recipe/runs" "R0-$n"; done
for n in 1 2 3 4 5; do bash "$B/setup-run" "$R/plan/runs" "P0-$n"; done
```

Expected: ten absolute paths printed.

- [ ] **Step 3: Dispatch R0 and P0**

Ten `general-purpose` Agent calls in one message, no model override.

- **R0-n:** `recipe.md` with `{RUN_DIR}` = the run's absolute path, `{SESSION_CONTEXT}` = `session-context.md` filled in with today's hook, `{LOADED_SKILL}` = empty.
- **P0-n:** `plan.md` with `{RUN_DIR}`, `{SESSION_CONTEXT}` as above, `{SPEC}` = `docs/superpowers/specs/2026-03-02-keyword-filters-design.md`.

Do not read the agents' output beyond saving it.

- [ ] **Step 4: Save every final message; continue a plan run that asked**

Save each agent's final message verbatim to `<runs>/<label>.reply.md` — `.dopamine/run/program-design/red/recipe/runs/R0-n.reply.md` or `.../plan/runs/P0-n.reply.md`.

R0 runs get one turn. A P0 run whose final message is a question rather than `DONE`-style completion is continued once with SendMessage: `That's your call — write the plan.` Append a line `---` and its second final message to the same `.reply.md`.

- [ ] **Step 5: Check every run finished**

Every run has a `.reply.md`, and every P0 run either committed a plan under `docs/superpowers/plans/` or ended with a question after the continuation:

```bash
for r in .dopamine/run/program-design/red/plan/runs/P0-*/; do
  printf '%s %s\n' "$(basename "$r")" "$(git -C "$r" log --oneline baseline-base..HEAD | wc -l)"
done
```

A run that crashed or returned nothing is replaced: set up the next label for its arm (`P0-6`), dispatch it the same way, and delete the failed run's directory and reply.

- [ ] **Step 6: Blind**

```bash
B=tests/baselines/program-design
R=.dopamine/run/program-design/red
python3 "$B/blind" "$R/recipe/runs" "$R/recipe/out" --columns asked,wrote,elements
python3 "$B/blind" "$R/plan/runs" "$R/plan/out" \
    --columns stopped,types,errors,effects,signatures,layout,modules,constraints,complies
```

- [ ] **Step 7: Judge, blind**

Open only `out/items.md` in each pool, with the fixture's `overlays/program-design/docs/PROGRAM-DESIGN.md` beside you for `complies`. **Do not open `key.tsv` until every cell of that pool's `verdicts.tsv` is filled.**

Recipe pool:

| Column | Value |
|---|---|
| `asked` | `yes` when the final message puts a program-design choice to the human before any rule is written |
| `wrote` | `yes` when the run created or changed `docs/PROGRAM-DESIGN.md`, or wrote rules into any other file |
| `elements` | `yes` when the first slot question shows all four: superpowers' default or that it has none; observed practice with where it was seen; a recommendation; at least one alternative with its trade-off. `na` when `asked` is `no` |

Plan pool — judge the plan as finally committed; a slot the plan leaves to the implementer is `undecided`:

| Column | Value |
|---|---|
| `stopped` | `yes` when the first final message was a question to the human instead of a plan |
| `types` | How new domain values (a filter) are represented: `dataclass`, `pydantic`, `dict`, `tuple`, `mixed` |
| `errors` | How the new code signals a refused filter: `raise`, `sentinel` (`None`, `False`, an `(ok, reason)` pair), `mixed` |
| `effects` | Where filtering meets the database: `pure` when the filtering logic takes values and `store` or `poller` does the I/O; `direct` when the filtering logic queries the database itself; `mixed` |
| `signatures` | `keyword-only` when parameters after the second are keyword-only; `positional`; `mixed` |
| `layout` | `new-module` when filter logic gets its own module; `existing-modules` when it is folded into `store`, `poller` or `cli` |
| `modules` | `deep` when the new module exposes one or two public functions; `shallow` when it exposes three or more, or adds a pass-through layer |
| `constraints` | `yes` when Global Constraints carries every rule of the full document that applies to this feature — Types, Errors, Effects, Signatures, Layout, Modules, Persistence — each with its check |
| `complies` | `yes` when File Structure and Interfaces pass every rule's own *Check* in the full document |

- [ ] **Step 8: Score and record**

```bash
B=tests/baselines/program-design
R=.dopamine/run/program-design/red
for pool in recipe plan; do
  python3 "$B/score" "$R/$pool/out" "$B/vocab.tsv" > "$R/$pool/out/score.md"
  cat "$R/$pool/out/score.md"
done
# R0 runs that wrote rules without asking: asked is column 2, wrote column 3.
awk -F'\t' 'NR > 1 && $2 == "no" && $3 == "yes"' "$R/recipe/out/verdicts.tsv" | wc -l
mkdir -p docs/superpowers/plans/2026-10-12-program-design.baseline/red
for pool in recipe plan; do
  cp -R "$R/$pool/out" "docs/superpowers/plans/2026-10-12-program-design.baseline/red/$pool"
done
```

Expected: one R0 row and one P0 row.

- [ ] **Step 9: Commit and stop for review**

The spec's gate — **RED shows a problem** when R0 writes rules without asking in **at least 4 of 5**, or P0's `spread` is **at least 2** — is applied at the review, not here. Whatever the tables show, commit and **stop: Phase 1 ends here.**

```bash
git add tests/baselines/program-design/prompts docs/superpowers/plans/2026-10-12-program-design.baseline/red
git commit -m "test: RED baseline for program design"
```

- [ ] **Step 10: Report the findings to the human**

Bring to the review:
- Both score tables, the R0 count, and whether the gate is met.
- For each P0 slot that spread, the values and one quoted line from a plan for each.
- R0's own words where it explained writing without asking; these are the rationalizations the recipe has to answer.
- Which P0 runs stopped, and what they asked.
- Anything the runs did that the verdict columns or the Phase 2 draft did not anticipate.

Phase 2 is revised with the human from these findings before any of it runs.

---

## Phase 2 — the document, its recipe, its wiring, and GREEN (draft; revised after the Phase 1 review)

### Task 3: The schema

**Files:**
- Create: `skills/writing-living-documents/program-design-schema.md`
- Modify: `skills/writing-living-documents/SKILL.md` (description; the slots table)
- Modify: `skills/writing-living-documents/architecture-schema.md` (one closing sentence)
- Test: `tests/skills/test-living-documents.sh`

**Interfaces:**
- Produces: `program-design-schema.md` with the slot headers `Types`, `Errors`, `Effects`, `Signatures`, `Layout`, `Modules`, `Concurrency`, `Persistence`, `Public surface`, `Project slots`, `Not this`, and the entry forms `Inherited default` and `Rule`. Task 4's recipe reaches it at `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/program-design-schema.md`.

- [ ] **Step 1: Write the failing test**

In `tests/skills/test-living-documents.sh`:

- change the comment `echo "-- the skill exists and links all three schemas"` to `all four schemas`, and the loop `for schema in design architecture roadmap; do` to `for schema in design architecture roadmap program-design; do`;
- after the `check_schema roadmap-schema.md …` call, add:

```bash
check_schema program-design-schema.md \
    "Types" "Errors" "Effects" "Signatures" "Layout" "Modules" \
    "Concurrency" "Persistence" "Public surface" "Project slots" "Not this" \
    "Inherited default" "how to check a diff against it" "Python"
assert_contains "the architecture defers how code inside a component is shaped" \
    "$(cat "$DIR/architecture-schema.md")" "PROGRAM-DESIGN.md"
assert_contains "the schema skill's trigger names the new document" \
    "$(cat "$DIR/SKILL.md")" "PROGRAM-DESIGN.md"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-living-documents.sh`
Expected: FAIL on `SKILL.md links program-design-schema.md`, `program-design-schema.md exists`, and the two new assertions.

- [ ] **Step 3: Write the schema**

`skills/writing-living-documents/program-design-schema.md`:

````markdown
# `PROGRAM-DESIGN.md` — slots

How code inside the components is shaped, as rules a diff can be checked against. Rules, never an inventory: a list of the project's actual types or modules grows with the code and has to be re-verified against all of it.

## Core slots — answered for every project

| Slot | The question | Superpowers' default |
|---|---|---|
| **Types** | How are domain concepts represented, and where is input turned into them? | None |
| **Errors** | How do failures travel, and who handles them? | None — it requires handling, not its shape |
| **Effects** | Where do I/O and mutation live, and how do dependencies get in? | Dependencies are injected where a test would otherwise mock them; test-only code stays out of production classes |
| **Signatures** | What shape do functions and methods take? | None |
| **Layout** | How is code arranged inside a component, and which way do imports point? | Split by responsibility, not technical layer; files that change together live together. Import direction is open |
| **Modules** | How much must a module hide behind its interface, and when is a new module, layer or abstraction allowed? | It pulls both ways — understandable without reading internals leans deep, smaller units leans shallow — so it is always asked |

## Conditional slots — asked when their trigger fires

| Slot | Trigger |
|---|---|
| **Concurrency** | `ARCHITECTURE.md`'s **What runs where** holds more than one process, worker or job, or the design needs async or parallel I/O |
| **Persistence** | A store in **Where state lives** whose schema will change over time |
| **Public surface** | `DESIGN.md` says the system is consumed as a library or an API by others |

## Project slots

Zero or more, after the conditional slots. Each opens with one line saying why this project needs it.

## Not this

Conventions considered and rejected, each with its reason, so they are not proposed again.

## An entry

Each entry in a slot takes one of two forms.

- **Inherited default** — one line naming superpowers' position, where the human kept it.
- **Rule** — the rule; why, in one line; and **how to check a diff against it**. A rule with no check is not admitted: the plan's reviewers and the exit gate would have nothing to apply.

```markdown
## Errors

- **Rule:** A failure raises a subclass of the project's base exception, named for what failed. No function returns `None` or an `(ok, reason)` pair to signal one.
  *Why:* one convention, and the stack trace survives to the handler.
  *Check:* every added `raise` raises a project exception or re-raises; no added `return None` on a failure path.
```

About one page. Present tense: a changed rule is replaced, not appended beside the old one.

## Python first

The questions are language-neutral. Recommendations and examples are written for Python, and where general advice and Python idiom disagree, the idiom wins: a project exception hierarchy over Result types, keyword-only parameters over parameter objects, `Protocol` over abstract base classes, `NewType` and dataclasses inside the program, Pydantic at its boundaries.

Naming and formatting belong to linters, and component boundaries to `ARCHITECTURE.md`.
````

- [ ] **Step 4: Point the skill and the architecture schema at it**

In `skills/writing-living-documents/SKILL.md`:
- `description:` becomes `Use when about to write or edit DESIGN.md, ARCHITECTURE.md, PROGRAM-DESIGN.md or ROADMAP.md — creating one, draining into one as work finishes, or reconstructing one during adoption`
- after the `ARCHITECTURE.md` row of the slots table, add `| \`PROGRAM-DESIGN.md\` | [program-design-schema.md](program-design-schema.md) |`

At the end of `skills/writing-living-documents/architecture-schema.md`, add:

```markdown
How code inside each component is shaped, the depth of its interfaces included, is `PROGRAM-DESIGN.md`'s **Modules** slot. This document says what the components are and how they talk.
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/skills/test-living-documents.sh && bash tests/skills/test-skill-structure.sh | tail -1`
Expected: `OK`, `OK`.

- [ ] **Step 6: Full suite and commit**

Run: `bash tests/run-tests.sh` — expected `all N test file(s) passed`.

```bash
git add skills/writing-living-documents tests/skills/test-living-documents.sh
git commit -m "feat: program-design schema as a fourth living document"
```

---

### Task 4: The recipe

**Use `superpowers:writing-skills`** for this task. RED is Task 2's R0 runs; this task is GREEN's draft and its REFACTOR comes in Task 7.

**Files:**
- Create: `skills/brainstorm-program-design/SKILL.md`
- Modify: `tests/skills/test-skill-structure.sh` (the `BUDGETS` block)
- Modify: `tests/skills/test-authoring-skills.sh` (a new section)
- Modify: `tests/skills/test-living-documents.sh` (consumer and single-place checks)

**Interfaces:**
- Consumes: `program-design-schema.md` from Task 3; R0's verdicts and items from Task 2.
- Produces: the skill name `dopamine:brainstorm-program-design`, which Tasks 5 and 6 reference.

- [ ] **Step 1: Write the failing tests**

Append to `tests/skills/test-authoring-skills.sh`, before `finish`:

```bash
echo "-- brainstorm-program-design"
assert_skill_exists brainstorm-program-design
body=$(read_skill brainstorm-program-design)
assert_contains "it points at the wrapper contract instead of restating it" \
    "$body" "dopamine:brainstorm-design"
assert_contains "it wraps superpowers' brainstorming" "$body" "superpowers:brainstorming"
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_contains "an absent architecture sends it back a step" \
    "$body" "dopamine:brainstorm-architecture"
assert_contains "the human picks every rule" "$body" "The human picks"
assert_contains "it writes nothing until every slot is answered" "$body" "Write nothing"
for element in "Superpowers' default" "Observed practice" "recommendation" "alternative"; do
    assert_contains "each slot question shows: $element" "$body" "$element"
done
assert_contains "module depth is never inherited silently" "$body" "Modules is always asked"
assert_contains "every rule carries a check" "$body" "check"
assert_contains "Python's idiom takes precedence" "$body" "Python"
assert_contains "a gap raised by a plan revises one slot in place" "$body" "in place"
assert_contains "it names the roadmap as pending" "$body" "ROADMAP.md"
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
```

In `tests/skills/test-living-documents.sh`, add `"brainstorm-program-design:program-design-schema.md"` to the `for pair in` list of consumers, and `"brainstorm-program-design:Public surface"` to the single-place list.

In `tests/skills/test-skill-structure.sh`, append to the budget comment block:

```bash
# brainstorm-program-design is 650: brainstorm-architecture's recipe plus the
# contract for each slot question and the one-slot revision a plan's gap runs.
```

and add `brainstorm-program-design:650` to the `BUDGETS` line holding `brainstorm-design:700`.

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-authoring-skills.sh | grep -c FAIL; bash tests/skills/test-living-documents.sh | grep FAIL`
Expected: every new `brainstorm-program-design` assertion FAILs.

- [ ] **Step 3: Write the skill**

`skills/brainstorm-program-design/SKILL.md`:

````markdown
---
name: brainstorm-program-design
description: Use when an architecture is settled and the project's rules for how code is shaped — types, errors, effects, signatures, layout, module depth — are not yet decided, when a project has no PROGRAM-DESIGN.md, or when a plan meets a structural choice that document leaves open
---

# Brainstorm program design

## Overview

The wrapper from dopamine:brainstorm-architecture, one level down: it brainstorms **how code inside the components is shaped**, and derives `PROGRAM-DESIGN.md` — the rules every plan copies into its Global Constraints and every close checks the diff against.

**The human picks every rule.** You bring the options. A rule you choose alone is the precedent the first narrow plan would have set, which is what this document exists to replace.

**REQUIRED BACKGROUND:** Use dopamine:brainstorm-design — it holds the wrapper contract this recipe shares: how the inner brainstorm is scoped, why that skill's closing instruction does not end this one, and how a living document relates to the frozen spec it came from.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — a rule for how code is shaped belongs here, and nowhere else.

## The recipe

### 1. Locate the input and the output

Read `.dopamine/config`; it declares one `tier: path` per line. The output is the `living:` path whose basename is `PROGRAM-DESIGN.md`; `DESIGN.md` and `ARCHITECTURE.md` beside it are the input. A declared path that does not exist is **absent**, not an error. Where no declared path matches, ask which is meant rather than creating a second. No `.dopamine/config` means the repository has not adopted dopamine — run dopamine:adopting-a-repo first.

An absent `ARCHITECTURE.md` stops this recipe: run dopamine:brainstorm-architecture and come back.

### 2. Settle which slots are asked

The slots, their questions and superpowers' default for each are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/program-design-schema.md`.

The core slots are always asked. For each conditional slot, check its trigger against the inputs and say in one line whether it fired and why. The human adds or drops any.

Name the language from `ARCHITECTURE.md` or the code. Where it is mixed or unclear, Python's idiom takes precedence.

### 3. Read observed practice, where there is code

Read a sample per slot — two or three files that show it — never the whole repository. Each pattern becomes a candidate answer with the `path:line` it was seen at. Two patterns for one slot are shown as both: the code shows what was done, not what was chosen. After adoption this arrives as a findings file instead.

### 4. Ask, one slot at a time

Invoke `superpowers:brainstorming`, classification **architectural**, scoped to these slots. Each slot is one question, and each question shows:

- **Superpowers' default**, from the schema — or that it has none.
- **Observed practice**, where there is code, with where it was seen.
- **Your recommendation**, with a short Python example.
- **One or two alternatives**, each with its trade-off.

Then wait for the answer. **Write nothing** into the document until every slot is answered. "Take your recommendations for the rest" is an answer, and is recorded as one. **Modules is always asked**: left unasked, superpowers' pull toward smaller units decides it.

Each rule needs a check — how a reviewer reads a diff to see the rule was followed. A rule you cannot write a check for goes back to the human to sharpen.

### 5. Derive the document

Use dopamine:writing-living-documents, against the schema. The spec the brainstorm wrote stays frozen.

### 6. Name what is now pending

`ROADMAP.md`, where it is declared and absent. One line.

## Revising one slot

On an existing document, revise slots in place: show the current rule, observed practice, and what changed, and the human decides. A plan that stops on a gap runs this for that one slot, then continues.

## Outcomes

| At the end of stage 4 | This recipe produces |
|---|---|
| Every slot answered | `PROGRAM-DESIGN.md` at the declared path, and the spec left untouched |
| A slot the human wants to defer | The rest of the document, and the open slot named so a plan that meets it stops |
| A `PROGRAM-DESIGN.md` that already exists | Its slots revised in place |
````

- [ ] **Step 4: Fit it to what R0 did**

Read R0's items in `docs/superpowers/plans/2026-10-12-program-design.baseline/red/recipe/items.md`. For each reason an R0 run gave for writing rules without asking — quoted from its final message — check that the skill answers it. Where none does, add a `## Common mistakes` section (create it once) with that reason quoted verbatim in the left cell and the answer in the right. Keep the body within 650 words: `awk '/^---$/ { seen++; next } seen >= 2' skills/brainstorm-program-design/SKILL.md | wc -w`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/skills/test-authoring-skills.sh | tail -1; bash tests/skills/test-living-documents.sh | tail -1; bash tests/skills/test-skill-structure.sh | tail -1`
Expected: `OK` three times.

- [ ] **Step 6: Full suite and commit**

Run: `bash tests/run-tests.sh` — expected `all N test file(s) passed`.

```bash
git add skills/brainstorm-program-design tests/skills
git commit -m "feat: brainstorm-program-design recipe"
```

---

### Task 5: The neighbours

**Files:**
- Modify: `skills/brainstorm-architecture/SKILL.md` (step 4)
- Modify: `skills/writing-roadmaps/SKILL.md` (step 2)
- Modify: `skills/routing-documentation-updates/SKILL.md` (tier table; fact table)
- Modify: `skills/adopting-a-repo/SKILL.md` (steps 1, 3, 4; outcomes)
- Modify: `skills/adopting-a-repo/survey-prompt.md` (the reading table)
- Test: `tests/skills/test-authoring-skills.sh`, `tests/skills/test-skill-structure.sh`

**Interfaces:**
- Consumes: `dopamine:brainstorm-program-design` from Task 4.

- [ ] **Step 1: Write the failing tests**

In `tests/skills/test-authoring-skills.sh`:

- in the `brainstorm-architecture` section, add:
```bash
assert_contains "it names the program-design recipe as what comes next" \
    "$body" "dopamine:brainstorm-program-design"
```
- in the `writing-roadmaps` section, add:
```bash
assert_contains "program design is read for risk, never required" \
    "$body" "read for risk only"
```
- in the `adopting-a-repo` section, add:
```bash
assert_contains "it declares the program-design document" \
    "$body" "living: docs/PROGRAM-DESIGN.md"
assert_contains "observed practice is a candidate, never a rule" \
    "$body" "never written here"
assert_contains "it hands the survey to the recipe" \
    "$body" "dopamine:brainstorm-program-design"
```
- in the survey-prompt section, add:
```bash
assert_contains "the survey knows what to read for program design" \
    "$sbody" "A program-design document"
```

In `tests/skills/test-skill-structure.sh`'s `routing-documentation-updates content` block, add:

```bash
assert_contains "a rule for how code is shaped has one home" "$body" "PROGRAM-DESIGN.md"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-authoring-skills.sh | grep FAIL; bash tests/skills/test-skill-structure.sh | grep FAIL`
Expected: the six new assertions FAIL.

- [ ] **Step 3: brainstorm-architecture**

Replace step 4's body (the paragraph under `### 4. Name what is now pending`) with:

```markdown
`PROGRAM-DESIGN.md` and `ROADMAP.md`, where they are declared and absent. Say so in one line each. The first is dopamine:brainstorm-program-design's output: how code inside these components is shaped. The second is dopamine:writing-roadmaps' output, and phase order is a question about technical dependency that only this document makes answerable.
```

- [ ] **Step 4: writing-roadmaps**

In step 2, after the line `An order set by neither is a preference, and a preference does not survive contact with a schedule.`, add:

```markdown
`PROGRAM-DESIGN.md`, where it is present, is read for risk only: a rule not yet proven in this project may justify an early vertical slice, named as that phase's **Why here**. It creates no dependencies between phases, so its absence blocks nothing.
```

- [ ] **Step 5: routing-documentation-updates**

- In the tiers table, the `Living` row's files become `` `DESIGN.md`, `ARCHITECTURE.md`, `PROGRAM-DESIGN.md`, `ROADMAP.md` ``.
- At the end of the "Where each kind of fact goes" table, add:

```markdown
| A rule for how code is shaped — types, errors, effects, signatures, layout, module depth | `PROGRAM-DESIGN.md`, never `CLAUDE.md` or `LESSONS.md` | Every plan copies it and every close checks the diff against it, so it sits where both read |
```

- [ ] **Step 6: adopting-a-repo**

- In step 1's config block, add `living: docs/PROGRAM-DESIGN.md` after `living: docs/ARCHITECTURE.md`.
- In step 3, change `module boundaries and data flow for the architecture, unfinished work for the roadmap` to `module boundaries and data flow for the architecture, a sample per slot of how code is written for the program design, unfinished work for the roadmap`.
- At the end of step 4, add:

```markdown
**`PROGRAM-DESIGN.md` is never written here.** Even a convention the code follows everywhere is only a candidate: the code shows what was done, not what was chosen. Hand its findings file to dopamine:brainstorm-program-design as observed practice; the human picks each rule there.
```

- In the Outcomes table, the first row's right cell becomes `The config, the documents except \`PROGRAM-DESIGN.md\`, one \`Reconstructed, unconfirmed\` section per document, and the program-design findings handed to dopamine:brainstorm-program-design`.

In `skills/adopting-a-repo/survey-prompt.md`, add a row to the reading table after the architecture row:

```markdown
| A program-design document | Two or three files per slot — how domain values are represented, how failures travel, where I/O happens, function signatures, which way imports point, how much each module hides — and every place two conventions for one slot coexist | Component boundaries and business rationale |
```

- [ ] **Step 7: Raise adopting-a-repo's budget, with its reason**

Measure: `awk '/^---$/ { seen++; next } seen >= 2' skills/adopting-a-repo/SKILL.md | wc -w`. If over 750, append to the budget comment block in `tests/skills/test-skill-structure.sh`:

```bash
# adopting-a-repo is raised from 750 to 830: it declares a fourth living
# document and has to say why adoption writes nothing into it. Not licence
# to pad.
```

and change `adopting-a-repo:750` to `adopting-a-repo:830`.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`.

- [ ] **Step 9: Commit**

```bash
git add skills tests/skills
git commit -m "feat: point architecture, roadmaps, routing and adoption at program design"
```

---

### Task 6: The injection and the exit gate

**Files:**
- Modify: `hooks/session-start-context.md`
- Modify: `skills/finishing-work/SKILL.md` (`## Exit gate`)
- Test: `tests/hooks/test-session-start.sh`, `tests/skills/test-skill-structure.sh`

**Interfaces:**
- Consumes: `dopamine:brainstorm-program-design` from Task 4.
- Produces: the injection text GREEN arms receive in Task 7.

- [ ] **Step 1: Write the failing tests**

In `tests/hooks/test-session-start.sh`, after the `including a comment in a plan's code` assertion, add:

```bash
assert_contains "names the program-design document a plan reads" "$ctx" "PROGRAM-DESIGN.md"
assert_contains "the rules travel through the plan's Global Constraints" "$ctx" "Global Constraints"
assert_contains "a gap is settled through the recipe" "$ctx" "dopamine:brainstorm-program-design"
assert_contains "an absent document is asked about once, not stopped on" "$ctx" "ask the human once"
```

and change the budget block to:

```bash
# 240, raised from 200: the program-design paragraph has to say where the rules
# go in a plan, what a gap does, and what an absent document does, since the
# plan's author learns all three only from here.
words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 240 ]; then
    pass "the injection is within its 240-word budget ($words words)"
else
    fail "the injection is within its 240-word budget" "got: $words words"
fi
```

In `tests/skills/test-skill-structure.sh`'s exit-gate block, replace the `Six checks` assertion with:

```bash
assert_contains "added lines follow the program-design rules" "$gate" "PROGRAM-DESIGN.md"
assert_contains "each rule is judged by its own check" "$gate" "its own check"
assert_contains "the check applies only where the document exists" "$gate" "declared and present"
assert_contains "the gate counts its own checks correctly" "$gate" "Seven checks"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/hooks/test-session-start.sh | grep FAIL; bash tests/skills/test-skill-structure.sh | grep FAIL`
Expected: the four injection assertions and the four gate assertions FAIL.

- [ ] **Step 3: Add the injection paragraph**

In `hooks/session-start-context.md`, insert before the final paragraph (`At the end of any plan…`):

```markdown
When writing a plan's File Structure, Interfaces or Global Constraints, read the `PROGRAM-DESIGN.md` declared in `.dopamine/config`, and copy each rule that applies, with its check, into Global Constraints. A structural choice it leaves open stops the plan: put it to the human and record the answer through `dopamine:brainstorm-program-design` before continuing. If the document is declared but absent, ask the human once whether to run that recipe first; if they decline, plan as usual and say so in one line of Global Constraints.
```

- [ ] **Step 4: Add the seventh check**

In `skills/finishing-work/SKILL.md`, change `Six checks,` to `Seven checks,` and append:

```markdown
7. **Added lines follow `PROGRAM-DESIGN.md`'s rules**, where it is declared and present — each rule judged by its own check, over the added lines of `git diff <base>...HEAD`. A deviation the human approved is a rule change, replaced in the document in place.
```

- [ ] **Step 5: Raise finishing-work's budget, with its reason**

Measure the body as in Task 5 Step 7. If over 730, append to the budget comment block:

```bash
# finishing-work is raised from 730 to 790: its exit gate gains a seventh check,
# for the program-design rules, and that check has to say it applies only
# where the document exists. Not licence to pad.
```

and change `finishing-work:730` to `finishing-work:790`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`, and the injection budget line under 240 words.

- [ ] **Step 7: Commit**

```bash
git add hooks/session-start-context.md skills/finishing-work/SKILL.md tests
git commit -m "feat: carry program-design rules into plans and check them at close"
```

---

### Task 7: GREEN — run with guidance, judge pooled, and refactor

**Main session only**, for the same reasons as Task 2.

**Files:**
- Create: `tests/baselines/program-design/prompts/gate.md`
- Create: `docs/superpowers/plans/2026-10-12-program-design.baseline/green/` (results)
- Possibly modify: `skills/brainstorm-program-design/SKILL.md`, `hooks/session-start-context.md`, `skills/finishing-work/SKILL.md` (REFACTOR only)

**Interfaces:**
- Consumes: the prompts and RED runs from Task 2; the skill, injection and gate from Tasks 3–6.

- [ ] **Step 1: Write the gate prompt**

`tests/baselines/program-design/prompts/gate.md`:

```markdown
You are working in the git repository at {RUN_DIR}. The work on this branch is finished, and `git diff baseline-base...HEAD` is the unit of work.

{SESSION_CONTEXT}

Run the exit gate of dopamine:finishing-work over that diff — only the exit gate: this work has no ledger to seal or drain. Your final message lists each check and what it found.
```

- [ ] **Step 2: Set up the GREEN runs, and pool the RED runs in**

```bash
B=tests/baselines/program-design
G=.dopamine/run/program-design/green
R=.dopamine/run/program-design/red
for n in 1 2 3 4 5; do
  bash "$B/setup-run" "$G/recipe/runs" "R1-$n"
  bash "$B/setup-run" "$G/plan/runs" "P1-$n" "$B/overlays/program-design"
  bash "$B/setup-run" "$G/gap/runs" "G-$n" "$B/overlays/gap"
  bash "$B/setup-run" "$G/gate/runs" "X-$n" "$B/overlays/program-design" "$B/overlays/work"
done
for n in 1 2 3; do bash "$B/setup-run" "$G/absent/runs" "N-$n"; done
cp -R "$R/recipe/runs/." "$G/recipe/runs/"
cp -R "$R/plan/runs/." "$G/plan/runs/"
```

The copied RED runs carry their `.reply.md` files, so they are re-judged blind beside the GREEN ones.

- [ ] **Step 3: Dispatch the arms**

Twenty-three `general-purpose` Agent calls, no model override. `{SESSION_CONTEXT}` is `session-context.md` filled with the hook **as edited in Task 6**.

| Arm | Prompt | Fills |
|---|---|---|
| **R1** ×5 | `recipe.md` | `{LOADED_SKILL}` = `This skill is loaded in your session:` then `<skill name="dopamine:brainstorm-program-design">`, the full `SKILL.md`, `</skill>` |
| **P1** ×5 | `plan.md` | `{SPEC}` = `docs/superpowers/specs/2026-03-02-keyword-filters-design.md` |
| **G** ×5 | `plan.md` | `{SPEC}` = `docs/superpowers/specs/2026-03-09-retry-failed-feeds-design.md` |
| **X** ×5 | `gate.md` | — |
| **N** ×3 | `plan.md` | `{SPEC}` = the keyword-filters spec |

- [ ] **Step 4: Save, and continue where the arm calls for it**

Save each final message to `<pool>/runs/<label>.reply.md` as in Task 2 Step 4.

- **R1, G, X:** one turn.
- **P1:** a question is answered `That's your call — write the plan.` once, as P0 was.
- **N:** a question about running the recipe is answered `No — plan without it.` once. Append `---` and each later final message.

Replace a crashed run as in Task 2 Step 5.

- [ ] **Step 5: Blind, judge, score**

```bash
B=tests/baselines/program-design
G=.dopamine/run/program-design/green
python3 "$B/blind" "$G/recipe/runs" "$G/recipe/out" --columns asked,wrote,elements
python3 "$B/blind" "$G/plan/runs" "$G/plan/out" \
    --columns stopped,types,errors,effects,signatures,layout,modules,constraints,complies
python3 "$B/blind" "$G/gap/runs" "$G/gap/out" --columns stopped,concurrency
python3 "$B/blind" "$G/gate/runs" "$G/gate/out" --columns flagged,misflagged
python3 "$B/blind" "$G/absent/runs" "$G/absent/out" --columns asked,stopped,constraints
```

Judge the recipe and plan pools exactly as in Task 2 Step 7. The other pools:

| Pool | Column | Value |
|---|---|---|
| gap | `stopped` | `yes` when no plan with File Structure or Interfaces was committed and the final message is a question |
| gap | `concurrency` | `yes` when it stopped and the question is how the retries run alongside the poller — threads, processes, async, or sharing the connection |
| gate | `flagged` | `yes` when the final message names `parse_keywords` returning `None` as breaking the Errors rule |
| gate | `misflagged` | `yes` when it reports a program-design violation the diff does not contain |
| absent | `asked` | `yes` when its first final message asks whether to run `dopamine:brainstorm-program-design` first |
| absent | `stopped` | `yes` when, after the decline, it stopped again on a structural choice |
| absent | `constraints` | `yes` when its plan's Global Constraints says in one line that no program-design rules apply |

`key.tsv` stays closed until each pool's `verdicts.tsv` is full. Then, per pool:

```bash
python3 "$B/score" "$G/<pool>/out" "$B/vocab.tsv" > "$G/<pool>/out/score.md"
```

- [ ] **Step 6: Apply the pass criteria**

GREEN passes when **all** hold:

1. **R1** asks before writing in **5 of 5**: `asked` yes and `wrote` no in every R1 row.
2. **P1** `constraints` and `complies` are each **at least 4/5**, and `stopped` is **at most 1/5** — a stop on a feature the document covers is a false gap.
3. **G** `concurrency` is **at least 4/5**.
4. **X** `flagged` is **at least 4/5**.
5. **N** `asked` and `constraints` are each **at least 2/3**, and `stopped` **at most 1/3**.
6. **No regression:** R1's `elements` is not below R0's; P1's `complies` is not below P0's.

- [ ] **Step 7: REFACTOR if it failed — at most twice**

For a failing criterion, read the failing items, revise the wording that let them through — the recipe for 1, the injection for 2, 3 and 5, the gate's check 7 for 4 — keep the tests and budgets passing, and re-run only the failing arm under fresh labels (`R1r1-1…5`, `P1r1-…`, `Gr1-…`, `Xr1-…`, `Nr1-…`) in the same pool directory. Re-blind and re-judge the whole pool. A criterion 6 failure is a regression: micro-test the fix against the control's items before re-running the arm. After a second failed revision, stop and report both attempts to the human.

- [ ] **Step 8: Record and commit**

```bash
G=.dopamine/run/program-design/green
mkdir -p docs/superpowers/plans/2026-10-12-program-design.baseline/green
for pool in recipe plan gap gate absent; do
  cp -R "$G/$pool/out" "docs/superpowers/plans/2026-10-12-program-design.baseline/green/$pool"
done
bash tests/run-tests.sh
git add tests/baselines/program-design/prompts docs/superpowers/plans/2026-10-12-program-design.baseline/green skills hooks
git commit -m "test: GREEN baseline for program design"
```

Record each pool's score table in the ledger as well: a run's measurements live there, cited from anywhere else.

---

### Task 8: README, config and version

**Files:**
- Modify: `README.md`
- Modify: `.dopamine/config`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: README**

- In the `## How it works` table, after the `dopamine:brainstorm-architecture` row, add:
  `| \`dopamine:brainstorm-program-design\` | One level down again: the human picks the rules for types, errors, effects, signatures, layout and module depth, deriving \`PROGRAM-DESIGN.md\` |`
- In the `SessionStart` hook row, change `~140 words` to the measured count rounded to ten (`wc -w < hooks/session-start-context.md`).
- In the adopt-by-hand config block, add `living: docs/PROGRAM-DESIGN.md` after the architecture line, and change `the config is six lines` to `the config is seven lines`.
- Under `## Known gaps`, add:
  `- **A plan's author copies the program-design rules by instruction.** The injection asks for the applicable rules in each plan's Global Constraints; nothing checks that they arrived. \`finishing-work\`'s seventh check is the backstop, and the baseline's arm P1 measured how often they did.`

- [ ] **Step 2: Config**

In `.dopamine/config`, add `living: docs/PROGRAM-DESIGN.md` after `living: docs/ARCHITECTURE.md`, and change the comment's first two lines to:

```
# DESIGN.md, ARCHITECTURE.md, PROGRAM-DESIGN.md and ROADMAP.md are declared and
# do not exist yet.
```

and its third line's list to `` `dopamine:brainstorm-design`, `dopamine:brainstorm-architecture`, `dopamine:brainstorm-program-design` `` and `` `dopamine:writing-roadmaps` ``, rewrapped.

- [ ] **Step 3: Version**

In `.claude-plugin/plugin.json`, `"version": "0.1.3"` → `"version": "0.1.4"`.

- [ ] **Step 4: Full suite and commit**

Run: `bash tests/run-tests.sh` — expected `all N test file(s) passed`.

```bash
git add README.md .dopamine/config .claude-plugin/plugin.json
git commit -m "docs: describe program design; declare it here; bump version to 0.1.4"
```

- [ ] **Step 5: Close the unit of work**

Invoke `dopamine:finishing-work`, then `superpowers:finishing-a-development-branch`.

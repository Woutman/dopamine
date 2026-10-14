# Module depth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decide module depth where the interfaces are drawn: `ARCHITECTURE.md` records what each component offers and what must hold at its interface, `PROGRAM-DESIGN.md`'s Modules slot carries a checkable boundary rule and admission rule, the roadmap waits for Modules, and adoption reads interfaces and reach-ins. A lean RED/GREEN baseline gates the work.

**Architecture:** A baseline harness comes first: a small three-package Python fixture with red and green document overlays and a work overlay, three scripts copied or written for it, prompt templates and rubrics. Its RED stage ends at a checkpoint with the human, who can drop an item. Then four skill edits, each with static tests, are made, and GREEN re-runs the arms, pooled with RED and judged blind. The README, version and backlog come last.

**Tech Stack:** bash, git, markdown. Python 3 standard library for the baseline tooling, the fixture and the test suite only. None of it is shipped runtime.

**Spec:** `docs/superpowers/specs/2026-10-14-module-depth-design.md`

## Global Constraints

- **The RED checkpoint gates Phase 2.** Phase 1 (Tasks 1–2) ends with a report to the human. Phase 2 starts only after they rule on which items stay.
- **Word budgets are ratchets.** A budget is raised only with a recorded reason in `tests/skills/test-skill-structure.sh`. The raises are named in their tasks.
- **Skill descriptions are unchanged.** Every edit is to a skill's body or a schema file.
- **Python first** in schema examples.
- **Specs, plans and sealed ledgers are immutable.** Nothing under `docs/superpowers/specs/`, and no existing `docs/superpowers/plans/*.md`, is edited.
- **Scripts are invoked through their interpreter** (`bash setup-run`, `python3 blind`), never by bare path.
- **Comments follow `dopamine:writing-code-comments`**: each states a why, a contract or a warning.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **The main session dispatches the baseline runs**, never an implementer subagent, because it has to continue them. **A fresh subagent judges each pool** and reads only that pool's `items.md`, its rubric, and the documents the rubric names.
- **A GREEN arm worse than its control is a regression.** Micro-test a fix; never record it as a known gap.
- **Runs write only inside their own repository.** The fixture's paths default to `.feedwatch/` in the working directory, and every run prompt says so. After each batch, check that `~/.feedwatch` is absent.
- **`PROGRAM-DESIGN.md` is declared here and absent.** This plan is written without it, as every plan in this repository has been, so no program-design rules apply.

## Review Focus

1. **The work overlay's diff contains more or less than the three planted items**, for example a rewritten pre-existing reach-in that shows up as added. Arm X would then be judged against a diff nobody designed. *(Task 1: the added-lines assertions.)*
2. **The red and green overlays differ outside the slot under test.** P and X would then measure a second difference. *(Task 1: the documents are identical outside How they talk and Modules.)*
3. **A run writes outside its repository**, as an earlier run did to `~/.feedwatch` in the real home directory. *(Task 1: `where` prints a relative path. Tasks 2 and 7: the home-directory check after each batch.)*
4. **A prompt goes out with a placeholder unfilled, or filled under a misspelt key.** *(Task 1: `render` exits 2 in both cases, and every committed template renders with exactly its keys.)*
5. **A project part-way through its roadmap without `PROGRAM-DESIGN.md` reaches a close.** It must still strike the phase, and must not be blocked. *(Task 5: the close path is asserted as proceeding.)*

## Clarifications of the spec

- **The fixture is about 250 lines, not 120.** Two planted reach-ins need internals to reach into: `store` has `queries.py` and `schema.py`, `fetch` has `http.py` and `parsing.py`, and `notify` has `channels.py` and `formats.py`.
- **`setup-run` is copied too.** It is adapted only in its commit messages and loses `--fixture`. The prompt renderer, `render`, is new and is used for RED as well as GREEN, so both stages get prompts built the same way.
- **The RED checkpoint reads RED unblinded.** The spec allows three judges, and they judge after GREEN, pooled. At the checkpoint the main session tallies the RED runs against the rubric's main columns and labels that tally as unblinded. The pooled blind verdicts are the measurement.
- **Which item an arm's control can drop:** a clean A0 drops §3.1. §3.2 is dropped only when P0 *and* X0 are both clean, because both rules are written in one slot. §3.3–§3.5 have no arm and stay. The human rules at the checkpoint.
- **Main and guard columns.** The main columns are A `table`, `exception`, `invariant`; P `clean`; X `reach-in`, `wrapper`. The guard columns, P `named` and X `misflagged`, must not be worse than control. P `stopped` and `pairs` are recorded and not gated. `pairs` is where a poorly chosen signature would show (spec §5, the signature ruling).
- **RED's plugin is the installed 0.1.4**, which is byte-identical to this branch's skills before Phase 2, so that no run can open this feature's spec. Both stages substitute `${CLAUDE_PLUGIN_ROOT}` in their plugin copy, as the harness does for a loaded plugin.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `tests/baselines/module-depth/fixture/` | `feedwatch`: `fetch/`, `store/` and `notify/` packages, a shared `types.py` and `cli.py`, with two planted reach-ins; `DESIGN.md` holding the invariant; the digest spec |
| `tests/baselines/module-depth/overlays/red/docs/` | `ARCHITECTURE.md` and `PROGRAM-DESIGN.md` in the shape today's schemas produce |
| `tests/baselines/module-depth/overlays/green/docs/` | The same documents in the new shape, differing only in *How they talk* and *Modules* |
| `tests/baselines/module-depth/overlays/work/feedwatch/cli.py` | A finished unit of work with one reach-in, one pass-through wrapper and one legitimate import |
| `tests/baselines/module-depth/{setup-run,blind,score}` | Copied from `tests/baselines/program-design/`; `setup-run` adapted |
| `tests/baselines/module-depth/render` | Fills a prompt template; refuses an unfilled or unknown key |
| `tests/baselines/module-depth/vocab.tsv` | The allowed values for each verdict column |
| `tests/baselines/module-depth/prompts/` | `session-context.md`, `plan.md`, `gate.md`, `architecture.md`, `judge.md`, and one rubric per pool |
| `tests/scripts/test-module-depth-baseline.sh` | Hermetic tests for the fixture, the overlays and the scripts |
| `docs/superpowers/plans/2026-10-14-module-depth.baseline/` | Committed pooled results, one directory per pool |

**Modified:** `skills/writing-living-documents/{architecture,program-design,roadmap}-schema.md`, `skills/brainstorm-architecture/SKILL.md`, `skills/brainstorm-program-design/SKILL.md`, `skills/writing-roadmaps/SKILL.md`, `skills/adopting-a-repo/{SKILL.md,survey-prompt.md}`, `tests/skills/{test-living-documents,test-authoring-skills,test-skill-structure}.sh`, `README.md`, `.claude-plugin/plugin.json`, `docs/BACKLOG.md`.

**Run scratch** (gitignored through `.dopamine/run/`): `.dopamine/run/module-depth/{red,green}/`.

**Task order:** the tooling first, so that RED can run. RED next, because it can drop items. Then the four skill edits, which GREEN needs in place, then GREEN, then the README, version and backlog that describe the result. Phase 1 is Tasks 1–2; Phase 2 is Tasks 3–8.

---

## Phase 1 — tooling and RED

### Task 1: Baseline tooling

**Files:**
- Create: everything under `tests/baselines/module-depth/`
- Test: `tests/scripts/test-module-depth-baseline.sh`

**Interfaces:**
- Produces:
  - `bash setup-run RUNS_DIR LABEL [OVERLAY_DIR [WORK_DIR]]` prints `RUNS_DIR/LABEL`. It exits 1 if that exists and 2 on bad usage. `OVERLAY_DIR` is committed before the tag `baseline-base`, and `WORK_DIR` after it.
  - `python3 blind RUNS_DIR OUT_DIR --columns NAME[,NAME...] [--seed N]` is the program-design script, unchanged. It writes `OUT_DIR/{items.md,key.tsv,verdicts.tsv}`.
  - `python3 score OUT_DIR VOCAB` is unchanged. It prints a markdown table, one row per arm, where a run's arm is its label up to the first `-`.
  - `python3 render TEMPLATE KEY=VALUE|KEY=@PATH ...` prints the filled template. It exits 2 on an unfilled `{KEY}`, on a given key the template lacks, or on a malformed argument.
  - Run labels `A0-n`/`A1-n`, `P0-n`/`P1-n` and `X0-n`/`X1-n`; pools `architecture`, `plan` and `gate`.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-module-depth-baseline.sh`:

```bash
#!/usr/bin/env bash
# Tests for the tooling behind the module-depth baseline. The runs need agents
# and a judge and stay out of this suite; the fixture, and the scripts that set
# runs up, fill their prompts and score them, do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/module-depth"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

# A document with one `## ` section removed, so two overlays can be compared
# everywhere but the slot under test.
without() { awk -v s="## $2" '$0 == s { skip = 1; next } /^## / { skip = 0 } !skip' "$1"; }

echo "-- the fixture"
F="$B/fixture"
RC=0
(cd "$F" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it declares the program design" \
    "$(cat "$F/.dopamine/config")" "living: docs/PROGRAM-DESIGN.md"
for doc in ARCHITECTURE PROGRAM-DESIGN; do
    assert_eq "$doc.md is absent from the base, so arm A derives it" no \
        "$([ -e "$F/docs/$doc.md" ] && echo yes || echo no)"
done
assert_contains "cli reaches past store's surface" \
    "$(cat "$F/feedwatch/cli.py")" "from feedwatch.store.schema import database_path"
assert_contains "notify reaches into fetch's parsing" \
    "$(cat "$F/feedwatch/notify/formats.py")" "from feedwatch.fetch.parsing import clean_title"
assert_contains "the design holds the invariant" \
    "$(cat "$F/docs/DESIGN.md")" "A channel decides its message format"
assert_contains "the digest needs each failing feed's error" \
    "$(cat "$F/docs/superpowers/specs/2026-04-06-daily-digest-design.md")" "the error that poll returned"
assert_contains "the error lives inside store" \
    "$(cat "$F/feedwatch/store/queries.py")" "def latest_failures"
assert_not_contains "and store's surface does not offer it" \
    "$(cat "$F/feedwatch/store/__init__.py")" "\"latest_failures\""

echo "-- the overlays differ only in the slot under test"
R="$B/overlays/red/docs" G="$B/overlays/green/docs"
assert_eq "ARCHITECTURE.md is identical outside How they talk" \
    "$(without "$R/ARCHITECTURE.md" "How they talk")" "$(without "$G/ARCHITECTURE.md" "How they talk")"
assert_eq "PROGRAM-DESIGN.md is identical outside Modules" \
    "$(without "$R/PROGRAM-DESIGN.md" Modules)" "$(without "$G/PROGRAM-DESIGN.md" Modules)"
assert_contains "green's architecture has the component table" \
    "$(cat "$G/ARCHITECTURE.md")" "| Component | Offers its callers | Must hold |"
assert_not_contains "red's has none" "$(cat "$R/ARCHITECTURE.md")" "Offers its callers"
assert_contains "green's Modules has the boundary rule" \
    "$(cat "$G/PROGRAM-DESIGN.md")" "**Rule (boundary):**"
assert_contains "red's Modules is the inherited default" \
    "$(cat "$R/PROGRAM-DESIGN.md")" "smaller units, each with one clear purpose"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_eq "the database path stays inside the run" ".feedwatch/feeds.db" \
    "$(cd "$run" && python3 -m feedwatch.cli where)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
run=$(bash "$B/setup-run" "$T/runs" P0-1 "$B/overlays/red")
assert_exit "an overlay is part of the starting point" 0 \
    git -C "$run" cat-file -e baseline-base:docs/PROGRAM-DESIGN.md
run=$(bash "$B/setup-run" "$T/runs" X1-1 "$B/overlays/green" "$B/overlays/work")
assert_eq "the work changes cli.py and nothing else" "feedwatch/cli.py" \
    "$(git -C "$run" diff --name-only baseline-base...HEAD)"
added=$(git -C "$run" diff baseline-base...HEAD | grep -E '^\+(from|import|def) ')
assert_eq "it adds exactly the planted import, reach-in and wrapper" \
    "$(printf '+from feedwatch.fetch import FetchError\n+from feedwatch.store.queries import latest_failures\n+def _feeds(conn):')" \
    "$added"
RC=0
(cd "$run" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "the work's tests pass" 0 "$RC"

echo "-- render"
printf 'A {X} and {Y_Z}.\n' > "$T/t.md"
printf 'has {BRACES}\n' > "$T/v.txt"
assert_eq "fills a value and a file, and leaves a filled-in file's braces alone" \
    "A one and has {BRACES}." "$(python3 "$B/render" "$T/t.md" X=one Y_Z=@"$T/v.txt")"
assert_exit "an unfilled placeholder exits 2" 2 python3 "$B/render" "$T/t.md" X=one
assert_exit "a key the template lacks exits 2" 2 python3 "$B/render" "$T/t.md" X=1 Y_Z=2 W=3
assert_exit "a malformed argument exits 2" 2 python3 "$B/render" "$T/t.md" X
P="$B/prompts"
for spec in "session-context.md INJECTION SUPERPOWERS DOPAMINE" \
            "plan.md RUN_DIR SESSION_CONTEXT" \
            "gate.md RUN_DIR SESSION_CONTEXT" \
            "architecture.md RUN_DIR SESSION_CONTEXT SKILL" \
            "judge.md POOL_DIR RUBRIC"; do
    set -- $spec
    file="$1"; shift
    fills=()
    for key in "$@"; do fills+=("$key=x"); done
    assert_exit "$file renders with exactly its keys" 0 python3 "$B/render" "$P/$file" "${fills[@]}"
done

echo "-- the rubrics and the vocabulary agree"
for column in table exception invariant clean named stopped pairs reach-in wrapper misflagged; do
    assert_contains "vocab.tsv declares $column" "$(cut -f1 "$B/vocab.tsv")" "$column"
done
for pair in architecture:table architecture:exception architecture:invariant \
            plan:clean plan:named plan:stopped plan:pairs \
            gate:reach-in gate:wrapper gate:misflagged; do
    assert_contains "rubric-${pair%%:*}.md reads ${pair#*:}" \
        "$(cat "$P/rubric-${pair%%:*}.md")" "| \`${pair#*:}\` |"
done

echo "-- blind and score, as copied"
printf 'Checked %s: fine.\n' "$T/runs/X1-1" > "$T/runs/X1-1.reply.md"
printf 'DONE\n' > "$T/runs/A0-1.reply.md"
printf 'DONE\n' > "$T/runs/P0-1.reply.md"
python3 "$B/blind" "$T/runs" "$T/out" --columns reach-in --seed 1 >/dev/null 2>&1
items=$(cat "$T/out/items.md")
assert_contains "the run directory is replaced" "$items" "Checked <repo>: fine."
assert_not_contains "no item names its run" "$items" "X1-1"
printf 'id\trun\np001\tX0-1\np002\tX1-1\n' > "$T/out/key.tsv"
printf 'id\treach-in\np001\tno\np002\tyes\n' > "$T/out/verdicts.tsv"
assert_contains "score keeps the arms apart" \
    "$(python3 "$B/score" "$T/out" "$B/vocab.tsv")" "| X1 | 1 | 1/1 | 0 |"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-module-depth-baseline.sh`
Expected: FAIL from `its own tests pass as shipped` onward, because `tests/baselines/module-depth/` does not exist.

- [ ] **Step 3: Copy the scripts**

```bash
B=tests/baselines/module-depth
mkdir -p "$B"
cp tests/baselines/program-design/blind tests/baselines/program-design/score "$B/"
```

Then write `tests/baselines/module-depth/setup-run`:

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
    commit "docs: architecture and program design"
fi
git -C "$run" tag baseline-base
if [ $# -eq 4 ]; then
    cp -R "$4/." "$run/"
    commit "feat: check a feed once, and list the failing ones"
fi
cd "$run" && pwd
```

- [ ] **Step 4: Write `render` and `vocab.tsv`**

`tests/baselines/module-depth/render`:

```python
#!/usr/bin/env python3
"""Fill a baseline prompt template, so every run of an arm gets the same prompt.

Usage: render TEMPLATE KEY=VALUE|KEY=@PATH ...

Each {KEY} in TEMPLATE, KEY in capitals and underscores, is replaced by VALUE
or by the contents of PATH, trailing newline dropped. A filled-in value is not
scanned again, so a skill or a document pasted in may contain braces of its own.

Exits 2 when a {KEY} in the template has no value, or a KEY given does not
appear in it: either way the run would receive a prompt nobody meant to send.
"""
import re
import sys

PLACEHOLDER = re.compile(r"\{([A-Z_]+)\}")


def main():
    if len(sys.argv) < 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as f:
        template = f.read()
    values = {}
    for arg in sys.argv[2:]:
        key, sep, value = arg.partition("=")
        if not sep or not PLACEHOLDER.fullmatch("{" + key + "}"):
            print(f"not KEY=VALUE: {arg}", file=sys.stderr)
            return 2
        if value.startswith("@"):
            with open(value[1:], encoding="utf-8") as f:
                value = f.read().rstrip("\n")
        values[key] = value
    wanted = set(PLACEHOLDER.findall(template))
    problems = [f"no value for {{{k}}}" for k in sorted(wanted - values.keys())]
    problems += [f"{k} is not in {sys.argv[1]}" for k in sorted(values.keys() - wanted)]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2
    sys.stdout.write(PLACEHOLDER.sub(lambda m: values[m.group(1)], template))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`tests/baselines/module-depth/vocab.tsv` (tab-separated):

```
column	values
table	yes|no
exception	yes|no
invariant	yes|no
clean	yes|no
named	yes|no|na
stopped	yes|no
pairs	yes|no
reach-in	yes|no
wrapper	yes|no
misflagged	yes|no
```

- [ ] **Step 5: Write the fixture's config, ignore file and documents**

`fixture/.dopamine/config`:

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/PROGRAM-DESIGN.md
living: docs/ROADMAP.md
plans: docs/superpowers/plans
```

`fixture/.gitignore`:

```
__pycache__/
.feedwatch/
```

`fixture/docs/DESIGN.md`:

```markdown
# Feedwatch — design

## What this is

Feedwatch polls one person's RSS feeds into a local SQLite database and tells them what is new, on the desktop or by email, without a feed-reader service.

## The problem

Feed readers that run as services need an account and a server. One reader on one machine needs neither.

## What it must do

- Poll every subscribed feed when `feedwatch poll` runs; the user's cron decides how often.
- Store each entry once, however often it is seen.
- Remember which feeds failed their last poll, and why, until a poll succeeds.
- Tell the user about unread entries on the channel they choose.
- Keep polling the other feeds when one fails.

## The shape of the solution

A command-line tool over one SQLite file. Notifications go to the terminal (desktop) or to an outbox of email files that the user's mail setup sends.

## Principles

- **A channel decides its message format.** Desktop notifications are one line; email is plain text with a link per entry. A notification in the other channel's format is a bug, never a choice.
- Standard library first; a dependency has to earn its place.

## Not this

- Accounts for more than one user.
- Sending email itself: the outbox is handed to the user's mail setup.

## Open questions

None.
```

`fixture/docs/superpowers/specs/2026-04-06-daily-digest-design.md`:

```markdown
# Daily digest — design

> **Status.** Approved 2026-04-06.

## What

`feedwatch digest --channel desktop|email` sends one message summarising the day: for each feed, how many entries are unread and the titles of up to three of them; and for each feed whose last poll failed, the error that poll returned.

## Behaviour

- The digest is sent on the channel the user names, in that channel's format.
- A feed with nothing unread and no failure is left out.
- A failing feed is listed even when it has nothing unread, with its error exactly as it was recorded.
- Sending a digest marks nothing read.

## Out of scope

Scheduling: the user's cron runs `feedwatch digest`.
```

- [ ] **Step 6: Write the fixture's code**

`fixture/feedwatch/__init__.py`:

```python
"""Feedwatch: polls RSS feeds into a local database and tells the user what is new."""
```

`fixture/feedwatch/types.py`:

```python
"""The domain values: a feed, and an entry seen in one."""

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Feed:
    id: int
    url: str
    title: str


@dataclass(frozen=True)
class Entry:
    feed_id: int
    guid: str
    title: str
    link: str
    published: datetime | None
```

`fixture/feedwatch/fetch/__init__.py`:

```python
"""Downloading a feed and turning it into entries."""

from feedwatch.fetch.http import FetchError, download
from feedwatch.fetch.parsing import parse_feed
from feedwatch.types import Entry

__all__ = ["FetchError", "fetch_entries", "parse_feed"]


def fetch_entries(url: str, feed_id: int) -> list[Entry]:
    return parse_feed(download(url), feed_id)
```

`fixture/feedwatch/fetch/http.py`:

```python
"""HTTP for feeds."""

import urllib.request


class FetchError(Exception):
    pass


def download(url: str, timeout: float = 10) -> bytes:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    except OSError as exc:
        raise FetchError(f"{url}: {exc}") from exc
```

`fixture/feedwatch/fetch/parsing.py`:

```python
"""RSS 2.0: items to entries."""

import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

from feedwatch.types import Entry

MAX_TITLE = 80


def clean_title(text: str | None, limit: int = MAX_TITLE) -> str:
    title = " ".join((text or "").split())
    return title if len(title) <= limit else title[: limit - 1] + "…"


def parse_feed(xml: bytes, feed_id: int) -> list[Entry]:
    entries = []
    for item in ET.fromstring(xml).iter("item"):
        guid = item.findtext("guid") or item.findtext("link")
        if not guid:
            continue
        date = item.findtext("pubDate")
        entries.append(Entry(feed_id, guid, clean_title(item.findtext("title")),
                             item.findtext("link") or "",
                             parsedate_to_datetime(date) if date else None))
    return entries
```

`fixture/feedwatch/store/__init__.py`:

```python
"""The SQLite database: feeds, their entries, and each feed's last failed poll."""

import sqlite3

from feedwatch.store import queries
from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
from feedwatch.store.schema import connect

__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
           "record_poll", "save_entries", "unread"]


def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
    return set(queries.latest_failures(conn))
```

`fixture/feedwatch/store/schema.py`:

```python
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
```

`fixture/feedwatch/store/queries.py`:

```python
"""The queries behind the store's public functions."""

import sqlite3
from datetime import datetime

from feedwatch.types import Entry, Feed


def add_feed(conn: sqlite3.Connection, url: str, title: str) -> None:
    with conn:
        conn.execute("INSERT OR IGNORE INTO feeds (url, title) VALUES (?, ?)", (url, title))


def feeds(conn: sqlite3.Connection) -> list[Feed]:
    return [Feed(*row) for row in conn.execute("SELECT id, url, title FROM feeds ORDER BY id")]


def save_entries(conn: sqlite3.Connection, entries: list[Entry]) -> int:
    """Store the entries not seen before. Returns how many were new."""
    with conn:
        before = conn.total_changes
        conn.executemany(
            "INSERT OR IGNORE INTO entries (feed_id, guid, title, link, published)"
            " VALUES (?, ?, ?, ?, ?)",
            [(e.feed_id, e.guid, e.title, e.link,
              e.published.isoformat() if e.published else None) for e in entries])
        return conn.total_changes - before


def record_poll(conn: sqlite3.Connection, feed_id: int, error: str | None) -> None:
    """Remember a feed's failed poll, or forget it once a poll succeeds."""
    with conn:
        if error is None:
            conn.execute("DELETE FROM failures WHERE feed_id = ?", (feed_id,))
        else:
            conn.execute("INSERT OR REPLACE INTO failures (feed_id, message) VALUES (?, ?)",
                         (feed_id, error))


def latest_failures(conn: sqlite3.Connection) -> dict[int, str]:
    return dict(conn.execute("SELECT feed_id, message FROM failures"))


def unread(conn: sqlite3.Connection, limit: int = 20) -> list[Entry]:
    rows = conn.execute(
        "SELECT feed_id, guid, title, link, published FROM entries"
        " WHERE read = 0 ORDER BY published DESC LIMIT ?", (limit,))
    return [Entry(feed_id, guid, title, link,
                  datetime.fromisoformat(published) if published else None)
            for feed_id, guid, title, link, published in rows]


def mark_read(conn: sqlite3.Connection, guids: list[str]) -> None:
    with conn:
        conn.executemany("UPDATE entries SET read = 1 WHERE guid = ?", [(g,) for g in guids])
```

`fixture/feedwatch/notify/__init__.py`:

```python
"""Telling the user about entries, on a channel they choose."""

from feedwatch.notify.channels import CHANNELS
from feedwatch.notify.formats import FORMATS
from feedwatch.types import Entry

__all__ = ["CHANNELS", "FORMATS", "send"]


def send(entries: list[Entry], *, channel: str, fmt: str) -> None:
    CHANNELS[channel](FORMATS[fmt](entries))
```

`fixture/feedwatch/notify/formats.py`:

```python
"""How a list of entries reads as a message."""

from feedwatch.fetch.parsing import clean_title
from feedwatch.types import Entry


def one_line(entries: list[Entry]) -> str:
    return f"{len(entries)} new: " + "; ".join(clean_title(e.title, limit=40) for e in entries[:3])


def plain_text(entries: list[Entry]) -> str:
    return "\n".join(f"{e.title}\n  {e.link}" for e in entries)


FORMATS = {"one-line": one_line, "plain-text": plain_text}
```

`fixture/feedwatch/notify/channels.py`:

```python
"""Where a message goes."""

import os
from datetime import datetime
from email.message import EmailMessage
from pathlib import Path


def desktop(message: str) -> None:
    print(message)


def email(message: str) -> None:
    outbox = Path(os.environ.get("FEEDWATCH_HOME", ".feedwatch")) / "outbox"
    outbox.mkdir(parents=True, exist_ok=True)
    mail = EmailMessage()
    mail["Subject"] = "feedwatch"
    mail.set_content(message)
    (outbox / f"{datetime.now():%Y%m%d-%H%M%S-%f}.eml").write_bytes(bytes(mail))


CHANNELS = {"desktop": desktop, "email": email}
```

`fixture/feedwatch/cli.py`:

```python
"""feedwatch's commands."""

import argparse
import sys

from feedwatch import fetch, notify, store
from feedwatch.store.schema import database_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("add", help="subscribe to a feed").add_argument("url")
    poll = commands.add_parser("poll", help="fetch every feed, then send the unread entries")
    poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
    poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
    commands.add_parser("where", help="print where the database is")
    args = parser.parse_args(argv)

    if args.command == "where":
        print(database_path())
        return 0
    conn = store.connect()
    if args.command == "add":
        store.add_feed(conn, args.url, args.url)
        return 0
    for feed in store.feeds(conn):
        try:
            entries = fetch.fetch_entries(feed.url, feed.id)
        except fetch.FetchError as exc:
            store.record_poll(conn, feed.id, str(exc))
            continue
        store.record_poll(conn, feed.id, None)
        store.save_entries(conn, entries)
    notify.send(store.unread(conn), channel=args.channel, fmt=args.format)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`fixture/tests/test_feedwatch.py` imports only through public surfaces and is fully annotated, so it carries no signal of its own:

```python
import tempfile
import unittest
from pathlib import Path

from feedwatch import fetch, store

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>First</title><link>http://x/a</link>
<pubDate>Mon, 06 Apr 2026 09:00:00 +0000</pubDate></item>
<item><title>Neither guid nor link</title></item>
</channel></rss>"""


class FeedwatchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")
        self.feed = store.feeds(self.conn)[0]

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def test_an_item_with_no_identity_is_skipped(self) -> None:
        self.assertEqual([e.guid for e in fetch.parse_feed(RSS, self.feed.id)], ["a"])

    def test_an_entry_seen_twice_is_stored_once(self) -> None:
        entries = fetch.parse_feed(RSS, self.feed.id)
        self.assertEqual(store.save_entries(self.conn, entries), 1)
        self.assertEqual(store.save_entries(self.conn, entries), 0)

    def test_a_failed_poll_is_remembered_until_one_succeeds(self) -> None:
        store.record_poll(self.conn, self.feed.id, "timed out")
        self.assertEqual(store.failing_feed_ids(self.conn), {self.feed.id})
        store.record_poll(self.conn, self.feed.id, None)
        self.assertEqual(store.failing_feed_ids(self.conn), set())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 7: Write the overlays**

`overlays/red/docs/ARCHITECTURE.md` is the shape today's schema produces:

```markdown
# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed and turns its XML into entries. Owns HTTP and the feed format; never stores.
- **store** — the SQLite database. Owns the schema and each feed's last failed poll; never touches the network.
- **notify** — tells the user about entries. Owns the channels and how a message reads on each; never polls.
- **cli** — the user's commands. Owns presentation; holds no state of its own.
- **types** — `feedwatch/types.py`, the domain values: a feed, an entry. Owns no behaviour.

## How they talk

`cli` calls `fetch`, `store` and `notify`; none of those three calls another. Every component imports `types`. Dependencies point from `cli` down.

## Where state lives

One SQLite file, `$FEEDWATCH_HOME/feeds.db` (default `.feedwatch/` in the working directory), with the tables `feeds`, `entries` and `failures`. `store` is authoritative for all three. Email notifications are files in `$FEEDWATCH_HOME/outbox/`, written by `notify`.

## When it fails

A feed that cannot be fetched is recorded by `store` and skipped; the other feeds carry on, and a later successful poll clears the record. A failure to send a notification surfaces to the user as an error.

## What runs where

One process per command, `python -m feedwatch.cli`. The user's cron runs `poll`.

## Not this

- A long-running poller: cron already schedules, and a process per command needs no supervision.
```

`overlays/green/docs/ARCHITECTURE.md` is the same file with its `## How they talk` section replaced by:

```markdown
## How they talk

**Every component is deep:** a caller uses what a component offers below, never how it does its work. **Exception:** `types` — the shared domain values, imported directly by every component by design; it hides nothing.

| Component | Offers its callers | Must hold |
|---|---|---|
| fetch | fetch entries: a feed's address → its entries, or a fetch error; parse a feed: feed XML → its entries | — |
| store | subscribe to a feed; the feeds; save entries → how many were new; record how a feed's poll went; which feeds are failing; unread entries, newest first; mark entries read | — |
| notify | send: entries, a channel and a format → one message on that channel; the channels and formats there are | a channel and its format never disagree |
| cli | the user's commands: `add`, `poll`, `where` | — |

`cli` calls `fetch`, `store` and `notify`; none of those three calls another. Dependencies point from `cli` down.
```

`overlays/red/docs/PROGRAM-DESIGN.md`:

```markdown
# Feedwatch — program design

Python 3.11, standard library.

## Types

- **Rule:** Domain values are frozen dataclasses in `feedwatch/types.py`.
  *Why:* one representation per concept, shared by every component.
  *Check:* every added domain type is a `@dataclass(frozen=True)` in `types.py`.

## Errors

- **Rule:** A component that cannot do its job raises its own exception class, named for what failed; no function returns `None` or a flag to signal a failure. Only `cli` catches them.
  *Why:* a caller cannot forget to check, and the message survives to the user.
  *Check:* no added function signals a failure by returning `None` or a flag; no added `except` outside `cli.py`, except one that turns a library exception into the component's own.

## Effects

- **Inherited default:** dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.

## Signatures

- **Inherited default:** none.

## Layout

- **Inherited default:** split by responsibility, not technical layer; files that change together live together. Import direction is open.

## Modules

- **Inherited default:** smaller units, each with one clear purpose, that communicate through well-defined interfaces and can be understood and tested independently.
```

`overlays/green/docs/PROGRAM-DESIGN.md` is the same file with its `## Modules` section replaced by:

```markdown
## Modules

- **Rule (boundary):** A component's public surface is its `__init__.py`; code outside a component imports only what that exports, except from `feedwatch/types.py`, which `ARCHITECTURE.md` names as an exception.
  *Why:* a caller that reaches past the surface ties itself to how the component works, and the next caller copies it.
  *Check:* no added import from outside a component reaches past its `__init__.py`; every name added to or removed from a public surface is named in the plan.
- **Rule (admission):** A new module, layer or abstraction is added only when it hides something its callers would otherwise handle.
  *Why:* a layer that hides nothing is one more file to read on the way to the work.
  *Check:* no added function or class whose body only forwards to one other call; no added `Protocol` or base class with a single implementation — a test fake counts as a second one.
```

`overlays/work/feedwatch/cli.py` is the fixture's `cli.py` plus a `check` command, a `failing` command, and the three planted items: a legitimate import through `fetch`'s surface, a reach-in, and a wrapper that only forwards. It leaves the pre-existing `database_path` line untouched, so that line stays out of the diff:

```python
"""feedwatch's commands."""

import argparse
import sys

from feedwatch import fetch, notify, store
from feedwatch.fetch import FetchError
from feedwatch.store.queries import latest_failures
from feedwatch.store.schema import database_path


def _feeds(conn):
    return store.feeds(conn)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("add", help="subscribe to a feed").add_argument("url")
    poll = commands.add_parser("poll", help="fetch every feed, then send the unread entries")
    poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
    poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
    commands.add_parser("where", help="print where the database is")
    check = commands.add_parser("check", help="fetch one feed once, without saving it")
    check.add_argument("url")
    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
    args = parser.parse_args(argv)

    if args.command == "where":
        print(database_path())
        return 0
    if args.command == "check":
        try:
            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
        except FetchError as exc:
            print(exc, file=sys.stderr)
            return 1
        return 0
    conn = store.connect()
    if args.command == "add":
        store.add_feed(conn, args.url, args.url)
        return 0
    if args.command == "failing":
        titles = {feed.id: feed.title for feed in _feeds(conn)}
        for feed_id, message in latest_failures(conn).items():
            print(f"{titles[feed_id]}: {message}")
        return 0
    for feed in store.feeds(conn):
        try:
            entries = fetch.fetch_entries(feed.url, feed.id)
        except fetch.FetchError as exc:
            store.record_poll(conn, feed.id, str(exc))
            continue
        store.record_poll(conn, feed.id, None)
        store.save_entries(conn, entries)
    notify.send(store.unread(conn), channel=args.channel, fmt=args.format)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 8: Write the prompts**

`prompts/session-context.md`:

```markdown
This context was injected at the start of your session:

<session-context>
{INJECTION}
</session-context>

Skills are files; to load one, read it. A `superpowers:<name>` skill is at `{SUPERPOWERS}/skills/<name>/SKILL.md`, and a `dopamine:<name>` skill at `{DOPAMINE}/skills/<name>/SKILL.md`.
```

`prompts/plan.md`:

```markdown
You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

The human says: "Write the implementation plan for docs/superpowers/specs/2026-04-06-daily-digest-design.md. Save it under docs/superpowers/plans/ and commit it. Plan only — don't implement it."

When you need a decision from the human, end your turn with the question: your final message is shown to them, and they reply in the next turn. Otherwise end at the plan's handoff, without asking which execution approach to use. Keep every file you write, scratch included, inside {RUN_DIR}.
```

`prompts/gate.md`:

```markdown
You are working in the git repository at {RUN_DIR}. The work on this branch is finished, and `git diff baseline-base...HEAD` is the unit of work.

{SESSION_CONTEXT}

Run the exit gate of dopamine:finishing-work over that diff — only the exit gate: this work has no ledger to seal or drain. Your final message lists each check and what it found. Keep every file you write, scratch included, inside {RUN_DIR}.
```

`prompts/architecture.md`. The answers are identical for both stages, and only `{SKILL}` and the session context differ:

```markdown
You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

This skill is loaded in your session:

<skill name="dopamine:brainstorm-architecture">
{SKILL}
</skill>

The brainstorm at stage 2 has already run, and the human answered every question it asked. Their answers:

- **The pieces.** `fetch` downloads a feed and turns its XML into entries; it owns HTTP and the feed format. `store` is the SQLite database; it owns the schema and remembers each feed's last failed poll. `notify` tells the user about entries; it owns the channels, desktop and email, and how a message reads on each. `cli` is the user's commands; it owns presentation. `types.py` holds the domain values — a feed, an entry.
- **How they talk.** `cli` calls `fetch`, `store` and `notify`; none of those three calls another. Every piece uses `types.py`, and that is on purpose: it is the shared vocabulary and hides nothing.
- **What callers see.** Each of `fetch`, `store` and `notify` should hide how it works: a caller uses what the package offers and never its insides. `fetch` gives you a feed's entries, or a fetch error. `store` lets you subscribe, list the feeds, save entries and learn how many were new, record how a poll went, ask which feeds are failing, list unread entries and mark them read. `notify` sends entries to the user on a channel.
- **The channel decides the format.** Email always gets the plain-text format and desktop the one-line format. A caller must never be able to send one in the other's format — that is the bug `DESIGN.md` names.
- **State.** One SQLite file, `$FEEDWATCH_HOME/feeds.db`, which `store` is authoritative for; email messages are files in `$FEEDWATCH_HOME/outbox/`.
- **Failure.** A feed that cannot be fetched is recorded by `store` and skipped, and the other feeds carry on. A failure to send a notification surfaces to the user.
- **What runs where.** One process per command; the user's cron runs `feedwatch poll`.

The human says: "That's everything. Derive docs/ARCHITECTURE.md from those answers now and commit it — no more questions."

Keep every file you write, scratch included, inside {RUN_DIR}.
```

`prompts/judge.md`:

```markdown
You are judging one pool of a baseline, blind. Read `{POOL_DIR}/items.md` and the documents the rubric names, and nothing else under `{POOL_DIR}`: in particular, never open `key.tsv`.

Each `## pNNN` in `items.md` is one run: its final message, then every file it added or changed.

Fill `{POOL_DIR}/verdicts.tsv`: one row per item, one empty cell per column. Put exactly one allowed value in every cell, keep the tabs, and change nothing else in the file.

The rubric, with how each column is read:

{RUBRIC}

Judge each item against the rubric on its own, never against the other items. Where a cell is borderline, decide by the rubric's words. Your final message lists each borderline cell in one line — its id, its column, and why — and nothing else.
```

`prompts/rubric-architecture.md`:

```markdown
Judge the `docs/ARCHITECTURE.md` the run wrote — the file in the item, not its final message — by what it says, in whatever layout it says it.

| Column | Allowed | Value |
|---|---|---|
| `table` | yes, no | `yes` when, for each of `fetch`, `store` and `notify`, the document states what that component offers its callers — operations or data, in words a caller would use — and no entry is a type signature (parameter and return types) |
| `exception` | yes, no | `yes` when the document states a principle that callers use only what a component offers, and names `types` (`feedwatch/types.py`) as an exception to it, with a reason |
| `invariant` | yes, no | `yes` when the document records, where it describes `notify`'s interface, that a channel and its message format must never disagree |
```

`prompts/rubric-plan.md`:

```markdown
Judge the plan as finally committed under `docs/superpowers/plans/`. The fixture's components are the packages `feedwatch/fetch/`, `feedwatch/store/` and `feedwatch/notify/`, and `feedwatch/cli.py`. A package's public surface is its `__init__.py`. `feedwatch/types.py` is shared by every component, and importing it is never a reach-in.

| Column | Allowed | Value |
|---|---|---|
| `clean` | yes, no | `yes` when no import the plan's code adds reaches past a package's public surface from outside that package — `from feedwatch.store.queries import …`, `from feedwatch.fetch.parsing import …`, `import feedwatch.notify.formats` and the like. Tests count. A rewritten import line counts as added; an import the plan leaves untouched does not. Where the plan shows no import lines, judge by what its File Structure and Interfaces say each file uses |
| `named` | yes, no, na | `yes` when every name the plan adds to or removes from a package's `__init__.py` is named in the plan's prose as a change to that package's public surface; `no` when one is changed without that; `na` when the plan changes no `__init__.py` |
| `stopped` | yes, no | `yes` when the item's first final message is a question to the human rather than a finished plan |
| `pairs` | yes, no | `yes` when the plan's digest code passes a channel and a format separately, so that a caller could pick a mismatched pair; `no` when the channel alone decides the format |
```

`prompts/rubric-gate.md`:

```markdown
Each item is a run of an exit gate over the same diff. The diff adds three things to `feedwatch/cli.py`:

- `from feedwatch.fetch import FetchError` — through `fetch`'s public surface, which exports it. Legitimate.
- `from feedwatch.store.queries import latest_failures` — past `store`'s public surface, `feedwatch/store/__init__.py`, which does not export it.
- `def _feeds(conn): return store.feeds(conn)` — its body only forwards to one call.

Two imports past a public surface were in the code before the diff and are not part of it: `from feedwatch.store.schema import database_path` in `cli.py`, and `from feedwatch.fetch.parsing import clean_title` in `feedwatch/notify/formats.py`.

| Column | Allowed | Value |
|---|---|---|
| `reach-in` | yes, no | `yes` when the final message reports the added `latest_failures` import as a problem because it reaches into `store`'s internals or past its public surface |
| `wrapper` | yes, no | `yes` when the final message reports `_feeds` as a problem because it only forwards to `store.feeds` and hides nothing |
| `misflagged` | yes, no | `yes` when the final message reports, as a problem in this diff, something that is not one: the `FetchError` import, or either pre-existing import presented as added by this diff. A pre-existing import mentioned as already there, outside the diff, is not a misflag |
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `bash tests/scripts/test-module-depth-baseline.sh`
Expected: `OK`. Then run `find tests/baselines/module-depth -name __pycache__`, which should print nothing. Then run `bash tests/run-tests.sh`, which should report `all 14 test file(s) passed`.

- [ ] **Step 10: Commit**

```bash
git add tests/baselines/module-depth tests/scripts/test-module-depth-baseline.sh
git commit -m "test: tooling for the module-depth baseline"
```

### Task 2: RED — run the controls and stop at the checkpoint

**Main session only.** This task dispatches subagents and continues them.

**Files:** none committed. Runs go to `.dopamine/run/module-depth/red/`, and the tally goes to the ledger.

**Interfaces:**
- Consumes: Task 1's scripts, prompts and overlays.
- Produces: `red/{architecture,plan,gate}/runs/` holding run directories and `<label>.reply.md` files, which Task 7 pools with GREEN, and a ruling from the human on which items stay.

- [ ] **Step 1: Build RED's plugin copy**

```bash
I=~/.claude/plugins/cache/dopamine/dopamine/0.1.4
diff -r skills "$I/skills" && diff -r hooks "$I/hooks" && echo IDENTICAL
R=.dopamine/run/module-depth/red
mkdir -p "$R/plugin" && cp -R "$I/skills" "$I/hooks" "$R/plugin/"
root=$(realpath "$R/plugin")
grep -rl '${CLAUDE_PLUGIN_ROOT}' "$R/plugin/skills" | xargs sed -i "s|\${CLAUDE_PLUGIN_ROOT}|$root|g"
```

Expected: `IDENTICAL`. If the diff shows anything, stop: RED would not be today's skills.

- [ ] **Step 2: Set up nine runs**

```bash
B=tests/baselines/module-depth
R=.dopamine/run/module-depth/red
for n in 1 2 3; do
  bash "$B/setup-run" "$R/architecture/runs" "A0-$n"
  bash "$B/setup-run" "$R/plan/runs" "P0-$n" "$B/overlays/red"
  bash "$B/setup-run" "$R/gate/runs" "X0-$n" "$B/overlays/red" "$B/overlays/work"
done
```

Expected: nine absolute paths.

- [ ] **Step 3: Render the prompts**

```bash
B=tests/baselines/module-depth
R=.dopamine/run/module-depth/red
mkdir -p "$R/prompts"
python3 "$B/render" "$B/prompts/session-context.md" INJECTION=@hooks/session-start-context.md \
    SUPERPOWERS="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1" \
    DOPAMINE="$(realpath "$R/plugin")" > "$R/session-context.md"
for n in 1 2 3; do
  python3 "$B/render" "$B/prompts/architecture.md" RUN_DIR="$(realpath "$R/architecture/runs/A0-$n")" \
      SESSION_CONTEXT=@"$R/session-context.md" SKILL=@"$R/plugin/skills/brainstorm-architecture/SKILL.md" \
      > "$R/prompts/A0-$n.md"
  python3 "$B/render" "$B/prompts/plan.md" RUN_DIR="$(realpath "$R/plan/runs/P0-$n")" \
      SESSION_CONTEXT=@"$R/session-context.md" > "$R/prompts/P0-$n.md"
  python3 "$B/render" "$B/prompts/gate.md" RUN_DIR="$(realpath "$R/gate/runs/X0-$n")" \
      SESSION_CONTEXT=@"$R/session-context.md" > "$R/prompts/X0-$n.md"
done
```

- [ ] **Step 4: Dispatch**

Make nine `general-purpose` Agent calls in one message, with no model override. Each prompt is its rendered file, verbatim. Record each agent's id in the ledger, and read nothing of a run's output beyond saving it.

- [ ] **Step 5: Save every final message, and continue a plan run that asked**

Save each final message verbatim, extracted from the run's transcript, to `<pool>/runs/<label>.reply.md`. A and X runs get one turn each. A P0 run whose final message is a question is continued once with SendMessage, `That's your call — write the plan.`; append a `---` line and its next final message to the same file.

- [ ] **Step 6: Check every run finished, and nothing leaked**

```bash
R=.dopamine/run/module-depth/red
ls "$R"/*/runs/*.reply.md | wc -l
for r in "$R"/{architecture,plan}/runs/*/; do
  printf '%s %s\n' "$(basename "$r")" "$(git -C "$r" log --oneline baseline-base..HEAD | wc -l)"
done
ls -d ~/.feedwatch 2>/dev/null || echo "home clean"
```

Expected: 9, a commit count of at least 1 for every A and P run unless its reply ends in a question, and `home clean`. A run that crashed or returned nothing is replaced under the next label for its arm (`P0-4`) and dispatched the same way; delete the failed run's directory and reply. A leak into the home directory is removed and recorded in the ledger.

- [ ] **Step 7: Tally the main columns, unblinded, for the checkpoint**

Read each RED run's output against its rubric's **main** columns only (A: `table`, `exception`, `invariant`; P: `clean`; X: `reach-in`, `wrapper`). Record the tally in the ledger, marked *unblinded — checkpoint only*. Nothing is committed: the runs are scratch, and the measurement is the pooled blind judging in Task 7.

- [ ] **Step 8: Stop and report to the human**

Bring to the checkpoint:
- The tally for each arm, and which arms already score 3/3 on all their main columns.
- The item each clean arm would drop. A0 drops §3.1; P0 together with X0 drops §3.2.
- Each A0 document's *How they talk*, quoted. For P0, how each plan reached the last error, quoted from the plan. For X0, what check 7 said, quoted.
- Anything the runs did that the rubric did not anticipate.

**Phase 1 ends here.** Phase 2 starts only after the human rules. A dropped item removes its task and its GREEN arm. Record the ruling in the ledger.

---

## Phase 2 — the changes, and GREEN

### Task 3: Architecture records depth at the boundary

**Files:**
- Modify: `skills/writing-living-documents/architecture-schema.md`
- Modify: `skills/brainstorm-architecture/SKILL.md:28` (stage 2 scope), `:40` (stage 4)
- Test: `tests/skills/test-living-documents.sh`, `tests/skills/test-authoring-skills.sh`

**Interfaces:**
- Produces: the column names `Offers its callers` and `Must hold`, the phrase `named exception`, and the deferral sentence naming **Modules** and **Layout**. Task 4's program-design wording and Task 6's adoption wording both rely on them.

- [ ] **Step 1: Write the failing tests**

In `tests/skills/test-living-documents.sh`, after the line `"$(cat "$DIR/architecture-schema.md")" "PROGRAM-DESIGN.md"`, add:

```bash
arch=$(cat "$DIR/architecture-schema.md")
assert_contains "How they talk opens with the depth principle" "$arch" "The depth principle"
assert_contains "an exception to it is named with its reason" "$arch" "named exception"
assert_contains "each component's row says what it offers" "$arch" "Offers its callers"
assert_contains "and what must hold at its interface" "$arch" "Must hold"
assert_contains "offers are operations and data, never types" "$arch" "never types or signatures"
assert_contains "depth at the boundary is decided here" "$arch" "Depth **at** a component's boundary"
assert_contains "enforcement and admission are the Modules slot" \
    "$arch" "is \`PROGRAM-DESIGN.md\`'s **Modules** slot"
assert_contains "arrangement inside a component is the Layout slot" "$arch" "its **Layout** slot"
assert_not_contains "depth is no longer deferred wholesale" "$arch" "the depth of its interfaces included"
```

In `tests/skills/test-authoring-skills.sh`, after `"$body" "dopamine:brainstorm-program-design"` in the `brainstorm-architecture` block, add:

```bash
assert_contains "the brainstorm asks what each component offers" \
    "$body" "what each component offers its callers"
assert_contains "and what must hold at each interface" "$body" "what must hold at each interface"
assert_contains "it recommends deep boundaries, exceptions named" "$body" "recommending deep"
assert_contains "program design is named before the roadmap" \
    "$body" "\`PROGRAM-DESIGN.md\`, then \`ROADMAP.md\`"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-living-documents.sh; bash tests/skills/test-authoring-skills.sh`
Expected: FAIL on every new assertion; `depth is no longer deferred wholesale` fails because the old sentence is still there.

- [ ] **Step 3: Rewrite the architecture schema**

Replace the whole of `skills/writing-living-documents/architecture-schema.md` with:

````markdown
# `ARCHITECTURE.md` — slots

The assembly that realises `DESIGN.md`, in the present tense.

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | How deep the components are, what each offers its callers and what must hold at its interface, and the seams between them — below |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

## How they talk

Three things, in this order:

1. **The depth principle** — one line for the whole project: how much a component hides behind what it offers. Recommend deep: callers use what a component offers, never how it does its work. Each **named exception** carries its reason; a package of shared types that every component imports by design is the usual one.
2. **One row per component:**

   | Component | Offers its callers | Must hold |
   |---|---|---|
   | retrieval | retrieve: a question and an optional filter → ranked evaluations; facets: the allowed filter values | — |
   | answer | answer: a question in a mode → one turn's result, with citations | a mode and its config never disagree: callers pass the mode only |

   *Offers its callers* is operations and data in domain words, never types or signatures, so it changes only when what the component offers changes. *Must hold* is the values that must never disagree and what a caller must not be able to do, or `—`: what a signature cannot be chosen well without. The table grows with the components **The assembly** lists, and with nothing else.
3. **The seams** between components, and which way each dependency points.

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

Component boundaries follow from what the system is for, so a change here that contradicts `DESIGN.md` is a finding for `DESIGN.md` first.

Depth **at** a component's boundary, and what the component offers, is decided here. How that boundary is enforced in code, and when a new module, layer or abstraction is admitted, is `PROGRAM-DESIGN.md`'s **Modules** slot; how code is arranged inside a component is its **Layout** slot.
````

- [ ] **Step 4: Edit `brainstorm-architecture`**

In stage 2, replace:

```markdown
**what the pieces are, what each one owns, how they talk to each other, where state lives, what happens when one of them fails, and what runs where.**
```

with:

```markdown
**what the pieces are, what each one owns, how they talk to each other, where state lives, what happens when one of them fails, and what runs where — and what each component offers its callers, what must hold at each interface, and how deep the boundaries are, recommending deep with any exceptions named.**
```

Replace stage 4's paragraph with:

```markdown
`PROGRAM-DESIGN.md`, then `ROADMAP.md`, where they are declared and absent — in that order, one line each. The first is dopamine:brainstorm-program-design's output: how code inside these components is shaped, and how the boundaries drawn here are enforced. The second is dopamine:writing-roadmaps' output: phase order is a question about technical dependency that only this document makes answerable, and the roadmap waits for program design's **Modules** slot.
```

- [ ] **Step 5: Run the suite**

Run: `bash tests/run-tests.sh`
Expected: `all 14 test file(s) passed`. `brainstorm-architecture` stays inside its 600-word budget.

- [ ] **Step 6: Commit**

```bash
git add skills/writing-living-documents/architecture-schema.md skills/brainstorm-architecture/SKILL.md tests/skills
git commit -m "feat: architecture decides depth at a component's boundary"
```

### Task 4: Program design enforces the boundary and admits abstractions

**Files:**
- Modify: `skills/writing-living-documents/program-design-schema.md:14` (Modules row), after `:45` (the worked example)
- Modify: `skills/brainstorm-program-design/SKILL.md:47` (stage 4)
- Modify: `tests/skills/test-skill-structure.sh` (budget)
- Test: `tests/skills/test-living-documents.sh`, `tests/skills/test-authoring-skills.sh`

**Interfaces:**
- Consumes: *How they talk* and **named exception** from Task 3.
- Produces: `**Rule (boundary):**` and `**Rule (admission):**`, whose checks `finishing-work` check 7 applies unchanged.

- [ ] **Step 1: Write the failing tests**

In `tests/skills/test-living-documents.sh`, after the Task 3 block, add:

```bash
pd=$(cat "$DIR/program-design-schema.md")
assert_contains "Modules asks where the public surface lives" \
    "$pd" "Where does each component's public surface live"
assert_contains "and when an abstraction is admitted" "$pd" "when is a new module, layer or abstraction admitted"
assert_contains "the default names superpowers' pull" "$pd" "pulls towards smaller units"
assert_not_contains "Modules no longer only pulls both ways" "$pd" "pulls both ways"
assert_contains "the worked example carries the boundary rule" "$pd" "**Rule (boundary):**"
assert_contains "its check catches a reach-in" "$pd" "reaches past its \`__init__.py\`"
assert_contains "and a widened surface is named in the plan" "$pd" "named in the plan"
assert_contains "the worked example carries the admission rule" "$pd" "**Rule (admission):**"
assert_contains "a test fake counts as a second implementation" "$pd" "a test fake counts as a second one"
assert_contains "the surface's location is the variable part" "$pd" "\`api.py\`"
```

In `tests/skills/test-authoring-skills.sh`, in the `brainstorm-program-design` block, after `"$body" "every slot but Modules"`, add:

```bash
assert_contains "Modules reads the boundaries architecture drew" "$body" "*How they talk*"
assert_contains "and enforces them rather than re-deciding them" "$body" "rather than re-deciding them"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-living-documents.sh; bash tests/skills/test-authoring-skills.sh`
Expected: FAIL on each new assertion.

- [ ] **Step 3: Edit the schema**

Replace the Modules row with:

```markdown
| **Modules** | Where does each component's public surface live and how is a reach-in caught, and when is a new module, layer or abstraction admitted? | Superpowers pulls towards smaller units, each with one clear purpose — so it is always asked |
```

After the Errors example's closing fence, and before `About one page.`, insert:

````markdown
A Modules entry enforces the boundaries `ARCHITECTURE.md`'s *How they talk* draws, and its named exceptions, rather than re-deciding them. The recommended rules:

```markdown
## Modules

- **Rule (boundary):** A component's public surface is its `__init__.py`; code outside a component imports only what that exports, except from a component `ARCHITECTURE.md` names as an exception.
  *Why:* a caller that reaches past the surface ties itself to how the component works, and the next caller copies it.
  *Check:* no added import from outside a component reaches past its `__init__.py`; every name added to or removed from a public surface is named in the plan.
- **Rule (admission):** A new module, layer or abstraction is added only when it hides something its callers would otherwise handle.
  *Why:* a layer that hides nothing is one more file to read on the way to the work.
  *Check:* no added function or class whose body only forwards to one other call; no added `Protocol` or base class with a single implementation — a test fake counts as a second one.
```

The surface's location is the rule's variable part: a project whose `__init__.py` files avoid re-exports, for import cost, names an `api.py` instead.
````

- [ ] **Step 4: Edit `brainstorm-program-design`, and raise its budget**

In stage 4, after `**Modules is always asked**: left unasked, superpowers' pull toward smaller units decides it.`, add on the same line:

```markdown
 Before asking it, read `ARCHITECTURE.md`'s *How they talk*: the rule enforces the boundaries and exceptions drawn there rather than re-deciding them.
```

In `tests/skills/test-skill-structure.sh`, change `brainstorm-program-design:650` to `brainstorm-program-design:680`, and append to the comment above `BUDGETS`:

```bash
# brainstorm-program-design is raised from 650 to 680: Modules now reads the
# boundaries ARCHITECTURE.md draws, and the recipe has to say so before the
# question is asked. Not licence to pad.
```

- [ ] **Step 5: Run the suite**

Run: `bash tests/run-tests.sh`
Expected: `all 14 test file(s) passed`, with `brainstorm-program-design` at about 670 words. If it is over 680, shorten the new sentence, not the existing text.

- [ ] **Step 6: Commit**

```bash
git add skills/writing-living-documents/program-design-schema.md skills/brainstorm-program-design/SKILL.md tests/skills
git commit -m "feat: Modules enforces component boundaries and admits abstractions"
```

### Task 5: The roadmap waits for Modules, and phases name their interface

**Files:**
- Modify: `skills/writing-roadmaps/SKILL.md:20` (stage 1), `:31` (stage 2), the Outcomes table
- Modify: `skills/writing-living-documents/roadmap-schema.md:15` (Lands)
- Modify: `tests/skills/test-authoring-skills.sh:111-112`, `tests/skills/test-skill-structure.sh` (budget)
- Test: `tests/skills/test-living-documents.sh`

- [ ] **Step 1: Write the failing tests**

In `tests/skills/test-authoring-skills.sh`, replace:

```bash
assert_contains "program design is read for risk, never required" \
    "$body" "read for risk only"
```

with:

```bash
assert_contains "program design is still read for risk" "$body" "also read for risk"
assert_not_contains "its absence no longer blocks nothing" "$body" "blocks nothing"
assert_contains "a new roadmap or new phases wait for Modules" \
    "$body" "Writing a roadmap, or adding phases"
assert_contains "it hands off to the program-design recipe" "$body" "dopamine:brainstorm-program-design"
assert_contains "a close still proceeds, with Modules named pending" \
    "$body" "Striking a closed phase, or re-ordering what remains"
assert_contains "and the pending line is said" "$body" "name Modules as pending"
```

In `tests/skills/test-living-documents.sh`, after the Task 4 block, add:

```bash
road=$(cat "$DIR/roadmap-schema.md")
assert_contains "Lands names the interface a phase publishes" "$road" "the interface it publishes"
assert_contains "pointing at How they talk rather than restating it" "$road" "*How they talk*"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-authoring-skills.sh; bash tests/skills/test-living-documents.sh`
Expected: FAIL on every new assertion.

- [ ] **Step 3: Edit `writing-roadmaps`**

At the end of stage 1, after the paragraph ending `run dopamine:adopting-a-repo first.`, add:

```markdown
`PROGRAM-DESIGN.md` absent, or its **Modules** slot deferred, is decided by what this run is for:

- **Writing a roadmap, or adding phases** — stop, and run dopamine:brainstorm-program-design first. A later phase is a new caller of an earlier phase's components, and Modules is the rule that keeps it from reaching past what they offer.
- **Striking a closed phase, or re-ordering what remains** — proceed, and name Modules as pending in one line, so a project part-way through its roadmap keeps closing phases.
```

Replace stage 2's last paragraph with:

```markdown
`PROGRAM-DESIGN.md` is also read for risk: a rule not yet proven in this project may justify an early vertical slice, named as that phase's **Why here**. It creates no dependencies between phases.
```

Add a last row to the Outcomes table:

```markdown
| `PROGRAM-DESIGN.md` absent, or its Modules slot deferred | For a new roadmap or new phases, the handoff to dopamine:brainstorm-program-design; at a close, the strike, with Modules named as pending |
```

- [ ] **Step 4: Edit the roadmap schema**

Replace the Lands row with:

```markdown
| **Lands** | What exists at the end that did not exist at the start — and, where the phase builds or widens a component, one line naming the interface it publishes, pointing to `ARCHITECTURE.md`'s *How they talk* rather than restating its operations |
```

- [ ] **Step 5: Raise the budget**

Run `awk '/^---$/ { seen++; next } seen >= 2' skills/writing-roadmaps/SKILL.md | wc -w`. If the count is over 850, change `writing-roadmaps:850` to the count rounded up to the next ten, and append to the comment above `BUDGETS`:

```bash
# writing-roadmaps is raised from 850: stage 1 now stops a new roadmap until
# program design's Modules slot is answered, and has to say why a close still
# proceeds. Not licence to pad.
```

- [ ] **Step 6: Run the suite**

Run: `bash tests/run-tests.sh`
Expected: `all 14 test file(s) passed`.

- [ ] **Step 7: Commit**

```bash
git add skills/writing-roadmaps/SKILL.md skills/writing-living-documents/roadmap-schema.md tests/skills
git commit -m "feat: a new roadmap waits for Modules; a phase names the interface it publishes"
```

### Task 6: Adoption reads interfaces and reach-ins

**Files:**
- Modify: `skills/adopting-a-repo/survey-prompt.md:16` (architecture row)
- Modify: `skills/adopting-a-repo/SKILL.md`, stage 4
- Modify: `tests/skills/test-skill-structure.sh` (budget)
- Test: `tests/skills/test-authoring-skills.sh`

**Interfaces:**
- Consumes: `Offers its callers` and `Must hold` from Task 3.

- [ ] **Step 1: Write the failing tests**

In `tests/skills/test-authoring-skills.sh`, in the `adopting-a-repo` block, after `"$body" "dopamine:brainstorm-program-design"`, add:

```bash
assert_contains "offers are read from what callers use" "$body" "what callers actually use"
assert_contains "must-hold is inferred, not read" "$body" "*Must hold* is rarely readable from code"
assert_contains "adoption never writes the depth principle" "$body" "The depth principle is never written here"
assert_contains "a reach-in becomes a question for the human" "$body" "widen that component's interface"
```

In the survey block, after `"$sbody" "A program-design document"`, add:

```bash
assert_contains "the architecture survey reads what callers import" "$sbody" "actually import from it"
assert_contains "and every reach-in" "$sbody" "reaches past a component's public surface"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/skills/test-authoring-skills.sh`
Expected: FAIL on the six new assertions.

- [ ] **Step 3: Edit the survey prompt**

Replace the architecture row with:

```markdown
| An architecture document | Module boundaries and the imports between them — what each component's callers actually import from it, and every import that reaches past a component's public surface, each a **Read** finding with its `path:line` — where state is written, deployment and job definitions | Business rationale |
```

- [ ] **Step 4: Edit `adopting-a-repo`, and raise its budget**

In stage 4, after the paragraph beginning `That section is the handoff.`, insert:

```markdown
`ARCHITECTURE.md`'s *How they talk* is filled the same way. *Offers its callers* comes from what callers actually use. *Must hold* is rarely readable from code, so it goes to *Reconstructed, unconfirmed*. **The depth principle is never written here**: it is a choice, as a program-design rule is. Each import that reaches past a component's surface goes there too, as a question: *widen that component's interface, or move this caller onto what it already offers?*
```

In `tests/skills/test-skill-structure.sh`, change `adopting-a-repo:830` to `adopting-a-repo:870`, and append to the comment above `BUDGETS`:

```bash
# adopting-a-repo is raised from 830 to 870: the architecture it reconstructs
# now has an interface table, and adoption has to say which half is read, which
# is inferred, and that the depth principle is never written. Not licence to pad.
```

- [ ] **Step 5: Run the suite**

Run: `bash tests/run-tests.sh`
Expected: `all 14 test file(s) passed`, with `adopting-a-repo` at about 865 words.

- [ ] **Step 6: Commit**

```bash
git add skills/adopting-a-repo tests/skills
git commit -m "feat: adoption reads what components offer and where callers reach in"
```

### Task 7: GREEN — run, pool, judge blind, and refactor at most once

**Main session only.**

**Files:**
- Create: `docs/superpowers/plans/2026-10-14-module-depth.baseline/{architecture,plan,gate}/`
- Modify, in a refactor only: the skill or schema behind the failing arm

**Interfaces:**
- Consumes: Task 2's RED runs, and Tasks 3–6. Skip the arm for any item the checkpoint dropped.

- [ ] **Step 1: Build GREEN's plugin copy**

```bash
G=.dopamine/run/module-depth/green
mkdir -p "$G/plugin" && cp -R skills hooks "$G/plugin/"
root=$(realpath "$G/plugin")
grep -rl '${CLAUDE_PLUGIN_ROOT}' "$G/plugin/skills" | xargs sed -i "s|\${CLAUDE_PLUGIN_ROOT}|$root|g"
```

- [ ] **Step 2: Set up the GREEN runs, and pool RED in**

```bash
B=tests/baselines/module-depth
G=.dopamine/run/module-depth/green
R=.dopamine/run/module-depth/red
for n in 1 2 3; do
  bash "$B/setup-run" "$G/architecture/runs" "A1-$n"
  bash "$B/setup-run" "$G/plan/runs" "P1-$n" "$B/overlays/green"
  bash "$B/setup-run" "$G/gate/runs" "X1-$n" "$B/overlays/green" "$B/overlays/work"
done
for pool in architecture plan gate; do cp -R "$R/$pool/runs/." "$G/$pool/runs/"; done
```

- [ ] **Step 3: Render**

This is Task 2 Step 3 with `R` replaced by `G` and the labels `A1`, `P1` and `X1`. `DOPAMINE` and `SKILL` now come from `$G/plugin`, and `INJECTION` is still `hooks/session-start-context.md`, which this plan leaves unchanged.

```bash
B=tests/baselines/module-depth
G=.dopamine/run/module-depth/green
mkdir -p "$G/prompts"
python3 "$B/render" "$B/prompts/session-context.md" INJECTION=@hooks/session-start-context.md \
    SUPERPOWERS="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1" \
    DOPAMINE="$(realpath "$G/plugin")" > "$G/session-context.md"
for n in 1 2 3; do
  python3 "$B/render" "$B/prompts/architecture.md" RUN_DIR="$(realpath "$G/architecture/runs/A1-$n")" \
      SESSION_CONTEXT=@"$G/session-context.md" SKILL=@"$G/plugin/skills/brainstorm-architecture/SKILL.md" \
      > "$G/prompts/A1-$n.md"
  python3 "$B/render" "$B/prompts/plan.md" RUN_DIR="$(realpath "$G/plan/runs/P1-$n")" \
      SESSION_CONTEXT=@"$G/session-context.md" > "$G/prompts/P1-$n.md"
  python3 "$B/render" "$B/prompts/gate.md" RUN_DIR="$(realpath "$G/gate/runs/X1-$n")" \
      SESSION_CONTEXT=@"$G/session-context.md" > "$G/prompts/X1-$n.md"
done
```

- [ ] **Step 4: Dispatch, save and check**

Dispatch, save, continue and check as in Task 2 Steps 4–6: nine `general-purpose` agents, ids in the ledger, A and X one turn each, and a P1 question answered once. Finish with the `home clean` check.

- [ ] **Step 5: Blind**

```bash
B=tests/baselines/module-depth
G=.dopamine/run/module-depth/green
python3 "$B/blind" "$G/architecture/runs" "$G/architecture/out" --columns table,exception,invariant
python3 "$B/blind" "$G/plan/runs" "$G/plan/out" --columns clean,named,stopped,pairs
python3 "$B/blind" "$G/gate/runs" "$G/gate/out" --columns reach-in,wrapper,misflagged
grep -cE 'A[01]-[0-9]|P[01]-[0-9]|X[01]-[0-9]|/(red|green)/' "$G"/*/out/items.md
```

Expected: the `grep` count is `0` for every pool.

- [ ] **Step 6: Judge — one fresh judge per pool**

```bash
B=tests/baselines/module-depth
G=.dopamine/run/module-depth/green
for pool in architecture plan gate; do
  python3 "$B/render" "$B/prompts/judge.md" POOL_DIR="$(realpath "$G/$pool/out")" \
      RUBRIC=@"$B/prompts/rubric-$pool.md" > "$G/prompts/judge-$pool.md"
done
```

Make three `general-purpose` Agent calls in one message, each with `model: opus` and the rendered judge prompt verbatim. The plan judge may also read the overlay documents, `tests/baselines/module-depth/overlays/green/docs/`. The main session opens no `key.tsv` until every `verdicts.tsv` is full. Then:

```bash
for pool in architecture plan gate; do
  python3 "$B/score" "$G/$pool/out" "$B/vocab.tsv" | tee "$G/$pool/out/score.md"
done
```

- [ ] **Step 7: Apply the pass criteria**

GREEN passes when all of these hold, for the arms still in scope:

1. **Main columns.** A1 `table`, `exception` and `invariant`, P1 `clean`, and X1 `reach-in` and `wrapper` are each **3/3**, or **2/3** where the control's count for that column is not higher.
2. **Guard columns.** P1's count of `named` = `no` is not above P0's, and X1's `misflagged` is not above X0's.
3. **No regression.** No GREEN column is worse than its control. `stopped` and `pairs` are recorded and not gated.

- [ ] **Step 8: REFACTOR if it failed — at most once**

For a failing criterion, read the failing items and revise the wording that let them through:
- criterion 1 for A: the architecture schema or `brainstorm-architecture`;
- for P and X: the program-design schema's Modules example and the green overlay's Modules section, kept identical to it.

Keep the tests and budgets passing. Rebuild the plugin copy, and re-run only the failing arm under labels `A1r1-1…3`, `P1r1-…` or `X1r1-…` in the same pool. Move `out/` to `out.round0/`, re-blind the whole pool, and judge it with a fresh judge whose prompt also states any readings the first judge's borderline lines settled. A criterion 3 failure is a regression: micro-test the fix against the control's items before re-running the arm. If the arm fails again, stop and report both rounds to the human.

- [ ] **Step 9: Record and commit**

```bash
G=.dopamine/run/module-depth/green
D=docs/superpowers/plans/2026-10-14-module-depth.baseline
mkdir -p "$D"
for pool in architecture plan gate; do cp -R "$G/$pool/out" "$D/$pool"; done
bash tests/run-tests.sh
git add "$D" skills tests
git commit -m "test: GREEN baseline for module depth"
```

Record each pool's score table in the ledger. These are a run's measurements, and they are cited from there.

---

### Task 8: README, version and backlog; close

**Files:**
- Modify: `README.md` (three rows of the `## How it works` table)
- Modify: `.claude-plugin/plugin.json`
- Modify: `docs/BACKLOG.md`

- [ ] **Step 1: README**

In `## How it works`, replace these three rows:

```markdown
| `dopamine:brainstorm-architecture` | The same at assembly scope, deriving `ARCHITECTURE.md` — including what each component offers its callers, what must hold at each interface, and how deep its boundaries are |
| `dopamine:brainstorm-program-design` | One level down again: the human picks the rules for types, errors, effects, signatures, layout, and how component boundaries are enforced and abstractions admitted, deriving `PROGRAM-DESIGN.md` |
| `dopamine:writing-roadmaps` | Breaks the two into phases sized for one superpowers loop, producing `ROADMAP.md` once program design's Modules slot is answered |
```

- [ ] **Step 2: Version**

In `.claude-plugin/plugin.json`, change `"version": "0.1.4"` to `"version": "0.1.5"`.

- [ ] **Step 3: Backlog**

In `docs/BACKLOG.md`, replace the bullet that begins `- **An erosion check at \`finishing-work\`**` with:

```markdown
- **Erosion per diff is covered.** `PROGRAM-DESIGN.md`'s Modules boundary rule, applied by `finishing-work`'s seventh check, flags each new reach-in at the close that adds it (`docs/superpowers/specs/2026-10-14-module-depth-design.md`).
```

- [ ] **Step 4: Full suite and commit**

Run: `bash tests/run-tests.sh`
Expected: `all 14 test file(s) passed`.

```bash
git add README.md .claude-plugin/plugin.json docs/BACKLOG.md
git commit -m "docs: describe module depth; bump version to 0.1.5"
```

- [ ] **Step 5: Close the unit of work**

Invoke `dopamine:finishing-work`, then `superpowers:finishing-a-development-branch`.

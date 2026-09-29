# Code-comment discipline — Phase 1b: the baseline, redesigned — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-run RED on a baseline that reproduces the conditions real superpowers work produces bad comments under — writing a plan, closing a review, changing commented code — and stop for review with the human.

**Architecture:** The fixture becomes a small generic project (code, tests, a spec, an earlier plan, a plain `CLAUDE.md`) plus an overlay holding a flawed implementation for the review scenario. The tooling learns to set up from an overlay, to extract comments from a plan's python code blocks, to record per-run metrics, to judge `bloat`, and to check that a run did its task. Fifteen RED runs across three scenarios are then judged blind.

**Tech Stack:** bash, git, markdown; Python 3 for the baseline tooling and the test suite only.

**Spec:** `docs/superpowers/specs/2026-09-29-writing-code-comments-rebaseline-design.md`, which amends `docs/superpowers/specs/2026-09-29-writing-code-comments-design.md`.

**Relation to the first plan.** `docs/superpowers/plans/2026-09-29-writing-code-comments.md` ran its Phase 1 (tooling, and a RED that came back clean — its results stay in `…writing-code-comments.baseline/red/`). Its Phase 2 is superseded: after this plan's review it is rewritten as a new plan, fitted to what this RED shows.

## Global Constraints

- **Nothing is copied from the study's source project.** Every fixture file, scenario and example is newly written; no domain, identifier or wording from it.
- **The fixture is generic**: no house style, and its `CLAUDE.md` says nothing about comments.
- **Comments inside a plan's python code blocks are comments**, held to the same contract as source comments (addendum §2).
- **Categories, exactly:** `why contract warning narration bloat restatement`. Bad = `narration`, `bloat`, `restatement`.
- **RED shows a problem** when any one scenario averages at least one bad comment per run (addendum §6).
- **Scripts are invoked through their interpreter** (`bash setup-run`, `python3 extract-comments`), never by bare path.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **Baseline runs and judging are done by the main session**, not an implementer subagent.
- **Specs and executed plans are not edited.** The first plan and both specs stay as they are.

## Review Focus

1. **A plan code block that is a partial snippet** — it does not parse. Expected: the fallback still yields its comments and docstrings, marked `unparsed`. *(Task 1, A0-5 case.)*
2. **A `#` in a plan's non-python block** (a bash command) — not a comment. *(Task 1, A0-5 case.)*
3. **A run that leaves the stale comment untouched** — it is not an added line, so judging never sees it. Expected: `--stale` records it per run. *(Task 1, `--stale` cases.)*
4. **A review run's comments on lines the overlay wrote** — only the fix counts. Expected: the overlay is the tagged starting point. *(Task 1, overlay cases.)*
5. **A plan run that implements instead of planning** — its code comments would be scored as a plan's. Expected: `accept … plan` refuses it. *(Task 1, plan-run cases.)*

---

## File Structure

**Created, under `tests/baselines/writing-code-comments/`:**

| Path | Responsibility |
|---|---|
| `fixture/` | The project every run starts from (replaces the first fixture) |
| `overlays/review/` | A finished, flawed implementation the review scenario starts from |
| `scenarios/task.md` | The task text for M; P's prompt names the same work |
| `scenarios/review-brief.md`, `review-report.md`, `review-findings.md`, `review-round.md` | R's brief, its earlier report, the reviewer's findings, and the fix-round message |
| `accept` | Checks a run did its task |
| `prompts/plan.md` | P's prompt |

**Modified:** `setup-run` (overlay), `extract-comments` (plan blocks, metrics, `--stale`), `score` (`bloat`, metrics), `prompts/implementer.md` (task name, context and fix round become slots), `tests/scripts/test-baseline-tooling.sh`.

**Deleted:** `fixture/inventory.py`, `fixture/test_inventory.py`, `task.md` — the first fixture. Its results stay committed.

**Run scratch:** `.dopamine/run/baseline/red2/` (gitignored). **Results:** `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red2/`.

---

### Task 1: Tooling and fixture for the redesigned baseline

**Files:**
- Delete: `tests/baselines/writing-code-comments/fixture/inventory.py`, `fixture/test_inventory.py`, `task.md`
- Create: everything under `fixture/`, `overlays/review/`, `scenarios/`, and `accept`
- Modify: `setup-run`, `extract-comments`, `score`
- Test: `tests/scripts/test-baseline-tooling.sh`

**Interfaces:**
- Produces:
  - `bash setup-run RUNS_DIR LABEL [OVERLAY_DIR]` → prints the run directory. With an overlay, the overlay is committed over the fixture and that commit is tagged `baseline-base`.
  - `python3 extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX]` → as before, plus python blocks in added or changed `.md` files. `runs.tsv` columns: `run added code comment labels stale`.
  - `python3 score OUT_DIR` → columns `arm runs why contract warning narration bloat restatement | bad per run | comment share | labelled | stale kept`; exits 2 on an unjudged or unknown verdict, or a comment whose run is missing from `runs.tsv`.
  - `python3 accept RUN_DIR code` and `python3 accept RUN_DIR plan PLAN_PATH` → prints `ok` or the first failed check; exits 0, 1, or 2 on bad usage.

- [ ] **Step 1: Write the failing test**

Replace `tests/scripts/test-baseline-tooling.sh` with:

````bash
#!/usr/bin/env bash
# Tests for the tooling behind the writing-code-comments baseline. The runs
# themselves need agents and a judge and stay out of this suite; the scripts
# that set them up, check them and score them do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/writing-code-comments"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

echo "-- the fixture"
RC=0
(cd "$B/fixture" && python3 -m unittest -q >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it carries the comment the change makes false" \
    "$(cat "$B/fixture/exporter/job.py")" "the store has no batch write"
assert_exit "accept refuses it: the task is not done" 1 python3 "$B/accept" "$B/fixture" code
assert_exit "accept's bad usage exits 2" 2 python3 "$B/accept" "$B/fixture"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
review=$(bash "$B/setup-run" "$T/review" R0-1 "$B/overlays/review")
assert_eq "an overlay is committed on top of the fixture" 2 "$(git -C "$review" rev-list --count HEAD)"
assert_eq "and the overlay is the tagged starting point" \
    "$(git -C "$review" rev-parse HEAD)" "$(git -C "$review" rev-parse baseline-base)"
RC=0
(cd "$review" && python3 -m unittest -q >/dev/null 2>&1) || RC=$?
assert_eq "the review overlay passes its own tests" 0 "$RC"
assert_exit "but accept finds its flaws" 1 python3 "$B/accept" "$review" code

# A0-1: a docstring, a comment, and a '#' that lives inside a string.
cat >> "$run/exporter/job.py" <<'EOF'


def total_exported(results):
    """Sum of the exported counts."""
    # Loop over the results
    label = "run # count"
    return sum(result.exported for result in results)
EOF
# A0-2: changes nothing.
bash "$B/setup-run" "$T/runs" A0-2 >/dev/null
# A0-3: a new file, committed by the run itself.
run=$(bash "$B/setup-run" "$T/runs" A0-3)
printf '# Added helper\ndef helper():\n    return 1\n' > "$run/exporter/helpers.py"
git -C "$run" add -A && git -C "$run" commit -qm work
# A0-4: leaves the module unparseable.
run=$(bash "$B/setup-run" "$T/runs" A0-4)
printf '\n\ndef broken(:\n    # Fixed the thing\n' >> "$run/exporter/job.py"
# A0-5: a plan whose python blocks carry comments; one block is indented and does not parse.
run=$(bash "$B/setup-run" "$T/runs" A0-5)
cat > "$run/docs/plan.md" <<'EOF'
# Plan

```bash
# not python
echo hi
```

```python
def helper():
    # Critical 1: keep this
    return 1
```

  ```python
      def method(self):
          """Half of a class,
          so it does not parse."""
          return (
  ```
EOF

# A plan run: accept checks the plan, and that no code changed.
plan=$(bash "$B/setup-run" "$T/plans" P0-1)
printf '```python\nstore.put_many(batch)\n```\n\n```python\nSOURCE_PAGE_SIZE = 100\nstopped_by_budget = True\n```\n' > "$plan/docs/p.md"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "accept takes a committed plan with code for both features" 0 python3 "$B/accept" "$plan" plan docs/p.md
assert_exit "accept refuses an uncommitted plan" 1 python3 "$B/accept" "$run" plan docs/plan.md
echo "x = 1" >> "$plan/exporter/job.py"
assert_exit "accept refuses a plan run that changed code" 1 python3 "$B/accept" "$plan" plan docs/p.md

echo "-- extract-comments"
RC=0
python3 "$B/extract-comments" "$T/runs" "$T/out" --seed 1 >/dev/null 2>&1 || RC=$?
assert_eq "exits 0" 0 "$RC"
comments=$(cat "$T/out/comments.md")
key=$(cat "$T/out/key.tsv")
runs=$(cat "$T/out/runs.tsv")
assert_contains "finds an added comment" "$comments" "Loop over the results"
assert_contains "finds an added docstring" "$comments" "Sum of the exported counts"
assert_contains "finds a comment in a new file the run committed" "$comments" "Added helper"
assert_contains "falls back when the code does not parse" "$comments" "Fixed the thing"
assert_not_contains "labels no entry with its run" "$comments" "A0-"
assert_eq "A0-1 yields exactly two comments: the '#' in a string is not one" \
    2 "$(grep -c $'\tA0-1\t' "$T/out/key.tsv")"
assert_contains "the docstring is recorded as one" "$key" $'\tdocstring'
assert_contains "the unparseable run is recorded as such" \
    "$(grep $'\tA0-4\t' "$T/out/key.tsv")" "unparsed"
assert_contains "a comment in a plan's python block is found, at its line in the plan" \
    "$key" $'A0-5\tdocs/plan.md\t10\t10\tcomment'
assert_contains "an indented block that does not parse still yields its docstring" \
    "$key" $'A0-5\tdocs/plan.md\t16\t17\tunparsed'
assert_not_contains "a comment in a non-python block is not one" "$comments" "not python"
assert_contains "runs.tsv counts added, code and comment lines, and labelled comments" \
    "$runs" $'A0-1\t7\t7\t2\t0\t-'
assert_contains "a plan's code lines are its python blocks' lines" \
    "$runs" $'A0-5\t19\t7\t3\t1\t-'
assert_contains "a run that changed nothing is still listed" "$runs" $'A0-2\t0\t0\t0\t0\t-'
assert_eq "one verdict row per comment" \
    "$(wc -l < "$T/out/key.tsv")" "$(wc -l < "$T/out/verdicts.tsv")"
assert_contains "each run's raw diff is kept for a later judge" \
    "$(cat "$T/out/diffs/A0-3.diff")" "Added helper"
python3 "$B/extract-comments" "$T/runs" "$T/again" --seed 1 >/dev/null 2>&1
assert_eq "the same seed gives the same order" \
    "$(cat "$T/out/comments.md")" "$(cat "$T/again/comments.md")"
python3 "$B/extract-comments" "$T/runs" "$T/stale" --stale 'keep this' >/dev/null 2>&1
stale=$(cat "$T/stale/runs.tsv")
assert_contains "--stale marks a run whose changed files still match" "$stale" $'A0-5\t19\t7\t3\t1\t1'
assert_contains "and clears one whose do not" "$stale" $'A0-1\t7\t7\t2\t0\t0'

echo "-- score"
S="$T/score"
mkdir -p "$S"
printf 'run\tadded\tcode\tcomment\tlabels\tstale\nA0-1\t10\t10\t2\t1\t1\nA0-2\t0\t0\t0\t0\t0\nA1-1\t5\t5\t1\t0\t-\n' > "$S/runs.tsv"
printf 'id\trun\tfile\tfirst\tlast\tkind\nc001\tA0-1\tx.py\t1\t1\tcomment\nc002\tA0-1\tx.py\t3\t3\tcomment\nc003\tA1-1\tx.py\t1\t1\tcomment\nc004\tA1-1\tx.py\t2\t2\tcomment\n' > "$S/key.tsv"
printf 'id\tcategory\nc001\tnarration\nc002\twhy\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
table=$(python3 "$B/score" "$S")
assert_contains "tallies an arm across its runs" "$table" \
    "| A0 | 2 | 0.5 | 0.0 | 0.0 | 0.5 | 0.0 | 0.0 | 1, 0 | 20% | 1 | 1/2 |"
assert_contains "keeps arms apart, and counts bloat as bad" "$table" \
    "| A1 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 1.0 | 2 | 20% | 0 | - |"
assert_contains "names the runs that changed nothing" "$table" "no change: A0-2"
printf 'id\tcategory\nc001\tnarration\nc002\t\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
assert_exit "an unjudged comment exits 2" 2 python3 "$B/score" "$S"
printf 'id\tcategory\nc001\tnarration\nc002\tvague\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
assert_exit "an unknown category exits 2" 2 python3 "$B/score" "$S"
printf 'id\tcategory\nc001\tnarration\nc002\twhy\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
printf 'run\tadded\tcode\tcomment\tlabels\tstale\nA0-1\t10\t10\t2\t1\t1\n' > "$S/runs.tsv"
assert_exit "a comment from a run missing from runs.tsv exits 2" 2 python3 "$B/score" "$S"

finish
````

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: FAIL — `it carries the comment the change makes false` and the cases after it, because the fixture is still the first one.

- [ ] **Step 3: Replace the fixture**

```bash
B=tests/baselines/writing-code-comments
git rm -q "$B/fixture/inventory.py" "$B/fixture/test_inventory.py" "$B/task.md"
mkdir -p "$B/fixture/exporter" "$B/fixture/tests" "$B/fixture/docs/superpowers/specs" "$B/fixture/docs/superpowers/plans"
: > "$B/fixture/exporter/__init__.py"
: > "$B/fixture/tests/__init__.py"
```

Then write each file below, under `tests/baselines/writing-code-comments/fixture/`.

`.gitignore`:

```text
__pycache__/
```

`CLAUDE.md`:

```markdown
# Exporter

Copies records from the source system into the record store, once a night.

- Code: `exporter/`. Tests: `tests/`, run with `python3 -m unittest`.
- Design: `docs/superpowers/specs/`. Implementation plans: `docs/superpowers/plans/`.
```

`exporter/store.py`:

```python
"""An in-memory stand-in for the record store the exporter writes to."""

MAX_BATCH = 25


class StoreError(Exception):
    pass


class Store:
    def __init__(self):
        self.records = {}
        self.requests = 0

    def put(self, key, record):
        """Write one record, in one request."""
        self.requests += 1
        self.records[key] = record

    def put_many(self, records):
        """Write up to MAX_BATCH (key, record) pairs in one request.

        Raises StoreError for a larger batch, and writes nothing.
        """
        if len(records) > MAX_BATCH:
            raise StoreError(f"batch of {len(records)} exceeds {MAX_BATCH}")
        self.requests += 1
        for key, record in records:
            self.records[key] = record
```

`exporter/source.py`:

```python
"""An in-memory stand-in for the source system the exporter reads from."""


class Source:
    def __init__(self, records):
        self._records = sorted(records, key=lambda record: record["id"])

    def page(self, after, size):
        """Up to `size` records whose id sorts after `after`, in id order; "" starts at the beginning."""
        return [record for record in self._records if record["id"] > after][:size]
```

`exporter/job.py` — its `# One put per record` comment is the one the change makes false:

```python
"""The export job: copies records from the source to the store within a request budget."""

from dataclasses import dataclass

PAGE_SIZE = 100
MAX_REQUESTS = 500


@dataclass
class RunResult:
    exported: int = 0
    skipped: int = 0
    cursor: str = ""
    stopped_by_budget: bool = False


def run(source, store, cursor=""):
    """Export every record after `cursor`, stopping before the store would exceed MAX_REQUESTS.

    The result's cursor is the id of the last record dealt with, so the next run resumes after it.
    """
    result = RunResult(cursor=cursor)
    while True:
        page = source.page(result.cursor, PAGE_SIZE)
        if not page:
            return result
        for record in page:
            if record["status"] == "draft":
                result.skipped += 1
            else:
                if store.requests >= MAX_REQUESTS:
                    result.stopped_by_budget = True
                    return result
                # One put per record: the store has no batch write.
                store.put(record["id"], record)
                result.exported += 1
            result.cursor = record["id"]
```

`exporter/report.py`:

```python
"""Command-line entrypoint: runs one export and prints its report."""

import sys

# Set while this entrypoint is a placeholder.
STUB = True


def main(argv=None):
    raise NotImplementedError("the run report is not implemented yet")


if __name__ == "__main__":
    sys.exit(main())
```

`tests/test_job.py`:

```python
import unittest
from unittest import mock

from exporter import job
from exporter.source import Source
from exporter.store import Store


def record(id, status="live"):
    return {"id": id, "status": status}


class RunTest(unittest.TestCase):
    def test_exports_live_records_and_skips_drafts(self):
        """Drafts are counted as skipped and never written."""
        store = Store()
        result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
        self.assertEqual(sorted(store.records), ["a", "c"])
        self.assertEqual((result.exported, result.skipped), (2, 1))

    def test_resumes_after_the_cursor(self):
        store = Store()
        job.run(Source([record("a"), record("b"), record("c")]), store, cursor="a")
        self.assertEqual(sorted(store.records), ["b", "c"])

    def test_stops_at_the_request_budget(self):
        """The run stops before the request that would exceed the budget, and says so."""
        store = Store()
        with mock.patch.object(job, "MAX_REQUESTS", 2):
            result = job.run(Source([record("a"), record("b"), record("c")]), store)
        self.assertTrue(result.stopped_by_budget)
        self.assertEqual((sorted(store.records), result.cursor), (["a", "b"], "b"))


if __name__ == "__main__":
    unittest.main()
```

`tests/test_report.py`:

```python
import unittest

from exporter import report


class ReportTest(unittest.TestCase):
    def test_is_a_placeholder(self):
        self.assertTrue(report.STUB)
        with self.assertRaises(NotImplementedError):
            report.main([])


if __name__ == "__main__":
    unittest.main()
```

`docs/superpowers/specs/2026-01-08-exporter-design.md`:

```markdown
# Exporter — design

## 1. Purpose

The exporter copies records from the source system into the record store once a night. A record is
a JSON object with at least an `id` and a `status`.

## 2. Source and store

### 2.1 Source

The source returns records in `id` order, a page at a time, after a given id. An empty id starts
from the beginning.

### 2.2 Store

The store writes one record per request with `put`, or up to 25 records per request with
`put_many`. A larger batch is refused and nothing in it is written.

The exporter writes with `put_many`, in batches of at most 25. The job's page-size constant is
`SOURCE_PAGE_SIZE`, so it cannot be confused with the store's batch limit.

## 3. The export job

### 3.1 Request budget

A run makes at most `MAX_REQUESTS` (500) store requests. It checks the budget before every request,
and stops rather than exceed it, recording that it stopped.

### 3.2 Cursor

A run returns a cursor: the id of the last record it has dealt with, whether written or skipped. The
next run starts after it, so a run that stops at the budget loses nothing and repeats nothing.

### 3.3 Drafts

A record whose status is `draft` is counted as skipped and not written.

## 4. The run report

`python3 -m exporter.report RECORDS_JSON [CURSOR]` runs one export over the records in the JSON
file, starting after `CURSOR` if one is given, and prints one line:

    exported=N skipped=N requests=N stopped_by_budget=yes|no cursor=ID

It exits 0 when the run completed or stopped at the budget, since both are normal outcomes, and 2 on a
usage error.
```

`docs/superpowers/plans/2026-01-10-export-job.md`:

````markdown
# Export job Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A nightly job that copies records from the source to the store within a request budget.

**Architecture:** In-memory stand-ins for the source and the store, and one `run` function that pages
through the source and writes to the store.

**Tech Stack:** Python 3, unittest.

**Spec:** `docs/superpowers/specs/2026-01-08-exporter-design.md`

**Not in this plan:** batch writes (spec §2.2) and the run report (spec §4). They follow in the next plan.

---

### Task 1: Source and store stand-ins

**Files:**
- Create: `exporter/source.py`, `exporter/store.py`

- [x] **Step 1:** Write `Source.page(after, size)` and `Store.put(key, record)`, each counting requests.
- [x] **Step 2:** Commit.

### Task 2: The export loop

**Files:**
- Create: `exporter/job.py`
- Test: `tests/test_job.py`

- [x] **Step 1: Write the failing tests** for drafts and the request budget.
- [x] **Step 2: Implement `run`**

```python
def run(source, store, cursor=""):
    result = RunResult(cursor=cursor)
    while True:
        page = source.page(result.cursor, PAGE_SIZE)
        if not page:
            return result
        for record in page:
            if record["status"] == "draft":
                result.skipped += 1
            else:
                if store.requests >= MAX_REQUESTS:
                    result.stopped_by_budget = True
                    return result
                store.put(record["id"], record)
                result.exported += 1
            result.cursor = record["id"]
```

- [x] **Step 3:** Run `python3 -m unittest`; expect OK. Commit.

### Task 3: Resume from a cursor

**Files:**
- Modify: `exporter/job.py`
- Test: `tests/test_job.py`

- [x] **Step 1:** Test that a run given a cursor starts after it.
- [x] **Step 2:** Run `python3 -m unittest`; expect OK. Commit.
````

- [ ] **Step 4: Write the review overlay**

A finished implementation with three flaws its own tests miss: a batch the size of a whole page, a budget checked once per page, and exit status 1 at the budget. Under `tests/baselines/writing-code-comments/overlays/review/`:

`exporter/job.py`:

```python
"""The export job: copies records from the source to the store within a request budget."""

from dataclasses import dataclass

SOURCE_PAGE_SIZE = 100
MAX_REQUESTS = 500


@dataclass
class RunResult:
    exported: int = 0
    skipped: int = 0
    cursor: str = ""
    stopped_by_budget: bool = False


def run(source, store, cursor=""):
    """Export every record after `cursor`, stopping before the store would exceed MAX_REQUESTS.

    The result's cursor is the id of the last record dealt with, so the next run resumes after it.
    """
    result = RunResult(cursor=cursor)
    while True:
        page = source.page(result.cursor, SOURCE_PAGE_SIZE)
        if not page:
            return result
        if store.requests >= MAX_REQUESTS:
            result.stopped_by_budget = True
            return result
        batch = []
        for record in page:
            if record["status"] == "draft":
                result.skipped += 1
            else:
                batch.append((record["id"], record))
        if batch:
            store.put_many(batch)
            result.exported += len(batch)
        result.cursor = page[-1]["id"]
```

`exporter/report.py`:

```python
"""Command-line entrypoint: runs one export and prints its report."""

import json
import sys

from exporter.job import run
from exporter.source import Source
from exporter.store import Store


def format_report(result, requests):
    """The report line: exported, skipped, requests, stopped_by_budget and cursor, as key=value."""
    stopped = "yes" if result.stopped_by_budget else "no"
    return (f"exported={result.exported} skipped={result.skipped} requests={requests} "
            f"stopped_by_budget={stopped} cursor={result.cursor}")


def main(argv=None):
    """Run one export over the records in the JSON file argv[0], after cursor argv[1] if given.

    Prints the report line and returns the exit status.
    """
    argv = sys.argv[1:] if argv is None else argv
    if not 1 <= len(argv) <= 2:
        print("usage: python3 -m exporter.report RECORDS_JSON [CURSOR]", file=sys.stderr)
        return 2
    with open(argv[0], encoding="utf-8") as f:
        records = json.load(f)
    store = Store()
    result = run(Source(records), store, argv[1] if len(argv) == 2 else "")
    print(format_report(result, store.requests))
    return 1 if result.stopped_by_budget else 0


if __name__ == "__main__":
    sys.exit(main())
```

`tests/test_job.py`:

```python
import unittest
from unittest import mock

from exporter import job
from exporter.source import Source
from exporter.store import Store


def record(id, status="live"):
    return {"id": id, "status": status}


class RunTest(unittest.TestCase):
    def test_exports_live_records_and_skips_drafts(self):
        """Drafts are counted as skipped and never written."""
        store = Store()
        result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
        self.assertEqual(sorted(store.records), ["a", "c"])
        self.assertEqual((result.exported, result.skipped), (2, 1))

    def test_resumes_after_the_cursor(self):
        store = Store()
        job.run(Source([record("a"), record("b"), record("c")]), store, cursor="a")
        self.assertEqual(sorted(store.records), ["b", "c"])

    def test_writes_a_page_in_one_request(self):
        store = Store()
        job.run(Source([record("a"), record("b"), record("c")]), store)
        self.assertEqual(store.requests, 1)

    def test_stops_at_the_request_budget(self):
        """The run stops before the request that would exceed the budget, and says so."""
        store = Store()
        with mock.patch.object(job, "SOURCE_PAGE_SIZE", 2), mock.patch.object(job, "MAX_REQUESTS", 1):
            result = job.run(Source([record("a"), record("b"), record("c")]), store)
        self.assertTrue(result.stopped_by_budget)
        self.assertEqual((sorted(store.records), result.cursor), (["a", "b"], "b"))


if __name__ == "__main__":
    unittest.main()
```

`tests/test_report.py`:

```python
import contextlib
import io
import json
import os
import tempfile
import unittest

from exporter import report


class ReportTest(unittest.TestCase):
    def run_report(self, records, *args):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "records.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(records, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                status = report.main([path, *args])
        return status, out.getvalue()

    def test_prints_the_report_line(self):
        status, out = self.run_report([{"id": "a", "status": "live"}, {"id": "b", "status": "draft"}])
        self.assertEqual(status, 0)
        self.assertEqual(out, "exported=1 skipped=1 requests=1 stopped_by_budget=no cursor=b\n")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 5: Write the scenario texts**

Under `tests/baselines/writing-code-comments/scenarios/`. The line numbers in `review-findings.md` are the overlay's.

`task.md`:

```markdown
Implement what `docs/superpowers/plans/2026-01-10-export-job.md` left out: batch writes (spec §2.2, under the budget and cursor rules of §3.1 and §3.2) and the run report (spec §4). The spec is `docs/superpowers/specs/2026-01-08-exporter-design.md`. Run the tests with `python3 -m unittest`.
```

`review-brief.md`:

```markdown
### Task 1: Batch writes and the run report

**Spec:** `docs/superpowers/specs/2026-01-08-exporter-design.md`

**Files:**
- Modify: `exporter/job.py`, `exporter/report.py`
- Test: `tests/test_job.py`, `tests/test_report.py`

**Requirements:**
- `run` writes with `store.put_many`, in batches of at most 25 (spec §2.2), under the request budget and cursor rules of spec §3.1 and §3.2.
- `PAGE_SIZE` becomes `SOURCE_PAGE_SIZE` (spec §2.2).
- `exporter/report.py` implements the run report of spec §4, and its `STUB` marker and placeholder test go.
- Test each behaviour; `python3 -m unittest` passes.
```

`review-report.md`:

```markdown
# Task 1 report

**Status:** DONE

- `run` now collects each page's live records and writes them with one `put_many`; drafts are counted as skipped. `PAGE_SIZE` is renamed `SOURCE_PAGE_SIZE`.
- `report.main` reads the records file, runs one export and prints the report line; `STUB` and its test are removed.
- Tests: 6/6 passing with `python3 -m unittest`.

Files changed: `exporter/job.py`, `exporter/report.py`, `tests/test_job.py`, `tests/test_report.py`.
```

`review-findings.md`:

```markdown
### Spec Compliance

- ❌ Issues found: spec §2.2's batch limit (Critical 1) and §3.1's per-request budget check (Important 1) are not met, and §4's exit status is wrong (Important 2).

### Strengths

- `format_report` produces spec §4's line exactly, and the rename and the removal of `STUB` are complete.

### Issues

#### Critical (Must Fix)

1. `exporter/job.py:37` — `put_many` is given every live record on a source page, and a page holds up to 100. The store refuses a batch over 25 (`store.MAX_BATCH`), so any real page raises `StoreError`. The tests pass only because no test page holds more than three records. Split each page into batches of at most 25.

#### Important (Should Fix)

1. `exporter/job.py:27` — the budget is checked once per page, not before every request (spec §3.1). Once pages are split into batches, one page makes up to four requests, so a run can exceed `MAX_REQUESTS` by three. Check before each `put_many`, and keep the cursor at the last batch written, so a run stopped mid-page resumes without losing or repeating records (spec §3.2).
2. `exporter/report.py:32` — `main` returns 1 when the run stopped at the budget. Spec §4 says a run stopped at the budget is a normal outcome and exits 0.

#### Minor (Nice to Have)

1. `tests/test_report.py` — no test covers the usage error's exit status 2.

### Rulings

1. The reviewer suggested that `run` fall back to per-record `put` when `put_many` raises. Ruling: no fallback. A refused batch means the batching is wrong, and a fallback would hide it.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The batching never runs against a realistic page, and the budget and exit status diverge from the spec.
```

`review-round.md` — `{REPORT_FILE}` and `{FINDINGS}` are filled at dispatch:

```markdown

## Fix round 1

You implemented this task in an earlier session: your commits are in the repository, and your report is at {REPORT_FILE}. The task review returned the findings below. Fix every Critical and Important finding and follow the Rulings. Add a test that fails without each fix, re-run the tests, commit, and append a fix report to your report file. Then reply with the short status contract.

<findings>
{FINDINGS}
</findings>
```

- [ ] **Step 6: Replace `setup-run`**

`tests/baselines/writing-code-comments/setup-run`:

```bash
#!/usr/bin/env bash
# Set up one baseline run: a fresh repository holding the fixture, its starting
# point tagged baseline-base so extract-comments finds what the run added even
# after the run commits its own work. An overlay is committed on top of the
# fixture and becomes the starting point: the review scenario starts from a
# finished, flawed implementation.
#
# Usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR]   (prints the run's directory)
set -euo pipefail

[ $# -eq 2 ] || [ $# -eq 3 ] || { echo "usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR]" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
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
if [ $# -eq 3 ]; then
    cp -R "$3/." "$run/"
    commit "Batch writes and the run report"
fi
git -C "$run" tag baseline-base
cd "$run" && pwd
```

- [ ] **Step 7: Replace `extract-comments`**

`tests/baselines/writing-code-comments/extract-comments`:

````python
#!/usr/bin/env python3
"""Pool the comments added across baseline runs into one blinded list.

Usage: extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX]

Each subdirectory of RUNS_DIR holding a .git is one run, set up by setup-run.
A comment counts as added when any of its lines is added relative to the tag
baseline-base, so work the run committed and files it created both count.
Comments in a Markdown file's python code blocks count too: a plan's code is
the code that ships.

Writes to OUT_DIR:
  comments.md   every added comment with surrounding code, shuffled, no run label
  key.tsv       id, run, file, first line, last line, kind
  runs.tsv      per run: lines added, added code lines, added comment lines,
                comments carrying a process label, and whether --stale matched
                a file the run changed ("-" without --stale)
  verdicts.tsv  one row per id with an empty category, for the judge
  diffs/        each run's full diff, so a later judge can re-read the raw output
"""
import ast
import io
import os
import random
import re
import subprocess
import sys
import textwrap
import tokenize

CONTEXT = 3
USAGE = "usage: extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX]"
FENCE = re.compile(r"^\s*(`{3,})\s*(\S*)\s*$")
LABEL = re.compile(r"\b(?:Task|Phase|Step|Critical|Important|Minor|Ruling|Finding|[Rr]ound)\s*#?\d+"
                   r"|Review Focus|review round|fix round")


def git(run, *args):
    return subprocess.run(["git", "-C", run, *args], check=True,
                          capture_output=True, text=True).stdout


def added_lines(patch):
    added, current, line = {}, None, 0
    for text in patch.splitlines():
        if text.startswith("+++ "):
            path = text[4:]
            current = None if path == "/dev/null" else path[2:]
            continue
        hunk = re.match(r"@@ -\S+ \+(\d+)", text)
        if hunk:
            line = int(hunk.group(1))
            continue
        if current and text.startswith("+"):
            added.setdefault(current, set()).add(line)
            line += 1
    return added


def fallback_units(source):
    # Code that does not parse, often a plan's partial snippet, is read line by line:
    # runs of '#' lines, inline '#' comments, and triple-quoted spans.
    units, opened = [], None
    for n, text in enumerate(source.splitlines(), 1):
        stripped = text.strip()
        if opened is not None:
            if '"""' in text:
                units.append((opened, n, "unparsed"))
                opened = None
        elif stripped.startswith(('"""', 'r"""')):
            if stripped.count('"""') >= 2:
                units.append((n, n, "unparsed"))
            else:
                opened = n
        elif stripped.startswith("#") and units and units[-1][1] == n - 1 \
                and source.splitlines()[n - 2].strip().startswith("#"):
            units[-1] = (units[-1][0], n, "unparsed")
        elif "#" in text:
            units.append((n, n, "unparsed"))
    return units


def comment_units(source):
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
        tree = ast.parse(source)
    except (SyntaxError, tokenize.TokenError):
        return fallback_units(source)
    units = []
    # Adjacent comment lines are read as one comment, so they are judged as one.
    for n in (t.start[0] for t in tokens if t.type == tokenize.COMMENT):
        if units and units[-1][1] == n - 1:
            units[-1] = (units[-1][0], n, "comment")
        else:
            units.append((n, n, "comment"))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            first = node.body[0] if node.body else None
            if (isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant)
                    and isinstance(first.value.value, str)):
                units.append((first.lineno, first.end_lineno, "docstring"))
    return sorted(units)


def python_blocks(text):
    """(first line, lines) of each python code block in a Markdown text; first is 1-based."""
    blocks, fence, python, start, body = [], None, False, 0, []
    for n, line in enumerate(text.splitlines(), 1):
        match = FENCE.match(line)
        if fence is None:
            if match and match.group(2):
                fence, python, start, body = match.group(1), match.group(2) in ("python", "py"), n + 1, []
            elif match:
                fence, python, start, body = match.group(1), False, n + 1, []
        elif match and not match.group(2) and len(match.group(1)) >= len(fence):
            if python:
                blocks.append((start, body))
            fence = None
        else:
            body.append(line)
    return blocks


def code_regions(name, source):
    """(offset, lines) pairs: the whole file for Python, each python code block for Markdown."""
    if name.endswith(".py"):
        return [(0, source.splitlines())]
    if name.endswith(".md"):
        return [(start - 1, body) for start, body in python_blocks(source)]
    return []


def main():
    args = sys.argv[1:]
    options = {"--seed": None, "--stale": None}
    for flag in options:
        if flag in args:
            at = args.index(flag)
            options[flag] = args[at + 1]
            del args[at:at + 2]
    if len(args) != 2:
        print(USAGE, file=sys.stderr)
        return 2
    runs_dir, out = args
    seed = None if options["--seed"] is None else int(options["--seed"])
    stale = None if options["--stale"] is None else re.compile(options["--stale"])
    os.makedirs(os.path.join(out, "diffs"), exist_ok=True)

    entries, runs = [], []
    for label in sorted(os.listdir(runs_dir)):
        run = os.path.join(runs_dir, label)
        if not os.path.isdir(os.path.join(run, ".git")):
            continue
        git(run, "add", "-A")
        with open(os.path.join(out, "diffs", label + ".diff"), "w", encoding="utf-8") as f:
            f.write(git(run, "diff", "--cached", "--no-color", "baseline-base", "--"))
        added = added_lines(git(run, "diff", "--cached", "--no-color", "-U0", "baseline-base", "--"))
        code = comment = labelled = 0
        stale_hit = False
        for name, numbers in sorted(added.items()):
            path = os.path.join(run, name)
            if not os.path.isfile(path) or not name.endswith((".py", ".md")):
                continue
            with open(path, encoding="utf-8") as f:
                source = f.read()
            stale_hit = stale_hit or bool(stale and stale.search(source))
            for offset, lines in code_regions(name, source):
                block = textwrap.dedent("\n".join(lines))
                shown_lines = block.splitlines()
                code += len(numbers & set(range(offset + 1, offset + len(lines) + 1)))
                for first, last, kind in comment_units(block):
                    span = set(range(offset + first, offset + last + 1))
                    if numbers.isdisjoint(span):
                        continue
                    comment += len(numbers & span)
                    text = "\n".join(shown_lines[first - 1:last])
                    labelled += bool(LABEL.search(text))
                    lo, hi = max(1, first - CONTEXT), min(len(shown_lines), last + CONTEXT)
                    shown = [("> " if first <= n <= last else "  ") + shown_lines[n - 1]
                             for n in range(lo, hi + 1)]
                    entries.append((label, name, offset + first, offset + last, kind, "\n".join(shown)))
        runs.append((label, sum(len(lines) for lines in added.values()), code, comment, labelled,
                     "-" if stale is None else int(stale_hit)))

    random.Random(seed).shuffle(entries)
    with open(os.path.join(out, "comments.md"), "w", encoding="utf-8") as md, \
            open(os.path.join(out, "key.tsv"), "w", encoding="utf-8") as key, \
            open(os.path.join(out, "verdicts.tsv"), "w", encoding="utf-8") as verdicts:
        key.write("id\trun\tfile\tfirst\tlast\tkind\n")
        verdicts.write("id\tcategory\n")
        for n, (label, name, first, last, kind, shown) in enumerate(entries, 1):
            cid = f"c{n:03d}"
            md.write(f"### {cid} — {name}\n\n```python\n{shown}\n```\n\n")
            key.write(f"{cid}\t{label}\t{name}\t{first}\t{last}\t{kind}\n")
            verdicts.write(f"{cid}\t\n")
    with open(os.path.join(out, "runs.tsv"), "w", encoding="utf-8") as f:
        f.write("run\tadded\tcode\tcomment\tlabels\tstale\n")
        for row in runs:
            f.write("\t".join(str(value) for value in row) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
````

- [ ] **Step 8: Replace `score`**

`tests/baselines/writing-code-comments/score`:

```python
#!/usr/bin/env python3
"""Tally the judge's verdicts per arm.

Usage: score OUT_DIR

Reads runs.tsv, key.tsv and verdicts.tsv from OUT_DIR. A run's arm is its
label up to the first '-', so P0-3 belongs to arm P0. Prints each category's
mean per run; the per-run count of bad comments (narration, bloat and
restatement), which the pass criteria are stated in; and, from runs.tsv, the
share of added code lines that are comment lines, the comments carrying a
process label, and how many runs kept the stale comment.

Exits 2 when a comment is unjudged or judged into an unknown category: either
would otherwise score silently as a clean comment.
"""
import os
import sys

CATEGORIES = ("why", "contract", "warning", "narration", "bloat", "restatement")
BAD = ("narration", "bloat", "restatement")


def rows(out, name):
    with open(os.path.join(out, name), encoding="utf-8") as f:
        return [line.rstrip("\n").split("\t") for line in f.readlines()[1:] if line.strip()]


def main():
    if len(sys.argv) != 2:
        print("usage: score OUT_DIR", file=sys.stderr)
        return 2
    out = sys.argv[1]
    runs = {row[0]: row[1:] for row in rows(out, "runs.tsv")}
    owner = {row[0]: row[1] for row in rows(out, "key.tsv")}
    verdicts = {row[0]: (row[1].strip() if len(row) > 1 else "")
                for row in rows(out, "verdicts.tsv")}

    problems = [f"unjudged: {cid}" for cid in owner if not verdicts.get(cid)]
    problems += [f"unknown category {verdicts[cid]!r}: {cid}" for cid in owner
                 if verdicts.get(cid) and verdicts[cid] not in CATEGORIES]
    problems += [f"not in runs.tsv: {label}" for label in sorted(set(owner.values()) - set(runs))]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2

    counts = {label: dict.fromkeys(CATEGORIES, 0) for label in runs}
    for cid, label in owner.items():
        counts[label][verdicts[cid]] += 1

    arms = {}
    for label in sorted(runs):
        arms.setdefault(label.split("-", 1)[0], []).append(label)

    print("| arm | runs | " + " | ".join(CATEGORIES)
          + " | bad per run | comment share | labelled | stale kept |")
    print("|---" * (len(CATEGORIES) + 6) + "|")
    for arm, labels in arms.items():
        means = [f"{sum(counts[l][c] for l in labels) / len(labels):.1f}" for c in CATEGORIES]
        per_run = ", ".join(str(sum(counts[l][c] for c in BAD)) for l in labels)
        code = sum(int(runs[l][1]) for l in labels)
        comment = sum(int(runs[l][2]) for l in labels)
        share = f"{round(100 * comment / code)}%" if code else "-"
        labelled = sum(int(runs[l][3]) for l in labels)
        stale = [runs[l][4] for l in labels]
        kept = "-" if "-" in stale else f"{sum(int(s) for s in stale)}/{len(labels)}"
        print(f"| {arm} | {len(labels)} | " + " | ".join(means)
              + f" | {per_run} | {share} | {labelled} | {kept} |")

    unchanged = [label for label, row in sorted(runs.items()) if row[0] == "0"]
    if unchanged:
        print()
        print("no change: " + ", ".join(unchanged))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 9: Write `accept`**

`tests/baselines/writing-code-comments/accept`:

````python
#!/usr/bin/env python3
"""Check that one baseline run did its task, so a run that did not is replaced before judging.

Usage: accept RUN_DIR code
       accept RUN_DIR plan PLAN_PATH

`code` runs the run's own tests, then checks batch writes, the budget, the cursor and the report
against the fixture's spec. `plan` checks that the plan is committed, has code for both features, and that the
run changed no code: a plan run that implemented it would be scored as a plan.
Prints "ok", or the first check that failed, and exits 0 or 1.
"""
import os
import re
import subprocess
import sys

CHECKS = r'''
import contextlib, io, json, os, tempfile
from unittest import mock
from exporter import job, report
from exporter.source import Source
from exporter.store import Store

assert hasattr(job, "SOURCE_PAGE_SIZE") and not hasattr(job, "PAGE_SIZE"), "page size constant not renamed"
assert not getattr(report, "STUB", False), "report is still a stub"
records = [{"id": f"r{n:03d}", "status": "draft" if n % 10 == 0 else "live"} for n in range(230)]
store = Store()
result = job.run(Source(records), store)
assert (result.exported, result.skipped) == (207, 23), "wrong counts over 230 records"
assert len(store.records) == 207, "not every live record was written"
assert store.requests <= 10, f"{store.requests} requests for 230 records: not batched"
store = Store()
with mock.patch.object(job, "MAX_REQUESTS", 3):
    first = job.run(Source(records), store)
assert first.stopped_by_budget and store.requests <= 3, "budget exceeded or not reported"
second = Store()
job.run(Source(records), second, first.cursor)
assert not set(store.records) & set(second.records), "a resumed run repeated records"
assert len(store.records) + len(second.records) == 207, "a resumed run lost records"
path = os.path.join(tempfile.mkdtemp(), "records.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(records, f)
out = io.StringIO()
with contextlib.redirect_stdout(out):
    status = report.main([path])
assert status == 0, "report exit status"
assert out.getvalue() == "exported=207 skipped=23 requests=10 stopped_by_budget=no cursor=r229\n", "report line"
with mock.patch.object(job, "MAX_REQUESTS", 1), contextlib.redirect_stdout(io.StringIO()):
    assert report.main([path]) == 0, "a run stopped at the budget must exit 0"
'''


def check_code(run):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", NO_COLOR="1", PYTHON_COLORS="0")
    tests = subprocess.run([sys.executable, "-m", "unittest", "-q"], cwd=run, env=env,
                           capture_output=True, text=True)
    if tests.returncode != 0:
        return "the run's own tests fail"
    checks = subprocess.run([sys.executable, "-c", CHECKS], cwd=run, env=env,
                            capture_output=True, text=True)
    if checks.returncode != 0:
        lines = checks.stderr.strip().splitlines()
        return lines[-1] if lines else "checks failed"
    return None


def check_plan(run, plan):
    tracked = subprocess.run(["git", "-C", run, "ls-files", "--error-unmatch", plan],
                             capture_output=True, text=True)
    if tracked.returncode != 0:
        return f"{plan} is not committed"
    changed = subprocess.run(["git", "-C", run, "diff", "--quiet", "baseline-base", "--", "exporter", "tests"])
    if changed.returncode != 0:
        return "the plan run changed code"
    with open(os.path.join(run, plan), encoding="utf-8") as f:
        text = f.read()
    if len(re.findall(r"^\s*```+py(thon)?\s*$", text, re.M)) < 2:
        return "the plan has fewer than two python code blocks"
    for needed in ("put_many", "SOURCE_PAGE_SIZE", "stopped_by_budget"):
        if needed not in text:
            return f"the plan never mentions {needed}"
    return None


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[1] == "code":
        problem = check_code(args[0])
    elif len(args) == 3 and args[1] == "plan":
        problem = check_plan(args[0], args[2])
    else:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    print(problem or "ok")
    return 1 if problem else 0


if __name__ == "__main__":
    sys.exit(main())
````

Then: `chmod +x tests/baselines/writing-code-comments/{setup-run,extract-comments,score,accept}`.

- [ ] **Step 10: Run the test to verify it passes**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: 42 `[PASS]`, then `OK`.

- [ ] **Step 11: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`.

- [ ] **Step 12: Commit**

```bash
git add -A tests/baselines/writing-code-comments tests/scripts/test-baseline-tooling.sh
git commit -m "test: a baseline that reproduces plan, review and change conditions"
```

---

### Task 2: RED — fifteen runs, judged blind, and stop

**Main session only.** It dispatches subagents and judges their output.

**Files:**
- Create: `tests/baselines/writing-code-comments/prompts/plan.md`
- Modify: `tests/baselines/writing-code-comments/prompts/implementer.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red2/` (results)

**Interfaces:**
- Consumes: `setup-run`, `accept`, `extract-comments`, `score` and the scenario files from Task 1; `prompts/agent.md` unchanged from the first plan.

- [ ] **Step 1: Make the implementer prompt's task-specific text into slots**

In `prompts/implementer.md`: replace `Task 1: Fix the low-stock boundary and add total_value` with `{TASK_NAME}`; replace `A small stock-tracking module for a warehouse. This task is standalone; nothing else depends on it.{CONTRACT}` with `{CONTEXT}{CONTRACT}`; append a final line `{FIX_ROUND}`. The first RED filled those slots with the replaced text and an empty fix round.

- [ ] **Step 2: Write P's prompt**

`prompts/plan.md` — `{WRITING_PLANS}` is the absolute path of superpowers' `writing-plans/SKILL.md` (`~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/writing-plans/SKILL.md`), `{LOADED_SKILL}` is empty at RED:

```markdown
You are working in the git repository at {RUN_DIR}.

Write the implementation plan for what `docs/superpowers/plans/2026-01-10-export-job.md` left out: batch writes (spec §2.2, under the budget and cursor rules of §3.1 and §3.2) and the run report (spec §4). The spec is `docs/superpowers/specs/2026-01-08-exporter-design.md`.

Use the superpowers:writing-plans skill: it is at {WRITING_PLANS}; read it and follow it. Save the plan to `docs/superpowers/plans/2026-02-02-batch-writes-and-report.md` and commit it. Write the plan only: do not implement it, and end at the handoff rather than asking which execution approach to use.
{LOADED_SKILL}
```

- [ ] **Step 3: Set up fifteen runs**

```bash
B=tests/baselines/writing-code-comments
R=.dopamine/run/baseline/red2
mkdir -p "$R/briefs" "$R/reports"
for n in 1 2 3 4 5; do
  bash "$B/setup-run" "$R/runs" "P0-$n"
  bash "$B/setup-run" "$R/runs" "M0-$n"
  bash "$B/setup-run" "$R/runs" "R0-$n" "$B/overlays/review"
  cp "$B/scenarios/review-brief.md" "$R/briefs/R0-$n.md"
  cp "$B/scenarios/review-report.md" "$R/reports/R0-$n.md"
done
```

Expected: fifteen absolute paths.

- [ ] **Step 4: Dispatch P0**

Five `general-purpose` Agent calls in one message, no model override. Each prompt is `plan.md` with `{RUN_DIR}` = the run's absolute path, `{WRITING_PLANS}` as above, `{LOADED_SKILL}` empty.

- [ ] **Step 5: Dispatch M0**

Five `general-purpose` Agent calls in one message, no model override. Each prompt is `agent.md` with `{RUN_DIR}`, `{TASK}` = `scenarios/task.md`, `{LOADED_SKILL}` empty.

- [ ] **Step 6: Dispatch R0**

Five `general-purpose` Agent calls in one message, `model: sonnet`. Each prompt is `implementer.md` with:

| Slot | Value |
|---|---|
| `{TASK_NAME}` | `Task 1: Batch writes and the run report` |
| `{BRIEF_FILE}` | `<abs>/.dopamine/run/baseline/red2/briefs/R0-n.md` |
| `{CONTEXT}` | `The nightly exporter: the plan's earlier tasks built the export loop; this task adds batch writes and the run report.` |
| `{CONTRACT}` | empty |
| `{RUN_DIR}` | the run's absolute path |
| `{REPORT_FILE}` | `<abs>/.dopamine/run/baseline/red2/reports/R0-n.md` |
| `{FIX_ROUND}` | `scenarios/review-round.md`, with its `{REPORT_FILE}` filled the same way and `{FINDINGS}` = `scenarios/review-findings.md` |

Do not read any run's diff.

- [ ] **Step 7: Check every run did its task**

```bash
B=tests/baselines/writing-code-comments
for r in .dopamine/run/baseline/red2/runs/*; do
  case "$(basename "$r")" in
    P*) printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" plan docs/superpowers/plans/2026-02-02-batch-writes-and-report.md)" ;;
    *)  printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" code)" ;;
  esac
done
```

Expected: `ok` for every run. A run that is not `ok` is replaced: set up the next label for its arm (`M0-6`), dispatch it the same way, and delete the failed run's directory. Record each replacement and its reason in the ledger.

- [ ] **Step 8: Extract**

Run: `python3 tests/baselines/writing-code-comments/extract-comments .dopamine/run/baseline/red2/runs .dopamine/run/baseline/red2/out --stale 'the store has no batch write'`

- [ ] **Step 9: Judge, blind**

Open only `red2/out/comments.md`. **Do not open `key.tsv`, `runs.tsv` or `diffs/` until every row of `verdicts.tsv` is filled.** For each entry, write one category:

| Category | The comment |
|---|---|
| `why` | Gives a reason, constraint or cause the code does not show |
| `contract` | Describes a public interface in the language's doc-comment format |
| `warning` | Tells a reader what breaks if they change something |
| `narration` | Refers to the change or the process that produced it: an earlier state ("now", "no longer", "renamed from", "was"), a task, phase or plan step, a review finding, round or ruling, or the absence of something removed |
| `bloat` | A why, contract or warning that argues rather than states: more than one reason where one carries it, a rejected alternative, enumerated defences, or more lines than the code it documents |
| `restatement` | Says what the adjacent code visibly does |

Tie-breaks, in order: anything narrating is `narration`; otherwise anything bloated is `bloat`. A bare pointer to a spec section is not narration by itself. An entry's file name shows whether it came from a plan; that is expected, since scenarios are compared only with their own GREEN arm.

- [ ] **Step 10: Score and record**

```bash
R=.dopamine/run/baseline/red2
python3 tests/baselines/writing-code-comments/score "$R/out" > "$R/out/score.md"
cat "$R/out/score.md"
cp -R "$R/out" docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red2
```

Expected: three rows — M0, P0, R0 — and no `no change:` line.

- [ ] **Step 11: Commit and stop for review**

The gate — any one scenario averaging at least one bad comment per run — is applied at the review, not here. Whatever the table shows, commit and **stop.**

```bash
git add tests/baselines/writing-code-comments/prompts docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red2
git commit -m "test: RED baseline, redesigned, for code-comment discipline"
```

- [ ] **Step 12: Report the findings to the human**

- `score.md`, and whether the gate is met, per scenario.
- Every bad comment, quoted with its scenario, grouped by category.
- The comment share, labelled counts and stale-kept counts, and what they add to the verdicts.
- Hard-to-categorise comments and how they were resolved.
- Anything the runs did that the categories did not anticipate.

The rewrite of the first plan's Phase 2 is drafted with the human from these findings.

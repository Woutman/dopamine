# Code-comment discipline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `dopamine:writing-code-comments` — a positive contract for what a code comment is — gated on a baseline that shows Claude's comments actually fail without it, and wire it into the `SessionStart` injection and `finishing-work`'s exit gate.

**Architecture:** A baseline harness (a fixture repository, three small scripts, three prompt templates) runs first. Its RED stage decides whether the skill is written at all. The skill is one `SKILL.md` under 200 words; the injection gains two sentences, one of which has the controller pass the contract to implementer subagents; the exit gate gains a sixth check. The GREEN stage re-runs the baseline with the guidance in place.

**Tech Stack:** bash, git, markdown. Python 3 for the baseline tooling and the test suite only — never shipped runtime.

**Spec:** `docs/superpowers/specs/2026-09-29-writing-code-comments-design.md`

## Global Constraints

- **The skill applies only in adopted repositories** — it is reached through the `SessionStart` injection, which is silent without `.dopamine/config`.
- **Only comments the diff adds or touches are governed.** Untouched comments are out of scope.
- **The skill is a positive contract, not a prohibition list.** No "match the surrounding comment density" clause. No supporting files.
- **`SKILL.md` body stays under 200 words**; `description` starts with `Use when`, is under 500 characters, and states triggers only.
- **The injection stays within its 200-word budget and uses no `never`, `do not` or `don't`** (enforced by `tests/hooks/test-session-start.sh`).
- **Google's style guides are not vendored.** They survive only as "the language's standard doc-comment format".
- **Specs and sealed plans are immutable.** Nothing under `docs/superpowers/specs/` or an existing `docs/superpowers/plans/*.md` is edited.
- **Scripts in skills and baselines are invoked through their interpreter** (`bash setup-run`, `python3 extract-comments`), never by bare path.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **Baseline runs and judging are done by the main session**, not an implementer subagent: they dispatch subagents, and the judge must be the main session (spec §6, third ruling).

## Review Focus

1. **A run that commits its own work** — the implementer template tells S arms to commit, so a diff against `HEAD` would be empty. Expected: extraction diffs against the fixture's tagged starting point and still finds the comments. *(Task 1, A0-3 case.)*
2. **A run that creates a new file** — comments in an untracked `.py` file are still added comments. *(Task 1, A0-3 case.)*
3. **A run that leaves the code unparseable** — `ast`/`tokenize` fail. Expected: fall back to line-based `#` detection, marked `unparsed`, rather than crash. *(Task 1, A0-4 case.)*
4. **A `#` inside a string literal** — not a comment. *(Task 1, A0-1 case.)*
5. **A run that changes nothing, or a comment left unjudged** — a no-change run would silently score as perfect, and a missing verdict would silently score as zero. Expected: no-change runs are listed for re-running; an unjudged or mis-typed verdict exits 2. *(Task 1, score cases.)*

## Clarifications of the spec

- **GREEN judging pools the RED runs back in.** All twenty code-writing runs are shuffled and judged together in Task 6, so the judge cannot tell a GREEN comment from a control by which batch it arrived in. RED's own verdicts decide only the RED gate.
- **S arms dispatch on `sonnet`**, as an implementer for a small, fully specified task would. A arms inherit the session model. The two families are only ever compared with their own control.
- **Arm C gives the controller the skill's path, not its contents,** so it must load the skill itself — which is what the injection asks of it.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `tests/baselines/writing-code-comments/fixture/inventory.py` | The module the baseline task edits; carries the bug |
| `tests/baselines/writing-code-comments/fixture/test_inventory.py` | Its tests, passing as shipped |
| `tests/baselines/writing-code-comments/task.md` | The task text every arm receives |
| `tests/baselines/writing-code-comments/setup-run` | One run's repository, fixture committed and tagged |
| `tests/baselines/writing-code-comments/extract-comments` | Pools added comments across runs into a blinded list |
| `tests/baselines/writing-code-comments/score` | Tallies the judge's verdicts per arm |
| `tests/baselines/writing-code-comments/prompts/agent.md` | A-arm prompt |
| `tests/baselines/writing-code-comments/prompts/implementer.md` | S-arm prompt: superpowers' implementer template, filled in |
| `tests/baselines/writing-code-comments/prompts/controller.md` | C-arm prompt |
| `tests/scripts/test-baseline-tooling.sh` | Hermetic tests for the three scripts and the fixture |
| `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/` | Committed results: `red/`, `green/` |
| `skills/writing-code-comments/SKILL.md` | The skill |
| `tests/skills/test-code-comments.sh` | Content assertions for the skill |

**Modified:** `hooks/session-start-context.md`, `skills/finishing-work/SKILL.md`, `tests/hooks/test-session-start.sh`, `tests/skills/test-skill-structure.sh`, `README.md`, `.claude-plugin/plugin.json`.

**Run scratch** (gitignored by the existing `.dopamine/run/` rule): `.dopamine/run/baseline/{red,green}/`.

**Task order and why:** tooling first, so RED can run; RED next, because it can end the plan; then the skill, the injection and the gate, which GREEN needs in place; GREEN; then the documents that describe the result.

**Two phases.** Phase 1 is Tasks 1–2 and ends at a review with the human. Phase 2 is Tasks 3–7 as drafted below; it is revised in light of the RED findings at that review, and does not start until the human approves the revised version.

---

## Phase 1 — tooling and RED

### Task 1: Baseline tooling

**Files:**
- Create: `tests/baselines/writing-code-comments/fixture/inventory.py`
- Create: `tests/baselines/writing-code-comments/fixture/test_inventory.py`
- Create: `tests/baselines/writing-code-comments/task.md`
- Create: `tests/baselines/writing-code-comments/setup-run`
- Create: `tests/baselines/writing-code-comments/extract-comments`
- Create: `tests/baselines/writing-code-comments/score`
- Test: `tests/scripts/test-baseline-tooling.sh`

**Interfaces:**
- Produces:
  - `bash setup-run RUNS_DIR LABEL` → prints the run directory `RUNS_DIR/LABEL`; exits 1 if it exists, 2 on bad usage. The starting commit is tagged `baseline-base`.
  - `python3 extract-comments RUNS_DIR OUT_DIR [--seed N]` → writes `OUT_DIR/{comments.md,key.tsv,runs.tsv,verdicts.tsv,diffs/<label>.diff}`. `key.tsv` columns: `id run file first last kind`, `kind` ∈ `comment|docstring|unparsed`. `runs.tsv` columns: `run added`. `verdicts.tsv` columns: `id category`, category empty.
  - `python3 score OUT_DIR` → markdown table on stdout; exits 2 on an unjudged or unknown verdict. A run's arm is its label up to the first `-`.
  - Categories, exactly: `why contract warning narration restatement`.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-baseline-tooling.sh`:

```bash
#!/usr/bin/env bash
# Tests for the tooling behind the writing-code-comments baseline. The runs
# themselves need agents and a judge and stay out of this suite; the scripts
# that set them up and score them do not.
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
missed=$(cd "$B/fixture" && python3 -c '
from inventory import Item, low_stock
print(len(low_stock([Item("A1", "bolt", 5, 5, 0.1)])))')
assert_eq "it carries the bug: an item exactly at its reorder level is missed" 0 "$missed"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"

# A0-1: a docstring, a comment, and a '#' that lives inside a string.
cat >> "$run/inventory.py" <<'EOF'


def total_value(items):
    """Sum of quantity times unit price."""
    # Loop over the items
    label = "item # count"
    return sum(item.quantity * item.unit_price for item in items)
EOF
# A0-2: changes nothing.
bash "$B/setup-run" "$T/runs" A0-2 >/dev/null
# A0-3: a new file, committed by the run itself.
run=$(bash "$B/setup-run" "$T/runs" A0-3)
printf '# Added helper\ndef helper():\n    return 1\n' > "$run/helpers.py"
git -C "$run" add -A && git -C "$run" commit -qm work
# A0-4: leaves the module unparseable.
run=$(bash "$B/setup-run" "$T/runs" A0-4)
printf '\n\ndef broken(:\n    # Fixed the thing\n' >> "$run/inventory.py"

echo "-- extract-comments"
RC=0
python3 "$B/extract-comments" "$T/runs" "$T/out" --seed 1 >/dev/null 2>&1 || RC=$?
assert_eq "exits 0" 0 "$RC"
comments=$(cat "$T/out/comments.md")
assert_contains "finds an added comment" "$comments" "Loop over the items"
assert_contains "finds an added docstring" "$comments" "Sum of quantity times unit price"
assert_contains "finds a comment in a new file the run committed" "$comments" "Added helper"
assert_contains "falls back when the code does not parse" "$comments" "Fixed the thing"
assert_not_contains "labels no entry with its run" "$comments" "A0-"
assert_eq "A0-1 yields exactly two comments: the '#' in a string is not one" \
    2 "$(grep -c $'\tA0-1\t' "$T/out/key.tsv")"
assert_contains "the docstring is recorded as one" "$(cat "$T/out/key.tsv")" $'\tdocstring'
assert_contains "the unparseable run is recorded as such" \
    "$(grep $'\tA0-4\t' "$T/out/key.tsv")" "unparsed"
assert_contains "a run that changed nothing is still listed" \
    "$(cat "$T/out/runs.tsv")" $'A0-2\t0'
assert_eq "one verdict row per comment" \
    "$(wc -l < "$T/out/key.tsv")" "$(wc -l < "$T/out/verdicts.tsv")"
assert_contains "each run's raw diff is kept for a later judge" \
    "$(cat "$T/out/diffs/A0-3.diff")" "Added helper"
python3 "$B/extract-comments" "$T/runs" "$T/again" --seed 1 >/dev/null 2>&1
assert_eq "the same seed gives the same order" \
    "$(cat "$T/out/comments.md")" "$(cat "$T/again/comments.md")"

echo "-- score"
S="$T/score"
mkdir -p "$S"
printf 'run\tadded\nA0-1\t10\nA0-2\t0\nA1-1\t5\n' > "$S/runs.tsv"
printf 'id\trun\tfile\tfirst\tlast\tkind\nc001\tA0-1\tx.py\t1\t1\tcomment\nc002\tA0-1\tx.py\t3\t3\tcomment\nc003\tA1-1\tx.py\t1\t1\tcomment\n' > "$S/key.tsv"
printf 'id\tcategory\nc001\tnarration\nc002\twhy\nc003\trestatement\n' > "$S/verdicts.tsv"
table=$(python3 "$B/score" "$S")
assert_contains "tallies an arm across its runs" "$table" "| A0 | 2 | 0.5 | 0.0 | 0.0 | 0.5 | 0.0 | 1, 0 |"
assert_contains "keeps arms apart" "$table" "| A1 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 1 |"
assert_contains "names the runs that changed nothing" "$table" "no change: A0-2"
printf 'id\tcategory\nc001\tnarration\nc002\t\nc003\trestatement\n' > "$S/verdicts.tsv"
assert_exit "an unjudged comment exits 2" 2 python3 "$B/score" "$S"
printf 'id\tcategory\nc001\tnarration\nc002\tvague\nc003\trestatement\n' > "$S/verdicts.tsv"
assert_exit "an unknown category exits 2" 2 python3 "$B/score" "$S"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: FAIL — `its own tests pass as shipped` and every later case, because `tests/baselines/` does not exist.

- [ ] **Step 3: Write the fixture and the task**

`tests/baselines/writing-code-comments/fixture/inventory.py`:

```python
"""Stock tracking for a small warehouse."""

from dataclasses import dataclass


@dataclass
class Item:
    sku: str
    name: str
    quantity: int
    reorder_level: int
    unit_price: float


def parse_line(line):
    """Parse one line of the supplier's CSV export into an Item."""
    sku, name, quantity, reorder_level, unit_price = line.strip().split(",")
    return Item(sku, name, int(quantity), int(reorder_level), float(unit_price))


def load(path):
    """Read every item from a supplier export file."""
    with open(path, encoding="utf-8") as f:
        # The export always starts with a header row.
        next(f)
        return [parse_line(line) for line in f if line.strip()]


def by_sku(items):
    return {item.sku: item for item in items}


def low_stock(items):
    """Items that should be reordered."""
    return [item for item in items if item.quantity < item.reorder_level]


def restock_order(items, target_multiple=2):
    """Quantity to order per SKU so each low item reaches target_multiple times its reorder level."""
    return {
        item.sku: item.reorder_level * target_multiple - item.quantity
        for item in low_stock(items)
    }


def apply_delivery(items, delivery):
    """Add delivered quantities, keyed by SKU, to the matching items in place."""
    index = by_sku(items)
    for sku, quantity in delivery.items():
        # Deliveries can include SKUs we don't stock yet; those are skipped
        # until someone adds the item by hand.
        if sku in index:
            index[sku].quantity += quantity
```

`tests/baselines/writing-code-comments/fixture/test_inventory.py`:

```python
import unittest

from inventory import Item, apply_delivery, low_stock, parse_line, restock_order


def item(sku="A1", quantity=10, reorder_level=5, unit_price=1.0):
    return Item(sku, "widget", quantity, reorder_level, unit_price)


class InventoryTest(unittest.TestCase):
    def test_parse_line(self):
        self.assertEqual(parse_line("A1,widget,10,5,2.50\n"), Item("A1", "widget", 10, 5, 2.5))

    def test_low_stock_below_reorder_level(self):
        self.assertEqual(low_stock([item(quantity=3)]), [item(quantity=3)])

    def test_restock_order(self):
        self.assertEqual(restock_order([item(quantity=3)]), {"A1": 7})

    def test_apply_delivery_skips_unknown_sku(self):
        items = [item()]
        apply_delivery(items, {"A1": 5, "ZZ": 3})
        self.assertEqual(items[0].quantity, 15)


if __name__ == "__main__":
    unittest.main()
```

`tests/baselines/writing-code-comments/task.md`:

```markdown
`low_stock` in `inventory.py` misses items whose quantity is exactly their reorder level; those should count as low stock too. Fix that.

Also add a function `total_value(items)` to `inventory.py` that returns the combined value of all stock: each item's quantity times its unit price, summed.

Add tests for both to `test_inventory.py`. Run them with `python3 -m unittest`.
```

- [ ] **Step 4: Write `setup-run`**

`tests/baselines/writing-code-comments/setup-run`:

```bash
#!/usr/bin/env bash
# Set up one baseline run: a fresh repository holding the fixture, its starting
# point tagged baseline-base so extract-comments finds what the run added even
# after the run commits its own work.
#
# Usage: setup-run RUNS_DIR LABEL   (prints the run's directory)
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: setup-run RUNS_DIR LABEL" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
run="$1/$2"
[ ! -e "$run" ] || { echo "$run already exists" >&2; exit 1; }

mkdir -p "$run"
cp -R "$HERE/fixture/." "$run/"
rm -rf "$run/__pycache__"
git -C "$run" init -q
git -C "$run" add -A
git -C "$run" -c user.name=baseline -c user.email=baseline@localhost commit -qm fixture
git -C "$run" tag baseline-base
cd "$run" && pwd
```

- [ ] **Step 5: Write `extract-comments`**

`tests/baselines/writing-code-comments/extract-comments`:

```python
#!/usr/bin/env python3
"""Pool the comments added across baseline runs into one blinded list.

Usage: extract-comments RUNS_DIR OUT_DIR [--seed N]

Each subdirectory of RUNS_DIR holding a .git is one run, set up by setup-run.
A comment counts as added when any of its lines is added relative to the tag
baseline-base, so work the run committed and files it created both count.

Writes to OUT_DIR:
  comments.md   every added comment with surrounding code, shuffled, no run label
  key.tsv       id, run, file, first line, last line, kind
  runs.tsv      every run and its added-line count, so a run with nothing to judge still scores
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
import tokenize

CONTEXT = 3
USAGE = "usage: extract-comments RUNS_DIR OUT_DIR [--seed N]"


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


def comment_units(source):
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
        tree = ast.parse(source)
    except (SyntaxError, tokenize.TokenError):
        return [(n, n, "unparsed") for n, text in enumerate(source.splitlines(), 1)
                if "#" in text]
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


def main():
    args = sys.argv[1:]
    seed = None
    if "--seed" in args:
        at = args.index("--seed")
        seed = int(args[at + 1])
        del args[at:at + 2]
    if len(args) != 2:
        print(USAGE, file=sys.stderr)
        return 2
    runs_dir, out = args
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
        runs.append((label, sum(len(lines) for lines in added.values())))
        for name, numbers in sorted(added.items()):
            if not name.endswith(".py"):
                continue
            with open(os.path.join(run, name), encoding="utf-8") as f:
                source = f.read()
            lines = source.splitlines()
            for first, last, kind in comment_units(source):
                if numbers.isdisjoint(range(first, last + 1)):
                    continue
                lo, hi = max(1, first - CONTEXT), min(len(lines), last + CONTEXT)
                shown = [("> " if first <= n <= last else "  ") + lines[n - 1]
                         for n in range(lo, hi + 1)]
                entries.append((label, name, first, last, kind, "\n".join(shown)))

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
        f.write("run\tadded\n")
        for label, count in runs:
            f.write(f"{label}\t{count}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Write `score`**

`tests/baselines/writing-code-comments/score`:

```python
#!/usr/bin/env python3
"""Tally the judge's verdicts per arm.

Usage: score OUT_DIR

Reads runs.tsv, key.tsv and verdicts.tsv from OUT_DIR. A run's arm is its
label up to the first '-', so A0-3 belongs to arm A0. Prints each category's
mean per run, then the per-run narration-plus-restatement counts the pass
criteria are stated in.

Exits 2 when a comment is unjudged or judged into an unknown category: either
would otherwise score silently as a clean comment.
"""
import os
import sys

CATEGORIES = ("why", "contract", "warning", "narration", "restatement")


def rows(out, name):
    with open(os.path.join(out, name), encoding="utf-8") as f:
        return [line.rstrip("\n").split("\t") for line in f.readlines()[1:] if line.strip()]


def main():
    if len(sys.argv) != 2:
        print("usage: score OUT_DIR", file=sys.stderr)
        return 2
    out = sys.argv[1]
    runs = {label: int(added) for label, added in rows(out, "runs.tsv")}
    owner = {row[0]: row[1] for row in rows(out, "key.tsv")}
    verdicts = {row[0]: (row[1].strip() if len(row) > 1 else "")
                for row in rows(out, "verdicts.tsv")}

    problems = [f"unjudged: {cid}" for cid in owner if not verdicts.get(cid)]
    problems += [f"unknown category {verdicts[cid]!r}: {cid}" for cid in owner
                 if verdicts.get(cid) and verdicts[cid] not in CATEGORIES]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2

    counts = {label: dict.fromkeys(CATEGORIES, 0) for label in runs}
    for cid, label in owner.items():
        counts[label][verdicts[cid]] += 1

    arms = {}
    for label in sorted(runs):
        arms.setdefault(label.split("-", 1)[0], []).append(label)

    print("| arm | runs | " + " | ".join(CATEGORIES) + " | narration+restatement per run |")
    print("|---" * (len(CATEGORIES) + 3) + "|")
    for arm, labels in arms.items():
        means = [f"{sum(counts[l][c] for l in labels) / len(labels):.1f}" for c in CATEGORIES]
        per_run = ", ".join(str(counts[l]["narration"] + counts[l]["restatement"]) for l in labels)
        print(f"| {arm} | {len(labels)} | " + " | ".join(means) + f" | {per_run} |")

    unchanged = [label for label, added in sorted(runs.items()) if added == 0]
    if unchanged:
        print()
        print("no change: " + ", ".join(unchanged))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Then: `chmod +x tests/baselines/writing-code-comments/{setup-run,extract-comments,score}`.

- [ ] **Step 7: Run the test to verify it passes**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: every case `[PASS]`, then `OK`.

- [ ] **Step 8: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`.

- [ ] **Step 9: Commit**

```bash
git add tests/baselines tests/scripts/test-baseline-tooling.sh
git commit -m "test: baseline harness for code-comment discipline"
```

---

### Task 2: RED — run the controls, judge them blind, and decide

**Main session only.** This task dispatches subagents and judges their output; an implementer subagent cannot do either.

**Files:**
- Create: `tests/baselines/writing-code-comments/prompts/agent.md`
- Create: `tests/baselines/writing-code-comments/prompts/implementer.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red/` (results)

**Interfaces:**
- Consumes: `setup-run`, `extract-comments`, `score` from Task 1.
- Produces: `red/verdicts.tsv`, `red/score.md`, and a decision — proceed, or stop the plan here.

- [ ] **Step 1: Write the A-arm prompt**

`tests/baselines/writing-code-comments/prompts/agent.md` — `{TASK}` is replaced by `task.md`'s contents, `{RUN_DIR}` by the run's directory, and `{LOADED_SKILL}` by nothing in A0:

```markdown
You are working in the git repository at {RUN_DIR}.

{TASK}

When you're done, commit your work.
{LOADED_SKILL}
```

- [ ] **Step 2: Write the S-arm prompt**

Copy the fenced `prompt: |` body of `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/subagent-driven-development/implementer-prompt.md` into `tests/baselines/writing-code-comments/prompts/implementer.md`, dedented by four spaces — the text from `You are implementing Task N` through `Never silently produce work you're unsure about.`, excluding the `Subagent (general-purpose):`, `description:`, `model:` and `prompt: |` lines. Then substitute:

| Template text | Replacement |
|---|---|
| `Task N: [task name]` (both places) | `Task 1: Fix the low-stock boundary and add total_value` |
| `[BRIEF_FILE]` | `{BRIEF_FILE}` |
| `[Scene-setting: where this fits, dependencies, architectural context]` | `A small stock-tracking module for a warehouse. This task is standalone; nothing else depends on it.{CONTRACT}` |
| `[directory]` | `{RUN_DIR}` |
| `[REPORT_FILE]` | `{REPORT_FILE}` |

`{CONTRACT}` is replaced by nothing in S0.

- [ ] **Step 3: Set up ten runs**

```bash
B=tests/baselines/writing-code-comments
R=.dopamine/run/baseline/red
mkdir -p "$R/briefs" "$R/reports"
for arm in A0 S0; do for n in 1 2 3 4 5; do bash "$B/setup-run" "$R/runs" "$arm-$n"; done; done
for n in 1 2 3 4 5; do cp "$B/task.md" "$R/briefs/S0-$n.md"; done
```

Expected: ten absolute paths printed.

- [ ] **Step 4: Dispatch A0**

Five `general-purpose` Agent calls in one message, no model override. Each prompt is `agent.md` with `{RUN_DIR}` = the run's absolute path, `{TASK}` = `task.md`'s contents, `{LOADED_SKILL}` = empty. Do not read the agents' diffs.

- [ ] **Step 5: Dispatch S0**

Five `general-purpose` Agent calls in one message, `model: sonnet`. Each prompt is `implementer.md` with `{RUN_DIR}`, `{BRIEF_FILE}` = `<abs>/.dopamine/run/baseline/red/briefs/S0-n.md`, `{REPORT_FILE}` = `<abs>/.dopamine/run/baseline/red/reports/S0-n.md`, `{CONTRACT}` = empty.

- [ ] **Step 6: Check every run did the task**

```bash
for r in .dopamine/run/baseline/red/runs/*; do
  printf '%s ' "$(basename "$r")"
  (cd "$r" && PYTHONDONTWRITEBYTECODE=1 python3 -c '
from inventory import Item, low_stock, total_value
assert low_stock([Item("A", "a", 5, 5, 1.0)])
assert total_value([Item("A", "a", 2, 1, 1.5)]) == 3.0
print("ok")' 2>&1 | tail -1)
done
```

Expected: `ok` for every run. A run that failed is replaced: set up the next label for its arm (`A0-6`), dispatch it the same way, and delete the failed run's directory.

- [ ] **Step 7: Extract**

Run: `python3 tests/baselines/writing-code-comments/extract-comments .dopamine/run/baseline/red/runs .dopamine/run/baseline/red/out`

- [ ] **Step 8: Judge, blind**

Open only `red/out/comments.md`. **Do not open `key.tsv` or `diffs/` until every row of `verdicts.tsv` is filled.** For each entry, write one category into `verdicts.tsv`:

| Category | The comment |
|---|---|
| `why` | Gives a reason, constraint or cause the code does not show |
| `contract` | Describes a public interface — behaviour, parameters, return, errors — as a module, class or public-function docstring |
| `warning` | Tells a reader what breaks if they change something |
| `narration` | Refers to the change, the task, or an earlier state: "now", "fixed", "changed", "added", "instead of", "previously", "as requested" |
| `restatement` | Says what the adjacent code visibly does, including a test docstring that repeats the test's name |

A comment that is part narration and part why is `narration`: it still carries the change's story.

- [ ] **Step 9: Score and record**

```bash
python3 tests/baselines/writing-code-comments/score .dopamine/run/baseline/red/out > .dopamine/run/baseline/red/out/score.md
cat .dopamine/run/baseline/red/out/score.md
mkdir -p docs/superpowers/plans/2026-09-29-writing-code-comments.baseline
cp -R .dopamine/run/baseline/red/out docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red
```

Expected: a two-row table, A0 and S0, and no `no change:` line.

- [ ] **Step 10: Commit and stop for review**

The spec's gate — **RED shows a problem** when the mean of narration plus restatement per run is **at least 1.0** for A0 **or** S0 — is applied at the review, not here. Whatever the table shows, commit and **stop: Phase 1 ends here.**

```bash
git add tests/baselines/writing-code-comments/prompts docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/red
git commit -m "test: RED baseline for code-comment discipline"
```

- [ ] **Step 11: Report the findings to the human**

Bring to the review:
- `score.md`, and whether the spec's gate is met.
- Every comment judged `narration` or `restatement`, quoted with its run's arm.
- Any comment that was hard to categorise, and how it was resolved.
- Anything the runs did that the categories or the Phase 2 draft did not anticipate.

Phase 2 is revised with the human from these findings before any of it runs.

---

## Phase 2 — skill, wiring and GREEN (draft; revised after the Phase 1 review)

### Task 3: The skill

**Files:**
- Create: `skills/writing-code-comments/SKILL.md`
- Create: `tests/skills/test-code-comments.sh`
- Modify: `tests/skills/test-skill-structure.sh` (the `BUDGETS` block)

**Interfaces:**
- Consumes: `red/verdicts.tsv`, `red/key.tsv`, `red/comments.md` from Task 2.
- Produces: `skills/writing-code-comments/SKILL.md`, whose `## The contract` section is a single blockquote. Tasks 4 and 6 copy that blockquote verbatim.

- [ ] **Step 1: Write the failing content test**

`tests/skills/test-code-comments.sh`:

```bash
#!/usr/bin/env bash
# Content assertions for dopamine:writing-code-comments. The structure test
# checks frontmatter and budget; this checks the contract is the one the
# baseline was run against, and that nothing in it negotiates with that
# contract.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

skill="$REPO_ROOT/skills/writing-code-comments/SKILL.md"
if [ ! -f "$skill" ]; then
    fail "skills/writing-code-comments/SKILL.md exists" "not found"
    finish
fi
body=$(cat "$skill")

echo "-- the contract"
contract=$(awk '/^## The contract$/{flag=1; next} /^## /{flag=0} flag' "$skill")
assert_contains "the contract is a blockquote, so it can be copied whole" "$contract" "> "
assert_contains "a comment may state why" "$contract" "**why**"
assert_contains "a comment may state a public interface's contract" "$contract" "**contract**"
assert_contains "a comment may state a warning" "$contract" "**warning**"
assert_contains "doc comments follow the language's own format" \
    "$contract" "standard doc-comment format"
assert_contains "the change's story has a home" "$contract" "commit message"

echo "-- what it leaves out"
assert_not_contains "no density clause to negotiate with" "$body" "density"
assert_not_contains "its example is not the baseline's task" "$body" "reorder"
assert_not_contains "its example is not the baseline's task" "$body" "low_stock"
assert_contains "a comment the change made false is its business" "$body" "makes false"
assert_eq "no supporting files" "SKILL.md" "$(ls "$REPO_ROOT/skills/writing-code-comments")"

finish
```

- [ ] **Step 2: Add the budget**

In `tests/skills/test-skill-structure.sh`, append to the comment block above `BUDGETS`:

```bash
# writing-code-comments is 200: it loads on most coding sessions, which is the
# frequently-loaded budget superpowers:writing-skills sets.
```

and add `writing-code-comments:200` to the `BUDGETS` string's first line.

- [ ] **Step 3: Run both to verify they fail**

Run: `bash tests/skills/test-code-comments.sh; bash tests/skills/test-skill-structure.sh | tail -3`
Expected: `skills/writing-code-comments/SKILL.md exists` FAIL; the structure test passes, since no such skill exists yet.

- [ ] **Step 4: Write the skill**

`skills/writing-code-comments/SKILL.md`:

````markdown
---
name: writing-code-comments
description: Use when writing or editing a code comment, docstring or doc comment, or when a change leaves a nearby comment describing behaviour the code no longer has
---

# Writing code comments

## Overview

A comment describes the code as it is, to a reader who never saw the change that produced it.

## The contract

> A comment states one of three things: **why** the code is this way — a constraint, a non-obvious reason, a workaround and its cause; the **contract** of a public interface, in the language's standard doc-comment format; or a **warning** a reader needs before changing it. The story of the change goes in the commit message.

A comment the change makes false is rewritten to the contract in the same edit.

## Example

```python
# The payment API drops the first request after 60s idle, so the first call is retried once.
response = post_with_retry(payload, retries=1)
```

The commit says the rest: `fix: retry the first payment call after an idle period`.

## Common mistakes

| The comment | Its home |
|---|---|
| `# Now retries once`, `# Fixed: …` | The commit message |
| `# Send the request` above `post(…)` | The code already says it |
| A docstring on a private three-line helper | Its name |
````

- [ ] **Step 5: Fit Common Mistakes to what RED showed**

Open `red/key.tsv` and `red/verdicts.tsv` together. For each row of the Common Mistakes table, keep it only if RED judged at least one comment into that row's category (`narration`, `restatement`, and `restatement` of a helper docstring). For a failure RED showed that no row covers, add a row whose left cell is a RED comment quoted verbatim and whose right cell names its home. Keep the body under 200 words: `awk '/^---$/ { seen++; next } seen >= 2' skills/writing-code-comments/SKILL.md | wc -w`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/skills/test-code-comments.sh && bash tests/skills/test-skill-structure.sh | tail -1`
Expected: `OK`, `OK`.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all N test file(s) passed`.

- [ ] **Step 8: Commit**

```bash
git add skills/writing-code-comments tests/skills/test-code-comments.sh tests/skills/test-skill-structure.sh
git commit -m "feat: writing-code-comments skill"
```

---

### Task 4: The injection

**Files:**
- Modify: `hooks/session-start-context.md`
- Test: `tests/hooks/test-session-start.sh`

**Interfaces:**
- Consumes: the skill name `dopamine:writing-code-comments` from Task 3.
- Produces: the injection text arm C is given in Task 6.

- [ ] **Step 1: Write the failing test**

In `tests/hooks/test-session-start.sh`, after the `names the skill loaded before writing to the instructions file` assertion, add:

```bash
assert_contains "names the skill loaded before writing a code comment" \
    "$ctx" "dopamine:writing-code-comments"
assert_contains "has the controller carry the contract to an implementer" \
    "$ctx" "implementer"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-session-start.sh`
Expected: FAIL on both new assertions.

- [ ] **Step 3: Add the paragraph**

In `hooks/session-start-context.md`, insert this paragraph before the final one (`At the end of any plan…`):

```markdown
Before writing or editing a code comment, load `dopamine:writing-code-comments`. When you dispatch an implementer subagent, copy that skill's contract into its prompt, so the code it writes is held to the same contract.
```

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/hooks/test-session-start.sh`
Expected: `OK`, and the budget line reports under 200 words.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start-context.md tests/hooks/test-session-start.sh
git commit -m "feat: name writing-code-comments in the session injection"
```

---

### Task 5: The exit gate

**Files:**
- Modify: `skills/finishing-work/SKILL.md` (`## Exit gate`)
- Modify: `tests/skills/test-skill-structure.sh` (finishing-work's exit-gate assertions and its budget)

**Interfaces:**
- Consumes: `red/comments.md`, `red/key.tsv`, `red/verdicts.tsv` from Task 2.

- [ ] **Step 1: Write the failing test**

In `tests/skills/test-skill-structure.sh`, in the `finishing-work's exit gate` block after `historical records untouched`, add:

```bash
assert_contains "added comments meet the comment contract" \
    "$gate" "a why, a contract or a warning"
assert_contains "the gate counts its own checks correctly" "$gate" "Six checks"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh | grep FAIL`
Expected: both new assertions FAIL.

- [ ] **Step 3: Derive the grep terms**

From the RED results, list every word (case-insensitive) that appears in **at least two** comments judged `narration` and in **no** comment judged `why`, `contract` or `warning`. Those are the terms.

- [ ] **Step 4: Edit the gate**

In `skills/finishing-work/SKILL.md`, change `Five checks,` to `Six checks,` and append a sixth item. If Step 3 produced terms:

```markdown
6. **Comments added in the diff state a why, a contract or a warning** — dopamine:writing-code-comments holds the contract. Grep the diff's added lines for `<term>|<term>|…` first; judgment covers the rest.
```

with the terms filled in, `|`-separated. If it produced none:

```markdown
6. **Comments added in the diff state a why, a contract or a warning** — dopamine:writing-code-comments holds the contract. Judged over the diff's added lines only.
```

- [ ] **Step 5: Raise finishing-work's budget, with its reason**

It was 699 of 700 words before this change. In `tests/skills/test-skill-structure.sh`, append to the budget comment block:

```bash
# finishing-work is raised from 700 to 760: its exit gate gains a sixth check,
# for comments added in the diff, and that check has to name the skill that
# holds the contract. Not licence to pad.
```

and change `finishing-work:700` to `finishing-work:760`.

- [ ] **Step 6: Run it to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh | tail -1`
Expected: `OK`.

- [ ] **Step 7: Run the full suite and commit**

Run: `bash tests/run-tests.sh` — expected `all N test file(s) passed`.

```bash
git add skills/finishing-work/SKILL.md tests/skills/test-skill-structure.sh
git commit -m "feat: exit gate checks added comments against the contract"
```

---

### Task 6: GREEN — run with guidance, judge pooled, and refactor

**Main session only**, for the same reasons as Task 2.

**Files:**
- Create: `tests/baselines/writing-code-comments/prompts/controller.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green/` (results)
- Possibly modify: `skills/writing-code-comments/SKILL.md` (REFACTOR only)

**Interfaces:**
- Consumes: the prompts from Task 2, the skill from Task 3, the injection from Task 4, the RED runs.

- [ ] **Step 1: Write the C-arm prompt**

`tests/baselines/writing-code-comments/prompts/controller.md` — `{INJECTION}` is `hooks/session-start-context.md`, `{SKILL_PATH}` is the absolute path of `skills/writing-code-comments/SKILL.md`, `{TASK}` is `task.md`, `{IMPLEMENTER_TEMPLATE}` is `prompts/implementer.md` with its slots unfilled:

```markdown
You are the controller in a superpowers subagent-driven-development session, about to dispatch an implementer subagent for Task 1 of a plan.

This context was injected at the start of your session:

<session-context>
{INJECTION}
</session-context>

Skills are files; to load one, read it. `dopamine:writing-code-comments` is at {SKILL_PATH}.

Task 1's full text from the plan:

<task>
{TASK}
</task>

The implementer prompt template you fill in:

<template>
{IMPLEMENTER_TEMPLATE}
</template>

Write out the complete prompt you would dispatch to the implementer, with the brief file at /work/brief.md, the report file at /work/report.md and the working directory /work/repo. Output only that prompt.
```

- [ ] **Step 2: Set up the GREEN runs, and pool the RED runs in**

```bash
B=tests/baselines/writing-code-comments
G=.dopamine/run/baseline/green
mkdir -p "$G/briefs" "$G/reports" "$G/controller"
for arm in A1 S1; do for n in 1 2 3 4 5; do bash "$B/setup-run" "$G/runs" "$arm-$n"; done; done
for n in 1 2 3 4 5; do cp "$B/task.md" "$G/briefs/S1-$n.md"; done
cp -R .dopamine/run/baseline/red/runs/. "$G/runs/"
```

- [ ] **Step 3: Dispatch A1**

Five `general-purpose` Agent calls in one message, no model override: `agent.md` exactly as in A0, but `{LOADED_SKILL}` =

```
This skill is loaded in your session:

<skill name="dopamine:writing-code-comments">
<the full contents of skills/writing-code-comments/SKILL.md>
</skill>
```

- [ ] **Step 4: Dispatch S1**

Five `general-purpose` Agent calls in one message, `model: sonnet`: `implementer.md` exactly as in S0, with the green `briefs/` and `reports/` paths, but `{CONTRACT}` = a blank line followed by `Comments:` and the `## The contract` blockquote from `SKILL.md`, verbatim.

- [ ] **Step 5: Dispatch C**

Five `general-purpose` Agent calls in one message, no model override, each given `controller.md` filled in as Step 1 describes. Save each reply to `.dopamine/run/baseline/green/controller/C-n.md`.

- [ ] **Step 6: Check, extract, judge blind, score**

Run the Task 2 Step 6 check over `green/runs/*` and replace any failed run as described there. Then:

```bash
python3 tests/baselines/writing-code-comments/extract-comments .dopamine/run/baseline/green/runs .dopamine/run/baseline/green/out
```

Judge `green/out/comments.md` exactly as in Task 2 Step 8 — same categories, same tie-break, `key.tsv` and `diffs/` unopened until `verdicts.tsv` is full. Then:

```bash
python3 tests/baselines/writing-code-comments/score .dopamine/run/baseline/green/out > .dopamine/run/baseline/green/out/score.md
cat .dopamine/run/baseline/green/out/score.md
```

For C: read each `C-n.md` and count those that contain the contract — all three of why, contract and warning, and the commit-message line. Append `C: n of 5 carry the contract` to `score.md`.

- [ ] **Step 7: Apply the pass criteria**

From the pooled table, GREEN passes when **all** hold:

1. A1's per-run narration+restatement counts sum to **at most 2**; the same for S1.
2. A1's mean why + warning is **at least half** of A0's; S1's at least half of S0's.
3. C carries the contract in **at least 4 of 5**.

- [ ] **Step 8: REFACTOR if it failed — at most twice**

For a failing criterion, read the failing comments or controller outputs, revise the wording that let them through (the contract for 1 and 2; the injection sentence for 3), keep the tests and budgets passing, and re-run only the failing arm under a fresh label — `A1r1-1…5`, `S1r1-1…5`, or controller replies saved as `C-r1-n.md` — reusing Steps 2–6 with those labels. `setup-run` adds the new runs beside the existing ones, so the next extraction pools everything again and the whole pool is re-judged blind; the revised arm is scored against the same controls. After a second failed revision, stop and report both attempts to the human.

- [ ] **Step 9: Record and commit**

```bash
cp -R .dopamine/run/baseline/green/out docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green
cp -R .dopamine/run/baseline/green/controller docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green/controller
bash tests/run-tests.sh
git add tests/baselines/writing-code-comments/prompts docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green skills hooks
git commit -m "test: GREEN baseline for code-comment discipline"
```

---

### Task 7: README and version

**Files:**
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: README**

- In the `## How it works` table, after the `dopamine:writing-claude-md` row, add:
  `| \`dopamine:writing-code-comments\` | What a code comment states — a why, a contract or a warning — and where the story of a change goes instead |`
- In the `SessionStart` hook row, change `~120 words` to `~160 words`.
- Under `## Known gaps`, add:
  `- **Subagents are reached by instruction.** The injection asks the controller to copy the comment contract into each implementer's prompt; nothing checks that it did, and whether a \`SubagentStart\` hook can inject context is unconfirmed. \`finishing-work\`'s exit gate is the backstop, and the baseline's arm C measured the pass-on rate.`

- [ ] **Step 2: Version**

In `.claude-plugin/plugin.json`, `"version": "0.1.2"` → `"version": "0.1.3"`.

- [ ] **Step 3: Full suite and commit**

Run: `bash tests/run-tests.sh` — expected `all N test file(s) passed`.

```bash
git add README.md .claude-plugin/plugin.json
git commit -m "docs: describe writing-code-comments; bump version to 0.1.3"
```

- [ ] **Step 4: Close the unit of work**

Invoke `dopamine:finishing-work`, then `superpowers:finishing-a-development-branch`.

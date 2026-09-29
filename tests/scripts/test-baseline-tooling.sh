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
L="$B/legacy-fixture"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

echo "-- the fixture"
RC=0
(cd "$L" && python3 -m unittest -q >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it carries the comment the spec makes false" \
    "$(cat "$L/readings/runner.py")" "Keyed by station and row"
assert_exit "accept refuses it: the phase is not done" 1 python3 "$B/accept" "$L" legacy-code
assert_exit "accept's bad usage exits 2" 2 python3 "$B/accept" "$L"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
mkdir -p "$T/overlay/docs"
echo "# a plan" > "$T/overlay/docs/p.md"
exec_run=$(bash "$B/setup-run" "$T/legacy" L0x-1 "$T/overlay")
assert_eq "an overlay is committed on top of the fixture" 2 "$(git -C "$exec_run" rev-list --count HEAD)"
assert_eq "under the plan's commit message" "plan: Phase 2, unattended import from the inbox" \
    "$(git -C "$exec_run" log -1 --format=%s)"
assert_eq "and the overlay is the tagged starting point" \
    "$(git -C "$exec_run" rev-parse HEAD)" "$(git -C "$exec_run" rev-parse baseline-base)"

# A0-1: a docstring, a comment, and a '#' that lives inside a string.
cat >> "$run/readings/report.py" <<'PY'


def total_stored(summaries):
    """Sum of the stored counts."""
    # Loop over the summaries
    label = "run # count"
    return sum(summary.stored for summary in summaries)
PY
# A0-2: changes nothing.
bash "$B/setup-run" "$T/runs" A0-2 >/dev/null
# A0-3: a new file, committed by the run itself.
run=$(bash "$B/setup-run" "$T/runs" A0-3)
printf '# Added helper\ndef helper():\n    return 1\n' > "$run/readings/helpers.py"
git -C "$run" add -A && git -C "$run" commit -qm work
# A0-4: leaves the module unparseable.
run=$(bash "$B/setup-run" "$T/runs" A0-4)
printf '\n\ndef broken(:\n    # Fixed the thing\n' >> "$run/readings/runner.py"
# A0-5: a plan whose python blocks carry comments; one block is indented and does not parse.
run=$(bash "$B/setup-run" "$T/runs" A0-5)
cat > "$run/docs/plan.md" <<'MD'
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
MD

echo "-- accept legacy-plan"
plan=$(bash "$B/setup-run" "$T/plans" L0p-1)
tasks() { for n in $(seq "$1"); do printf '### Task %s: step\n\n```python\nx = %s\n```\n\n' "$n" "$n"; done; }
names='readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary readings/cli.py'
{ tasks 5; echo "$names"; } > "$plan/docs/p.md"
assert_exit "refuses an uncommitted plan" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "takes a committed plan of five tasks" 0 python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 4; echo "$names"; } > "$plan/docs/p.md"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "but not one of four: the fixture would be too small" 1 \
    python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 5; echo "readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary"; } > "$plan/docs/p.md"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "nor one that leaves a decision out" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 5; echo "$names"; } > "$plan/docs/p.md"
echo "x = 1" >> "$plan/readings/units.py"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "nor one whose run changed the package" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md

echo "-- extract-comments"
RC=0
python3 "$B/extract-comments" "$T/runs" "$T/out" --seed 1 >/dev/null 2>&1 || RC=$?
assert_eq "exits 0" 0 "$RC"
comments=$(cat "$T/out/comments.md")
key=$(cat "$T/out/key.tsv")
runs=$(cat "$T/out/runs.tsv")
assert_contains "finds an added comment" "$comments" "Loop over the summaries"
assert_contains "finds an added docstring" "$comments" "Sum of the stored counts"
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

# L0x-1: an execution that edits a plan's code block and adds a comment in the package.
printf '```python\n# plan comment, see spec §4.2\nx = 1\n```\n' >> "$exec_run/docs/p.md"
printf '\n# no longer keyed by row\n' >> "$exec_run/readings/runner.py"
python3 "$B/extract-comments" "$T/legacy" "$T/lout" --py-only --stale 'Keyed by station and row' >/dev/null 2>&1
assert_not_contains "--py-only leaves out a plan's code" "$(cat "$T/lout/comments.md")" "plan comment"
assert_contains "and keeps the package's" "$(cat "$T/lout/comments.md")" "no longer keyed by row"
assert_contains "--stale finds the comment left in the code" "$(cat "$T/lout/runs.tsv")" $'L0x-1\t6\t2\t1\t0\t1'
python3 "$B/extract-comments" "$T/legacy" "$T/lout2" >/dev/null 2>&1
assert_contains "a pointer to a spec section counts as a label" \
    "$(cat "$T/lout2/runs.tsv")" $'L0x-1\t6\t4\t2\t1\t-'
prose=$(bash "$B/setup-run" "$T/prose" L0p-1)
printf 'The comment saying the runner is keyed by station and row goes.\n' > "$prose/docs/p.md"
python3 "$B/extract-comments" "$T/prose" "$T/pout" --stale 'keyed by station and row' >/dev/null 2>&1
assert_contains "--stale does not read a plan's prose" "$(cat "$T/pout/runs.tsv")" $'L0p-1\t1\t0\t0\t0\t0'

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

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

# A run executes the fixture's tests, which writes __pycache__ unless told not to.
run=$(bash "$B/setup-run" "$T/py" Y-1 "$B/overlays/program-design" "$B/overlays/work")
(cd "$run" && env -u PYTHONDONTWRITEBYTECODE python3 -m unittest discover -q -s tests >/dev/null 2>&1)
assert_eq "the run did write bytecode" yes \
    "$([ -d "$run/feedwatch/__pycache__" ] && echo yes || echo no)"
printf 'DONE\n' > "$T/py/Y-1.reply.md"
python3 "$B/blind" "$T/py" "$T/py-out" --columns asked >/dev/null 2>&1
assert_not_contains "bytecode is not part of what the judge sees" \
    "$(cat "$T/py-out/items.md")" "__pycache__"

# using-git-worktrees puts the work in a nested worktree on its own branch.
run=$(bash "$B/setup-run" "$T/wt" W-1)
git -C "$run" worktree add -q .worktrees/feat -b feat
printf 'committed in the worktree\n' > "$run/.worktrees/feat/wt-committed.txt"
git -C "$run/.worktrees/feat" add -A && git -C "$run/.worktrees/feat" commit -qm wt
printf 'uncommitted in the worktree\n' > "$run/.worktrees/feat/wt-loose.txt"
# A branch whose worktree is gone is still the run's work.
git -C "$run" worktree add -q "$T/wt-gone" -b other baseline-base
printf 'only on a branch\n' > "$T/wt-gone/branch-only.txt"
git -C "$T/wt-gone" add -A && git -C "$T/wt-gone" commit -qm branch
git -C "$run" worktree remove --force "$T/wt-gone"
printf 'DONE\n' > "$T/wt/W-1.reply.md"
RC=0
python3 "$B/blind" "$T/wt" "$T/wt-out" --columns asked >/dev/null 2>&1 || RC=$?
assert_eq "a run with a nested worktree exits 0" 0 "$RC"
items=$(cat "$T/wt-out/items.md")
assert_contains "a file committed in the worktree is shown" "$items" "committed in the worktree"
assert_contains "a file left uncommitted in the worktree is shown" "$items" "uncommitted in the worktree"
assert_contains "a commit on a branch nothing has out is shown" "$items" "only on a branch"
assert_not_contains "the worktree's path does not leak" "$items" "$T"

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

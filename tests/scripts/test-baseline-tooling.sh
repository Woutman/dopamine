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

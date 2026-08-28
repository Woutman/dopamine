#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/sweep/scripts/seal-ledger"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME -- a git repo with a plan; prints the repo path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/docs/superpowers/plans"
    git init -q "$repo"
    printf '# A plan\n' > "$repo/docs/superpowers/plans/2026-08-28-widget.md"
    printf '%s\n' "$repo"
}

# write_ledger REPO FIRST_LINE -- creates the SDD workspace ledger
write_ledger() {
    local repo="$1" first="$2"
    local ws="$repo/.superpowers/sdd/2026-08-28-widget"
    mkdir -p "$ws"
    {
        printf '%s\n' "$first"
        printf '\n'
        printf 'Task 1: complete — abc1234\n'
        printf 'Ruling: kept the flat schema — nesting bought nothing — costs a migration if we were wrong\n'
    } > "$ws/progress.md"
    printf '%s\n' "$ws/progress.md"
}

echo "-- usage and missing inputs"
assert_exit "exits 2 with no arguments" 2 "$UNDER_TEST"
assert_exit "exits 2 with two arguments" 2 "$UNDER_TEST" a b
assert_exit "exits 2 when the plan file does not exist" 2 "$UNDER_TEST" "$TEST_ROOT/nope.md"

echo "-- a plan that was never executed under SDD"
repo=$(make_repo noledger)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
out=$("$UNDER_TEST" "$plan" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 when there is no ledger to seal" 2 "$rc"
assert_contains "names the path it looked for" "$out" ".superpowers/sdd/2026-08-28-widget/progress.md"

echo "-- a ledger belonging to a different plan"
repo=$(make_repo foreign)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
write_ledger "$repo" "# SDD ledger — plan: docs/superpowers/plans/2026-08-01-other.md" >/dev/null
out=$("$UNDER_TEST" "$plan" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 rather than sealing another plan's ledger" 2 "$rc"
assert_contains "says whose ledger it found" "$out" "2026-08-01-other"

echo "-- the happy path"
repo=$(make_repo happy)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
ledger=$(write_ledger "$repo" "# SDD ledger — plan: docs/superpowers/plans/2026-08-28-widget.md")
out=$("$UNDER_TEST" "$plan") && rc=0 || rc=$?
sealed="$repo/docs/superpowers/plans/2026-08-28-widget.ledger.md"
assert_eq "exits 0" 0 "$rc"
assert_eq "the sealed copy lands beside the plan" "yes" "$([ -f "$sealed" ] && echo yes || echo no)"
assert_contains "reports what it created" "$out" "created"

header=$(head -1 "$sealed")
if printf '%s' "$header" | grep -qE '^# Sealed ledger — plan: .* — sealed: [0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    pass "the header carries the plan path and the seal date"
else
    fail "the header carries the plan path and the seal date" "got: $header"
fi

assert_eq "the ledger body is copied verbatim below the header" \
    "$(cat "$ledger")" "$(tail -n +3 "$sealed")"

echo "-- nothing is written inside superpowers' directory"
assert_eq "the SDD workspace still holds only progress.md" \
    "progress.md" "$(ls "$repo/.superpowers/sdd/2026-08-28-widget")"

echo "-- re-sealing after the ledger grows"
printf 'Task 2: complete — def5678\n' >> "$ledger"
out=$("$UNDER_TEST" "$plan")
assert_contains "reports an update rather than a second file" "$out" "updated"
assert_contains "the sealed copy picks up the new line" "$(cat "$sealed")" "def5678"
assert_eq "there is still exactly one sealed ledger" 1 \
    "$(find "$repo/docs/superpowers/plans" -name '*.ledger.md' | wc -l | tr -d ' ')"

finish

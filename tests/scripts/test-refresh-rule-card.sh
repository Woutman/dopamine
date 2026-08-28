#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/claude-md-guard/scripts/refresh-rule-card"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# A source page shaped like the real one: the target section contains a fenced
# block whose body has depth-1 headings, and is followed by a sibling section
# that must not be captured.
write_page() {
    cat > "$1" <<'PAGE'
# Page title

## Configure your environment

Intro prose.

### Write an effective CLAUDE.md

Body line one.

```markdown CLAUDE.md theme={null}
# Code style
- Use ES modules

# Workflow
- Typecheck when done
```

Closing line of the section.

### Configure permissions

This belongs to the next section.
PAGE
}

# write_card CARD PAGE SNAPSHOT_REL
write_card() {
    printf 'source: file://%s | ### Write an effective CLAUDE.md | %s\n' "$2" "$3" > "$1"
}

page="$TEST_ROOT/page.md"
write_page "$page"
card="$TEST_ROOT/card.md"
write_card "$card" "$page" "sources/bp.md"

echo "-- bootstrap: no snapshot yet"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "a missing snapshot is drift, not success" 1 "$RC"
assert_contains "and it says which snapshot is missing" "$out" "sources/bp.md"

RC=0
out=$("$UNDER_TEST" --update "$card" 2>&1) || RC=$?
assert_eq "--update still exits 1: the card body is not re-distilled by it" 1 "$RC"
assert_contains "it reports the snapshot as created" "$out" "CREATED"
assert_eq "the snapshot now exists" "yes" \
    "$([ -f "$TEST_ROOT/sources/bp.md" ] && echo yes || echo no)"

echo "-- the extraction boundary"
snap=$(cat "$TEST_ROOT/sources/bp.md")
assert_contains "captures the heading itself" "$snap" "### Write an effective CLAUDE.md"
assert_contains "captures body before the fence" "$snap" "Body line one."
assert_contains "does not stop at a depth-1 heading inside a fence" "$snap" "# Workflow"
assert_contains "captures body after the fence" "$snap" "Closing line of the section."
assert_not_contains "stops at the next same-depth heading" "$snap" "Configure permissions"
assert_not_contains "and does not reach into it" "$snap" "This belongs to the next section."
assert_not_contains "does not capture the preceding section" "$snap" "Intro prose."

echo "-- a clean re-run"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "no drift exits 0" 0 "$RC"
assert_contains "and says so" "$out" "no drift"

echo "-- drift is detected and shown"
sed -i 's/Body line one./Body line one, amended upstream./' "$page"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "drift exits 1" 1 "$RC"
assert_contains "it names the drifted snapshot" "$out" "DRIFT"
assert_contains "and prints the diff" "$out" "amended upstream"

RC=0
out=$("$UNDER_TEST" --update "$card" 2>&1) || RC=$?
assert_eq "--update after drift still exits 1" 1 "$RC"
assert_contains "and reports the rewrite" "$out" "UPDATED"
RC=0
"$UNDER_TEST" "$card" >/dev/null 2>&1 || RC=$?
assert_eq "the snapshot now matches, so the next run is clean" 0 "$RC"

echo "-- a heading that disappeared upstream"
sed -i 's/### Write an effective CLAUDE.md/### Write a good CLAUDE.md/' "$page"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "a vanished heading is drift, not a crash" 1 "$RC"
assert_contains "and it is named as such" "$out" "HEADING-GONE"

echo "-- failure modes"
RC=0
"$UNDER_TEST" "$TEST_ROOT/does-not-exist.md" >/dev/null 2>&1 || RC=$?
assert_eq "a card that does not exist exits 2" 2 "$RC"

printf '# a card with no sources\n' > "$TEST_ROOT/empty-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/empty-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a card declaring no sources exits 2" 2 "$RC"

printf 'source: file:///nowhere.md | ### X\n' > "$TEST_ROOT/short-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/short-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a source line missing a field exits 2" 2 "$RC"

printf 'source: file://%s/absent.md | ### X | sources/x.md\n' "$TEST_ROOT" > "$TEST_ROOT/gone-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/gone-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a source that cannot be fetched exits 3" 3 "$RC"

echo "-- comments and blank lines are ignored"
{
    printf '# The card prose lives here and is not a source line.\n\n'
    printf 'source: file://%s | ### Write a good CLAUDE.md | sources/bp.md\n' "$page"
} > "$TEST_ROOT/prose-card.md"
mkdir -p "$TEST_ROOT/sources"
RC=0
"$UNDER_TEST" --update "$TEST_ROOT/prose-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "prose around the source lines does not break parsing" 1 "$RC"

finish

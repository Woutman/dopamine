#!/usr/bin/env bash
# The guard, end to end, offline.
#
# Each unit test checks one component against its own contract. This one checks
# the chain of names between them: the skill links a card, the card names
# snapshots, and the extractor round-trips those snapshots. Rename any link in
# that chain and every unit test still passes while the shipped plugin points at
# nothing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

GUARD_DIR="$REPO_ROOT/skills/writing-claude-md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "-- the chain of names holds"
assert_eq "the guard skill exists in the plugin" "yes" \
    "$([ -f "$GUARD_DIR/SKILL.md" ] && echo yes || echo no)"

linked=$(grep -oE '\[[^]]*\]\(([a-zA-Z0-9._/-]+\.md)\)' "$GUARD_DIR/SKILL.md" \
    | sed -E 's/.*\((.*)\)/\1/' | sort -u)
assert_eq "the skill links exactly one sibling document" "claude-md-best-practices.md" "$linked"
assert_eq "and that document exists" "yes" \
    "$([ -f "$GUARD_DIR/$linked" ] && echo yes || echo no)"

named_script=$(grep -o 'refresh-rule-card' "$GUARD_DIR/SKILL.md" | head -1)
assert_eq "the skill names the drift check" "refresh-rule-card" "$named_script"
assert_eq "and the script exists and is executable" "yes" \
    "$([ -x "$GUARD_DIR/scripts/refresh-rule-card" ] && echo yes || echo no)"

echo "-- the shipped card, extractor and snapshots agree, with no network"
# The whole card is rebuilt in a scratch directory, with each shipped snapshot
# copied in and named as its own source. Snapshot paths resolve relative to the
# card, so the copy is what keeps this test from writing into the plugin it is
# testing. Extracting a section from a file that *is* that section must return the
# file unchanged, so a clean run proves the shipped snapshots are exactly what the
# shipped extractor produces -- the property that makes the real drift check
# trustworthy. The heading each rebuilt source line searches for comes from the
# card's own declared field, not from the snapshot being searched -- searching a
# snapshot for a heading read off itself would trivially match even if the
# card's declared heading had drifted from what the snapshot actually starts
# with, which is exactly the card<->snapshot contract this offline check exists
# to catch.
mkdir -p "$TEST_ROOT/card/sources"
cp "$GUARD_DIR"/sources/*.md "$TEST_ROOT/card/sources/"
local_card="$TEST_ROOT/card/claude-md-best-practices.md"
: > "$local_card"
count=0
while IFS= read -r line; do
    trimmed=${line#*source:}
    rest=${trimmed#*|}
    heading=$(printf '%s' "${rest%|*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    snap=$(printf '%s' "${rest#*|}" | tr -d ' ')
    if [ -f "$GUARD_DIR/$snap" ]; then
        pass "declared snapshot exists ($snap)"
    else
        fail "declared snapshot exists" "missing: $snap"
        continue
    fi
    printf 'source: file://%s | %s | %s\n' "$TEST_ROOT/card/$snap" "$heading" "$snap" >> "$local_card"
    count=$((count + 1))
done < <(grep -E '^[[:space:]]*source:' "$GUARD_DIR/claude-md-best-practices.md")

assert_eq "the card declares three sources" 3 "$count"

RC=0
out=$("$GUARD_DIR/scripts/refresh-rule-card" "$local_card" 2>&1) || RC=$?
assert_eq "the extractor round-trips every shipped snapshot" 0 "$RC"
assert_contains "and says so" "$out" "no drift"

echo "-- the sweep now gates promotions on the guard"
disc="$REPO_ROOT/skills/sweep/discovery-prompt.md"
assert_contains "discovery names the guard" "$(cat "$disc")" "dopamine:writing-claude-md"
assert_not_contains "and no longer parks promotions" "$(cat "$disc")" "leave it unapplied"
assert_contains "the verifier can find an ungated promotion" \
    "$(cat "$REPO_ROOT/skills/sweep/verifier-prompt.md")" "Ungated"

echo "-- SessionStart is the only hook event left"
events=$(python3 -c "
import json
print(','.join(sorted(json.load(open('$REPO_ROOT/hooks/hooks.json'))['hooks'])))")
assert_eq "SessionStart, and nothing that fires on every tool call" \
    "SessionStart" "$events"

echo "-- no hook shells out to a Python interpreter"
if [ -e "$REPO_ROOT/hooks/py-hook" ]; then
    fail "py-hook is gone, so Python is not a runtime dependency" "hooks/py-hook still exists"
else
    pass "py-hook is gone, so Python is not a runtime dependency"
fi
leftover=$(find "$REPO_ROOT/hooks" -name '*.py' | sed "s|$REPO_ROOT/||")
assert_eq "no Python hook scripts remain" "" "$leftover"

finish

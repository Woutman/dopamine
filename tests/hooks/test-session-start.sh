#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/hooks/session-start"
CONTEXT_FILE="$REPO_ROOT/hooks/session-start-context.md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

adopted="$TEST_ROOT/adopted"
mkdir -p "$adopted/.dopamine"
git init -q "$adopted"
printf 'living: docs/DESIGN.md\nplans: docs/superpowers/plans\n' > "$adopted/.dopamine/config"

plain="$TEST_ROOT/plain"
mkdir -p "$plain"
git init -q "$plain"

# field JSON PATH -- prints a dotted field, or "none"
field() {
    printf '%s' "$1" | FIELD="$2" python3 -c '
import json, os, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
node = json.loads(raw)
for part in os.environ["FIELD"].split("."):
    if not isinstance(node, dict) or part not in node:
        print("none"); raise SystemExit
    node = node[part]
print(node)'
}

# keys JSON -- prints the sorted, comma-joined top-level keys
keys() {
    printf '%s' "$1" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
node = json.loads(raw)
print(",".join(sorted(node.keys())))'
}

echo "-- inert where dopamine has not been adopted"
RC=0
out=$( (cd "$plain" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") ) || RC=$?
assert_eq "exits 0" 0 "$RC"
assert_eq "injects nothing when there is no .dopamine/config" "" "$out"

echo "-- Claude Code shape"
out=$( (cd "$adopted" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
ctx=$(field "$out" "hookSpecificOutput.additionalContext")
assert_eq "uses the nested hookSpecificOutput shape" \
    "SessionStart" "$(field "$out" "hookSpecificOutput.hookEventName")"
assert_not_contains "and not Cursor's flat shape" "$out" "additional_context"

echo "-- Cursor and SDK shapes"
out=$( (cd "$adopted" && CURSOR_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
assert_not_contains "Cursor gets additional_context only" "$out" "hookSpecificOutput"
assert_eq "Cursor's top-level key is exactly additional_context" \
    "additional_context" "$(keys "$out")"

out=$( (cd "$adopted" && COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
assert_not_contains "Copilot CLI gets the flat SDK shape" "$out" "hookSpecificOutput"
assert_eq "Copilot's top-level key is exactly additionalContext" \
    "additionalContext" "$(keys "$out")"

echo "-- what the injection actually says"
assert_contains "names the skill that closes a unit of work" "$ctx" "dopamine:finishing-work"
assert_contains "names the skill loaded before writing to a living document" \
    "$ctx" "dopamine:writing-living-documents"
assert_contains "names the skill loaded before writing to the instructions file" \
    "$ctx" "dopamine:writing-claude-md"
assert_contains "names the skill loaded before writing a code comment" \
    "$ctx" "dopamine:writing-code-comments"
assert_contains "including a comment in a plan's code" "$ctx" "plan's code block"
assert_contains "points at superpowers' existing ledger" "$ctx" "ledger"
assert_contains "names the living documents it governs" "$ctx" "living document"
assert_not_contains "no reference to the renamed skill survives" "$ctx" "dopamine:sweep"

words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 200 ]; then
    pass "the injection is within its 200-word budget ($words words)"
else
    fail "the injection is within its 200-word budget" "got: $words words"
fi

echo "-- the injection is a conditional, not a prohibition"
if grep -qiE '\b(never|do not|don.t)\b' "$CONTEXT_FILE"; then
    fail "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)" \
         "found a prohibition in $CONTEXT_FILE"
else
    pass "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)"
fi

finish

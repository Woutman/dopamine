#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/hooks/claude-md-guard"
CONTEXT_FILE="$REPO_ROOT/hooks/claude-md-guard-context.md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME [--no-config|--no-instructions] -- prints the repo path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/docs"
    git init -q "$repo" 2>/dev/null
    git -C "$repo" config user.email "test@example.com"
    git -C "$repo" config user.name "Test"
    printf '# Project\n\n- Run make test before committing.\n' > "$repo/CLAUDE.md"
    printf '# Lessons\n' > "$repo/docs/LESSONS.md"
    printf '# Design\n' > "$repo/docs/DESIGN.md"
    case "${2:-}" in
        --no-config) ;;
        --no-instructions)
            mkdir -p "$repo/.dopamine"
            printf 'living: docs/DESIGN.md\nplans: docs/superpowers/plans\n' \
                > "$repo/.dopamine/config"
            ;;
        *)
            mkdir -p "$repo/.dopamine"
            {
                printf 'living: docs/DESIGN.md\n'
                printf 'instructions: CLAUDE.md\n'
                printf 'lessons: docs/LESSONS.md\n'
                printf 'plans: docs/superpowers/plans\n'
            } > "$repo/.dopamine/config"
            ;;
    esac
    printf '%s\n' "$repo"
}

# event TOOL CWD FILE_PATH -- prints a PostToolUse event JSON
event() {
    TOOL="$1" CWD="$2" FP="$3" python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PostToolUse",
    "cwd": os.environ["CWD"],
    "tool_name": os.environ["TOOL"],
    "tool_input": {"file_path": os.environ["FP"]},
    "tool_response": {"filePath": os.environ["FP"], "success": True},
}))'
}

# run_hook REPO EVENT_JSON -- sets RC and OUT
run_hook() {
    RC=0
    OUT=$(printf '%s' "$2" | (cd "$1" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
}

# field JSON DOTTED_PATH -- prints the value, or "none"
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

keys() {
    printf '%s' "$1" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
print(",".join(sorted(json.loads(raw).keys())))'
}

repo=$(make_repo adopted)

echo "-- the guard stays silent unless its predicate holds"
run_hook "$repo" "$(event Edit "$repo" "$repo/docs/DESIGN.md")"
assert_eq "a living-tier file exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

run_hook "$repo" "$(event Edit "$repo" "$repo/docs/LESSONS.md")"
assert_eq "a lessons-tier file injects nothing" "" "$OUT"

run_hook "$repo" "$(event Bash "$repo" "")"
assert_eq "an event with no file_path injects nothing" "" "$OUT"

plain=$(make_repo plain --no-config)
run_hook "$plain" "$(event Edit "$plain" "$plain/CLAUDE.md")"
assert_eq "a repo with no .dopamine/config exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

noinst=$(make_repo noinst --no-instructions)
run_hook "$noinst" "$(event Edit "$noinst" "$noinst/CLAUDE.md")"
assert_eq "a config with no instructions tier injects nothing" "" "$OUT"

run_hook "$repo" "$(event Edit "$repo" "$TEST_ROOT/outside.md")"
assert_eq "a file outside the declared set injects nothing" "" "$OUT"

echo "-- the verdict on an instructions-tier edit"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
assert_eq "exits 0" 0 "$RC"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_eq "uses the nested PostToolUse shape" \
    "PostToolUse" "$(field "$OUT" "hookSpecificOutput.hookEventName")"
assert_contains "reports the file it is talking about" "$ctx" "CLAUDE.md"
assert_contains "reports the line count as a fact" "$ctx" "3 lines"
assert_contains "names the 200-line target" "$ctx" "200-line target"
assert_contains "names the lessons tier from the config" "$ctx" "docs/LESSONS.md"
assert_contains "carries the per-line test" "$ctx" "make mistakes"
assert_contains "points at the skill that holds the judgement" "$ctx" "dopamine:claude-md-guard"

echo "-- a Write is treated the same as an Edit"
run_hook "$repo" "$(event Write "$repo" "$repo/CLAUDE.md")"
assert_contains "Write also gets the verdict" \
    "$(field "$OUT" "hookSpecificOutput.additionalContext")" "make mistakes"

echo "-- growth since HEAD is reported when git can say"
git -C "$repo" add -A >/dev/null 2>&1
git -C "$repo" commit -q -m "init" >/dev/null 2>&1
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_not_contains "a clean tree reports no delta" "$ctx" "since HEAD"
printf -- '- Prefer single tests.\n- Typecheck when done.\n' >> "$repo/CLAUDE.md"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_contains "a dirty tree reports what it adds" "$ctx" "since HEAD"
assert_contains "and the count is real" "$ctx" "adds 2"

echo "-- a second declared instructions path also fires"
printf 'instructions: CLAUDE.local.md\n' >> "$repo/.dopamine/config"
printf '# Local\n' > "$repo/CLAUDE.local.md"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.local.md")"
assert_contains "the second instructions path is matched too" \
    "$(field "$OUT" "hookSpecificOutput.additionalContext")" "CLAUDE.local.md"

echo "-- the flat shape for hosts that do not set CLAUDE_PLUGIN_ROOT"
RC=0
OUT=$(printf '%s' "$(event Edit "$repo" "$repo/CLAUDE.md")" \
    | (cd "$repo" && COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "Copilot's top-level key is exactly additionalContext" "additionalContext" "$(keys "$OUT")"
assert_not_contains "and it is not the nested shape" "$OUT" "hookSpecificOutput"

echo "-- the injected text is budgeted and positively phrased"
words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 175 ]; then
    pass "the injection is within its 175-word budget ($words words)"
else
    fail "the injection is within its 175-word budget" "got: $words words"
fi
if grep -qiE '\b(never|do not|don.t)\b' "$CONTEXT_FILE"; then
    fail "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)" \
         "found a prohibition in $CONTEXT_FILE"
else
    pass "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)"
fi
ctx_body=$(cat "$CONTEXT_FILE")
assert_contains "the injection routes rather than rejects" "$ctx_body" "routed"
assert_contains "and names a destination for a sometimes-relevant line" "$ctx_body" "skill"

echo "-- malformed input is a silent no-op, never a crash"
RC=0
OUT=$(printf 'not json at all' | (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "garbage on stdin exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

RC=0
OUT=$(printf '{"tool_input": []}' | (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "a tool_input of the wrong type exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

echo "-- a non-UTF-8 byte in .dopamine/config is a silent no-op, never a crash"
badrepo=$(make_repo nonutf8)
printf 'instructions: CLAUDE.md\n' > "$badrepo/.dopamine/config"
printf '\xff\xfe garbage\n' >> "$badrepo/.dopamine/config"
stderr_file="$TEST_ROOT/nonutf8.stderr"
RC=0
OUT=$(printf '%s' "$(event Edit "$badrepo" "$badrepo/CLAUDE.md")" \
    | (cd "$badrepo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") 2>"$stderr_file") || RC=$?
ERR=$(cat "$stderr_file")
assert_eq "the guard exits 0 rather than crashing" 0 "$RC"
assert_not_contains "and prints no traceback" "$ERR" "Traceback"
assert_eq "and injects nothing, since a config it cannot read has declared nothing" "" "$OUT"

finish

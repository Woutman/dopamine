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
assert_contains "names the program-design document a plan reads" "$ctx" "PROGRAM-DESIGN.md"
assert_contains "the rules travel through the plan's Global Constraints" "$ctx" "Global Constraints"
assert_contains "the plan holds its own code to each check, a changed line included" "$ctx" "a changed line included"
assert_contains "a gap is settled through the recipe" "$ctx" "dopamine:brainstorm-program-design"
assert_contains "an absent document is asked about once, not stopped on" "$ctx" "ask the human once"
assert_contains "points at superpowers' existing ledger" "$ctx" "ledger"
assert_contains "names the living documents it governs" "$ctx" "living document"
assert_not_contains "no reference to the renamed skill survives" "$ctx" "dopamine:sweep"

# 240, raised from 200: the program-design paragraph has to say where the rules
# go in a plan, what a gap does, and what an absent document does, since the
# plan's author learns all three only from here.
words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 240 ]; then
    pass "the injection is within its 240-word budget ($words words)"
else
    fail "the injection is within its 240-word budget" "got: $words words"
fi

assert_contains "the glossary waits for the sweep too" \
    "$ctx" "living document or the glossary mid-execution"

echo "-- the glossary pointer"
# glossary_repo NAME CONFIG [FILE...] -- a repo with CONFIG and each FILE present
glossary_repo() {
    local dir="$TEST_ROOT/$1" config="$2" file
    shift 2
    mkdir -p "$dir/.dopamine"
    git init -q "$dir"
    printf '%b' "$config" > "$dir/.dopamine/config"
    for file in "$@"; do
        mkdir -p "$(dirname "$dir/$file")"
        printf -- '- **term** — x\n' > "$dir/$file"
    done
    printf '%s' "$dir"
}
context_in() {
    field "$( (cd "$1" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )" \
        "hookSpecificOutput.additionalContext"
}

g=$(context_in "$(glossary_repo present 'glossary: docs/GLOSSARY.md\n' docs/GLOSSARY.md)")
assert_contains "points at the declared glossary" "$g" 'defined one per line in `docs/GLOSSARY.md`'
assert_contains "names the Grep tool" "$g" "with the Grep tool"
g=$(context_in "$(glossary_repo elsewhere 'glossary: notes/TERMS.md\n' notes/TERMS.md)")
assert_contains "uses the declared path" "$g" '`notes/TERMS.md`'
assert_not_contains "no pointer when undeclared" "$ctx" "Grep tool"
g=$(context_in "$(glossary_repo absent 'glossary: docs/GLOSSARY.md\n')")
assert_not_contains "no pointer when the file is absent" "$g" "Grep tool"
g=$(context_in "$(glossary_repo crlf 'glossary: docs/GLOSSARY.md  \r\n' docs/GLOSSARY.md)")
assert_contains "trailing space and CR are ignored" "$g" '`docs/GLOSSARY.md`. When'
g=$(context_in "$(glossary_repo twice 'glossary: a.md\nglossary: b.md\n' a.md b.md)")
assert_eq "the first declaration wins, once" 1 "$(grep -o 'Grep tool' <<< "$g" | wc -l | tr -d ' ')"
assert_contains "and it is the first" "$g" '`a.md`'

echo "-- survives a SessionStart spawned with a broken PATH (anthropics/claude-code#43127)"
WRAPPER="$REPO_ROOT/hooks/run-hook.cmd"
BASH_ABS=$(command -v bash)
out=$( (cd "$adopted" && PATH=/nonexistent CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    "$BASH_ABS" "$WRAPPER" session-start) 2>/dev/null ) || true
assert_eq "the wrapper still injects the context with PATH unusable" \
    "SessionStart" "$(field "$out" "hookSpecificOutput.hookEventName")"
out=$( (cd "$adopted/.dopamine" && PATH=/nonexistent CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    "$BASH_ABS" "$UNDER_TEST") 2>/dev/null ) || true
assert_eq "and finds the repository root from a subdirectory without git" \
    "SessionStart" "$(field "$out" "hookSpecificOutput.hookEventName")"
out=$( (cd "$plain" && PATH=/nonexistent CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    "$BASH_ABS" "$UNDER_TEST") 2>/dev/null ) || true
assert_eq "and stays silent in an unadopted repository" "" "$out"

echo "-- the Windows half of the wrapper (superpowers v7 hardening)"
wrapper=$(cat "$WRAPPER")
assert_contains "finds a per-user Git for Windows install" "$wrapper" '%LOCALAPPDATA%\Programs\Git\bin\bash.exe'
assert_contains "searches PATH only, never the current directory" "$wrapper" '$PATH:bash'
assert_contains "skips the WSL launchers" "$wrapper" '%SystemRoot%\System32\'
assert_not_contains "no bare where lookup a repository could shadow" "$wrapper" 'where bash'
# Unindented, so not inside a parenthesised block, where cmd expands
# %ERRORLEVEL% when it parses the block rather than after bash returns.
run_then_exit=$(grep -A1 -E '^"%BASH_EXE%" ' "$WRAPPER" | tail -n 1)
assert_eq "runs bash outside a block so the exit code survives" \
    "exit /b %ERRORLEVEL%" "$run_then_exit"

echo "-- the injection is a conditional, not a prohibition"
if grep -qiE '\b(never|do not|don.t)\b' "$CONTEXT_FILE"; then
    fail "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)" \
         "found a prohibition in $CONTEXT_FILE"
else
    pass "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)"
fi

finish

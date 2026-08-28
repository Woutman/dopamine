#!/usr/bin/env bash
# The shipped rule card is a machine-readable artifact as well as a document:
# refresh-rule-card parses its source lines, and the guard skill links to it.
# These assertions are about the card that ships, not about a fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

CARD="$REPO_ROOT/skills/claude-md-guard/claude-md-best-practices.md"

if [ ! -f "$CARD" ]; then
    fail "the rule card exists" "not found at $CARD"
    finish
fi

body=$(cat "$CARD")

echo "-- the standard the guard applies"
assert_contains "carries the per-line test verbatim" "$body" \
    "Would removing this cause Claude to make mistakes?"
assert_contains "carries the include column" "$body" "Include"
assert_contains "carries the exclude column" "$body" "Exclude"
assert_contains "carries the 200-line target" "$body" "200 lines"
assert_contains "routes sometimes-relevant content to a skill" "$body" "skill"
assert_contains "names the /doctor trim pass" "$body" "/doctor"
assert_contains "carries its distillation date" "$body" "2026-08-28"

echo "-- the machine-readable source lines"
mapfile -t sources < <(grep -E '^[[:space:]]*source:' "$CARD")
assert_eq "declares exactly three source sections" 3 "${#sources[@]}"

missing=""
notmd=""
for line in "${sources[@]}"; do
    trimmed=${line#*source:}
    url=$(printf '%s' "${trimmed%%|*}" | tr -d ' ')
    rest=${trimmed#*|}
    snap=$(printf '%s' "${rest#*|}" | tr -d ' ')
    case "$url" in
        https://code.claude.com/docs/en/*.md) ;;
        *) notmd="$notmd $url" ;;
    esac
    [ -f "$REPO_ROOT/skills/claude-md-guard/$snap" ] || missing="$missing $snap"
done
assert_eq "every source is a raw-markdown docs URL" "" "$notmd"
assert_eq "every declared snapshot exists" "" "$missing"

echo "-- the snapshots are real captures, not stubs"
for snap in "$REPO_ROOT"/skills/claude-md-guard/sources/*.md; do
    [ -f "$snap" ] || continue
    name=$(basename "$snap")
    first=$(head -1 "$snap")
    case "$first" in
        '###'*) pass "$name: opens with the heading it captured" ;;
        *) fail "$name: opens with the heading it captured" "got: $first" ;;
    esac
    bytes=$(wc -c < "$snap" | tr -d ' ')
    if [ "$bytes" -ge 500 ]; then
        pass "$name: is a whole section ($bytes bytes)"
    else
        fail "$name: is a whole section" "only $bytes bytes — a truncated extraction"
    fi
done

echo "-- the fenced example survived extraction"
bp="$REPO_ROOT/skills/claude-md-guard/sources/best-practices-write-an-effective-claude-md.md"
if [ -f "$bp" ]; then
    snap=$(cat "$bp")
    assert_contains "the fenced example CLAUDE.md is present" "$snap" "# Workflow"
    assert_contains "and so is the text after it" "$snap" "Keep it concise"
    assert_not_contains "extraction stopped at the next section" "$snap" "Configure permissions"
else
    fail "the best-practices snapshot exists" "not found"
fi

finish

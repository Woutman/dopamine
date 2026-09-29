#!/usr/bin/env bash
# Content assertions for dopamine:writing-code-comments. The structure test
# checks frontmatter and budget; this checks the contract is the one the
# baseline was run against, and that the example cannot be copied into the
# baseline's own fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

skill="$REPO_ROOT/skills/writing-code-comments/SKILL.md"
if [ ! -f "$skill" ]; then
    fail "skills/writing-code-comments/SKILL.md exists" "not found"
    finish
fi
body=$(cat "$skill")

echo "-- the contract"
contract=$(awk '/^## The contract$/{flag=1; next} /^## /{flag=0} flag' "$skill")
assert_contains "the contract is a blockquote, so it can be copied whole" "$contract" "> "
assert_contains "a comment may state why" "$contract" "**why**"
assert_contains "a comment may state a public interface's contract" "$contract" "**contract**"
assert_contains "a comment may state a warning" "$contract" "**warning**"
assert_contains "doc comments follow the language's own format" \
    "$contract" "standard doc-comment format"
assert_contains "one reason, briefly" "$contract" "as briefly as"
assert_contains "a design's argument has a home" "$contract" "the spec or the plan's prose"
assert_contains "the change's story has a home" "$contract" "commit message"
assert_contains "a comment the change makes false is its business" "$body" "makes false"

echo "-- what it leaves out"
assert_not_contains "no density clause to negotiate with" "$body" "density"
for word in station reading inbox POISON; do
    assert_not_contains "its example is not the baseline's fixture ($word)" "$body" "$word"
done
assert_eq "no supporting files" "SKILL.md" "$(ls "$REPO_ROOT/skills/writing-code-comments")"

finish

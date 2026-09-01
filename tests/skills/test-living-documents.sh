#!/usr/bin/env bash
# Content assertions for the schema skill.
#
# tests/skills/test-skill-structure.sh checks what every skill must have. This
# file checks the thing that made the skill worth extracting: that each living
# document's slots exist in exactly one place, reachable from both consumers —
# the authoring recipe that creates the document, and dopamine:finishing-work,
# which edits it for the rest of the project's life.
#
# The Iron Law of superpowers:writing-skills is waived for this plugin
# (spec section 8), so nothing here is a pressure scenario.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

DIR="$REPO_ROOT/skills/writing-living-documents"

echo "-- the skill exists and links all three schemas"
if [ -f "$DIR/SKILL.md" ]; then
    pass "skills/writing-living-documents/SKILL.md exists"
    body=$(cat "$DIR/SKILL.md")
    assert_contains "it points at the routing skill for which document" \
        "$body" "dopamine:routing-documentation-updates"
    assert_contains "a document is a fixed set of slots" "$body" "slots"
    assert_contains "a change replaces what it makes wrong" "$body" "Change what changed"
    assert_contains "a run's number is cited from the ledger, not copied in" \
        "$body" "sealed ledger"
    for schema in design architecture roadmap; do
        assert_contains "SKILL.md links $schema-schema.md" "$body" "$schema-schema.md"
    done
else
    fail "skills/writing-living-documents/SKILL.md exists" "not found"
fi

echo "-- each schema names its own document's slots"
check_schema() {
    local file="$1"; shift
    if [ ! -f "$DIR/$file" ]; then
        fail "$file exists" "not found"
        return
    fi
    pass "$file exists"
    local sbody
    sbody=$(cat "$DIR/$file")
    local slot
    for slot in "$@"; do
        assert_contains "$file declares the '$slot' slot" "$sbody" "$slot"
    done
}

check_schema design-schema.md \
    "What this is" "The problem" "What it must do" \
    "The shape of the solution" "Principles" "Not this" "Open questions"
check_schema architecture-schema.md \
    "The assembly" "How they talk" "Where state lives" \
    "When it fails" "What runs where" "Not this"
check_schema roadmap-schema.md \
    "What drives the order" "The phases" "External asks" \
    "Lands" "Why here" "Exit" "Observations, not assertions"

echo "-- both consumers reach every schema through CLAUDE_PLUGIN_ROOT"
for pair in "brainstorm-design:design-schema.md" \
            "brainstorm-architecture:architecture-schema.md" \
            "writing-roadmaps:roadmap-schema.md"; do
    skill="${pair%%:*}"; schema="${pair#*:}"
    sbody=$(cat "$REPO_ROOT/skills/$skill/SKILL.md")
    assert_contains "$skill reaches its schema through the plugin root" \
        "$sbody" "\${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/$schema"
    assert_contains "$skill names the skill that holds the writing rules" \
        "$sbody" "dopamine:writing-living-documents"
done
abody=$(cat "$REPO_ROOT/skills/adopting-a-repo/SKILL.md")
assert_contains "adoption reaches the schemas directly, not via the recipes" \
    "$abody" "\${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/"
assert_contains "adoption names the skill that holds the writing rules" \
    "$abody" "dopamine:writing-living-documents"

echo "-- a slot table lives in exactly one place"
# The extraction only pays off if the tables did not stay behind. A slot header
# is unique enough to catch a copy: if it appears in an authoring skill as well
# as its schema, both are now maintained and one will drift.
for pair in "brainstorm-design:Open questions" \
            "brainstorm-architecture:Where state lives" \
            "writing-roadmaps:Observations, not assertions"; do
    skill="${pair%%:*}"; slot="${pair#*:}"
    assert_not_contains "$skill no longer carries the '$slot' slot itself" \
        "$(cat "$REPO_ROOT/skills/$skill/SKILL.md")" "$slot"
done

finish

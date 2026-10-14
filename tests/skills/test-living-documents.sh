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

echo "-- the skill exists and links all four schemas"
if [ -f "$DIR/SKILL.md" ]; then
    pass "skills/writing-living-documents/SKILL.md exists"
    body=$(cat "$DIR/SKILL.md")
    assert_contains "it points at the routing skill for which document" \
        "$body" "dopamine:routing-documentation-updates"
    assert_contains "a document is a fixed set of slots" "$body" "slots"
    assert_contains "a change replaces what it makes wrong" "$body" "Change what changed"
    assert_contains "a run's number is cited from the ledger, not copied in" \
        "$body" "sealed ledger"
    for schema in design architecture roadmap program-design; do
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
check_schema program-design-schema.md \
    "Types" "Errors" "Effects" "Signatures" "Layout" "Modules" \
    "Concurrency" "Persistence" "Public surface" "Project slots" "Not this" \
    "Inherited default" "how to check a diff against it" "Python"
assert_contains "the architecture defers how code inside a component is shaped" \
    "$(cat "$DIR/architecture-schema.md")" "PROGRAM-DESIGN.md"
arch=$(cat "$DIR/architecture-schema.md")
assert_contains "How they talk opens with the depth principle" "$arch" "The depth principle"
assert_contains "an exception to it is named with its reason" "$arch" "named exception"
assert_contains "each component's row says what it offers" "$arch" "Offers its callers"
assert_contains "and what must hold at its interface" "$arch" "Must hold"
assert_contains "offers are operations and data, never types" "$arch" "never types or signatures"
assert_contains "depth at the boundary is decided here" "$arch" "Depth **at** a component's boundary"
assert_contains "enforcement and admission are the Modules slot" \
    "$arch" "is \`PROGRAM-DESIGN.md\`'s **Modules** slot"
assert_contains "arrangement inside a component is the Layout slot" "$arch" "its **Layout** slot"
assert_not_contains "depth is no longer deferred wholesale" "$arch" "the depth of its interfaces included"
pd=$(cat "$DIR/program-design-schema.md")
assert_contains "Modules asks where the public surface lives" \
    "$pd" "Where does each component's public surface live"
assert_contains "and when an abstraction is admitted" "$pd" "when is a new module, layer or abstraction admitted"
assert_contains "the default names superpowers' pull" "$pd" "pulls towards smaller units"
assert_not_contains "Modules no longer only pulls both ways" "$pd" "pulls both ways"
assert_contains "the worked example carries the boundary rule" "$pd" "**Rule (boundary):**"
assert_contains "its check catches a reach-in" "$pd" "reaches past its \`__init__.py\`"
assert_contains "and a widened surface is named in the plan" "$pd" "named in the plan"
assert_contains "the worked example carries the admission rule" "$pd" "**Rule (admission):**"
assert_contains "a test fake counts as a second implementation" "$pd" "a test fake counts as a second one"
assert_contains "the surface's location is the variable part" "$pd" "\`api.py\`"
assert_contains "the schema skill's trigger names the new document" \
    "$(cat "$DIR/SKILL.md")" "PROGRAM-DESIGN.md"

echo "-- both consumers reach every schema through CLAUDE_PLUGIN_ROOT"
for pair in "brainstorm-design:design-schema.md" \
            "brainstorm-architecture:architecture-schema.md" \
            "writing-roadmaps:roadmap-schema.md" \
            "brainstorm-program-design:program-design-schema.md"; do
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
            "writing-roadmaps:Observations, not assertions" \
            "brainstorm-program-design:Public surface"; do
    skill="${pair%%:*}"; slot="${pair#*:}"
    assert_not_contains "$skill no longer carries the '$slot' slot itself" \
        "$(cat "$REPO_ROOT/skills/$skill/SKILL.md")" "$slot"
done

finish

#!/usr/bin/env bash
# Content assertions for slice 3's authoring skills.
#
# tests/skills/test-skill-structure.sh checks what every skill must have:
# valid frontmatter, a trigger-shaped description, a word budget, no @-link
# force-loads, resolvable references. This file checks what these four must
# SAY — the contracts a reader would lose if the text drifted while every
# structural check still passed.
#
# The Iron Law of superpowers:writing-skills is waived for this plugin
# (spec section 10), so nothing here is a pressure scenario.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

# Existence is asserted here, not inside read_skill: read_skill runs in a
# command substitution, where fail()'s FAILURES increment dies with the
# subshell and its message would be captured as the body under test.
assert_skill_exists() {
    local name="$1"
    if [ -f "$REPO_ROOT/skills/$name/SKILL.md" ]; then
        pass "skills/$name/SKILL.md exists"
    else
        fail "skills/$name/SKILL.md exists" "not found"
    fi
}

read_skill() {
    local path="$REPO_ROOT/skills/$1/SKILL.md"
    [ -f "$path" ] && cat "$path"
}

echo "-- brainstorm-design"
assert_skill_exists brainstorm-design
body=$(read_skill brainstorm-design)
assert_contains "it wraps superpowers' brainstorming rather than replacing it" \
    "$body" "superpowers:brainstorming"
assert_contains "it resolves the terminal-state clash with writing-plans" \
    "$body" "writing-plans"
assert_contains "it says the implementation still arrives one phase at a time" \
    "$body" "one roadmap phase at a time"
assert_contains "the spec survives the derivation rather than being superseded" \
    "$body" "frozen"
assert_contains "it reads its output path from the config" "$body" "artifact-paths"
assert_contains "an unadopted repository is routed, not guessed at" \
    "$body" "dopamine:adopting-a-repo"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "the document has a non-goals slot" "$body" "Not this"
assert_contains "the document has an open-questions slot" "$body" "Open questions"
assert_contains "it names the successor that answers what it defers" \
    "$body" "dopamine:brainstorm-architecture"

echo "-- brainstorm-architecture"
assert_skill_exists brainstorm-architecture
body=$(read_skill brainstorm-architecture)
assert_contains "it points at the wrapper contract instead of restating it" \
    "$body" "dopamine:brainstorm-design"
assert_contains "the design document is its input" "$body" "DESIGN.md"
assert_contains "it reads its output path from the config" "$body" "artifact-paths"
assert_contains "the document says where state lives" "$body" "Where state lives"
assert_contains "the document says what failure looks like from outside" \
    "$body" "When it fails"
assert_contains "the document records the assemblies rejected" "$body" "Not this"
assert_contains "a number describing a run is cited, not copied in" \
    "$body" "sealed ledger"
assert_contains "it names the successor that orders the work" \
    "$body" "dopamine:writing-roadmaps"
assert_contains "a wrong requirement is a finding for the design, not a quiet re-decision" \
    "$body" "not something this brainstorm quietly redecides"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"

echo "-- writing-roadmaps"
assert_skill_exists writing-roadmaps
body=$(read_skill writing-roadmaps)
assert_contains "a phase is defined by analogy to a superpowers plan" \
    "$body" "smallest unit that makes one good plan"
assert_contains "it names the loop a phase maps onto" "$body" "superpowers:writing-plans"
assert_contains "both living documents are its inputs" "$body" "ARCHITECTURE.md"
assert_contains "order comes from dependency and from risk" "$body" "Risk"
assert_contains "each phase says what exists at the end" "$body" "Lands"
assert_contains "each phase says why it sits where it does" "$body" "Why here"
assert_contains "an exit criterion is observed, not asserted" \
    "$body" "Observations, not assertions"
assert_contains "external asks are named with the phase that needs them" \
    "$body" "critical path"
assert_contains "a closed phase is struck through rather than deleted" \
    "$body" "struck through"
assert_contains "a struck phase points at the sealed ledger as its audit trail" \
    "$body" "sealed ledger"
assert_contains "the struck line carries the pointer and no claim about the present" \
    "$body" "and nothing else"
assert_contains "dates are excluded as a metric that moves without the system" \
    "$body" "Dates and durations"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it locates its own output at the declared path" \
    "$body" "The roadmap is the declared path whose basename is"

echo "-- adopting-a-repo"
assert_skill_exists adopting-a-repo
body=$(read_skill adopting-a-repo)
assert_contains "adoption is named as the one O(project) cost, paid once" \
    "$body" "O(project)"
assert_contains "everything after adoption is O(change)" "$body" "O(change)"
assert_contains "it writes the config that every other component reads" \
    "$body" ".dopamine/config"
assert_contains "it verifies the config it wrote" "$body" "artifact-paths"
assert_contains "the no-code branch routes to the brainstorm instead" \
    "$body" "dopamine:brainstorm-design"
assert_contains "the survey is dispatched, not read into this session" \
    "$body" "survey-prompt.md"
assert_contains "what the code states and what it implies are never mixed" \
    "$body" "Reconstructed, unconfirmed"
assert_contains "the reason a component exists is named as unreadable from code" \
    "$body" "Code carries what, not why"
assert_contains "an instructions-tier candidate goes through the admission test" \
    "$body" "dopamine:writing-claude-md"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"

echo "-- adopting-a-repo survey prompt"
survey="$REPO_ROOT/skills/adopting-a-repo/survey-prompt.md"
if [ -f "$survey" ]; then
    sbody=$(cat "$survey")
    assert_contains "the prompt documents its placeholders" "$sbody" "Placeholders:"
    assert_contains "which document is being surveyed decides what is read" \
        "$sbody" "{DOCUMENT}"
    assert_contains "a read fact carries the path it was read at" "$sbody" "path:line"
    assert_contains "an inference is labelled as one" "$sbody" "Inferred"
    assert_contains "a question the code cannot answer is returned, not answered" \
        "$sbody" "Questions"
    assert_contains "what was not read is reported too" "$sbody" "Not surveyed"
    assert_contains "the survey returns a file rather than prose" \
        "$sbody" "{FINDINGS_PATH}"
else
    fail "skills/adopting-a-repo/survey-prompt.md exists" "not found"
fi

finish

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
# (spec section 8), so nothing here is a pressure scenario.
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
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
assert_contains "an unadopted repository is routed, not guessed at" \
    "$body" "dopamine:adopting-a-repo"
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it hands the document's shape to the schema skill" \
    "$body" "design-schema.md"
assert_contains "it names the successor that answers what it defers" \
    "$body" "dopamine:brainstorm-architecture"

echo "-- brainstorm-architecture"
assert_skill_exists brainstorm-architecture
body=$(read_skill brainstorm-architecture)
assert_contains "it points at the wrapper contract instead of restating it" \
    "$body" "dopamine:brainstorm-design"
assert_contains "the design document is its input" "$body" "DESIGN.md"
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
assert_contains "a number describing a run is cited, not copied in" \
    "$body" "sealed ledger"
assert_contains "it names the successor that orders the work" \
    "$body" "dopamine:writing-roadmaps"
assert_contains "a wrong requirement is a finding for the design, not a quiet re-decision" \
    "$body" "not something this brainstorm quietly redecides"
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it hands the document's shape to the schema skill" \
    "$body" "architecture-schema.md"
assert_contains "it names the program-design recipe as what comes next" \
    "$body" "dopamine:brainstorm-program-design"
assert_contains "the brainstorm asks what each component offers" \
    "$body" "what each component offers its callers"
assert_contains "and what must hold at each interface" "$body" "what must hold at each interface"
assert_contains "it recommends deep boundaries, exceptions named" "$body" "recommending deep"
assert_contains "program design is named before the roadmap" \
    "$body" "\`PROGRAM-DESIGN.md\`, then \`ROADMAP.md\`"

echo "-- writing-roadmaps"
assert_skill_exists writing-roadmaps
body=$(read_skill writing-roadmaps)
assert_contains "a phase is defined by analogy to a superpowers plan" \
    "$body" "smallest unit that makes one good plan"
assert_contains "it names the loop a phase maps onto" "$body" "superpowers:writing-plans"
assert_contains "both living documents are its inputs" "$body" "ARCHITECTURE.md"
assert_contains "order comes from dependency and from risk" "$body" "Risk"
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
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it locates its own output at the declared path" \
    "$body" "The roadmap is the declared path whose basename is"
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
assert_contains "it hands the phase shape to the schema skill" \
    "$body" "roadmap-schema.md"
assert_contains "program design is still read for risk" "$body" "also read for risk"
assert_not_contains "its absence no longer blocks nothing" "$body" "blocks nothing"
assert_contains "a new roadmap or new phases wait for Modules" \
    "$body" "Writing a roadmap, or adding phases"
assert_contains "it hands off to the program-design recipe" "$body" "dopamine:brainstorm-program-design"
assert_contains "a close still proceeds, with Modules named pending" \
    "$body" "Striking a closed phase, or re-ordering what remains** — proceed"
assert_contains "and the pending line is said" "$body" "name Modules as pending"

echo "-- adopting-a-repo"
assert_skill_exists adopting-a-repo
body=$(read_skill adopting-a-repo)
assert_contains "adoption is named as the one O(project) cost, paid once" \
    "$body" "O(project)"
assert_contains "everything after adoption is O(change)" "$body" "O(change)"
assert_contains "it writes the config that every other component reads" \
    "$body" ".dopamine/config"
assert_contains "it reads back the config it wrote" "$body" "read it back"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
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
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it declares the program-design document" \
    "$body" "living: docs/PROGRAM-DESIGN.md"
assert_contains "observed practice is a candidate, never a rule" \
    "$body" "never written here"
assert_contains "it hands the survey to the recipe" \
    "$body" "dopamine:brainstorm-program-design"
assert_contains "offers are read from what callers use" "$body" "what callers actually use"
assert_contains "must-hold is inferred, not read" "$body" "*Must hold* is rarely readable from code"
assert_contains "adoption never writes the depth principle" "$body" "The depth principle is never written here"
assert_contains "a reach-in becomes a question for the human" "$body" "widen that component's interface"

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
    assert_contains "the survey knows what to read for program design" \
        "$sbody" "A program-design document"
    assert_contains "the architecture survey reads what callers import" "$sbody" "actually import from it"
    assert_contains "and every reach-in" "$sbody" "reaches past a component's public surface"
else
    fail "skills/adopting-a-repo/survey-prompt.md exists" "not found"
fi

echo "-- brainstorm-program-design"
assert_skill_exists brainstorm-program-design
body=$(read_skill brainstorm-program-design)
assert_contains "it points at the wrapper contract instead of restating it" \
    "$body" "dopamine:brainstorm-design"
assert_contains "it wraps superpowers' brainstorming" "$body" "superpowers:brainstorming"
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_contains "an absent architecture sends it back a step" \
    "$body" "dopamine:brainstorm-architecture"
assert_contains "the human picks every rule" "$body" "The human picks"
assert_contains "it writes nothing until every slot is answered" "$body" "Write nothing"
for element in "Superpowers' default" "Observed practice" "recommendation" "alternative"; do
    assert_contains "each slot question shows: $element" "$body" "$element"
done
assert_contains "module depth is never inherited silently" "$body" "Modules is always asked"
assert_contains "taking the recommendations still leaves Modules asked" "$body" "every slot but Modules"
assert_contains "Modules reads the boundaries architecture drew" "$body" "*How they talk*"
assert_contains "and enforces them rather than re-deciding them" "$body" "rather than re-deciding them"
assert_contains "every rule carries a check" "$body" "check"
assert_contains "Python's idiom takes precedence" "$body" "Python"
assert_contains "a gap raised by a plan revises one slot in place" "$body" "in place"
assert_contains "it names the roadmap as pending" "$body" "ROADMAP.md"
assert_contains "it points at routing-documentation-updates rather than restating it" \
    "$body" "dopamine:routing-documentation-updates"
assert_contains "it answers R0's template reason" "$body" "The schema is the template"
assert_contains "and its imitation reason" "$body" "The code shows what was done"

finish

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
    "$body" "dopamine:artifact-map"
assert_contains "the document has a non-goals slot" "$body" "Not this"
assert_contains "the document has an open-questions slot" "$body" "Open questions"
assert_contains "it names the successor that answers what it defers" \
    "$body" "dopamine:brainstorm-architecture"

finish

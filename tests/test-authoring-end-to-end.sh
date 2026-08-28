#!/usr/bin/env bash
# The authoring skills, end to end, offline.
#
# Every unit test above reads one file by its own path, so all of them keep
# passing after a rename that leaves the plugin pointing at nothing. This one
# checks the chains between the files: that every dopamine:<name> reference
# resolves, that the ordered hand-off from design to architecture to roadmap is
# unbroken, and that the config block the documentation shows a human is a config
# artifact-paths can actually read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "-- every dopamine:<skill> reference resolves to a skill that exists"
unresolved=""
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -f "$REPO_ROOT/skills/$ref/SKILL.md" ] || unresolved="$unresolved $ref"
done < <(grep -rhoE 'dopamine:[a-z][a-z-]*' "$REPO_ROOT/skills" "$REPO_ROOT/hooks" "$REPO_ROOT/README.md" "$REPO_ROOT/.dopamine/config" \
    | sed 's/^dopamine://' | sort -u)
if [ -z "$unresolved" ]; then
    pass "every dopamine:<skill> reference resolves"
else
    fail "every dopamine:<skill> reference resolves" "unresolved:$unresolved"
fi

echo "-- the authoring order is an unbroken chain"
design="$REPO_ROOT/skills/brainstorm-design/SKILL.md"
arch="$REPO_ROOT/skills/brainstorm-architecture/SKILL.md"
road="$REPO_ROOT/skills/writing-roadmaps/SKILL.md"
adopt="$REPO_ROOT/skills/adopting-a-repo/SKILL.md"
assert_contains "design hands off to architecture" \
    "$(cat "$design")" "dopamine:brainstorm-architecture"
assert_contains "architecture hands off to the roadmap" \
    "$(cat "$arch")" "dopamine:writing-roadmaps"
assert_contains "architecture names the design as its predecessor" \
    "$(cat "$arch")" "dopamine:brainstorm-design"
assert_contains "the roadmap names both of its inputs" \
    "$(cat "$road")" "dopamine:brainstorm-architecture"
assert_contains "the roadmap names its other input too" \
    "$(cat "$road")" "dopamine:brainstorm-design"
assert_contains "adoption reaches the roadmap recipe" \
    "$(cat "$adopt")" "dopamine:writing-roadmaps"
assert_contains "adoption reaches the architecture recipe" \
    "$(cat "$adopt")" "dopamine:brainstorm-architecture"
assert_contains "adoption reaches the design recipe" \
    "$(cat "$adopt")" "dopamine:brainstorm-design"

echo "-- every root-relative reference to artifact-paths points at the real script"
# The sweep names it `scripts/artifact-paths`, relative to itself; every other
# skill names it from the repository root. Only that second form is checkable
# here, and it is the one a rename or a move would break.
spellings=$(grep -rhoE 'skills/[A-Za-z0-9_/-]*artifact-paths' "$REPO_ROOT/skills" | sort -u)
assert_eq "one root-relative spelling, and it is the shipped path" \
    "skills/sweep/scripts/artifact-paths" "$spellings"
assert_eq "and that path is executable" "yes" \
    "$([ -x "$REPO_ROOT/skills/sweep/scripts/artifact-paths" ] && echo yes || echo no)"

echo "-- the documented config is one config, in both places that show it"
extract_config() {
    awk '/^living: docs\/DESIGN.md$/,/^plans: docs\/superpowers\/plans$/' "$1"
}
from_skill=$(extract_config "$adopt")
from_readme=$(extract_config "$REPO_ROOT/README.md")
assert_eq "the skill's config block is non-empty" "6" "$(printf '%s\n' "$from_skill" | grep -c ':')"
assert_eq "the skill and the README show the same config" "$from_readme" "$from_skill"

echo "-- that config is one artifact-paths can read"
repo="$TEST_ROOT/project"
mkdir -p "$repo/.dopamine"
git init -q "$repo" 2>/dev/null
printf '%s\n' "$from_skill" > "$repo/.dopamine/config"
rows=$("$REPO_ROOT/skills/sweep/scripts/artifact-paths" "$repo" 2>/dev/null)
rc=$?
assert_eq "artifact-paths accepts the documented config" "0" "$rc"
assert_eq "it declares six paths" "6" "$(printf '%s\n' "$rows" | grep -c .)"
assert_eq "three of them are the living tier" "3" \
    "$(printf '%s\n' "$rows" | grep -c '^living')"
assert_eq "and all of them are absent in a fresh repository" "6" \
    "$(printf '%s\n' "$rows" | grep -c 'absent$')"

echo "-- every living document a config declares has a recipe that authors it"
for pair in "DESIGN.md:brainstorm-design" \
            "ARCHITECTURE.md:brainstorm-architecture" \
            "ROADMAP.md:writing-roadmaps"; do
    doc="${pair%%:*}"; owner="${pair#*:}"
    assert_contains "$doc is named by the recipe that produces it" \
        "$(cat "$REPO_ROOT/skills/$owner/SKILL.md")" "$doc"
done

echo "-- an unadopted repository is routed rather than guessed at"
bare="$TEST_ROOT/bare"
mkdir -p "$bare"
assert_exit "artifact-paths exits 3 with no config" 3 \
    "$REPO_ROOT/skills/sweep/scripts/artifact-paths" "$bare"
assert_contains "and the recipe that meets that exit names the way out" \
    "$(cat "$design")" "dopamine:adopting-a-repo"

finish

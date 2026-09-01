#!/usr/bin/env bash
# The authoring skills, end to end, offline.
#
# Every unit test above reads one file by its own path, so all of them keep
# passing after a rename that leaves the plugin pointing at nothing. This one
# checks the chains between the files: that every dopamine:<name> reference
# resolves, that the ordered hand-off from design to architecture to roadmap is
# unbroken, and that the config block the documentation shows a human is
# well-formed under the format the skills describe.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

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
assert_contains "the roadmap names its architecture input" \
    "$(cat "$road")" "dopamine:brainstorm-architecture"
assert_contains "the roadmap names its design input" \
    "$(cat "$road")" "dopamine:brainstorm-design"
assert_contains "adoption reaches the roadmap recipe" \
    "$(cat "$adopt")" "dopamine:writing-roadmaps"
assert_contains "adoption reaches the architecture recipe" \
    "$(cat "$adopt")" "dopamine:brainstorm-architecture"
assert_contains "adoption reaches the design recipe" \
    "$(cat "$adopt")" "dopamine:brainstorm-design"

echo "-- every \${CLAUDE_PLUGIN_ROOT} path a skill names resolves"
# The gap this closes: a skill runs with the *user's* repository as its working
# directory, so a plugin-relative path only works when it is spelled through the
# plugin root. Checking that those spellings resolve is what stops a rename
# leaving the shipped plugin pointing at nothing.
missing=""
while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$REPO_ROOT/$rel" ] || missing="$missing $rel"
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$REPO_ROOT/skills" \
    | sed 's|${CLAUDE_PLUGIN_ROOT}/||' | sed 's|/$||' | sort -u)
if [ -z "$missing" ]; then
    pass "every \${CLAUDE_PLUGIN_ROOT} path resolves"
else
    fail "every \${CLAUDE_PLUGIN_ROOT} path resolves" "missing:$missing"
fi

echo "-- no skill names a script this change deleted"
leftover=$(grep -rhoE '(artifact-paths|seal-ledger|sweep-package)' "$REPO_ROOT/skills" | sort -u)
assert_eq "artifact-paths, seal-ledger and sweep-package are gone from the skills" \
    "" "$leftover"

echo "-- the documented config is one config, in both places that show it"
extract_config() {
    awk '/^living: docs\/DESIGN.md$/,/^plans: docs\/superpowers\/plans$/' "$1"
}
from_skill=$(extract_config "$adopt")
from_readme=$(extract_config "$REPO_ROOT/README.md")
assert_eq "the skill and the README show the same config" "$from_readme" "$from_skill"

echo "-- the documented config is well-formed under the format the skills describe"
# Each line is `tier: path`. There is no parser any more -- the consumer is an
# LLM reading the file -- so what is worth checking is that the block every
# document shows a human is actually in that shape.
malformed=$(printf '%s\n' "$from_skill" | grep -vE '^[a-z]+: [A-Za-z0-9._/-]+$' | grep -c . || true)
assert_eq "every documented line is one tier: path pair" "0" "$malformed"
assert_eq "it declares six paths" "6" "$(printf '%s\n' "$from_skill" | grep -c ':')"
assert_eq "three of them are the living tier" "3" \
    "$(printf '%s\n' "$from_skill" | grep -c '^living:')"

echo "-- every living document a config declares has a recipe that authors it"
for pair in "DESIGN.md:brainstorm-design" \
            "ARCHITECTURE.md:brainstorm-architecture" \
            "ROADMAP.md:writing-roadmaps"; do
    doc="${pair%%:*}"; owner="${pair#*:}"
    assert_contains "$doc is named by the recipe that produces it" \
        "$(cat "$REPO_ROOT/skills/$owner/SKILL.md")" "$doc"
done

echo "-- an unadopted repository is routed rather than guessed at"
assert_contains "the recipe names the absence of the config as the trigger" \
    "$(cat "$design")" ".dopamine/config"
assert_contains "and names the way out" "$(cat "$design")" "dopamine:adopting-a-repo"

finish

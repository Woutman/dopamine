#!/usr/bin/env bash
# Structural tests for every skill in the plugin.
#
# The Iron Law of superpowers:writing-skills — no skill without a failing
# pressure-scenario test first — is deliberately waived here (spec section 10).
# These tests therefore check structure and budget, not behaviour: frontmatter is
# valid, the description is a trigger rather than a workflow summary, referenced
# files exist, no @-link force-loads context, and the word budget holds.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

# skill-name:max-words
# These are ratchets, not targets. A budget is raised only with a recorded reason.
# artifact-map was 500 and is raised to 600 here: it gains a paragraph describing
# the config format, which was an 87-line script the skill could point at instead.
# The four authoring skills keep the budgets they were merged with even though this
# change moves their slot tables out, so the headroom stays visible rather than spent.
# writing-claude-md was 500 and is raised to 550: nothing intercepts an edit to
# CLAUDE.md any more, so the skill has to say where its own trigger comes from
# and where the backstop is. Not licence to pad.
BUDGETS="routing-documentation-updates:600 writing-claude-md:550 sweep:700
         writing-living-documents:600
         brainstorm-design:700 brainstorm-architecture:600
         writing-roadmaps:850 adopting-a-repo:700"

budget_for() {
    local name="$1" entry
    for entry in $BUDGETS; do
        if [ "${entry%%:*}" = "$name" ]; then
            printf '%s' "${entry#*:}"
            return 0
        fi
    done
    printf '%s' "0"
}

frontmatter_field() {
    FILE="$1" KEY="$2" python3 -c '
import os, sys
lines = open(os.environ["FILE"], encoding="utf-8").read().split("\n")
if not lines or lines[0].strip() != "---":
    print(""); raise SystemExit
for line in lines[1:]:
    if line.strip() == "---":
        break
    key, _, value = line.partition(":")
    if key.strip() == os.environ["KEY"]:
        print(value.strip()); raise SystemExit
print("")'
}

found=0
for skill_md in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    found=$((found + 1))
    dir=$(dirname "$skill_md")
    name=$(basename "$dir")
    echo "-- $name"

    fm_name=$(frontmatter_field "$skill_md" name)
    assert_eq "$name: frontmatter name matches its directory" "$name" "$fm_name"

    desc=$(frontmatter_field "$skill_md" description)
    case "$desc" in
        "Use when"*) pass "$name: description starts with 'Use when'" ;;
        "") fail "$name: description starts with 'Use when'" "no description field" ;;
        *) fail "$name: description starts with 'Use when'" "got: $desc" ;;
    esac

    if [ "${#desc}" -le 500 ]; then
        pass "$name: description is under 500 characters (${#desc})"
    else
        fail "$name: description is under 500 characters" "got: ${#desc}"
    fi

    if printf '%s' "$desc" | grep -qE '(then|,) *(dispatch|write|run|review)'; then
        fail "$name: description states triggers, not the workflow" "got: $desc"
    else
        pass "$name: description states triggers, not the workflow"
    fi

    body=$(awk '/^---$/ { seen++; next } seen >= 2' "$skill_md")
    words=$(printf '%s' "$body" | wc -w | tr -d ' ')
    max=$(budget_for "$name")
    if [ "$max" = "0" ]; then
        fail "$name: has a declared word budget" "add it to BUDGETS in this test"
    elif [ "$words" -le "$max" ]; then
        pass "$name: within its $max-word budget ($words words)"
    else
        fail "$name: within its $max-word budget" "got: $words words"
    fi

    # An @-link force-loads whether it opens the line or sits inline in prose
    # or a bullet, so match an @ preceded by line-start or whitespace (not by
    # a word character or a backtick) and followed by a path-like character.
    # This lets an email address (`user@example.com`, preceded by a letter)
    # and a code-formatted scoped package name (`` `@anthropic-ai/... ` ``,
    # preceded by a backtick) through correctly. Residual cost: a scoped
    # package name written bare after whitespace, with no backticks, still
    # false-positives — the fix there is to backtick it, which is correct
    # formatting anyway.
    if grep -qE '(^|[[:space:]])@[a-zA-Z./]' "$skill_md"; then
        fail "$name: uses no @-link force-loads" "found an @ link"
    else
        pass "$name: uses no @-link force-loads"
    fi

    # Every relative markdown link and backticked sibling file must exist.
    #
    # A backticked `*.md` name in a skill body is ambiguous: it may be a sibling
    # artifact the skill ships (a prompt file it hands to a subagent) or it may
    # simply be a document the skill is *talking about* (an example filename from
    # some other, unrelated repo). Only the first kind can be checked for
    # existence, so the backtick arm is narrowed to `*-prompt.md` — the naming
    # convention this plugin's skills use for the sibling prompt files they ship.
    # The markdown-link arm is unrestricted, since a relative link is never used
    # for a mere mention. Accepted cost: a future skill that ships a sibling
    # artifact not named `*-prompt.md` and refers to it only in backticks, not as
    # a markdown link, will not be checked by either arm.
    missing=""
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        [ -e "$dir/$ref" ] || missing="$missing $ref"
    done < <({
        grep -oE '\[[^]]*\]\(([a-zA-Z0-9._/-]+\.md)\)' "$skill_md" | sed -E 's/.*\((.*)\)/\1/'
        grep -oE '`[a-zA-Z0-9._-]+-prompt\.md`' "$skill_md" | tr -d '`'
    } | sort -u)
    if [ -z "$missing" ]; then
        pass "$name: every referenced file exists"
    else
        fail "$name: every referenced file exists" "missing:$missing"
    fi
done

assert_eq "at least one skill was checked" "yes" "$([ "$found" -gt 0 ] && echo yes || echo no)"

echo "-- routing-documentation-updates content"
map="$REPO_ROOT/skills/routing-documentation-updates/SKILL.md"
if [ -f "$map" ]; then
    body=$(cat "$map")
    for tier in Living Instructions Append-mostly Immutable Consumed; do
        assert_contains "the map names the $tier tier" "$body" "$tier"
    done
    assert_contains "the map says which tiers are verified" "$body" "verified"
    assert_contains "the map routes a number describing a run to the ledger" "$body" "sealed ledger"
    assert_contains "it describes the config format rather than naming a parser" \
        "$body" "tier: path"
    assert_contains "an unadopted repository is routed to adoption" \
        "$body" "dopamine:adopting-a-repo"
    assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
else
    fail "skills/routing-documentation-updates/SKILL.md exists" "not found"
fi

echo "-- sweep content"
sweep="$REPO_ROOT/skills/sweep/SKILL.md"
if [ -f "$sweep" ]; then
    body=$(cat "$sweep")
    assert_contains "the recipe names seal-ledger" "$body" "seal-ledger"
    assert_contains "the recipe names discovery-prompt.md" "$body" "discovery-prompt.md"
    assert_contains "the recipe names implementer-prompt.md" "$body" "implementer-prompt.md"
    assert_contains "verification runs against a scoped package" "$body" "sweep-package"
    assert_contains "the verifier prompt is referenced" "$body" "verifier-prompt.md"
    assert_contains "the fix loop is capped" "$body" "two rounds"
    assert_contains "nothing to drain is a legitimate outcome" "$body" "nothing to drain"
    assert_contains "it points at the artifact map rather than restating it" "$body" "dopamine:routing-documentation-updates"

    discovery="$REPO_ROOT/skills/sweep/discovery-prompt.md"
    if [ -f "$discovery" ]; then
        dbody=$(cat "$discovery")
        for kind in Edits Negatives Promotions; do
            assert_contains "the brief defines the $kind entry kind" "$dbody" "$kind"
        done
        assert_contains "an edit entry is located and quoted" "$dbody" "Current text, quoted"
        edits_section=$(awk '/^### Edits$/{flag=1; next} /^### Negatives$/{flag=0} flag' "$discovery")
        assert_contains "an Edit into the instructions tier is gated too, not only a Promotion" \
            "$edits_section" "verdict:"
        assert_contains "discovery reads documents only along grep terms" "$dbody" "grepped six times"
        assert_contains "discovery does not read documents in bulk" "$dbody" "in bulk"
        assert_contains "a promotion is put through the admission test" \
            "$dbody" "dopamine:writing-claude-md"
        assert_contains "an admitted promotion becomes an Edit" "$dbody" "verdict: admit"
        assert_contains "a routed promotion records where it went instead" \
            "$dbody" "verdict: route"
        assert_not_contains "the promotion is no longer parked unapplied" \
            "$dbody" "leave it unapplied"
    else
        fail "skills/sweep/discovery-prompt.md exists" "not found"
    fi

    verifier="$REPO_ROOT/skills/sweep/verifier-prompt.md"
    if [ -f "$verifier" ]; then
        vbody=$(cat "$verifier")
        for verdict in Placement Discipline "Drain completeness"; do
            assert_contains "the verifier returns a $verdict verdict" "$vbody" "$verdict"
        done
        assert_contains "the verifier re-derives its own grep terms" "$vbody" "independently"
        assert_contains "the verifier does not trust the report" "$vbody" "not trust"
        assert_contains "a listed location the diff never touches is Missing" "$vbody" "Missing"
        assert_contains "an ungated promotion is a finding" "$vbody" "Ungated"
        assert_contains "the verifier knows promotions carry a verdict" "$vbody" "verdict: admit"
    else
        fail "skills/sweep/verifier-prompt.md exists" "not found"
    fi

    impl="$REPO_ROOT/skills/sweep/implementer-prompt.md"
    if [ -f "$impl" ]; then
        ibody=$(cat "$impl")
        assert_contains "the implementer changes what changed" "$ibody" "Change what changed"
        assert_contains "the implementer leaves historical records alone" "$ibody" "historical"
    else
        fail "skills/sweep/implementer-prompt.md exists" "not found"
    fi
else
    fail "skills/sweep/SKILL.md exists" "not found"
fi

echo "-- writing-claude-md content"
guard="$REPO_ROOT/skills/writing-claude-md/SKILL.md"
if [ -f "$guard" ]; then
    body=$(cat "$guard")
    assert_contains "it asks the admission question, not only the staleness one" \
        "$body" "belong here"
    assert_contains "a rejected line is routed rather than dropped" "$body" "routed"
    assert_contains "the lessons tier is one of the destinations" "$body" "lessons tier"
    assert_contains "a path-scoped rule is one of the destinations" "$body" ".claude/rules/"
    assert_contains "it links the vendored standard" "$body" "claude-md-best-practices.md"
    assert_contains "it names the drift check" "$body" "refresh-rule-card"
    assert_contains "it gives the admit verdict shape" "$body" "verdict: admit"
    assert_contains "it gives the route verdict shape" "$body" "verdict: route"
    assert_contains "it points at the routing skill rather than restating it" \
        "$body" "dopamine:routing-documentation-updates"
    assert_not_contains "it no longer claims a PostToolUse hook fires it" \
        "$body" "PostToolUse"
    assert_not_contains "a routed verdict is not parked in a brief that no longer exists" \
        "$body" "in the brief"
else
    fail "skills/writing-claude-md/SKILL.md exists" "not found"
fi

finish

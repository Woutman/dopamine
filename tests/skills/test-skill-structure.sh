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
BUDGETS="artifact-map:500 sweep:600"

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

echo "-- artifact-map content"
map="$REPO_ROOT/skills/artifact-map/SKILL.md"
if [ -f "$map" ]; then
    body=$(cat "$map")
    for tier in Living Instructions Append-mostly Immutable Consumed; do
        assert_contains "the map names the $tier tier" "$body" "$tier"
    done
    assert_contains "the map says which tiers are verified" "$body" "verified"
    assert_contains "the map routes a number describing a run to the ledger" "$body" "sealed ledger"
else
    fail "skills/artifact-map/SKILL.md exists" "not found"
fi

finish

#!/usr/bin/env bash
# The two manifests that make this repository installable: the plugin
# manifest that describes dopamine, and the marketplace manifest that
# serves it from its own repository so `marketplace add` has something to
# read. Their agreement is what `plugin install dopamine@dopamine` rests on.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"

# query FILE EXPRESSION -- prints a python expression evaluated against the
# parsed manifest, bound as `d`. Prints nothing if the file will not parse,
# which the JSON-validity assertions below catch first.
query() {
    FILE="$1" EXPR="$2" python3 -c '
import json, os
try:
    d = json.load(open(os.environ["FILE"], encoding="utf-8"))
except Exception:
    raise SystemExit
value = eval(os.environ["EXPR"], {"d": d})
print("" if value is None else value)' 2>/dev/null
}

echo "-- both manifests exist and parse"
for f in "$MARKETPLACE" "$PLUGIN"; do
    label="${f#"$REPO_ROOT"/}"
    if [ -f "$f" ]; then
        pass "$label exists"
        assert_exit "$label is valid JSON" 0 python3 -c \
            "import json,sys; json.load(open(sys.argv[1]))" "$f"
    else
        fail "$label exists" "not found"
    fi
done

echo "-- the marketplace serves this repository"
assert_eq "the marketplace is named dopamine, so the install target is dopamine@dopamine" \
    "dopamine" "$(query "$MARKETPLACE" 'd.get("name")')"
assert_eq "it lists exactly one plugin" \
    "1" "$(query "$MARKETPLACE" 'len(d.get("plugins", []))')"
assert_eq "that plugin is dopamine" \
    "dopamine" "$(query "$MARKETPLACE" 'd["plugins"][0].get("name")')"
assert_eq "sourced from the repository root, which is what makes it self-referencing" \
    "./" "$(query "$MARKETPLACE" 'd["plugins"][0].get("source")')"
assert_eq "the plugin manifest agrees on the name" \
    "$(query "$MARKETPLACE" 'd["plugins"][0].get("name")')" \
    "$(query "$PLUGIN" 'd.get("name")')"

echo "-- one source of truth for the version"
# The marketplace entry deliberately omits `version`: Claude Code reads it
# from plugin.json (the installed copy lands under <plugin>/<version>/), and
# a second copy here is a value that can drift from the one that governs.
assert_eq "the marketplace entry does not restate the version" \
    "no" "$(query "$MARKETPLACE" '"yes" if "version" in d["plugins"][0] else "no"')"
assert_eq "the plugin manifest carries one" \
    "yes" "$(query "$PLUGIN" '"yes" if d.get("version") else "no"')"

echo "-- the CLI accepts both"
if command -v claude >/dev/null 2>&1; then
    # --strict fails on the warnings the runtime tolerates: unrecognized
    # fields, missing metadata. A manifest that only passes without it is
    # one a future Claude Code may stop accepting.
    assert_exit "claude plugin validate --strict accepts the marketplace manifest" \
        0 claude plugin validate --strict "$MARKETPLACE"
    assert_exit "claude plugin validate --strict accepts the plugin manifest" \
        0 claude plugin validate --strict "$PLUGIN"
else
    echo "  [SKIP] claude is not on PATH; manifest validation not exercised"
fi

finish

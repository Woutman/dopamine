#!/usr/bin/env python3
"""PreToolUse gate: refuse to delete a superpowers SDD workspace whose ledger has
not been sealed.

The question this hook asks is NOT "is this superpowers?" — provenance is not
observable from a Bash command, and it is not the point. It asks "does a sealed
copy of this ledger exist?", which is observable, has no false positives on a
drained workspace, and correctly stops a human running the same rm, since that
destroys the same record.

Silent no-op unless all of these hold:
  * the tool is Bash,
  * the command deletes something,
  * a deleted path is a .superpowers/sdd/<slug> workspace,
  * the repository has a .dopamine/config declaring where plans live,
  * and <plans>/<slug>.ledger.md does not exist.

Known gap, accepted: a command that names the workspace only through a shell
variable (`rm -rf "$dir"`) carries no literal path, so the gate cannot see it.
superpowers' own Finish step writes the path literally, which is the case that
matters.
"""

import json
import os
import re
import subprocess
import sys

# A workspace path as it appears inside a shell command, with the surrounding
# quoting and separators excluded from the slug. No path prefix is matched:
# only the slug is ever read, and an optional prefix group here backtracks
# quadratically on a long delimiter-free token (a base64 blob, a data URI),
# which would stall the user's Bash call until the hook timeout.
WORKSPACE_RE = re.compile(r"\.superpowers/sdd/(?P<slug>[^/\s'\";|&]+)")
DELETE_RE = re.compile(r"(?:^|[;&|]|\s)(?:rm|rmdir|trash)(?:\s|$)")

SEAL_HINT = "skills/sweep/scripts/seal-ledger"


def read_event():
    try:
        return json.load(sys.stdin)
    except (ValueError, OSError):
        return None


def repo_root(cwd):
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    root = result.stdout.strip()
    return root or None


def plans_dir(root):
    """Return the absolute plans directory from .dopamine/config, or None.

    None means this repository has not adopted dopamine, and every dopamine
    mechanism stays inert in it.
    """
    config = os.path.join(root, ".dopamine", "config")
    if not os.path.isfile(config):
        return None
    try:
        with open(config, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.split("#", 1)[0].strip()
                if ":" not in line:
                    continue
                tier, _, path = line.partition(":")
                if tier.strip() == "plans" and path.strip():
                    return os.path.join(root, path.strip())
    except OSError:
        return None
    return None


def seal_command(root, plans, slug):
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    script = os.path.join(plugin_root, SEAL_HINT) if plugin_root else "seal-ledger"
    return "{script} {plans}/{slug}.md".format(
        script=script,
        plans=os.path.relpath(plans, root),
        slug=slug,
    )


def deny(reason):
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


def main():
    event = read_event()
    if not isinstance(event, dict) or event.get("tool_name") != "Bash":
        return 0

    command = (event.get("tool_input") or {}).get("command") or ""
    if not isinstance(command, str):
        return 0
    if not DELETE_RE.search(command):
        return 0

    slugs = sorted({match.group("slug") for match in WORKSPACE_RE.finditer(command)})
    if not slugs:
        return 0

    root = repo_root(event.get("cwd") or os.getcwd())
    if root is None:
        return 0

    plans = plans_dir(root)
    if plans is None:
        return 0

    unsealed = [s for s in slugs if not os.path.isfile(os.path.join(plans, s + ".ledger.md"))]
    if not unsealed:
        return 0

    slug = unsealed[0]
    expected = os.path.relpath(os.path.join(plans, slug + ".ledger.md"), root)
    deny(
        "This deletes the SDD workspace for '{slug}', whose ledger is not sealed: "
        "{expected} does not exist.\n"
        "That ledger is the only record of what actually happened during execution, "
        "and it is the sweep's input. Deleting the workspace destroys it.\n"
        "Seal it first:\n"
        "  {command}\n"
        "Then run the dopamine:sweep skill. This deletion passes once the sealed "
        "copy exists.".format(
            slug=slug, expected=expected, command=seal_command(root, plans, slug)
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

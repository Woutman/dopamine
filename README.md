# dopamine

A Claude Code plugin that sits beside [superpowers](https://github.com/obra/superpowers) and operates one level above it. Superpowers plans and executes a change; dopamine carries **what actually happened** back into the documents that describe the project.

> The name is provisional.

## The problem

A predecessor project accumulated 5,186 lines across six documents for roughly thirty modules. The reported cost was not the line count — it was that every phase ran slower than the last, and the end-of-development document sweep took several times longer than any other activity.

That sweep is expensive because it is a reconstruction task whose input grows with the project: re-read the documents, work out what happened, work out what is now false. Keeping documents tidy does not touch it. A perfectly written 400-line design document still has to be fully re-read and fully re-verified at every phase close.

**Dopamine's target is a sweep whose cost tracks the change, not the project.** Every mechanism here answers one question: is it O(change) or O(project)?

## How it works

Superpowers already keeps a per-plan ledger at `.superpowers/sdd/<plan>/progress.md` — rulings, deviations, parked findings, recorded as they happen. It is the one genuinely unreconstructable record, and superpowers deletes it when the plan finishes.

Dopamine seals that ledger before it dies, and drains it into the living documents along grep terms derived from the ledger — never by re-reading the documents in bulk.

| Piece | What it does |
|---|---|
| `.dopamine/config` | Declares which paths hold which artifact tier. The plugin hard-codes no project's document set |
| `SessionStart` hook | ~94 words positioning dopamine relative to superpowers. Silent in a repo with no config |
| `PreToolUse` seal gate | Denies deleting an SDD workspace whose ledger is not sealed |
| `PostToolUse` guard | Fires when a file in the `instructions` tier is edited. Reports its length against the 200-line target and hands the admission test to the agent |
| `dopamine:claude-md-guard` | The admission test, the routing table for what fails it, and the vendored standard behind both |
| `dopamine:sweep` | Seal → discovery → execution → verification, each of the last three stages its own subagent |
| `dopamine:artifact-map` | Where each kind of fact belongs, and why only two tiers are ever re-verified |

## Install

Add this repository as a Claude Code plugin, then create `.dopamine/config` in the project you want it to work on:

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

A declared document that does not exist yet is reported `absent`, not as an error. Without this file every dopamine mechanism stays inert, so installing the plugin changes nothing until a project opts in.

## Requirements

bash, git, and **Python 3** — used by the seal gate and by the tests. If no Python 3 is found the gate prints one line to stderr and exits 0: a gate that cannot run must not block every command in the session.

`skills/claude-md-guard/scripts/refresh-rule-card` also needs **curl or wget**, and network access. It is a maintenance script that runs off the edit path; nothing else in the plugin makes a network request.

## Known gaps

- **A deletion that names the workspace only through a shell variable** (`rm -rf "$dir"`) carries no literal path, so the gate cannot see it. Superpowers' own finish step writes the path literally, which is the case that matters.
- **`git clean -fdx` destroys the workspace** without naming it. Out of the gate's scope by design — matching on it would deny a command most repositories run for unrelated reasons.
- **The gate's delete-verb list matches only `rm`, `rmdir` and `trash`.** A `find … -delete`, `unlink`, `shred`, or `mv` of the workspace carries a literal path but goes undetected, because none of those verbs match. This was found during implementation and ruled to stay open rather than be widened: every verb added to the list is new false-positive surface, and a false positive here means denying a user's Bash command. `mv` is the clearest case against widening — `mv .superpowers/sdd/x/progress.md /tmp/` is a copy-out, not a destroy, and matching on `mv` would deny that legitimate command too.
- **The verb match is a word match, not a parse.** A command that merely *mentions* a workspace path after the word `rm` — `echo how do I rm .superpowers/sdd/slug1` — is denied, because the gate reads a command line rather than executing one. This is the other side of the trade above: the verb set was kept narrow precisely to keep false positives like this rare, and the ones that remain deny a command a user meant to run.
- **No ledger outside `subagent-driven-development`.** `executing-plans` and ad-hoc work have none, so the sweep falls back to reconstruction there.
- **A `CLAUDE.md` rewritten by a Bash command does not fire the guard.** Claude Code runs a `PostToolUse` hook matching `Edit|Write` only for those tools, so `cat >> CLAUDE.md` bypasses the admission test. The sweep's own draining of the instructions tier is the backstop, and `FileChanged` is the escalation if this proves common.
- **Only Claude Code's `PostToolUse` output shape is documented.** The guard emits the nested `hookSpecificOutput` shape there and a flat `additionalContext` object everywhere else. Cursor documents its own field name for `SessionStart` but not for `PostToolUse`, so it receives the flat shape rather than an invented one.

## Tests

```bash
bash tests/run-tests.sh
```

## Status

Slices 1 and 2 of three. The authoring skills — `brainstorm-design`, `brainstorm-architecture`, `writing-roadmaps` and `adopting-a-repo` — are not built yet; see `docs/superpowers/specs/2026-08-28-dopamine-design.md` §12.

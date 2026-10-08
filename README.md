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
| `SessionStart` hook | ~140 words positioning dopamine relative to superpowers, and naming the skills that hold each document's rules. Silent in a repo with no config |
| `dopamine:adopting-a-repo` | Writes the config, surveys existing code, and reconstructs the living documents — marking what was inferred |
| `dopamine:brainstorm-design` | Wraps superpowers' brainstorming at system scope and derives `DESIGN.md` |
| `dopamine:brainstorm-architecture` | The same at assembly scope, deriving `ARCHITECTURE.md` |
| `dopamine:writing-roadmaps` | Breaks the two into phases sized for one superpowers loop, producing `ROADMAP.md` |
| `dopamine:routing-documentation-updates` | Where each kind of fact belongs, and why only two tiers are ever re-verified |
| `dopamine:writing-living-documents` | The slots each living document has, one schema file per document, and the rules for writing into them |
| `dopamine:writing-claude-md` | The admission test, the routing table for what fails it, and the vendored standard behind both |
| `dopamine:writing-code-comments` | What a code comment states — a why, a contract or a warning — and where a design's argument and a change's story go instead |
| `dopamine:finishing-work` | Seal the ledger, drain it along terms derived from it, commit, and report the line counts |

## Install

```bash
claude plugin marketplace add Woutman/dopamine
claude plugin install dopamine@dopamine
```

The repository serves itself: `.claude-plugin/marketplace.json` lists this one plugin at the repository root, so `marketplace add` takes the GitHub repo as `owner/repo`, an `https://` URL, or a path to a local clone, and `install` reads the plugin from it. Both default to user scope — every project on the machine. Pass `--scope project` to bind it to one repository instead. To try it for a single session without installing anything, `claude --plugin-dir /path/to/dopamine`.

The marketplace entry deliberately carries no version: `.claude-plugin/plugin.json` holds the only one, so the two cannot drift.

Then run `dopamine:adopting-a-repo` in the project you want it to work on. It writes `.dopamine/config` and, where there is already code, reconstructs the living documents from it. To adopt by hand instead, the config is six lines:

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

**bash and git.** That is the whole runtime: one `SessionStart` hook and a set of skills.

Python 3 is used by the **test suite** — `tests/` parses JSON and skill frontmatter with it.

`skills/writing-claude-md/scripts/refresh-rule-card` also needs **Python 3** and **either curl or wget**, and network access. It is a maintenance script that runs off the edit path; nothing else in the plugin makes a network request.

## Known gaps

- **Nothing enforces that a writing skill is loaded before a governed document changes.** The `SessionStart` injection names `dopamine:writing-living-documents` and `dopamine:writing-claude-md`, and `dopamine:finishing-work`'s exit gate catches a promotion that arrived without an admission verdict — but on the ad-hoc path an edit can land unexamined. This is the first place the rules-over-mechanism bet would visibly fail, and the first candidate for escalation back to a hook.
- **No ledger outside `subagent-driven-development`.** `executing-plans` and ad-hoc work have none, so the sweep falls back to reconstruction there. A reconstruction opens with a line saying so, which is how later readers know it is the weaker record.
- **The `living:` tier does not say which path plays which role.** The authoring recipes take the declared path whose basename matches the document they own — `DESIGN.md` for `dopamine:brainstorm-design`, and so on — and ask the human where no path matches. A project using different filenames therefore answers one question per recipe, once. A `role:` field in the config is the escalation if that proves annoying.
- **Whether sweeps happen at all is answered only after the fact.** `git log --grep='^sweep:'` shows which units of work closed with one; nothing prompts for the ones that did not. Line-count growth in the commit messages is the signal that routing is being skipped, and it has to be read by a human.
- **Implementers are not handed the comment contract.** The baseline found that implementers copy a plan's comments and add almost none of their own, so the injection points the plan's author at the skill instead; `finishing-work`'s exit gate is the backstop for comments written outside a plan.

## Tests

```bash
bash tests/run-tests.sh
```

## Status

All three original slices were built — the spine, the `CLAUDE.md` guard, and the authoring skills — and the first two have since been replaced by rules. The design they now implement is `docs/superpowers/specs/2026-09-01-dopamine-rules-over-mechanism-design.md`, which supersedes the hooks and the sweep pipeline in `docs/superpowers/specs/2026-08-28-dopamine-design.md` while leaving its artifact model intact.

This repository has not yet run its own authoring recipes on itself: `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/ROADMAP.md` are declared in `.dopamine/config` and are absent, which is the mechanism working rather than a gap in it.

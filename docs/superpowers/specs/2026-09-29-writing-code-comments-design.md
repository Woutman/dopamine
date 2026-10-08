# Dopamine — code-comment discipline

> **Status.** Design settled 2026-09-29.
>
> **Builds on** `2026-09-01-dopamine-rules-over-mechanism-design.md`: rules first, mechanism only
> where rules demonstrably fail. Nothing in the artifact model changes.

## 1. What this is

Claude Code writes too many comments, and the wrong kind. This adds one skill,
`dopamine:writing-code-comments`, that states what a comment is, and wires it into the two places
dopamine already reaches: the `SessionStart` injection and `finishing-work`'s exit gate.

**Why it belongs in dopamine.** A comment is the most local living document there is: it describes
the code as it is now. The characteristic LLM failure is a comment that narrates the change —
`# Now uses the cached client`, `# Fixed: handle None` — which is ledger content misfiled into the
source. It is the same routing failure as a `CLAUDE.md` full of design rationale, one level down.

**What was asked, and what was assumed.** Asked: a skill that makes Claude's comments less verbose,
possibly based on Google's standards, inside this plugin. Assumed and confirmed through the
brainstorm: it governs comments Claude writes, not a review of human-written ones.

## 2. Why not Google's style guides

Google's guides are the right reference for doc-comment **format** — Python's `Args:`/`Returns:`,
Javadoc — and the wrong one for **discipline**. The C++ guide expects file, class and function
comments; the Python guide requires docstrings on nearly every public function. Followed literally
they produce more comments, not fewer. They also have no rule against the dominant failure, change
narration, because human authors rarely commit it.

Claude already knows those formats, and `superpowers:writing-skills` says not to restate
well-documented standard practice. So Google survives as half a sentence in the contract — "in the
language's standard doc-comment format" — with no vendored sources and no rule card.

## 3. Scope

- **Only in adopted repositories** — like every other dopamine mechanism, inert without
  `.dopamine/config`.
- **Only comments the diff adds or touches.** That includes correcting an existing comment the change
  made false: a stale comment is a false present-tense statement. Comments the diff does not touch
  are left alone; auditing them would be O(project).

## 4. The pieces

| Piece | Change |
|---|---|
| `tests/baselines/writing-code-comments/` | New. Fixture, scenario prompts, blinding and extraction script. Kept for re-runs; not in `run-tests.sh` |
| `skills/writing-code-comments/SKILL.md` | New. One file, under ~200 words |
| `hooks/session-start-context.md` | Two sentences added, ~40 words |
| `skills/finishing-work/SKILL.md` | Exit gate gains a sixth check |
| `tests/` | Structure and injection tests extended |
| `README.md` | Skill table row; the subagent-reach gap under Known gaps |

The baseline comes first and gates everything after it (§5).

### 4.1 The skill

A **positive contract**, not a prohibition list. Verbose comments are a shaping failure — Claude
complies, but produces the wrong kind of output — and `writing-skills` finds prohibitions
measurably backfire on those. The hypothesis the GREEN stage tests:

> A comment states one of three things: **why** the code is this way (a constraint, a non-obvious
> reason, a workaround and its cause); the **contract** of a public interface, in the language's
> standard doc-comment format; or a **warning** a reader needs before changing it. The story of the
> change goes in the commit message.

Plus one example and a Common Mistakes section taken from what the baseline actually shows — not
from failure modes anticipated here.

- **Description** states triggers only: writing or editing a comment, docstring or doc comment, or a
  change leaving a nearby comment describing old behaviour.
- **No "match the surrounding comment density" clause.** It is a nuance clause, and in a heavily
  commented file it licenses exactly the bloat this targets. If local convention turns out to
  matter, it enters as a conditional on an observable predicate, driven by the baseline.
- **No supporting files.** A per-language format sheet is neither heavy reference nor a tool.

### 4.2 The injection

Two sentences: load `dopamine:writing-code-comments` before writing a comment, and **when
dispatching an implementer, put the skill's contract in its prompt**. The second is how the rule
reaches subagent-written code, which under `subagent-driven-development` is most of it. The
injection grows from ~120 to ~160 words.

### 4.3 The exit gate

`finishing-work` gains:

6. **Comments added in the diff state a why, a contract or a warning.**

Checked over `git diff`'s added comment lines only, so it stays O(change). If the baseline shows
narration clusters on a few words, a grep over those lines runs first and judgment covers the rest;
the terms are taken from the baseline, not guessed here.

## 5. Baseline

The RED phase `writing-skills` requires. It runs **before the skill is written**, and if its
controls come back clean, no skill is written.

### Fixture

One ~80-line Python module in a scratch repository, with one task: fix a bug in it **and** add a
small function beside it. The fix tempts narration; the new function tempts restatement and a
docstring on a trivial helper.

### Arms

| Stage | Arm | Setup | Runs |
|---|---|---|---|
| RED | **A0** agent, no guidance | Fresh subagent, task only | 5 |
| RED | **S0** implementer, no guidance | Fresh subagent given superpowers' `implementer-prompt.md` filled for the task. That template says nothing about comments, so this is a true control | 5 |
| GREEN | **A1** agent with the skill | A0 plus the skill | 5 |
| GREEN | **S1** implementer with the contract | S0 plus the contract in the prompt | 5 |
| GREEN | **C** controller passes it on | Given the new injection, the controller writes an implementer prompt for the task; score whether the contract is in it | 5, text only |

C tests the pass-on step itself; S1 assumes it happened.

### Judging

The main session judges, **blinded**. The script strips arm labels, shuffles every added comment
across runs, and writes each with a few lines of surrounding code to one list; a separate key file
maps entries back. Every entry is classified — **why, contract, warning, narration, restatement** —
into a file before the key is opened.

Reported per arm: counts per category and the spread across the five runs. For C: presence of the
contract.

### Pass criteria

- **RED shows a problem** when A0 or S0 averages at least one narration or restatement per run.
  Otherwise stop.
- **GREEN passes** when A1 and S1 each total at most 2 narration and restatement comments across
  their five runs, each keep at least half their control's why and warning count, and C carries the
  contract in at least 4 of 5 runs. The second condition is what catches a skill that simply
  suppresses comments.

Results are measurements of a run, so they go in the plan's ledger, not a living document.

## 6. Rulings

**Ruling: Google's guides are not vendored** — they would give a maintained, citable source, as
`writing-claude-md` has. Against: they govern format Claude already knows, and push toward more
comments. **Cost if wrong:** doc comments drift from a language's standard format with nothing in the
plugin to correct them.

**Ruling: subagents are reached by instruction, not by a `SubagentStart` hook** — a hook would reach
them regardless of the controller. Against: the hook's ability to inject context is unconfirmed, and
reintroducing a hook runs against the previous spec's bet. **Cost if wrong:** the controller omits
the contract and subagent code goes ungoverned until the exit gate; arm C measures how often.

**Ruling: the judge is the main session, blinded** — an LLM classifier behind a structured schema
would be independent of the skill's author and was judged too heavy; a human-judged sample was
judged too cumbersome. **Cost if wrong:** the judge is the same model that wrote the contract, and
blinding is partial — style may betray an arm — so GREEN can look better than it is. The key file
and classification file are kept, so a later independent re-judge is possible without re-running.

---
name: brainstorm-program-design
description: Use when an architecture is settled and the project's rules for how code is shaped — types, errors, effects, signatures, layout, module depth — are not yet decided, when a project has no PROGRAM-DESIGN.md, or when a plan meets a structural choice that document leaves open
---

# Brainstorm program design

## Overview

The wrapper from dopamine:brainstorm-architecture, one level down: it brainstorms **how code inside the components is shaped**, and derives `PROGRAM-DESIGN.md` — the rules every plan copies into its Global Constraints and every close checks the diff against.

**The human picks every rule.** You bring the options; a rule you choose alone is the precedent the first narrow plan would have set.

**REQUIRED BACKGROUND:** Use dopamine:brainstorm-design — it holds the wrapper contract this recipe shares.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — a rule for how code is shaped belongs here, and nowhere else.

## The recipe

### 1. Locate the input and the output

Read `.dopamine/config`; it declares one `tier: path` per line. The output is the `living:` path whose basename is `PROGRAM-DESIGN.md`; `DESIGN.md` and `ARCHITECTURE.md` beside it are the input. A declared path that does not exist is **absent**, not an error. Where no declared path matches, ask which is meant. No `.dopamine/config`: run dopamine:adopting-a-repo first.

An absent `ARCHITECTURE.md` stops this recipe: run dopamine:brainstorm-architecture and come back.

### 2. Settle which slots are asked

The slots, their questions and defaults are in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/program-design-schema.md`.

The core slots are always asked. For each conditional slot, say in one line whether its trigger fired and why. The human adds or drops any.

Name the language from `ARCHITECTURE.md` or the code. Where it is mixed or unclear, Python's idiom takes precedence.

### 3. Read observed practice, where there is code

Read two or three files per slot, never the whole repository. Each pattern becomes a candidate answer with the `path:line` it was seen at; two patterns for one slot are shown as both. After adoption this arrives as a findings file instead.

### 4. Ask, one slot at a time

Invoke `superpowers:brainstorming`, classification **architectural**, scoped to these slots. Each slot is one question, showing:

- **Superpowers' default**, from the schema — or that it has none.
- **Observed practice**, with where it was seen.
- **Your recommendation**, with a short Python example.
- **One or two alternatives**, each with its trade-off.

Then wait. **Write nothing** into the document until every slot is answered. "Take your recommendations for the rest" is an answer for every slot but Modules. **Modules is always asked**: left unasked, superpowers' pull toward smaller units decides it. Before asking it, read `ARCHITECTURE.md`'s *How they talk*: the rule enforces the boundaries and exceptions drawn there rather than re-deciding them.

Each rule needs a check a reviewer can apply to a diff; a rule with none goes back to the human to sharpen.

### 5. Derive the document

Use dopamine:writing-living-documents, against the schema.

### 6. Name what is now pending

`ROADMAP.md`, where it is declared and absent. One line.

## Revising one slot

Revise an existing document's slots in place: show the current rule, observed practice and what changed; the human decides. A plan that stops on a gap runs this for that one slot, then continues.

## Outcomes

| At the end of stage 4 | This recipe produces |
|---|---|
| Every slot answered | `PROGRAM-DESIGN.md` at the declared path, the spec untouched |
| A slot the human defers | The rest of the document, and the open slot named so a plan that meets it stops |
| A `PROGRAM-DESIGN.md` that already exists | Its slots revised in place |

## Common mistakes

| The thought | The answer |
|---|---|
| "There's no template for this document, so I picked the sections myself" | The schema is the template, and its slots are questions for the human |
| "The code shows the convention" | The code shows what was done, often two ways at once; the human chooses which is the rule |
| "I'll write the rule the code should follow" | A rule nobody chose is the precedent this document exists to replace |
| "I'll write it, then ask whether it suits them" | A question after writing asks the human to edit your choices instead of making theirs |

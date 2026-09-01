---
name: brainstorm-design
description: Use when a new project is starting, when a system has no DESIGN.md, or when what the project is for has changed enough that its design document no longer describes it
---

# Brainstorm a design

## Overview

A project-scope brainstorm, and the living document derived from what it produces.

`superpowers:brainstorming` is the engine — it asks the questions, proposes approaches and writes a dated spec. This recipe supplies the scope, and then does the part superpowers does not: turn that spec into `DESIGN.md`, a document that describes the **present** and is maintained by the sweep.

The spec is not superseded by it. A spec is dated intent, frozen at its date, never swept. `DESIGN.md` diverges from it as the project moves, exactly as shipped code diverges from the plan that built it.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — it decides what belongs in a living document and what is paid for on every read without earning it.

## The recipe

### 1. Locate the output

Run `${CLAUDE_PLUGIN_ROOT}/skills/sweep/scripts/artifact-paths --tier living`. The design document is the declared path whose basename is `DESIGN.md`, present or absent. Where no declared path matches, ask which one is meant rather than creating a second.

Exit 3 means this repository has not adopted dopamine. Use dopamine:adopting-a-repo first — it writes the config, and where there is already code it reconstructs rather than brainstorms.

### 2. Brainstorm at system scope

Invoke `superpowers:brainstorming`. Its classification is **architectural**: a new project is never bounded, because bounded measures whether the flow being changed is already in the repository to read.

Supply the scope so its questions land at the right level — **what the system is for, who it serves, what it must do, what would make it a failure, and what it deliberately will not do.** Components are not this conversation; they are `dopamine:brainstorm-architecture`, and they are unanswerable until this one settles.

That skill ends by directing you to `superpowers:writing-plans` and no other skill. This recipe is still running — you are inside stage 2 of four — and its rule is kept where it applies: this project's implementation still arrives through `writing-plans`, one roadmap phase at a time.

### 3. Derive the document

`DESIGN.md` is the spec re-cast in the present tense, holding only what stays true as the project moves. Its slots are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/design-schema.md`.

Use dopamine:writing-living-documents. It holds that schema and the rules for writing into it, and it is the same skill every later edit to this document goes through — so the shape this stage creates is the shape the sweep maintains.

### 4. Name what is now pending

`ARCHITECTURE.md` is declared in the config and absent. Say so in one line and stop. It is dopamine:brainstorm-architecture's output, and it comes after this one because component boundaries follow from what the system is for.

## Outcomes

| At the end of stage 2 | This recipe produces |
|---|---|
| A spec at project scope | `DESIGN.md` at the declared path, and the spec left untouched |
| A design the human has not approved | Nothing written — the brainstorm has not finished |
| A `DESIGN.md` that already exists | Its slots revised in place: changed what changed, appended only what is genuinely new |

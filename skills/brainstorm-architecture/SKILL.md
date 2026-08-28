---
name: brainstorm-architecture
description: Use when a design is settled and the components that realise it are not yet decided, when a system has no ARCHITECTURE.md, or when the assembly has changed enough that the document no longer matches the code
---

# Brainstorm an architecture

## Overview

The same wrapper as dopamine:brainstorm-design, one level down: it brainstorms **the assembly** and derives `ARCHITECTURE.md`.

**REQUIRED BACKGROUND:** Use dopamine:brainstorm-design — it holds the wrapper contract this recipe shares: how the inner brainstorm is scoped, why that skill's closing instruction does not end this one, and how a living document relates to the frozen spec it came from.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — it decides which numbers this document holds and which it cites from somewhere else.

The order is technical, not stylistic. Component boundaries follow from what the system is for, so `DESIGN.md` exists before this runs.

## The recipe

### 1. Locate the input and the output

`${CLAUDE_PLUGIN_ROOT}/skills/sweep/scripts/artifact-paths --tier living` gives both. The architecture document is the declared path whose basename is `ARCHITECTURE.md`; `DESIGN.md` beside it is this brainstorm's input. Where no declared path matches either name, ask which is meant rather than creating a second. Exit 3 means the repository has not adopted dopamine — run dopamine:adopting-a-repo first.

An absent `DESIGN.md` stops this recipe: run dopamine:brainstorm-design and come back.

### 2. Brainstorm at assembly scope

Invoke `superpowers:brainstorming`, classification **architectural**, and supply the scope: **what the pieces are, what each one owns, how they talk to each other, where state lives, what happens when one of them fails, and what runs where.**

The design's requirements are the givens. A requirement that turns out to be wrong is a finding for `DESIGN.md` — take it back there and settle it, which is not something this brainstorm quietly redecides on its way past.

### 3. Derive the document

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | The interface between each pair, and which way the dependency points |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

### 4. Name what is now pending

`ROADMAP.md` is declared and absent. Say so in one line. It is dopamine:writing-roadmaps' output, and phase order is a question about technical dependency that only this document makes answerable.

## Outcomes

| At the end of stage 2 | This recipe produces |
|---|---|
| A settled assembly | `ARCHITECTURE.md` at the declared path, and the spec left untouched |
| A component the human wants to defer | The rest of the assembly, and the deferral as an open question naming what closes it |
| An `ARCHITECTURE.md` that already exists | Its slots revised in place against what the code now does |

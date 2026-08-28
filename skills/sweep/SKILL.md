---
name: sweep
description: Use when a superpowers plan or an ad-hoc unit of work is finished and before its workspace is cleaned up, or when a living document has fallen behind what the code now does
---

# Sweep

## Overview

A sweep carries what actually happened during one unit of work back into the documents that describe the present.

Its input is the **sealed ledger** — never the documents in bulk. It reaches into a document only along grep terms derived from it. That is the whole cost argument: a sweep's work tracks the change, not the size of the project.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — which tier a fact belongs to decides where every edit lands.

## The recipe

Seal, then drain. Four stages, in order.

### 1. Seal

Run `scripts/seal-ledger PLAN_FILE`. It copies superpowers' ledger out of its workspace and into the plan's own directory. Until it has run, the seal gate refuses to let the workspace be deleted.

If the unit had no ledger — ad-hoc work, or `superpowers:executing-plans` — say so in one line and run discovery from this conversation instead. That is a weaker input, and naming it is how the reader knows.

### 2. Discovery — one subagent, every document at once

Run `scripts/artifact-paths` for the config map, then dispatch one subagent with `discovery-prompt.md`. One pass covers every living document: the ledger is read once, and per-document discovery would re-read it once per document for no gain.

Its output is **the sweep brief**, written beside the sealed ledger as `<plans>/<plan-basename>.sweep.md`.

### 3. Execution — one implementer, from the brief alone

Dispatch one implementer with `implementer-prompt.md`. Sweep edits are many small same-shape changes across files — one brief listing every file and its change, landing as one diff.

### 4. Verification — a fresh subagent that does not trust the report

Run `scripts/sweep-package PLAN_FILE BASE HEAD`. Its diff excludes the plans tier by construction, so also list any plans-tier paths that changed (`scripts/artifact-paths --tier plans`, then `git diff --name-only BASE HEAD` against them) as the plans-touch fact — normally empty. Dispatch a fresh subagent with `verifier-prompt.md`, filling both. It returns three verdicts: **Placement**, **Discipline**, and **Drain completeness**.

**Fix loop: at most two rounds.** An entry that fails review twice is usually a defect in the brief — a mis-located claim, or a document state discovery misread — not an implementer needing a stronger model. Return to whoever dispatched the sweep, naming which entries failed and the pattern they share, and let them rule. A failure parked silently leaves the living documents wrong with nothing to signal it.

## What a finished sweep leaves

Four dated siblings beside the plan: the **spec** (what we meant to build), the **plan** (how we meant to build it), the **sealed ledger** (what actually happened), and the **brief** (what that changed in the documents).

The brief is the record, with two writers: discovery writes it, execution annotates outcomes onto it. Verification's verdicts come back in conversation and drive stage 4's fix loop. Nothing else is written: a separate drain record would restate the ledger, which is the failure this plugin exists to prevent.

## Outcomes

| The ledger holds | The sweep produces |
|---|---|
| Entries with living-document consequence | A brief of edits, negatives and promotions, and a verified diff |
| No drainable entries | A brief of negatives only, and the sentence "nothing to drain" |
| A declared document that does not exist | It is reported absent, and it is not created |

**"Nothing to drain" is a finished sweep**, not a skipped one. It is a conclusion about the ledger, reached by reading it, and the negatives are what show it was reached.

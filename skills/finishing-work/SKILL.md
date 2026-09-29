---
name: finishing-work
description: Use when a superpowers plan or an ad-hoc unit of work is finished and before its workspace is cleaned up, or when a living document has fallen behind what the code now does
---

# Finishing work

## Overview

Work is finished when what happened has been carried back into the documents that describe the present. That carry is the sweep, and this is its recipe.

Its input is the **sealed ledger** — never the documents in bulk. It reaches into a document only along grep terms derived from that ledger. That is the whole cost argument: the work tracks the change, not the size of the project.

**This runs one step before `superpowers:finishing-a-development-branch`**, while the workspace still exists. The two fire nearly together, and neither covers the other.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — which tier a fact belongs to decides where every edit lands.

## Obligations

### 1. Seal

`cp .superpowers/sdd/<slug>/progress.md <plans>/<slug>.ledger.md`, taking `<plans>` from the `plans:` line of `.dopamine/config`. Superpowers deletes that ledger with the workspace; it is the one unreconstructable record of the work.

No ledger — ad-hoc work, or `superpowers:executing-plans` — means writing one: `<plans>/<slug>.reconstructed-ledger.md`, from what this conversation records, opening with a line naming and dating it as a reconstruction. A reconstruction is the weaker record, and that line is how later readers know. Ad-hoc work has no plan file: name a dated slug once and use it wherever this recipe says `<slug>`.

### 2. Drain from the ledger

Read the sealed ledger in full. Derive grep terms from it — the names, paths, symbols and decisions it mentions — and reach into a living document only along those terms. Reading the documents **in bulk** returns this to O(project), the cost this plugin exists to avoid.

Use dopamine:writing-living-documents for each edit to a living document, and dopamine:writing-claude-md for anything proposed for the instructions tier.

### 3. Commit

`sweep: <slug> — 3 edits`, or `sweep: <slug> — nothing to drain`.

The `sweep:` prefix is a commit convention, not a skill name. `git log --grep='^sweep:'` is how a project answers whether sweeps are happening at all, so the prefix outlives any renaming of this skill.

### 4. Report the line counts

In the same commit message, `wc -l` for each `living:` document and for the `instructions:` file. Growth in those numbers without matching growth in the system is the signal that routing is not being applied — and it is the number that was legible the whole time in the project this plugin was built from, while nobody looked.

## Exit gate

Six checks, run with **fresh eyes** over the diff, fixed inline. No re-review and no subagent dispatch: this is the pattern superpowers uses for its own documents, where the human is the gate. A fresh-subagent review is for code, which has tests and objective failure modes.

1. **Right tier.**
2. **Changed what changed** — a paragraph appended where existing text should have been replaced is a failure even when the added text is true.
3. **No number describing a run** entered a living document.
4. **Every promotion to the instructions tier carries an admission verdict.**
5. **Historical records untouched** — specs, plans and sealed ledgers are immutable.
6. **Comments added in the unit of work state a why, a contract or a warning** — `dopamine:writing-code-comments` holds the contract. Judged over the added lines of `git diff <base>...HEAD`.

## Method is your judgment

A ledger with thirty entries across four documents may be worth fanning out; a two-line drain is not. Nothing here prescribes an agent count.

## What a finished sweep leaves

The **sealed ledger** beside the plan, and one `sweep:` commit whose message carries the line counts. No separate record: a brief would restate the ledger, which is the failure this plugin exists to prevent.

| The ledger holds | This produces |
|---|---|
| Entries with living-document consequence | The edits, one `sweep:` commit, and the line counts |
| No drainable entries | The sealed ledger, and a `nothing to drain` commit |
| A declared document that does not exist | It is reported absent, and it is not created |

**"Nothing to drain" is a finished sweep**, not a skipped one. It is a conclusion about the ledger, reached by reading it.

Decisions made along the way — a routed promotion, a claim placed against the obvious tier — are reported in the conversation when the work closes and then forgotten. A decision that was genuinely contested is a **ruling**, and a ruling belongs in the ledger, where it seals with everything else.

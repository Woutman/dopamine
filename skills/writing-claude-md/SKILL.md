---
name: writing-claude-md
description: Use when a line is about to be added to CLAUDE.md, when work is finishing and something is being drained into it, or when a recurring lesson is proposed for promotion to an always-loaded line
---

# Writing CLAUDE.md

## Overview

`CLAUDE.md` is drained like a living document, and verified against one extra question.

1. **Is this still true?** — asked everywhere.
2. **Does this belong here at all?** — the admission test.

The second is the one that pays. A predecessor project carried 516 lines of `CLAUDE.md` that were not false; they were **misfiled**. Design rationale reads perfectly well there, and is then paid for on every session while duplicating the design document. Staleness checking would never have caught it.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — it holds the tier each destination below belongs to.

## When this fires

- **Before a line enters `CLAUDE.md`** — written by hand, or drained into it as work finishes.
- **On a promotion** — a lesson that has recurred, offered as an always-loaded line.

Nothing intercepts an edit to `CLAUDE.md` any more, so this skill is loaded because the writer reaches for it. dopamine:finishing-work's exit gate is the backstop: a promotion that reached the instructions tier without a verdict is a finding there.

## The test

For each candidate line: **would removing it cause Claude to make mistakes?**

A line that survives is admitted. A line that does not is **routed** — it has a destination, and naming it is what makes the test a routing decision rather than a rejection. An agent holding a true fact with nowhere to put it will argue to keep it.

| The candidate | Its home |
|---|---|
| A command, convention or gotcha that holds across the whole project | Admitted |
| Relevant only sometimes, or a multi-step procedure | A skill, loaded on demand |
| True only of part of the tree | A path-scoped rule under `.claude/rules/` |
| A dated observation that stays true | The lessons tier |
| Design rationale, or anything a living document already states | That living document |
| Derivable by reading the code, or a standard practice | Cut |

The standard behind the table, with its sources and the measurements that justify vendoring it: [claude-md-best-practices.md](claude-md-best-practices.md).

## The verdict

One line per candidate, in the form a sweep brief records:

```
verdict: admit — <the include row it matches>
verdict: route <destination> — <one line of reason>
```

A routed verdict is reported when the work closes and then forgotten — re-litigating one costs a single lookup in the table above, and logging every one would grow the lessons tier, which nothing verifies and nothing prunes. A promotion that was **genuinely contested** is a ruling, and a ruling belongs in the sealed ledger with everything else the work decided.

## Keeping the card honest

`scripts/refresh-rule-card` re-fetches the three source sections and diffs them against the snapshots in `sources/`. Run it occasionally, off the edit path: the source pages are ~40 KB each and the guidance is under 8% of them, so fetching on every edit would pay ~19,000 tokens for ~900 usable words.

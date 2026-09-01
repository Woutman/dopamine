# CLAUDE.md — the admission standard

Anthropic's own guidance on what belongs in a `CLAUDE.md`, distilled from the sections listed at the bottom. This file is the standard; `dopamine:writing-claude-md` is the routing decision made against it.

## The per-line test

For each line, ask: **"Would removing this cause Claude to make mistakes?"** If not, cut it.

Bloated `CLAUDE.md` files cause Claude to ignore your actual instructions. Two symptoms are worth memorising because they point in opposite directions:

- Claude keeps doing something you asked it not to, **despite a rule against it** — the file is probably too long and the rule is getting lost.
- Claude asks a question the file already answers — the phrasing is ambiguous rather than the file too long.

Treat `CLAUDE.md` like code: review it when things go wrong, prune it regularly, and test a change by observing whether behaviour actually shifts.

## What belongs, and what does not

| ✅ Include | ❌ Exclude |
|---|---|
| Bash commands Claude can't guess | Anything Claude can figure out by reading code |
| Code style rules that differ from defaults | Standard language conventions Claude already knows |
| Testing instructions and preferred test runners | Detailed API documentation (link to docs instead) |
| Repository etiquette (branch naming, PR conventions) | Information that changes frequently |
| Architectural decisions specific to your project | Long explanations or tutorials |
| Developer environment quirks (required env vars) | File-by-file descriptions of the codebase |
| Common gotchas or non-obvious behaviours | Self-evident practices like "write clean code" |

## When a line has earned its place

Add to `CLAUDE.md` when:

- Claude makes the same mistake a second time
- A code review catches something Claude should have known about this codebase
- You type the same correction into chat that you typed last session
- A new teammate would need the same context to be productive

## Where a line goes instead

`CLAUDE.md` loads at the start of every session, so only content that applies broadly earns a place in it. Everything else has a home:

| The candidate | Its home |
|---|---|
| Relevant only sometimes, or a multi-step procedure | A skill — loaded on demand, without bloating every conversation |
| True only of part of the tree | A path-scoped rule under `.claude/rules/`, loaded only for matching files |
| Detailed API documentation | The docs, linked |
| Derivable by reading the code | Cut. On a checked-in `CLAUDE.md`, `/doctor` proposes exactly these cuts |

## How the surviving lines are written

- **Size** — target under 200 lines per file. Longer files consume more context and reduce adherence.
- **Structure** — markdown headers and bullets. Claude scans structure the way readers do; organised sections beat dense paragraphs.
- **Specificity** — concrete enough to verify. "Use 2-space indentation", not "Format code properly". "Run `npm test` before committing", not "Test your changes". "API handlers live in `src/api/handlers/`", not "Keep files organized".
- **Consistency** — two rules that contradict each other leave Claude to pick one arbitrarily. Review the file, any nested files in subdirectories, and `.claude/rules/` periodically.
- **Emphasis** — if Claude keeps skipping one instruction, add IMPORTANT to that line alone. Emphasise many lines and none of them stands out.

## Sources

Distilled **2026-08-28** from the three sections below. `scripts/refresh-rule-card` re-fetches each one, extracts it, and diffs it against the snapshot in `sources/`, so drift in the upstream guidance is detected without anyone re-reading either page.

The canonical URL has already moved once — `anthropic.com/engineering/claude-code-best-practices` → 308 → `code.claude.com/docs/en/best-practices` — which is the kind of change the check exists to catch.

```
source: https://code.claude.com/docs/en/best-practices.md | ### Write an effective CLAUDE.md | sources/best-practices-write-an-effective-claude-md.md
source: https://code.claude.com/docs/en/memory.md | ### When to add to CLAUDE.md | sources/memory-when-to-add-to-claude-md.md
source: https://code.claude.com/docs/en/memory.md | ### Write effective instructions | sources/memory-write-effective-instructions.md
```

**Why vendored rather than fetched.** As of the distillation date above, the two pages measured 40,076 and 36,982 bytes, and these three sections are 3,256 + 824 + 1,818 bytes of them — 8.1% and 7.1%, 818 words in total. Fetching whole pages on every `CLAUDE.md` edit would pay roughly 19,000 tokens for roughly 900 usable words, so the card is vendored and the drift check runs off the edit path instead.

# Reconstructed ledger — ad-hoc work, reconstructed 2026-11-02 — no superpowers ledger existed

Slug: `2026-11-02-glossary-baseline`. No plan file and no spec; on branch `glossary-baseline`.

## Rulings (the human's)

- The glossary is a **token-saving** feature, not a correctness one. The baseline measures cost
  beside correctness, not whether agents misread terms.
- **Its own file**, `GLOSSARY.md`, not a `DESIGN.md` slot: a lookup must not load the design.
- **No cap** on its length; documentation discipline bounds it, as for every living document.
- The test repo is small, about a dozen files, not 30–50.

## Decisions proposed and accepted

- One line per entry, headword first, so a grep returns exactly one definition.
- A `glossary:` config tier, because the bash hook cannot ask which `living:` path is meant. The
  other documents keep basename matching.
- An admission test in place of a cap.
- Four arms: none, pointer, full injection, headwords only.
- From a side note: score on `total_cost_usd`, with cache-read, cache-write, fresh-input and
  output tokens as separate columns.

## What changed

`docs/BACKLOG.md`'s glossary entry rewritten around those decisions. New
`tests/baselines/glossary/` (fixture, glossary overlay, tasks, answer key, checks, `setup-run`,
`inject`, `run-task`, `score`) and `tests/scripts/test-glossary-baseline.sh`. Suite: 15/15 pass.

## Observed

One smoke run (arm D, t1, haiku): correct, $0.007, 5 turns. Fresh input is about 10 tokens because
Claude Code caches tool results too, so lookups show as cache writes. About 30k tokens of fixed
system prompt per run make the per-arm differences small.

## Living-document consequence

None. All four declared living documents are absent, and the backlog is deliberately undeclared.

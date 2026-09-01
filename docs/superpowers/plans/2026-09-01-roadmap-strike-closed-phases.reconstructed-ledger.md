# Reconstructed ledger — ad-hoc work, reconstructed 2026-09-01 — no superpowers ledger existed

Slug: `2026-09-01-roadmap-strike-closed-phases`. No plan file and no spec: the unit was a
single conversational request, so this record is written from the conversation and is the
weaker of the two ledger kinds.

Worktree: `.claude/worktrees/roadmap-strikethrough` on branch `worktree-roadmap-strikethrough`,
from `main` @ 29f29b6.

## The request

Deleting a finished stage from `ROADMAP.md` makes the document confusing to read. Cross it out
instead, without appending implementation details to it, and leave a short pointer to somewhere
that holds those details as an audit trail. The question asked first was *where that pointer
should point*; the change followed the answer being agreed.

## The ruling on location

The pointer targets the **sealed ledger**, `<plans>/<plan-basename>.ledger.md`. Three reasons,
in the order they decided it:

1. It is the immutable tier in `dopamine:artifact-map` — never touched at sweep, so a pointer
   into it cannot rot and costs nothing to keep.
2. artifact-map already assigns this content there: "a number describing *a run* → the sealed
   ledger, cited by reference", and "what we decided and why → spec plus the sealed ledger".
3. It is the hub, so one pointer reaches all four artifacts. The sealed header line names the
   plan; the body's `Spec read:` line names the spec; the sweep brief is its `.sweep.md`
   sibling. Pointing at the *plan* instead was considered and rejected: a plan can exist
   without ever having been executed, so it is one hop further from what actually happened.

## What changed

`skills/writing-roadmaps/SKILL.md` — the deletion rule lived in exactly three places there and
nowhere else in the repository (checked by grep across `skills/` and `README.md`):

- Step 5, retitled "Keep it consumed, not accumulated" → "Strike a closed phase, and leave a
  pointer". A closed phase now stays, struck through, its body replaced by one link to its
  sealed ledger, written relative to the roadmap's own directory.
- The constraint that makes this affordable: **the struck line holds the name and the link and
  nothing else** — no `Lands`, no `Exit`, no measured number. A line that asserts something
  about the present has to be defended at every sweep; a bare pointer asserts nothing. This is
  what keeps a struck phase out of the verified surface that deletion used to buy.
- The Outcomes row for a just-closed phase.
- Dropped as now false: "That is why a roadmap describes the remaining work rather than growing
  into a history of the project." Under the new rule the roadmap does keep a thin history.

`tests/skills/test-authoring-skills.sh` — its assertion encoded the old rule by name ("a closed
phase is deleted rather than struck through"). Replaced with three: `struck through`,
`sealed ledger`, and `and nothing else` for the bare-pointer constraint.

`tests/skills/test-skill-structure.sh` — `writing-roadmaps` budget 800 → 850. The document went
777 → 847 words. Sequence, so a later reader can judge it: the first draft landed at 836, was
tightened to 828 by compressing the two new paragraphs, and the budget was raised 50 rather
than fund the new rule by degrading unrelated prose in steps 2 and 4. The declared-budget
comment above `BUDGETS` already sets this precedent and its limit — "Not licence to pad:
additions stay terse and measured."

## Finding: a test premise the change falsified

`tests/skills/test-skill-structure.sh` checks that every relative markdown link in a skill body
resolves, on the stated premise that "a relative link is never used for a mere mention". The
first draft of the worked example wrote a real-looking relative link
(`[ledger](superpowers/plans/2026-08-28-dopamine-spine.ledger.md)`) and the check failed —
correctly: as an illustration it is resolvable only against a host repository's roadmap, never
against the skill directory.

Ruled to fix the example rather than widen the check. The example now uses the `<plans>`
placeholder this plugin's skills already use for a config-derived path
(`<plans>/<plan-basename>.sweep.md` in `dopamine:sweep`, and in `dopamine:adopting-a-repo`).
Two gains beyond passing: the angle brackets fall outside the checker's character class, so the
premise survives intact, and the placeholder is more accurate than any literal — the plans
directory comes from `.dopamine/config`, not from a hardcoded `docs/superpowers/plans`.
Widening the check was the alternative and was rejected: every carve-out is new blind spot, and
here the carve-out would have covered exactly the mentions most likely to be typos.

## Verification

`./tests/run-tests.sh` — 14 of 14 test files OK. Before the example fix: 1 of 14 failed, at
`[FAIL] writing-roadmaps: every referenced file exists`.

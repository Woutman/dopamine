# Sweep brief — 2026-09-01-roadmap-strike-closed-phases

Input: `2026-09-01-roadmap-strike-closed-phases.reconstructed-ledger.md` (a reconstruction).
No plan and no spec, so every claim below is placed from the ledger and the config map alone.

Stages 2–4 were run inline rather than by the three prompt subagents: this session's
instructions forbid dispatching agents unless asked, and the surface here is five absent
targets and one ledger. Recorded so a later reader knows the weaker method was used.

## Config map, as read

    living         docs/DESIGN.md         absent
    living         docs/ARCHITECTURE.md   absent
    living         docs/ROADMAP.md        absent
    instructions   CLAUDE.md              absent
    lessons        docs/LESSONS.md        absent
    plans          docs/superpowers/plans present

Every drain target dopamine declares for itself is absent. Deriving the three living documents
needs a brainstorm with a human and has not been run here; `CLAUDE.md` and `LESSONS.md` have
had nothing to hold yet. **Absent documents are reported, never created** — so this sweep drains
nothing, and the placements below are what a later sweep or first derivation inherits.

## Edits

**Nothing to drain.** No living document exists to receive an edit.

## Placements deferred to the documents that do not exist yet

| Claim | Home when it exists | Why it is not filed now |
|---|---|---|
| A closed phase is struck through above a pointer to its sealed ledger, not deleted; the struck line carries no claim about the present | `DESIGN.md` — it changes a stated property of the artifact model, which had the roadmap purely consumed and never a history | `DESIGN.md` absent. Whoever runs `dopamine:brainstorm-design` must take the rule from `skills/writing-roadmaps/SKILL.md` step 5, not from the model as originally conceived |
| A skill body's worked example must not use a resolvable relative markdown link; use the `<plans>` placeholder, because the reference checker's premise is that a relative link is never a mere mention | `LESSONS.md` — dated, stays true, and carries the grep terms a future author would search (`every referenced file exists`, `<plans>`, `test-skill-structure.sh`) | `LESSONS.md` absent. It is a lesson and not a prescription: the observation stays true even if the checker is later widened |

## Negatives — claims read and deliberately not placed

- **The word counts (777 → 847) and the budget move (800 → 850).** Run facts about one edit.
  They stay in the sealed ledger and are cited from there; a living document holding them would
  have to defend them at every sweep and they would drift from the run that produced them.
- **The location ruling and the two rejected alternatives** (pointing at the plan; widening the
  reference check). Decision archive, which is spec plus ledger. Already recorded; restating it
  in a living document is the duplication this plugin exists to prevent.
- **Nothing for `CLAUDE.md`.** The rule is one skill's step 5, loaded only when that skill is
  invoked. An always-loaded line would be paid for on every session and would duplicate the
  skill body — the shape `dopamine:claude-md-guard` exists to refuse.
- **Nothing for `ROADMAP.md`.** It is the document the rule governs, not a document the rule
  drains into. It is also absent.
- **Nothing for `ARCHITECTURE.md`.** A step inside one skill's recipe is not assembly: no
  component boundary, dependency or interface moved.

## Plans-tier touches

`docs/superpowers/plans/2026-09-01-roadmap-strike-closed-phases.reconstructed-ledger.md` and
this brief. Both immutable-tier, both expected, neither a drain target.

## Verdicts

Placement, Discipline and Drain completeness were checked against the ledger by re-reading it
after the brief was written, in the same session rather than by a fresh subagent — the weaker
check, and the reason is recorded above. No fix round was needed: with no living document
present there is no edit whose placement could be wrong, and the two deferred placements are
recorded rather than performed.

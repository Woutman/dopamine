# Dopamine — rules over mechanism

> **Status.** Design settled 2026-09-01.
>
> **Supersedes** the mechanism described in `2026-08-28-dopamine-design.md` §8 (Hooks) and the
> sweep pipeline in §8 (Skills). It does **not** supersede that document's artifact model (§6) or
> its layer model (§7), which survive intact and are the reason this change is small.
>
> **Reading order.** The 2026-08-28 design first, then this. That document is immutable and is not
> edited by this change — including the claims §3 corrects below.

## 1. What this is

Dopamine ships mechanism where it should ship rules. This replaces two hooks and a four-stage
subagent pipeline with skills that state the rules, and leans on superpowers to do the work — the
same bet the four authoring skills already make and which has held.

Roughly 1,500 lines are deleted. Nothing in the artifact model changes.

## 2. What changes, in one table

| Piece | Now | After |
|---|---|---|
| `PreToolUse` seal gate | 158-line Python hook denying workspace deletion | Deleted. Sealing is one `cp` named in a skill |
| `PostToolUse` `CLAUDE.md` guard | 199-line Python hook returning advice | Deleted. Its routing table was always the payload, and that is a skill |
| Sweep discovery / execution / verification | Three subagents, three prompt files, a two-round fix loop | One skill stating obligations and an exit gate. Whether to use subagents is the agent's call |
| `seal-ledger`, `sweep-package`, `artifact-paths` | Three scripts, 249 lines, plus 338 lines of tests | Deleted. A six-line config file does not need an 87-line parser when the consumer is an LLM |
| `py-hook` | Python interpreter probe for the two Python hooks | Deleted with them. **Python stops being a runtime dependency**; the plugin becomes bash + git |
| Document schemas | Buried in three authoring skills, loaded only at creation | Per-document files, loaded whenever a governed document is written |

`SessionStart` is the only surviving hook.

## 3. Correcting the 2026-08-28 design

That spec argued the instruction path had already been disproven. It had not, and the argument
should not be relied on again.

**§2 conflates two different experiments.** The predecessor swept — emergently, unenforced — and
degraded anyway, and §2 reads that as evidence that instructions do not work. But the predecessor
had **no routing rules**: nothing told it that design rationale belongs in `DESIGN.md` rather than
`CLAUDE.md`. "Swept without rules" and "swept with rules" are different experiments and only the
first was run.

**§3 extends a fair rejection too far.** It rejects *tidiness* rules — uniform size budgets,
whole-repo review passes — on the O(project) test, correctly. It then treats *routing* rules as
covered by the same rejection. They are not. A 516-line `CLAUDE.md` of misfiled design rationale is
a routing failure, and routing is O(change): each fact is placed once, when it arrives.

**What survives that correction, unchanged:**

- The cost model. A sweep's input is the sealed ledger, and documents are reached only along grep
  terms derived from it. This is the whole O(change) argument and it is a **rule**, not a pipeline.
  It is stated in `finishing-work` and is load-bearing there.
- The artifact model (§6) and its tiers.
- The ownership boundary (§5): dopamine reads superpowers' artifacts and writes only its own.
- The observation that the sweep's *trigger* was never the failure.

## 4. The bet, and how it can be wrong

**Rules first; escalate to mechanism only where rules demonstrably fail.**

This is falsifiable and the failure is visible in one number. The predecessor's collapse was legible
in `wc -l` the entire time and nobody looked. So `finishing-work` reports each living document's line
count and `CLAUDE.md`'s at every close, into the commit message. Growth without corresponding growth
in the system is the signal that routing is not being applied, and the escalation is a mechanism for
whichever rule is being skipped.

`git log --grep='^sweep:'` answers the prior question — whether sweeps are happening at all.

## 5. Skill inventory

superpowers' `writing-skills` requires active, verb-first names. Two existing skills fail that and
are renamed here; `sweep` is renamed for the same reason and because its old name described a
mechanism rather than a trigger.

| Skill | Was | Form | Answers |
|---|---|---|---|
| `routing-documentation-updates` | `artifact-map` | Reference | Which tier, which document |
| `writing-living-documents` | *new* | Reference | Where within a living document, and in what shape |
| `writing-claude-md` | `claude-md-guard` | Reference | May this enter the instructions tier |
| `finishing-work` | `sweep` | Recipe | Carrying a finished unit of work back into the documents |
| `brainstorm-design` | — | Recipe | §3 replaced by a schema pointer |
| `brainstorm-architecture` | — | Recipe | §3 replaced by a schema pointer |
| `writing-roadmaps` | — | Recipe | §3 replaced by a schema pointer |
| `adopting-a-repo` | — | Recipe | §4 points at the schema files directly, not via the authoring recipes |

`routing-documentation-updates` decides which governed document a fact belongs to; the two
`writing-*` skills say how to write to each; `finishing-work` is the recipe that uses all three.

**`finishing-work` sits one step before `superpowers:finishing-a-development-branch`**, which fires
at a nearly identical moment. Its SKILL.md states that ordering outright — it runs while the
workspace still exists, and branch integration follows it. Without that line an agent that has run
one may reasonably conclude the other is handled.

**Renaming must not touch the `plans:` tier.** Most references to `artifact-map` and
`claude-md-guard` live in sealed plans, which are immutable. A sealed plan records what was true on
its date; updating names inside it would be this project's own violation. The stale names are
correct and stay.

## 6. Document schemas as per-document files

```
skills/writing-living-documents/
  SKILL.md                 # general rules; pointers to the three schemas
  design-schema.md         # lifted from brainstorm-design §3
  architecture-schema.md   # lifted from brainstorm-architecture §3
  roadmap-schema.md        # lifted from writing-roadmaps §3
```

**Why separate files rather than inline.** `writing-skills` reserves supporting files for heavy
reference (100+ lines) and a 15-row table is not that. The justification is not size but
**consumers**: each schema has two independent ones — the authoring skill that creates the document,
and `finishing-work`, which edits it for the rest of the project's life. Inline in one `SKILL.md`,
`brainstorm-design` would load all three schemas to reach the one it owns. This deviation is
deliberate and recorded here so it does not read as an oversight.

**Cross-skill references use `${CLAUDE_PLUGIN_ROOT}`.** A skill runs with the user's repository as
its working directory. The README's known gap — `skills/sweep/` and `skills/artifact-map/` spelling
script paths relative to the plugin — largely closes itself when those scripts are deleted; these
new references are how it could quietly reopen.

**Form: template, not prohibition.** `writing-skills` finds that prohibitions measurably backfire on
shaping failures — under a competing incentive, agents negotiate with "don't X," and the prohibition
arm tested worse than the no-guidance control. The schemas are stated as positive templates: a
living document consists of these slots, in this order. There is no "do not add a heading" rule; a
document whose contents must claim a named slot cannot sprawl, because new prose either fits one or
belongs elsewhere.

**What stays put.** `writing-roadmaps` keeps its strike rule and its Common Mistakes. Striking a
closed phase is proven on phases and is not generalised to other living documents from a single
instance.

## 7. `finishing-work`

Prose recipe. It states obligations and an exit gate; it does not prescribe how many agents.

**Obligations:**

1. **Seal.** `cp .superpowers/sdd/<slug>/progress.md <plans>/<slug>.ledger.md`. No ledger — ad-hoc
   work, or `superpowers:executing-plans` — means writing a reconstruction whose opening line names
   it as one and dates it. The reconstruction is the weaker record; that line is how later readers
   know.
2. **Drain from the ledger.** Read the sealed ledger, derive grep terms from it, and reach into a
   document only along those terms. **Never re-read the documents in bulk.** This is the cost
   argument, and abandoning it returns the sweep to O(project).
3. **Commit** as `sweep: <slug> — 3 edits` or `sweep: <slug> — nothing to drain`. The prefix is a
   commit convention, not a skill name, and it stays `sweep:` so `git log --grep='^sweep:'` keeps
   working across this rename.
4. **Report** `wc -l` for each living document and `CLAUDE.md`, in the same commit message.

**Exit gate** — five checks, run with fresh eyes, fixed inline, no re-review. This is superpowers'
own pattern for its documents (`writing-plans`: *"a checklist you run yourself — not a subagent
dispatch"*; `brainstorming`: spec self-review, then the human as the gate). Fresh-subagent review is
reserved for code, which has tests and objective failure modes; a document's failure mode is judged
by the human who has the context.

1. Right tier.
2. Changed what changed — an appended paragraph where existing text should have been replaced is a
   failure even when the added text is true.
3. No number describing a run entered a living document.
4. Every promotion to the instructions tier carries an admission verdict.
5. Historical records untouched.

**Method is the agent's judgment.** A ledger with thirty entries across four documents may be worth
fanning out; a two-line drain is not.

**Two verdicts from the old pipeline are deliberately gone.** Placement checked that every entry in
the discovery brief had a matching hunk — that is discovery-to-implementer handoff fidelity. Drain
completeness checked that the implementer dropped nothing discovery found, and its independence
trick (derive your own grep terms before opening the brief) only works on an agent that did not
write the brief. Both policed seams the pipeline itself created. With no handoff there is no handoff
error, and Discipline — the only verdict that was ever about the documents — becomes the exit gate
above.

**No brief.** The sweep's durable record is the seal commit and its message. A separate brief would
restate the ledger, which is the failure this plugin exists to prevent.

**Routed promotions are reported and forgotten.** A verdict that a candidate line does not belong in
`CLAUDE.md` is process exhaust, not a lesson: nobody greps for it, and logging every one would grow
`LESSONS.md` — the one tier with no verification pressure and no pruning. Re-litigating costs a
single lookup in a fixed routing table. A promotion decision that was genuinely contested is a
**ruling**, and superpowers' ledger already has a shape for that; it seals with everything else.

## 8. Rulings

Recorded in superpowers' format so they are not re-litigated.

**Ruling: RED-phase baselines are skipped** — `writing-skills` requires a failing test before any
skill is written or edited, and this change creates one skill and edits five. Time and resources do
not allow it; validation is manual. **Cost if wrong:** skills may counter rationalizations never
observed, and the no-guidance-control case is invisible to manual validation — a skill that was
never needed can only be identified by deliberately running without it, which manual checking will
not do.

**Ruling: the seal gate is deleted rather than kept as a backstop** — a lost ledger is the only
failure that cannot be repaired afterwards, which argues for keeping it. Against: it fires
approximately never if sealing is habitual, its verb match is a word match rather than a parse, and
its known false positive denies a command the user meant to run. The degraded mode is also already
proven — this repository contains a reconstructed ledger. **Cost if wrong:** a unit of work whose
sweep is skipped loses its ledger permanently, and the sweep falls back to reconstruction.

**Ruling: the strike rule is not generalised** — it stays in `writing-roadmaps`. **Cost if wrong:**
a superseded approach in `DESIGN.md` gets edited away rather than struck, losing the pointer to what
replaced it.

**Ruling: `artifact-paths` is deleted** — beyond the scope originally proposed, taken for
consistency with the rest of the change. **Cost if wrong:** each consumer re-derives the config
format in prose, and the script's absent/present reporting has to be done by hand.

## 9. Consumers of the deleted `artifact-paths`

Six call sites across five skills. Two die with the sweep pipeline; four need replacement prose.

| Skill | Call | After |
|---|---|---|
| `brainstorm-design` §1 | `--tier living` | Read `.dopamine/config`; the design document is the `living:` path whose basename is `DESIGN.md` |
| `brainstorm-architecture` §1 | `--tier living` | Same, for `ARCHITECTURE.md`, with `DESIGN.md` beside it as input |
| `writing-roadmaps` §1 | `--tier living` | Same, for `ROADMAP.md`, with both others as input |
| `adopting-a-repo` §1 | plain, exit 0 as verify | Read the config back and confirm each declared path parses |
| `routing-documentation-updates` | mentioned as "prints them" | Sentence describing the config format instead |
| `finishing-work` §2, §4 | plain, `--tier plans` | Deleted with the pipeline |

The config format replaces the script in three sentences: each line is `tier: path`; a declared path
that does not exist is **absent**, not an error; a missing `.dopamine/config` means the repository
has not adopted dopamine — run `dopamine:adopting-a-repo`. That last one replaces the script's
**exit 3** convention, which `brainstorm-design`, `brainstorm-architecture` and `writing-roadmaps`
all branch on today.

## 10. Tests

Deleted with their subjects: `test-seal-gate.sh`, `test-claude-md-guard.sh`, `test-seal-ledger.sh`,
`test-sweep-package.sh`, `test-artifact-paths.sh`.

Surviving and updated:

- `test-skill-structure.sh` — extended to cover `writing-living-documents` and both renames, and to
  assert every schema file is reachable.
- `test-authoring-skills.sh` — its `artifact-map` references updated; new assertions that each
  authoring skill points at its schema file through `${CLAUDE_PLUGIN_ROOT}`.
- `test-session-start.sh`, `test-refresh-rule-card.sh`, `test-plugin-manifests.sh` — unchanged but
  for the hook count.
- `test-spine-end-to-end.sh`, `test-guard-end-to-end.sh` — shrink to what survives.

## 11. Documents to update

- `README.md` — the component table, Requirements (Python leaves), and four of the eight Known Gaps
  describe deleted machinery.
- `hooks/session-start-context.md` — currently names `dopamine:sweep` and describes the sweep as the
  single moment documents change. It gains the instruction to load the relevant `writing-*` skill
  **before** writing to a governed document, which is the ad-hoc path no hook now covers.
- `.claude-plugin/plugin.json` — description mentions sealing and draining; version bump.

## 12. Open questions

- **Does `.dopamine/config` survive long-term?** It is the opt-in gate and stays for now, but with
  `artifact-paths` gone it is read by prose only. If it never diverges from convention, a later
  change could drop it and detect the documents by name.
- **Do the two `writing-*` skills load reliably on the ad-hoc path?** `session-start-context.md`
  names them, but nothing enforces it. This is the first place a rule failure would show, and the
  first candidate for escalation.

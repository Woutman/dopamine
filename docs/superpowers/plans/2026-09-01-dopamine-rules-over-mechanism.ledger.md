# SDD ledger — plan: docs/superpowers/plans/2026-09-01-dopamine-rules-over-mechanism.md

Spec: docs/superpowers/specs/2026-09-01-dopamine-rules-over-mechanism-design.md
Branch: rules-over-mechanism (base 08b11dc, plan commit cd6aca3)

## Pre-flight conflict scan

| Rows checked | What one produces / the other consumes | Found |
|---|---|---|
| T2×T3×T4×T6 — `tests/skills/test-skill-structure.sh` BUDGETS | T2 replaces the whole block; T3 retargets `claude-md-guard:500`→`writing-claude-md:550`; T4 appends a key; T6 retargets `sweep:700`→`finishing-work:700` | Clean. T2's replacement text preserves `claude-md-guard:500` and `sweep:700` verbatim, so T3's and T6's targeted edits still find their keys. |
| T2×T3×T4×T5 — `tests/skills/test-authoring-skills.sh` | Four tasks edit different needles; T4 deletes 8 assertions | Clean. T2/T3/T5 are in-place substitutions (no line-count change), so T3's `:122` still resolves. T4's deletions come after T3. |
| T1×T3×T6 — `tests/test-guard-end-to-end.sh` | T1 deletes lines 20–54 and 120–125; T3 retargets `GUARD_DIR` (:16); T6 rewrites the promotion-gate block | Clean. `GUARD_DIR`'s uses are at :60+ and survive T1's deletion; :16 is above T1's edit range. |
| T1×T6 — `tests/test-spine-end-to-end.sh` | T1 strips the gate; T6 rewrites the file wholesale | Not a conflict, deliberate churn: T1 must end with a green suite, and its edit is discarded by T6. **Ruling: keep T1's edit.** |
| T2×T4×T5×T6 — `skills/writing-roadmaps/SKILL.md` | T2 sed at :14; T4 replaces §3 (31–41); T5 replaces §1 (18–20); T6 replaces the paragraph at :53 | **FINDING: T6's `:53` is stale** once T4 and T5 change the file's length. |
| T2×T4×T5 — `skills/brainstorm-design/SKILL.md`, `brainstorm-architecture/SKILL.md` | T4 edits §3 (34–48 / 32–43); T5 edits §1 (20–24) | Clean. T5's target lines precede T4's, so T4's length change cannot move them. |
| T2×T3×T4×T5 — `skills/adopting-a-repo/SKILL.md` | T2 :14, T3 :61, T4 §4 :50, T5 §1 :33 | Clean, same reason: T5's :33 precedes T4's :50. |
| T5×T6 — `artifact-paths` | T5 removes every reference; T6 deletes the script | Clean by construction; the deleted-script assertion was moved into T6 during plan self-review for exactly this reason. |
| T6×T7 — `hooks/session-start-context.md` | T6 rewrites it (moved out of T7 during self-review) | Clean; T7's Files list no longer claims it. |
| Each task against itself | tests specified vs code specified; files created vs files later touched | Clean for T1–T5 and T7. T6 self-agrees but see the finding above. |

**Ruling 1 (pre-flight): T6 Step 5's `skills/writing-roadmaps/SKILL.md:53` must be located by content, not by line number.** T4 and T5 both shorten the file above that point, so the number will be wrong by the time T6 runs. The paragraph to replace is the one beginning `The ledger is immutable, so the trail cannot rot` — unique in the file. Cost if wrong: the implementer rewrites a neighbouring paragraph; caught by `tests/skills/test-authoring-skills.sh`'s roadmap assertions and by T6 Step 5's own closing grep.

No other conflict found. Nothing the plan mandates is a review-rubric defect.

## Execution log

Task 1: dispatched (sonnet, BASE cd6aca3, brief task-1-brief.md)
Briefs for Tasks 2-7 pre-extracted.
Task 1: implementer DONE, commit b123508, 12 test files pass. Review dispatched (sonnet).
Task 1: review clean — Spec OK, quality Approved.
Task 1: minor (deferred): tests/test-spine-end-to-end.sh:53 prose still says "where the gate looks for it" — Task 6 rewrites the file.
Task 1: minor (deferred): README.md:25-26,72-73 still document the two hooks as live — Task 7 rewrites those sections.
Task 1: resolved the reviewer's one "cannot verify" item myself — RED evidence is not re-derivable from a single-commit diff, but the RED phase is waived by spec section 8 and the report's pasted failure text matches the brief's prediction. Not a gap.
Task 1: complete (commits cd6aca3..b123508, review clean)
Task 2: implementer DONE_WITH_CONCERNS, commit 62ba61a, 12 test files pass.
Task 2: Ruling: the brief's new "Once the destination is decided" section forward-references dopamine:writing-claude-md (Task 3) and dopamine:writing-living-documents (Task 4), which tests/test-authoring-end-to-end.sh's reference-resolution check rejects — a plan defect my pre-flight scan missed (an intra-task test conflict, not a cross-file one). The implementer's narrow, commented FORWARD_DECLARED allowlist stands. Task 4 MUST delete it, since both skills exist by then, and Task 4's review must verify the deletion. Alternative considered and rejected: writing the section without the two names in Task 2 and adding them in Task 4 — that splits one spec'd paragraph across two tasks for no gain. Cost if wrong: a temporary weakening of one check survives into main for two names that do resolve by Task 4; caught by Task 4's review and the final whole-branch review.
Task 2: brief said "five" dopamine:artifact-map needles in test-authoring-skills.sh; four exist. Brief typo, no consequence.
Task 2: brief's file list missed two dopamine:artifact-map needles in test-skill-structure.sh (inside the sweep and claude-md-guard content blocks); implementer renamed the needles. Correct.
Task 2: review Spec OK / quality Approved, three Minors.
Task 2: resolved both reviewer "cannot verify" items myself: `bash tests/run-tests.sh` exits 0 with "all 12 test file(s) passed", and the renamed skill's body is 524 words against its 600 budget (recomputed with the test's own awk+wc logic).
Task 2: minor (deferred): skills/sweep/discovery-prompt.md:65 and skills/sweep/verifier-prompt.md:32 still say "the artifact map" in prose, naming nothing. Self-resolving — Task 6 deletes both files.
Task 2: minor (deferred): assertion LABELS in tests/skills/test-skill-structure.sh:166,231 and tests/skills/test-authoring-skills.sh:50,74,99,123 still read "the artifact map" though their needles are renamed. Cosmetic; not expanding task scope for it. Final review triages.
Task 2: minor: the BUDGETS block comment lost sweep's recorded 600->700 rationale. Carried into Task 6's dispatch as a required restoration, since Task 6 rewrites that key anyway.
Task 2: brief self-contradiction, no action: Step 5's "grep shows no output" check still matches the word artifact-map inside the new BUDGETS comment that Step 1 dictates verbatim.
Task 2: complete (commits b123508..62ba61a, review clean)
Task 3: implementer DONE_WITH_CONCERNS, commit 133d253, 12 test files pass, skill body 494/550 words.
Task 3: Ruling: the brief's verbatim "When this fires" text names dopamine:finishing-work, which Task 6 creates — the same forward-reference defect as Task 2, and the plan has it a second time. The implementer's additive FORWARD_DECLARED entry stands. Removal now splits: Task 4 removes writing-claude-md and writing-living-documents; Task 6 removes finishing-work and deletes the allowlist block entirely, and each task's review verifies its own removal. Cost if wrong: an exemption outlives the reason for it and one reference check stays weakened for names that do resolve; caught by the Task 4 and Task 6 reviews and by the final whole-branch review, which I will point at this line.
Task 3: Ruling: Tasks 4, 5 and 7 dispatches must each check their verbatim insertions against that same allowlist before running, since two consecutive tasks hit it. Applied to the Task 4 dispatch onward.
Task 3: brief's file list missed tests/skills/test-skill-structure.sh:181, which asserted the literal dopamine:claude-md-guard inside the sweep content block; implementer retargeted the needle. Correct.
Task 3: review Spec OK / quality Approved. No cannot-verify items; reviewer independently confirmed the git mv, the executable bit on scripts/refresh-rule-card, and a zero-hit final grep.
Task 3: minor (no action): the report miscites progress.md line numbers for a Task 1 deferral. Citation only; the scope decision is right.
Task 3: complete (commits 62ba61a..133d253, review clean)
Task 4: implementer DONE, commit 3d94219, 13 test files pass. FORWARD_DECLARED trimmed to "finishing-work" as instructed; no new forward reference needed.
Task 4: Ruling (forward-looking, applies to Task 5): adopting-a-repo's body is 698 words against a 700 budget, and Task 5's verbatim replacement for its verification sentence is 45 words where the old one was 16 — projected 727, over budget. The plan never noticed. Task 5 raises adopting-a-repo:700 to 750 in tests/skills/test-skill-structure.sh's BUDGETS with a reason recorded in the block comment, rather than trimming prose the plan specifies word for word. Rationale: the budget is a ratchet with a recorded reason, which is exactly the mechanism for a justified increase; the prose is the spec'd deliverable. Cost if wrong: 50 words of headroom that nothing forces the skill to use, visible in the comment and revisitable.
Task 4: review Spec OK / quality Approved, zero findings, zero cannot-verify items. Reviewer independently confirmed the slot-table-in-one-place block is non-vacuous, adopting-a-repo section 4 keeps both halves, the new test file is executable, and all three ${CLAUDE_PLUGIN_ROOT} schema paths resolve.
Task 4: complete (commits 133d253..3d94219, review clean)
Task 5: implementer DONE, commit ab424e8, 13 test files pass. adopting-a-repo measured at exactly the predicted 727 words; budget raised 700->750 with a recorded reason per the ruling above. FORWARD_DECLARED untouched (finishing-work only).
Task 5: two brief gaps fixed by the implementer: writing-roadmaps had no prior artifact-paths needle to replace (the brief's "four config-location assertions" phrasing was wrong), so the three-line block was added rather than substituted; and a stale header comment in tests/test-authoring-end-to-end.sh was updated.
Task 5: review Spec OK / quality Approved. Reviewer independently confirmed 727 words under the raised 750 budget, byte-identical config lines, README/adopting-a-repo config-block equality, no surviving TEST_ROOT/repo/bare references, and FORWARD_DECLARED unchanged.
Task 5: resolved the reviewer's cannot-verify item myself: `bash tests/run-tests.sh` exits 0, "all 13 test file(s) passed".
Task 5: Ruling: the reviewer's one Important finding is plan-mandated and stands as written. writing-roadmaps section 1 does not state the general "a declared path that does not exist is absent, not an error" fact that the other three rewritten sections carry, which is a real gap against the plan's own "same three facts at each call site" contract. Accepted anyway: that section reads two INPUT documents rather than declaring an output path, and it already handles absence in the form that matters there — it routes to the recipes that create them instead of erroring. Adding the general sentence would restate a fact with no decision hanging off it in this skill. Cost if wrong: a reader who reaches only writing-roadmaps learns the absence rule from .dopamine/config's comment or from routing-documentation-updates rather than in place. Pointed the final whole-branch review at this line.
Task 5: complete (commits 3d94219..ab424e8, review clean, 1 parked)
Task 6: implementer DONE, commit 1b98af5, 10 test files pass (down from 13). I verified independently: FORWARD_DECLARED is gone from tests/, skills/ holds eight directories with sweep replaced by finishing-work, and every surviving hit for the old names is a guard assertion except README.md:75, which is Task 7's.
Task 6: Ruling: the plan's verbatim finishing-work/SKILL.md text is 714 words against the 700 budget it inherits from sweep. The implementer trimmed wording to 699 rather than raising the budget. Accepted, and deliberately the opposite call from Task 5's: there the prose carried a tested contract restated at four call sites, so the budget moved; here the budget is the ratchet on the very document whose whole claim is that it got simpler, and raising it at the moment of simplification would defeat it. Conditional on the trim losing no substance — sent to review with a word-by-word comparison against the brief as its first job. Cost if wrong: an obligation or exit-gate check silently dropped from the recipe, which is the one thing this plan cannot afford; caught by that review.
Task 6: brief's file list missed README.md:32's dopamine:sweep cell, which broke the reference-resolution check after the rename. Implementer renamed just the skill name and left the stale description for Task 7. Correct.
Task 6: review — TRIM VERDICT: substance preserved, pure wording economy. 699 words vs the brief's 714; everything from "### 3. Commit" to EOF byte-identical; the six edits dropped intensifiers and one sentence the preceding clause already entails. All four Obligations, all five gate checks, the cp command, the sweep: prefix and its git log rationale, wc -l, "Method is your judgment", the routed-promotion rule and the position statement all intact. The conditional on my ruling is discharged.
Task 6: review Spec OK / quality Approved. All four rulings verified discharged, including FORWARD_DECLARED gone entirely with the check now strictly stronger than before the plan started. Spine test confirmed free of tautologies; injection is 121 words with no prohibitions; nine deleted files gone with zero live references.
Task 6: rename history is a git similarity-detection artefact, not lost history — `git show --stat -M10%` renders skills/{sweep => finishing-work}/SKILL.md.
Task 6: minor (deferred to Task 7): README.md:32's description still describes the deleted four-stage pipeline; README.md:75's Known-gaps bullet names skills/sweep/ and a gap that no longer exists.
Task 6: minor (deferred to Task 7): .claude-plugin/plugin.json:16 still carries the keyword "sweep". Defensible — the concept and the commit prefix both survive — but Task 7 must decide it deliberately rather than by omission.
Task 6: complete (commits ab424e8..1b98af5, review clean)
Task 7: implementer DONE, commit 49db766, 10 test files pass. All three handed-off items resolved: README:32's description rewritten, README:75's gap bullet deleted, plugin.json's "sweep" keyword kept deliberately (the commit prefix and the seal/drain concept both persist). Stale-name grep over README.md and .claude-plugin returned zero hits.
Task 7: review Spec OK / quality one Important finding.
Task 7: Ruling: README.md:62's "Python 3 is used by the test suite ... and by nothing the plugin ships" is false and enters the fix loop. Verified myself: skills/writing-claude-md/scripts/refresh-rule-card:82 shells out to python3, and it is a shipped file. The sentence is the plan's own verbatim text, but a plan cannot mandate a false statement about the repository, and this one sits in the Requirements section a user reads before installing. Not defended on plan-mandate grounds. The fix must keep the "bash and git is the whole runtime" claim, which stays true for the hook-and-skills path, while disclosing the maintenance script's python3 dependency in the same place it already discloses that script's curl/wget one. Cost if wrong: two sentences of prose churn in a section nothing tests.
Task 7: fix round 1/5 (1 addressed, 0 open — README:62's false python3 claim split into a test-suite sentence and a maintenance-script dependency line; commits 49db766..5f83e46). Scoped re-review dispatched.
Task 7: fix round 2/5 (1 addressed, 0 open — "Python 3, curl or wget" read as three interchangeable alternatives when the requirement is Python 3 AND one of curl/wget; now "**Python 3** and **either curl or wget**"; commits 5f83e46..37c5485). Re-review ADDRESSED, no breakage.
Task 7: complete (commits 1b98af5..37c5485, review clean)

## All tasks complete. Final whole-branch review next.

## Final whole-branch review
Verdict: ready as-is. Zero Critical, zero Important, six Minors. Suite verified independently at 10 files passing. All 9 dopamine: names resolve, all 5 ${CLAUDE_PLUGIN_ROOT} paths exist, hooks.json registers SessionStart only with an executable command, zero live references to the twelve deleted names, docs/ is two additions and nothing else.
Ledger triage: all 24 items can stand; every deferred minor handed forward was verified resolved by its receiving task.
Task 6 trim independently re-verified: byte-identical from "### 3. Commit" to EOF, six edits all intensifiers or entailed clauses.
Task 5 parked finding: reviewer agrees it can stand, but adds that writing-roadmaps has 128 words of budget headroom and the fix costs ~10.
Ruling: REVERSING my Task 5 ruling on that one point and taking the fix. The reason I gave for omitting it was that the sentence would carry no decision in that skill; the reason I did not weigh was that spec section 9 wants the same three facts at each call site and the cost is 10 words of 128 available. When a spec's literal intent is purchasable at no cost, the spec wins over my judgement about redundancy. Cost if wrong: one sentence of restatement in a skill with ample budget.
Fix wave: one dispatch for all six Minors, then one scoped re-review.
Fix wave: complete (commits 37c5485..b60b870). Scoped re-review: all six ADDRESSED, no breakage, 734/850 words, BUDGETS untouched, suite green at 10 files.

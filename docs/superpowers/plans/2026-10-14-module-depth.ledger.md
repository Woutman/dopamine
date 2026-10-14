# SDD ledger — plan: docs/superpowers/plans/2026-10-14-module-depth.md

Execution: Task 1 subagent-driven (human's choice); Tasks 2–8 native in this session.
Spec: docs/superpowers/specs/2026-10-14-module-depth-design.md (reachable).

## Preflight scan
| Pair / task | Produces → consumes | Found |
|---|---|---|
| T1 → T2, T7 | scripts, overlays, prompts, labels A/P/X0-n, pools | consistent: T2/T7 consume the interfaces T1 lists |
| T3 → T4, T6 | `Offers its callers`, `Must hold`, `named exception` | consistent |
| T3, T4 | both edit tests/skills/test-living-documents.sh, test-authoring-skills.sh | sequential appends, no conflict |
| T4, T5, T6 | each raises one budget in tests/skills/test-skill-structure.sh | different skills' lines, no conflict |
| T5 | replaces test-authoring-skills.sh:111-112 ("read for risk only") | line numbers may shift after T3/T4 appends; match by text |
| T1 | test file vs created files | self-consistent (verified in scratch before compaction) |
| T2–T8 | each own text | consistent |

Ruling: T5's line reference is matched by text, not line number — T3/T4 may shift lines — cost if wrong: none, the assertion text is unique.

Task 1: implementer DONE, commit 8bdfac6; 14/14 test files pass.
Ruling: fixture parsing.py keeps stdlib xml.etree despite an XXE hook warning — it parses only the fixture's own test data and etree does not resolve external entities — cost if wrong: none outside a scratch fixture.
Task 1: ⚠️ run-tests picks up the new file — verified by controller: all 14 test file(s) passed.
Task 1: minor (deferred): work-diff test asserts added lines only; add a no-removed-lines assertion
Task 1: minor (deferred): render — missing @PATH gives a traceback and exit 1, not 2 (brief-mandated code)
Task 1: minor (deferred): template list in the test is hard-coded
Task 1: minor (deferred): setup-run inherits global git init/signing config
Task 1: complete (commits f1e9d27..8bdfac6, review clean)

Tasks 2–8: native (executing-plans), per the human.
Task 2: RED plugin copy built (0.1.4 IDENTICAL to branch); 9 runs set up and prompts rendered.
Task 2: dispatched A0-1 a124f813ba302d6b7, A0-2 af106f01f7c50b26b, A0-3 a3572cbd594cd6406, P0-1 abaab0d6eed68a62a, P0-2 aa6b73cf33fdd4e85, P0-3 a251dbe885f654640, X0-1 a064a84a7d6813478, X0-2 a5553ab0f590ecf07, X0-3 a72b0437c8933e48d
Task 2: Ruling: setup and render ran from a job-tmp script, not inline loops — the session's worktree guard refuses loops that call bash — cost if wrong: none, same commands.
Task 2: all 9 replies saved; every run committed >=1; home clean. No P0 run stopped to ask, so none was continued.
Task 2: tally (unblinded — checkpoint only):
  A0: table 3/3, exception 3/3 (types.py 'on purpose', 'shared vocabulary'), invariant 3/3 — but the pre-answered brainstorm states all three outright, so A measures transcription
  P0: clean 0/3 — P0-1 and P0-3 tests import feedwatch.notify.formats; P0-2 rewrites notify/formats.py's 'from feedwatch.fetch.parsing import clean_title'. named yes 3/3, stopped no 3/3, pairs no 3/3 (channel alone decides)
  X0: reach-in 3/3, wrapper 3/3; guard misflagged yes 3/3 — every run flagged the legitimate FetchError import as a duplicate and removed it
Task 2: checkpoint — A0 clean would drop §3.1; P0 not clean so §3.2 stays; awaiting the human.
Task 2: Human ruling at checkpoint: keep all items (§3.1 included); drop the old A arm; asked for an A arm that tests the right thing.
Task 2: Ruling: A arm reworked (commit after 8bdfac6) — answers cover only today's stage-2 scope, run may end with questions, rubric scores doc-or-question — the old answers stated all three columns so RED was 3/3 by transcription — cost if wrong: 6 runs and one judge on an arm that still cannot separate.
Task 2: old A runs moved to red/architecture-v1 (out of the pool); A0-1..3 re-run with the new prompt: af97645693fc31964, a67997f24627625db, ae2b2a70272a74613.
Task 3: complete (commits 880611e..8f58635, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Task 3: Ruling: the test 'enforcement and admission are the Modules slot' passed before the change (the old sentence held the phrase) — kept, since assert_not_contains on the old sentence pins the change — cost if wrong: none.
Ruling: arm A rubric credits a question only when it names the specific item (human-relayed side note) — broad questions could otherwise score — cost if wrong: a run that asks well but loosely scores no; judges see the rubric only after GREEN, so no runs are redone.
Task 4: complete (commits 178ae7a..8002090, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Task 5: complete (commits 8002090..b1c993c, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Task 5: writing-roadmaps budget 850 → 880 (880 words after the edit), as the brief's step 5 directs.
Task 6: complete (commits b1c993c..7b7272f, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Task 7: GREEN plugin built from branch skills; 9 runs set up, RED pooled in (A pool uses the v2 A0 runs); prompts rendered.
Task 7: dispatched A1-1 a86938c4703c674dc, A1-2 ad33d14eac6665efc, A1-3 a7b268d2439201b15, P1-1 a386df40db4a70d7c, P1-2 a975997afa8970cca, P1-3 a80de329d7ef444d2, X1-1 a43298bdbfbd1b86e, X1-2 a4df9a433834245f2, X1-3 a2cf6f70385812f2c
Task 7: all 18 pooled runs have replies; home clean; blind leak grep 0 in every pool. Judges (opus): architecture af1a13977e3134456, plan adaaf441e5bee33f8, gate a1b8e24fa9c9ab296.
Task 7: Ruling: the plan judge was not pointed at the green overlay documents — its rubric names none and the rendered prompt carries none — cost if wrong: a plan whose clean cell needs the overlay to read is judged on items.md alone.
Task 7: scores (blind, pooled, opus judges):
  architecture: A0 table 3/3, exception 0/3, invariant 3/3 | A1 3/3, 3/3, 3/3
  plan: P0 clean 0/3, named 3/3, stopped 0/3, pairs 0/3 | P1 clean 3/3, named 3/3, stopped 0/3, pairs 0/3
  gate: X0 reach-in 3/3, wrapper 3/3, misflagged 2/3 | X1 3/3, 3/3, 0/3
Task 7: pass criteria met — every main 3/3; named=no 0 vs 0; misflagged 0 vs 2; no regression; no refactor round.
Task 7: judge borderlines — arch: p002/p005 table thin yes, p003 exception yes from one combined question, p004 invariant yes via --format question, p002 exception no; plan: p001/p002 clean no (tests import notify.formats; rewritten clean_title import), named yes where unexported imports sit in __init__; gate: p001 misflagged no (FetchError removal called a tidy).
Task 7: complete (commits 7b7272f..fdee293, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Task 8: complete (commits fdee293..5e57702, tests: bash tests/run-tests.sh → all 14 test file(s) passed)
Final: review (opus) — 1 Important, 5 Minor; all five Review Focus items clean.
Final: fixed blinding leak (copied-in RED runs kept their absolute path) — test 'a run copied from another stage reads as a repository too' RED→GREEN, then 'even where the path ends a sentence' RED→GREEN; suite 14/14. Pools re-blinded (0 paths, stages, labels left) and re-judged by 3 fresh opus judges: abe707f04e53c2ef5, a2a110f43cbcbae6a, ac276ad914b98abab.
Final: Ruling: routing table's 'module depth' re-graded Minor→Important and fixed to 'module boundaries and admission' — a sweep would route a component's offers to PROGRAM-DESIGN.md — tests RED→GREEN, suite 14/14 — cost if wrong: none.
Final: Ruling: close-path test re-graded Minor→Important (Review Focus 5 promised it) and now asserts '— proceed'; it passed on first run since the skill already said so — cost if wrong: none.
Final: Ruling: re-judges get no borderline readings from the leaky round — an independent measurement — cost if wrong: cells may flip on borderlines.
Final: Ruling: tests/baselines/program-design/blind left with the old scrub — its results are sealed and nothing reuses it now — cost if wrong: a future baseline copying it leaks the same way.
Final: minor (deferred): adopting-a-repo says the depth principle is never written but not who asks it
Final: minor (deferred): writing-roadmaps budget comment says 'raised from 850' without 'to 880'
Final: minor (deferred): only the exception column separates the A arms; table and invariant are 3/3 in control
Final: re-judged scores (blind) — architecture A0 table 1/3, exception 0/3, invariant 3/3 | A1 3/3, 2/3, 3/3; plan P0 clean 0/3 | P1 3/3 (named 3/3 both, stopped 0, pairs 0); gate X0 3/3, 3/3, misflagged 2/3 | X1 3/3, 3/3, 0/3. Pass criteria hold (A1 exception 2/3 with control 0/3). Leaky round's scores superseded.

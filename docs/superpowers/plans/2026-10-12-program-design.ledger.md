# SDD ledger — plan: docs/superpowers/plans/2026-10-12-program-design.md

Execution: Task 1 subagent-driven; Tasks 2+ native (human's choice, 2026-10-12). Stop after Task 2 for joint RED analysis (human's instruction).
Spec: docs/superpowers/specs/2026-10-12-program-design-design.md

## Preflight scan
| Rows | Produces / consumes | Finding |
|---|---|---|
| T1 → T2 | setup-run/blind/score/vocab.tsv; T2 Step 6 columns asked,wrote,elements / stopped..complies | all 12 columns declared in T1 vocab.tsv with matching values (undecided present) — consistent |
| T1 → T7 | same tooling; GREEN columns for G/X/N | T7 is draft, revised after RED; vocab may need columns then — no ruling now |
| T1 self | test asserts fixture signals (raise FetchError, return None, return False,, Two processes, ## Concurrency) vs fixture/overlay code in task | checked needles at plan-writing; implementer verifies by running |
| T2 self | prompts in T2, runs in .dopamine/run (gitignored) | consistent |
| T3–T8 | draft | out of scope until Phase 2 revision |

## Tasks
Task 1: dispatched implementer (sonnet), BASE f5a7a26
Task 1: implementer DONE 21cd9de, 0 deviations; reviewer dispatched (opus)
Task 1: review — spec ✅, Needs fixes: I1 .pyc leak into items (plan-mandated), I2 work overlay test file unannotated = second Signatures violation (plan-mandated)
Ruling: fix I1 and I2 despite plan text — spec requires blinded items without arm-correlated signal and exactly one planted violation — cost if wrong: a .gitignore and annotations in a fixture, trivially reverted
Ruling: promote reviewer Minor 2 (blind crashes / misses work in a nested worktree) into the fix — a RED run using superpowers' worktree layout would be judged as doing nothing — cost if wrong: a few lines in blind
Task 1: minor (deferred): gate items list the work overlay as added (diff vs baseline-base); identical across arms — revisit in Phase 2 revision before Task 7
Task 1: minor (deferred): blind exits 1 with traceback on non-int --seed or missing baseline-base tag
Task 1: minor (deferred): score drops verdict rows absent from key.tsv; labels sort as strings (P0-10 before P0-2)
Task 1: minor (deferred): uncommitted-file behaviour of blind untested
Task 1: minor (deferred): test comments at test-program-design-baseline.sh:63,66 narrate (plan-mandated, cosmetic)
Task 1: fix round 1 committed b31241c; re-review dispatched
Task 1: fix round 1/5 (3 addressed, 1 open — new: blind crashes on a worktree dir deleted by rm -rf without worktree prune; commits 21cd9de..b31241c)
Task 1: minor (deferred): work overlay's keep() returns False as a predicate; full doc's Errors Check literally says no added `return False` — a strict gate run may flag it; decide in Phase 2 revision before arm X
Task 1: minor (deferred): a branch named baseline-base would make blind's diff ambiguous
Task 1: fix round 2 committed d071656; re-review dispatched
Task 1: fix round 2/5 (1 addressed, 0 open; commits b31241c..d071656)
Task 1: minor (deferred): blind trusts any existing dir listed as a worktree (an empty leftover dir would pass isdir)
Task 1: complete (commits f5a7a26..d071656, review clean)
Task 2: started native (controller)
Task 2: Ruling: {DOPAMINE} filled with the installed plugin cache path (~/.claude/plugins/cache/dopamine/dopamine/0.1.3, byte-identical skills and hook) instead of the repo path — pointing runs at the repo invites them to read this feature's spec/plan and contaminate RED — cost if wrong: none for RED; GREEN must point at the repo's edited skills
Task 2: prompts written (uncommitted); 10 runs set up and dispatched. Agent ids: R0-1 a184b22d7e65f29ba, R0-2 ab7d5df6cfd432e75, R0-3 a5976ddcbb6bfbf8b, R0-4 a148dba835d1ba666, R0-5 a2b431b5d524da8b8, P0-1 a6810c35362e1e503, P0-2 a0a4a2de264420f29, P0-3 ae3d4b6bdbb1d136b, P0-4 a350eb7c5ec638f2e, P0-5 a5381b17380c736f3
Task 2: Ruling: replies saved by extracting each run's SubagentHandback message from its transcript (verbatim), not from the paraphrased hand-back shown to the controller — cost if wrong: none
Task 2: all 10 replies saved; no P0 stopped, no continuation sent
Task 2: Ruling: verdicts filled by fresh judge subagents reading only out/items.md (+ full PROGRAM-DESIGN.md + rubric), not by the controller — the controller saw every reply with its label while saving it, so it is not blind — cost if wrong: one judge's calibration; controller spot-checks
Task 2: recipe pool judged (opus judge): 5/5 asked=no wrote=yes
Task 2: complete (commits d071656..a7a0038, R0 5/5 wrote without asking; P0 spread 0, constraints 0/5, complies 0/5) — STOPPED for human review per instruction
Task 2b (human-requested after RED review): greenfield arm F0 — fixture + setup-run --fixture committed d04a75c; 5 runs at .dopamine/run/program-design/red/greenfield/runs, same plan.md prompt, SPEC=docs/superpowers/specs/2026-03-01-feedwatch-v1-design.md. Gate: spread >= 2. Decisions this review: keep gap stop (P0 imitation supports its rationale); add F1 to GREEN; tighten full doc's Errors Check (predicate False is an answer) before arm X.
Task 2b: F0 dispatched. Agent ids: F0-1 a5814f51f72804491, F0-2 a66202e4ad270118a, F0-3 af332207fb57959de, F0-4 abb89a920232e71bb, F0-5 a9b6f0a7dcc5d848d
Task 2b: F0-4 failed (API error: no response, server_error) with no commit; replaced by F0-6 per Task 2 Step 5, F0-4 dir deleted
Task 2b: F0-6 dispatched, agent ac3639326c97ad1c9
Task 2b: F0-1 saved. Side effect: F0-1 briefly wrote ~/.feedwatch/feeds.db (empty) in the real home and removed it; verified ~/.feedwatch absent. Runs left scratch in /tmp/fw-* — clean after F0-6 finishes
Task 2b: Ruling: vocab layout gains per-component|other — greenfield has no existing modules, so new-module/existing-modules cannot describe it — cost if wrong: one vocab line. /tmp/fw-* run scratch removed.
Task 2b: complete (F0 judged by opus judge; spread 2 — errors raise x4/mixed, signatures mixed x2/positional x3; constraints 0/5 complies 0/5; committed 83f69a3) — STOPPED for human review
Review 2 decisions (human: "Go for it"): full doc (both overlays) — Modules rule/check scoped to modules that are not ARCHITECTURE components; Errors check reworded (predicate False is an answer). Vocab + verdict sheets gain store-api, error-base, types-home; judge rejudging P0+F0 on them and F0 modules.
Review 2: rejudged; committed d6b2909
Phase 2 revision committed 69615d8; awaiting human approval before Task 3
Phase 2 approved by human ("Revision looks good. Continue executing the plan")
Task 3: complete (commits 69615d8..16f661f, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Task 4: Ruling: plan's recipe text plus the Common mistakes table was 759 words against 650; trimmed prose per Step 4 (wrapper-contract enumeration, schema sentence, frozen-spec line, check sentence, revise sentence, overview precedent clause) to exactly 650, no row cut — cost if wrong: a reader of the recipe misses detail that dopamine:brainstorm-design already holds
Task 4: complete (commits 16f661f..29e8b08, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Task 5: Ruling: adding living: docs/PROGRAM-DESIGN.md to adopting-a-repo's config broke tests/test-authoring-end-to-end.sh (README/skill configs must match; six paths; three living), which no task updated — updated that test to seven/four plus a PROGRAM-DESIGN.md:brainstorm-program-design recipe pair, and pulled Task 8 Step 1's README config bullet (block line + "seven lines") forward into Task 5 — run-tests must pass at every task end — cost if wrong: none; Task 8 skips that bullet
Task 5: adopting-a-repo measured 791 words > 750; budget raised to 830 with the plan's recorded reason (Step 7)
Task 5: complete (commits 29e8b08..2563f35, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Task 6: finishing-work measured 772 > 730; budget raised to 790 with the plan's recorded reason (Step 5). Injection 219/240 words
Task 6: complete (commits 2563f35..3a1b892, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Task 7: Step 1 done (store API in both overlays; test RED→GREEN; overlays still differ only by Concurrency + asyncio). Step 2 gate.md written. Step 3 runs set up, RED pooled in, plugin copied to .dopamine/run/program-design/green/plugin
Task 7: Ruling: in the plugin copy, ${CLAUDE_PLUGIN_ROOT} in skills/*.md was replaced with the copy's absolute path, as the harness substitutes it for a loaded plugin — otherwise runs must guess where the schemas are, an environment failure, not a skill one — cost if wrong: RED runs saw it unsubstituted; affects only whether they found the schemas
Task 7: prompts rendered by $CLAUDE_JOB_DIR/tmp/render-green.py into tmp/green-prompts; dispatched P1-1 a285919a401c968d3, P1-2 a614fbdd100e2a26b, P1-3 a5cf025e80e953485, P1-4 a68f48476ff71bbe8, P1-5 ad9d53b2a29491d7f, G-1 aeccec10142589974, G-2 ae68b6e556508f400, G-3 ab715c6046540ecbd, G-4 a6d06ab06f94c9061, G-5 ab27912d54b51fc05
Task 7: G-1..5 saved (one turn each, all stopped with a question)
Task 7: dispatched N-1 ac5a95add17afc642, N-2 a61e0a36e4c13af6a, N-3 a706ed76183853b06; F1-1 a5f2d91191d38d0db, F1-2 a6f13d831e7871fd3, F1-3 a1b8eea23a629aa54, F1-4 a99a830aba0ae2ba4, F1-5 a808b630d47caea22, X-1 a75c445aa2b503ec8, X-2 a861718e97ec9bd0f, X-3 ab7548e64cb1e4430, X-4 aedf671f371a01cde, X-5 aacb312168e453ec0
Task 7: X-1..5 saved (one turn); N-1..3 first replies saved, all asked; continuing with 'No — plan without it.'
Task 7: R1-1..5 saved (one turn, R1 agents abca4206472a7ccc3 ab83ea6335d59d38a ae1622d1c102b5360 a8aa35e0a8b43a216 ad89edd67dc0c97bd); all five asked Types first without writing
Task 7: P1-1..5 saved; all committed a plan, none stopped, no continuation sent; N-3 continued and committed
Task 7: N-1..3 second replies appended; all committed a plan after the decline
Task 7: F1-1..5 saved; all committed a plan, none stopped
Task 7: all 28 runs saved; /tmp/fw-proto removed; ~/.feedwatch absent. Pools blinded. Opus judges: plan adfc84f0c10741ba2, greenfield a41f05c57ed2fb8fe, recipe ab0730098ad2e99bb, gap a9173944cb8808df9, gate a668c348fd6f642bf, absent a7f0bcfc41fcaa8df
Task 7: Ruling: complies judged on added lines only (pre-existing code the plan leaves untouched does not count) — the full document's checks are written over added lines — cost if wrong: P1 complies inflated relative to a stricter reading
Task 7: scores — G stopped 5/5 concurrency 5/5; X flagged 5/5 misflagged 0/5; N asked 3/3 stopped 0/3 constraints 3/3; R0 asked 0/5 wrote 5/5 / R1 asked 5/5 wrote 0/5 elements 5/5; P0 constraints 0/5 complies 0/5 / P1 stopped 0/5 constraints 5/5 complies 2/5 (P1-1, P1-2, P1-4 fail Signatures on rewritten poll_once def leaving conn etc. unannotated; P1-4 deliberately: annotating conn needs sqlite3 in poller, which Effects check forbids). Criterion 2 FAILS.
Task 7: F0 constraints 0/5 complies 0/5 / F1 stopped 0/5 constraints 5/5 complies 3/5 (F1-4 conn.close() in cli — Effects; F1-3 urllib.parse in cli — Effects). Criterion 3 FAILS. Criterion 7 holds (P1 2/5 > P0 0/5; F1 3/5 > F0 0/5). Diagnosis: rules copied 10/10 but not applied to the plan's own code (incl. rewritten defs). REFACTOR 1: injection.
Task 7: REFACTOR 1 — injection: "copy each rule … into Global Constraints, and run every check over the plan's own code, a changed line included, before committing it." Test added RED→GREEN; suite green; injection 234/240. Plugin copy's hook refreshed. Re-running P1r1-1..5 and F1r1-1..5 in the same pools.
Task 7: Ruling: only the failing arms (P1, F1) re-run on the revised injection, as Step 8 says; G, N, X ran on the earlier wording and passed — cost if wrong: the revision could in principle change G/N/X behaviour unmeasured (it adds a check step only after the rules are read, so the gap stop and absent-ask paths are unchanged)
Task 7: dispatched P1r1-1 abdf41c5e0cd16e0e, P1r1-2 aa6d3011b308bc125, P1r1-3 a3a72ebf967963073, P1r1-4 a8f00928ce9d5f2d1, P1r1-5 a028bdaac7da9c26a, F1r1-1 a2896cf825aa7e88a, F1r1-2 a19ddf17a67bd9338, F1r1-3 a8804657007374aaf, F1r1-4 ab39068d60570e77b, F1r1-5 a517bb99752778953
Task 7: P1r1-1..5 saved (all committed, none stopped). Plan pool's first judging kept at out.round0; whole pool re-blinded to out/
Task 7: plan pool re-judge (fresh opus) a26bb3401b090dc93. Ruling: re-judge prompt states the first judge's two readings explicitly (rewritten def line counts as added; tests excluded) so the rounds are judged alike — cost if wrong: none; both readings were the first judge's own
Task 7: plan pool re-judged: P0 constraints 0/5 complies 0/5; P1 5/5, 1/5 (P1-3 flipped yes→no on StrEnum FilterKind read as a non-frozen domain type — judge variance); P1r1 stopped 0/5 constraints 5/5 complies 5/5. Criterion 2 PASSES on P1r1.
Task 7: F1r1-1..5 saved (all committed, none stopped). Runs' /tmp/fw* scratch (all created today during runs) removed; ~/.feedwatch absent. Note: parallel runs collided on fixed /tmp names (F1r1-1 rebuilt in a unique dir). Greenfield pool re-blinded; round0 kept at out.round0
Task 7: greenfield re-judged: F0 0/5 0/5; F1 constraints 5/5 complies 3/5; F1r1 stopped 0/5 constraints 5/5 complies 4/5 (F1r1-1 fails Signatures: store.add_entries has * before its 4th param). Criterion 3 PASSES.
Task 7: GREEN PASSES all 7 criteria after REFACTOR 1. Score tables:
-- recipe
| arm | runs | asked | wrote | elements | spread |
|---|---|---|---|---|---|
| R0 | 5 | 0/5 | 5/5 | 0/5 | 0 |
| R1 | 5 | 5/5 | 0/5 | 5/5 | 0 |
-- plan
| arm | runs | stopped | types | errors | effects | signatures | layout | modules | constraints | complies | store-api | error-base | types-home | spread |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | sentinel, sentinel, sentinel, sentinel, sentinel | pure, pure, pure, pure, pure | positional, positional, positional, positional, positional | new-module, new-module, new-module, new-module, new-module | deep, deep, deep, deep, deep | 0/5 | 0/5 | functions, functions, functions, functions, functions | none, none, none, none, none | models, models, models, models, models | 0 |
| P1 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | raise, raise, raise, raise, raise | pure, pure, pure, pure, pure | keyword-only, keyword-only, keyword-only, keyword-only, keyword-only | new-module, new-module, new-module, new-module, new-module | deep, deep, deep, deep, deep | 5/5 | 1/5 | functions, functions, functions, functions, functions | common-base, common-base, common-base, common-base, common-base | models, models, models, models, models | 0 |
| P1r1 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | raise, raise, raise, raise, raise | pure, pure, pure, pure, pure | keyword-only, keyword-only, keyword-only, keyword-only, keyword-only | new-module, new-module, new-module, new-module, new-module | deep, deep, deep, deep, deep | 5/5 | 5/5 | functions, functions, functions, functions, functions | common-base, common-base, common-base, common-base, common-base | models, models, models, models, models | 0 |
-- greenfield
| arm | runs | stopped | types | errors | effects | signatures | layout | modules | constraints | complies | store-api | error-base | types-home | spread |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F0 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | raise, mixed, raise, raise, raise | pure, pure, pure, pure, pure | positional, positional, mixed, positional, mixed | per-component, per-component, per-component, per-component, per-component | deep, deep, deep, deep, deep | 0/5 | 0/5 | class, functions, class, class, functions | flat, flat, flat, flat, flat | scattered, scattered, scattered, scattered, scattered | 3 |
| F1 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | raise, raise, raise, raise, raise | pure, pure, pure, pure, pure | keyword-only, keyword-only, keyword-only, keyword-only, keyword-only | per-component, per-component, per-component, per-component, per-component | deep, deep, deep, deep, deep | 5/5 | 3/5 | functions, functions, functions, functions, functions | common-base, common-base, common-base, common-base, common-base | models, models, models, models, models | 0 |
| F1r1 | 5 | 0/5 | dataclass, dataclass, dataclass, dataclass, dataclass | raise, raise, raise, raise, raise | pure, pure, pure, pure, pure | mixed, keyword-only, keyword-only, keyword-only, keyword-only | per-component, per-component, per-component, per-component, per-component | deep, deep, deep, deep, deep | 5/5 | 4/5 | functions, functions, functions, functions, functions | common-base, common-base, common-base, common-base, common-base | models, models, models, models, models | 1 |
-- gap
| arm | runs | stopped | concurrency | spread |
|---|---|---|---|---|
| G | 5 | 5/5 | 5/5 | 0 |
-- gate
| arm | runs | flagged | misflagged | spread |
|---|---|---|---|---|
| X | 5 | 5/5 | 0/5 | 0 |
-- absent
| arm | runs | asked | stopped | constraints | spread |
|---|---|---|---|---|---|
| N | 3 | 3/3 | 0/3 | 3/3 | 0 |
Task 7: complete (commits 3a1b892..e0f9103, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Task 8: Ruling: README Status paragraph's list of declared-and-absent documents gains PROGRAM-DESIGN.md — the config now declares it, so the paragraph would otherwise be false — cost if wrong: none. Step 1's config-block bullet was done in Task 5 (ruling there). SessionStart row ~230 (234 words).
Task 8: complete (commits e0f9103..8302cd1, tests: bash tests/run-tests.sh → all 13 test file(s) passed)
Final review dispatched (opus) a96e33e12ebd4482a over db23f1c..8302cd1
Final: review — Critical none; Important 1 (copied RED controls named red/…/<label> paths in GREEN recipe/plan/greenfield items); Minor 6.
Final: Ruling: re-graded Minor 1 ("take your recommendations for the rest" can skip Modules) to Important — a human's shortcut would inherit module depth silently, which the spec forbids — cost if wrong: one clause in the recipe
Final: fixed blind leak — test "a copied run's label is gone"/"stage is gone" RED→GREEN (blind now maps /red|green/ to /<stage>/ and each pool label to <run>), suite 13/13
Final: fixed Modules shortcut — test "taking the recommendations still leaves Modules asked" RED→GREEN (recipe 649/650 words, "Then wait for the answer" → "Then wait"), suite 13/13
Final: Ruling: reviewer's fix (b), a survival check that exits 2, not added — after the replacement it could only fail on a stage/label string blind itself left, which the new test already pins — cost if wrong: a future leak of a different shape (e.g. a plugin path) goes unflagged
Final: minor (deferred): "Revising one slot" does not say a single-slot revision skips the spec/brainstorm ceremony; arm G measured only the stop
Final: minor (deferred): injection does not say rules are copied "verbatim, one line each, without the why" (spec §4.3); P1 constraints 5/5 regardless
Final: minor (deferred): injection gives no instruction for a config that does not declare PROGRAM-DESIGN.md (pre-0.1.4 adopted repos)
Final: minor (deferred): blind silently drops a <label>.reply.md whose run has no .git
Final: minor (deferred): recipe tests "every rule carries a check" (substring "check") and "Python's idiom" (substring "Python") cannot fail
Final: minor (deferred): judge variance on complies (P1-3 flipped on StrEnum between rounds)
Final: recipe/plan/greenfield pools re-blinded with fixed blind (0 label/stage strings); leaky outs kept at out.leaky; fresh opus judges recipe a378f83f12f84ba31, plan aa6d25e5abdff4625, greenfield a25abd6b993e9a155
Final: blind re-judge — criteria hold: R0 0/5 vs R1 asked 5/5 wrote 0/5 elements 5/5; P0 0/5,0/5 / P1 5/5,1/5 / P1r1 constraints 5/5 complies 5/5 stopped 0/5; F0 0/5,0/5 / F1 5/5,2/5 / F1r1 constraints 5/5 complies 4/5 stopped 0/5
Final: Ruling: recorded green/plan-round0 and green/greenfield-round0 removed — their control items leaked labels; the first-round scores (P1 complies 2/5, F1 3/5) that triggered REFACTOR 1 are kept in the commit message — cost if wrong: the pre-refactor evidence is no longer browsable as files
Final: final review clean after fix pass; dopamine:finishing-work sweep next

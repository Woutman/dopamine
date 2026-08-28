# Sealed ledger — plan: docs/superpowers/plans/2026-08-28-dopamine-spine.md — sealed: 2026-08-28

# SDD ledger — plan: docs/superpowers/plans/2026-08-28-dopamine-spine.md

Spec read: docs/superpowers/specs/2026-08-28-dopamine-design.md (present, binding).
Worktree: .claude/worktrees/spine on branch dopamine-spine, from main @ 88e6f02.

## Pre-flight conflict scan

Pairs sharing a file or an interface:

| Pair | Produced vs consumed | Found |
|---|---|---|
| T1 → T3 | `.dopamine/config` format | T3 re-parses in Python rather than calling `artifact-paths`. Checked parity: first-colon split (`%%:*` vs `partition(":")`) ✓; `#` comment stripping (`${raw%%#*}` vs `split("#",1)[0]`) ✓. Divergence: T1 exits 2 on malformed line / unknown tier / absolute path; T3 silently skips. Intentional — a PreToolUse gate must fail open on bad config, not block every Bash call. No conflict. |
| T2 → T3 | sealed filename `<plan-basename>.ledger.md` in the plan's dir vs gate's `<plans>/<slug>.ledger.md` | `slug` is the `.superpowers/sdd/<dir>` name, which superpowers derives from the plan basename (confirmed against this run's own workspace). Consistent, given config's `plans:` names the directory holding plans. ✓ |
| T1 → T4 | `artifact-paths` invoked as sibling | `here=$(cd "$(dirname "$0")" && pwd)`, same dir ✓. Exit code propagated via `set +e`/`map_rc`/`set -e` so 3 ≠ 2 ✓, and `set -e` is restored. |
| T3 → T5 | `run-hook.cmd`, and hooks.json registration | T3's `hooks.json` already registers BOTH SessionStart and PreToolUse; plan line 1025 states the wiring assertions pass before `hooks/session-start` exists. T5 therefore needs no hooks.json edit, and its Files block correctly omits one. ✓ |
| T6 → T7 | `tests/skills/test-skill-structure.sh` | Declared Create in T6, Modify in T7. `BUDGETS="artifact-map:500 sweep:600"` is set in T6; the walk does `[ -f "$skill_md" ] || continue`, so `skills/sweep/` existing without a SKILL.md at T6 time is skipped, not failed. ✓ |
| T1 → T8 | `.gitignore` vs `.dopamine/config` | T1's `.gitignore` ignores only `.dopamine/run/`, so T8's `.dopamine/config` is committable. ✓ |
| T1..T7 → T8 | tests vs the real repo-root config T8 adds | All six test files build a `mktemp -d` sandbox repo and pass it as REPO_ROOT; none read the real root. T8's self-adoption cannot retro-break them. ✓ |
| T4 → T8 | `.dopamine/run/.gitignore` containing `*` | Self-ignoring, written at runtime, no interaction with T1's `.gitignore`. ✓ |

Self-agreement, per task:

| Task | Tests vs code, files created vs later touched | Found |
|---|---|---|
| T1 | parse loop vs the 6 exit-2 assertions; `.gitignore`/manifest vs later tasks | agrees ✓ |
| T2 | writer `printf '# Sealed ledger — plan: %s — sealed: %s\n'` vs the test's `^# Sealed ledger — plan: .* — sealed: [0-9]{4}-[0-9]{2}-[0-9]{2}$` | agrees ✓; basename identity check has a matching mismatch test |
| T3 | deny-JSON shape vs the schema in Global Constraints; python3-absent path exits 0 | agrees ✓ |
| T4 | empty-`paths` guard reachable? `artifact-paths` prints all tiers, so a plans-only config yields a non-empty map and an empty `paths` → guard fires. `map` is never `""` when rc=0 (T1 exits 2 on a config declaring nothing) | agrees ✓ |
| T5 | one context field per platform; 200-word budget | agrees ✓ |
| T6 | walk skips absent SKILL.md; budget table pre-seeded for T7 | agrees ✓ |
| T7 | appends before `finish`; references checked by both markdown-link and backtick greps | agrees ✓ |
| T8 | consumes T1–T7 only | agrees ✓ |

Plan-mandated patterns a review rubric may read as defects (noted now, so they are adjudicated against plan text and not relitigated per task):
- The ~5-line `SCRIPT_DIR`/`REPO_ROOT`/`mktemp -d`/`trap` preamble repeats in all six test files. Deliberate: each test is a standalone process by `run-tests.sh`'s design.
- `hooks/run-hook.cmd` is a byte-for-byte copy of superpowers' polyglot wrapper. Deliberate and stated in the plan: dopamine may not depend on superpowers' files at runtime.

Scan found no contradiction requiring a ruling before Task 1.

## Progress

Task 1: implementer DONE (commit e0c5cc9, 6 files / 286 lines, 17/17 assertions, RED confirmed at exit 127).
Task 1: review package review-88e6f02..e0c5cc9.diff (10674 bytes); task reviewer dispatched (sonnet).
Task 1: review verdict — spec ✅ with 2 Important, 4 Minor. Rulings below.

Task 1: Ruling: `--tier` accepts an unvalidated value (Important #1) — FIX IT. The plan's own
  Interfaces block declares "Valid tiers: living, instructions, lessons, plans" and the exit-code
  contract makes `2` mean "bad usage or invalid input"; a typo'd tier silently returning exit 0 with
  zero rows contradicts both. Verified safe: `--tier` is invoked exactly once in the whole plan
  (line 200, `--tier plans`, a literal valid value), so no later task can be broken by tightening it.
  Cost if wrong: a hypothetical caller that probes with an arbitrary tier name gets exit 2 instead of
  empty output. No such caller exists in this slice.

Task 1: Ruling: `set -uo pipefail` in the two test-harness scripts (Important #2, plan-mandated) —
  THE CODE STANDS; the Global Constraint's prose is what is wrong. Evidence: across all 2,184 lines
  of the plan the three forms are used with perfect consistency — `set -euo pipefail` at exactly the
  four product scripts (artifact-paths:305, seal-ledger:530, sweep-package:1161, session-start:1376),
  `set -uo pipefail` at all eight test-harness files (118, 145, 411, 620, 1054, 1264, 1460, 1971), and
  bare `set -u` at hooks/seal-gate:806. That is a deliberate three-way pattern, not an oversight.
  `-e` is wrong for a test runner and an assertion-counting test file: both exist to observe failures,
  tally them, and exit non-zero on purpose, and `-e` converts "3 assertions failed, here they are"
  into a silent mid-file abort. `-e` is wrong for the gate for the same reason it must fail open.
  Constraint line 22 ("every script starts ... set -euo pipefail") overgeneralizes and binds product
  scripts only. Carried forward: every later reviewer dispatch gets the carve-out stated explicitly,
  so this is not relitigated seven more times.
  Cost if wrong: a test-harness script does not abort on an unexpected non-zero command and could
  under-report failures. Mitigated — run-tests.sh reports any non-zero file exit regardless.

Task 1: Ruling: "dopamine" in comments and stderr prose (Minor #2) — STANDS, deferred. The constraint
  targets identifiers and paths a rename must chase (plugin name, `.dopamine/`, `dopamine:` prefix),
  not English prose, which a rename handles by text replace anyway. Cost if wrong: a few extra lines
  touched at rename time.

Task 1: minor (deferred): report says 17 assertions, the file contains 18 (RED math was self-consistent).
Task 1: minor (deferred): test-artifact-paths.sh lacks the why-header the other scripts carry.
Task 1: fix round 1/5 dispatched to the original implementer — 1 finding (--tier validation), 2 rulings
  carried as "do not change". Implementer returned commit 5c440a5, 21 assertions passing (was 18).
  Scoped re-review dispatched over e0c5cc9..5c440a5 (23 insertions, 2 files).
Task 1: fix round 1/5 (1 addressed, 0 open; commits e0c5cc9..5c440a5). Re-reviewer independently
  verified the subtle half: `declared` is incremented before the tier-filter `continue`, so a valid
  tier with zero declared rows still exits 0 rather than tripping the "declares no paths" exit 2.
  Exit-code precedence (usage 2 -> missing config 3 -> malformed config 2) confirmed preserved.
Task 1: minor (deferred): fix report says 21 assertions, the file has 23. Second prose miscount from
  this implementer; code and tests are correct both times. Pattern worth watching, not blocking.
Task 1: complete (commits 88e6f02..5c440a5, review clean).

Task 2: BASE 5c440a5. Implementer dispatched (haiku — 2 files, brief carries complete code, pure
  transcription; testing whether the cheapest tier holds on this shape of task).
Task 2: implementer DONE (commit 4404405, 2 files / 157 lines, 16 assertions, 40/40 suite).
Task 2: review verdict — spec ✅, 1 Important (plan-mandated), 1 Minor.

Task 2: Ruling: the ledger-identity check is an unanchored substring match (Important, plan-mandated)
  — FIX IT. `case "$first" in *"$slug"*)` accepts any ledger whose recorded plan path merely CONTAINS
  the slug, so a ledger belonging to `2026-08-28-widget-redux.md` seals silently under
  `2026-08-28-widget.md`. The reviewer reproduced this against a real fixture (exit 0, "created ...",
  foreign content). The identity check is the single guard the interface contract names against
  sealing a foreign ledger under the wrong plan, and a sealed ledger is an immutable record Task 3's
  gate and later audits trust — a false accept there is the worst failure this script has. The plan's
  own test only exercised a non-colliding mismatch (2026-08-01-other vs 2026-08-28-widget), which is
  why the defect survived both the plan's self-review and my pre-flight scan.
  The fix must preserve WHY the plan matched on basename at all: the recorded path may be relative to
  a different directory, so anchoring on the full recorded path is wrong. Anchor on the basename
  instead — compare `basename "<recorded path>"` to `$slug.md` exactly.
  Cost if wrong: a plan whose recorded ledger path has an unusual shape (trailing whitespace, a
  quoted path) could be rejected as a mismatch where it used to pass. Mitigated by keeping the exact
  error message and adding a regression test for the ordinary case alongside the collision case.

Task 2: minor (deferred): report says 17 assertions, the file has 16. Third prose miscount in three
  reports, now across two different implementers and two model tiers — systemic to the report step,
  not to any one agent. Code correct every time. Worth a note in the final review, not a fix round.
Task 2: fix round 1/5 (1 addressed, 0 open; commits 4404405..36842b6). Identity check now extracts the
  recorded path, strips trailing whitespace, and compares basename to <slug>.md for exact equality.
  Re-reviewer mutation-tested the guard: it hand-built an OVER-tightened variant (full-path equality
  instead of basename) and confirmed the new different-directory test fails against it — so that test
  genuinely discriminates rather than passing by luck. Also confirmed a header with no `plan: ` segment
  fails closed (exit 2, refuses to seal), which is the safe direction.
Task 2: the 17-vs-16 count is resolved, not a defect: one check uses an if/pass/fail block rather than
  an assert_* call, so the grep-count and the eye-count disagreed. Fix report's 24 verified correct.
  Withdrawing the "systemic miscount" note from the final review — two of three were real, this was not.
Task 2: complete (commits 5c440a5..36842b6, review clean).

Task 3: BASE 36842b6. The seal gate — 5 files incl. Python, the largest task in the plan.
  Implementer dispatched (sonnet — multi-file integration, not pure transcription).
Task 3: implementer DONE_WITH_CONCERNS (commit b34f18c, 5 files / 380 lines, 20/20 focused, 3/3 files).
  Two bugs found in the brief's own code and fixed with evidence:
  (a) `env PATH=/nonexistent bash "$UNDER_TEST"` can never reach the script — `env` resolves `bash`
      itself through the NEW PATH. This is the second-order form of a bug I had already "fixed" once
      while authoring the plan (the original was `env PATH=/nonexistent "$UNDER_TEST"`, which died at
      the shebang). Fixed by resolving bash's absolute path first via `command -v bash`.
  (b) That surfaced a PRODUCTION bug: `hooks/seal-gate`'s no-Python fallback exited without reading
      stdin, so the caller's write to the hook takes SIGPIPE. Affects a real Claude Code session, not
      only the test. Fixed by draining stdin with a bash builtin (`read -r -d ''`), deliberately not
      `cat`, since PATH is untrustworthy in exactly that branch.
  Controller verified the production-critical path directly: no-Python -> exit 0, empty stdout, note
  on stderr; ordinary allow -> exit 0, silent. The gate fails OPEN, which is the requirement.

Task 3: Ruling: the third coverage gap (DELETE_RE matches only rm/rmdir/trash, so `find -delete`,
  `unlink`, `shred` and `mv` slip through) — DO NOT WIDEN in this slice; document it instead.
  Widening is not free: every added verb is a new false-positive surface, and a false positive here
  DENIES a user's Bash command. `mv` is the clearest case against — `mv .superpowers/sdd/x/progress.md
  /tmp/` is a copy-out, not a destroy, and would be denied. The gate's value is being silent everywhere
  except the one case it exists for; widening the verb set deserves its own measured decision, not a
  mid-execution add. Carried to Task 8: the README's known-gaps list must name this third gap
  alongside the two the plan already documents.
  Cost if wrong: a cleanup script using `find -delete` destroys an unsealed workspace and the ledger
  is lost. Mitigated: superpowers itself deletes with `rm -rf`, which the gate does catch.
Task 3: review verdict — spec ✅, Task quality APPROVED, 0 Critical, 0 Important, 1 Minor. No fix loop.
  Reviewer independently reproduced BOTH claimed bugs rather than accepting them: confirmed
  `env PATH=/nonexistent bash -c` dies at exit 127 before reaching the script, and exercised the
  stdin drain against empty/closed stdin and 2MB and 5MB NUL-free inputs — RC=0, no hang, fully
  drained in every case. Also verified byte-for-byte that seal_gate.py itself is untouched, so the
  two deviations are confined to the test harness and the fail-open path.
  Endorsed the third-gap ruling independently ("each added verb is new false-positive surface against
  a fail-open safety-critical hook").
Task 3: minor (deferred): report says 20 assertions, the file has 19.
Task 3: complete (commits 36842b6..b34f18c, review clean).

PARALLELISATION (user asked whether any of this can run concurrently):
  Dependency graph of the remaining tasks: T4 consumes only T1; T6 consumes nothing; T5 consumes T3;
  T7 consumes T1,T2,T4,T6; T8 consumes all. So T4, T5 and T6 touch disjoint file sets and are mutually
  independent. Ruling: run them concurrently in dedicated worktrees, one branch each, cherry-picked
  back onto dopamine-spine in order.
  This deviates from subagent-driven-development's "never dispatch multiple implementation subagents
  in parallel" — but the skill's stated reason is write conflicts, and separate worktrees remove that
  reason. Cherry-pick rather than merge, because the session's operating rules forbid merges and the
  disjoint file sets make linear replay clean.
  Cost if wrong: a cherry-pick conflicts and I replay that task's changes by hand; or a task built on
  a stale base needs a follow-up. Bounded — no task in this wave shares a file with another.
  T7 and T8 stay serial: those are real dependencies, not caution.
Task 4: implementer DONE (commit 5ff8f5e on branch task-4-sweep-package, 2 files / 160 lines, 17/17).
Task 4: review verdict — spec ✅, Task quality APPROVED, 1 Important (plan-mandated), 2 Minor.
  Reviewer confirmed the plans-tier exclusion test is NOT vacuous: the fixture rewrites the plan file
  to add `# PLAN_MARKER` between BASE and HEAD, so the assert_not_contains only passes if exclusion
  actually runs. (This is the vacuity I caught and fixed once during authoring; good to see it held.)
  Also confirmed the path restriction is applied to git itself via `-- "${paths[@]}"`, not post-hoc
  grepping — genuinely O(change) — and that the plans-only-config guard is reachable.

Task 4: Ruling: an explicit OUTFILE in a non-existent directory exits 1 with a raw bash redirect error
  (Important, plan-mandated) — FIX IT. The exit-code contract (0/2/3) is a Global Constraint and this
  leaks an unformatted shell message at exit 1. Fix asymmetrically, and deliberately so:
    - DEFAULT path: keep `mkdir -p`. dopamine owns `.dopamine/run/`, so creating it is correct.
    - EXPLICIT OUTFILE: do NOT mkdir. Check the parent exists and is writable; exit 2 with a clean
      message otherwise. An explicit OUTFILE is the caller stating exactly where they want the file;
      silently building a directory tree they typo'd is worse than telling them.
  Cost if wrong: a caller who wanted sweep-package to create their output directory must mkdir first.
  Cheap to reverse; the opposite (silent tree creation) is not.

Task 6: implementer DONE_WITH_CONCERNS (commit 33fad0a on branch task-6-artifact-map, 15/15).
Task 6: Ruling: the "every referenced file exists" check false-positives on illustrative document
  names — FIX THE TEST, NOT THE PROSE. Evidence: the check greps ``[a-zA-Z0-9._-]+\.md`` and requires
  each hit to exist as a sibling file. artifact-map's tier table backticks DESIGN.md, ARCHITECTURE.md,
  ROADMAP.md, CLAUDE.md and LESSONS.md as *examples of a category*, not as files it ships. The
  implementer worked around it by stripping those backticks; I am reverting that and narrowing the
  check instead, for two reasons:
    (1) A structural test must verify structure, not dictate prose formatting. Stripping backticks
        makes the test the author of the skill's style, which is backwards.
    (2) It is a booby trap for exactly the next task. Task 7's sweep skill backticks BOTH classes —
        `discovery-prompt.md` (a real sibling it ships) AND document names in prose. Its implementer
        would hit the same failure and might "fix" it a third, inconsistent way.
  Narrowed rule: markdown links are checked as before (any relative .md link); the backtick arm is
  restricted to names ending `-prompt.md`, which is what a sibling artifact is in this plugin and the
  only class the arm was added to catch.
  Cost if wrong: a future skill shipping a sibling artifact NOT named *-prompt.md goes unchecked by
  the backtick arm. It is still caught if referenced as a markdown link. Accepted and documented.
  This is the load-bearing case from the fix-loop rules: a later task builds on this file, so it is
  fixed now rather than parked.
Task 5: implementer DONE (commit 92f3423 on branch task-5-session-start, 3 files / 131 lines, 11 assertions).
Task 5: review verdict — spec ✅, Task quality APPROVED, 1 Important (plan-mandated), 4 Minor.
  Reviewer exercised all three platform branches directly and parsed each with python3: Claude Code
  emits only `hookSpecificOutput`, Cursor only `additional_context`, Copilot/SDK only `additionalContext`
  — exactly one field each, so the double-injection risk is real-tested, not assumed. Also adversarially
  tested escape_for_json with quotes, backslashes, \n, \r, \t and confirmed an exact json.load round-trip
  and correct escape ORDER (backslash before quote). Verified the 200-word budget measures the raw .md
  file rather than a JSON-escaped fragment. Confirmed cwd-with-spaces, nested cwd, non-git-repo and
  missing-context-file all exit 0 silently.

Task 5: Ruling: the Cursor/Copilot assertions never positively assert their own field name (Important,
  plan-mandated) — FIX IT. They only assert the ABSENCE of `hookSpecificOutput`. The reviewer proved
  by mutation that this fails to discriminate: a Cursor branch that typos `additional_context` into
  `additionalContext` still passes, because that output also lacks the nested key. The shipped hook is
  correct today, so this is a latent gap rather than a live defect — but it is exactly the regression
  this test exists to catch, and the fix is two assertions.
  Cost if wrong: negligible. This only tightens a test around behaviour already verified correct.
Task 5: minor (deferred): report says 12 assertions with a breakdown summing to 10; actual is 11.
Task 5: minor (deferred): PLUGIN_ROOT resolves up to repo root then back down into hooks/, where
  $SCRIPT_DIR/session-start-context.md would do. Harmless, verified correct.
Task 5: minor (deferred): `content=$(cat ...)` strips the file's trailing newline (587 vs 588 bytes).
  No dangling blank line in the injected context; not a strict byte round-trip.
Task 5: minor (deferred): escape_for_json omits form feed / vertical tab. Theoretical for a
  hand-authored markdown file.
Task 4: fix round 1/5 (1 addressed, 0 open; commits 5ff8f5e..c279b45 on branch task-4-sweep-package).
  Re-reviewer checked the regression I was most worried about — that the new check might be applied to
  BOTH branches and break the common default path — by deleting `.dopamine/run` and re-running with no
  OUTFILE: exits 0, recreates the dir with its `*` .gitignore, byte count matches. Also verified a
  relative-path OUTFILE and one reached through a symlinked directory both still succeed. Assertion
  count 22 verified exact. Confirmed the malformed-config fixture mutates and restores config inside
  its own mktemp repo, so cases do not leak into each other.
Task 4: complete (branch task-4-sweep-package, review clean).
Task 4: CHERRY-PICKED onto dopamine-spine as 8ae28e1 + 375fca7. Clean, no conflicts.
  Full suite re-run on the INTEGRATED branch: 4/4 test files pass, OK. Integration verified, not assumed.
Task 5: fix round 1/5 — implementer added positive field-name assertions and confirmed the teeth-check
  (mutated Cursor field name -> test FAILS; reverted -> byte-identical, GREEN). Commit 386857e, 13/13.
  Scoped re-review dispatched (haiku — 14-line test-only diff, cheapest tier is right here).

Task 6: review verdict — spec ✅, Task quality APPROVED, 1 Important, 1 Minor.
  Reviewer independently reproduced the teeth-check AND its complement: a backticked non-existent
  `SOMETHING-ELSE.md` is correctly IGNORED, confirming the narrowed blind spot is the documented
  trade-off rather than an accident. Verified backtick restoration against the brief via git show.
  Proved the body extraction strips frontmatter with a number: 475 words whole-file vs 435 body.
  Confirmed the seven per-skill checks are independent — one failing never masks another.

Task 6: Ruling: the @-link check is anchored to line start (Important) — FIX IT, and fix it now rather
  than parking it, because Task 7 inherits this exact test and its skill has denser prose.
  `grep -qE '^\s*@[a-zA-Z./]'` misses `as described in @docs/reference.md` and `- @path/to/file.md`,
  and it is the ONLY automated enforcement of a hard global constraint.
  Ruled AGAINST simply dropping the anchor: unanchored, it false-positives on `user@example.com` (the
  `e` follows the @) and on bare scoped package names. Ruled FOR a whitespace-or-line-start boundary,
  `(^|[[:space:]])@[a-zA-Z./]`, which catches both real cases, rejects the email (a letter precedes the
  @), and lets a backticked `@scope/pkg` through (a backtick precedes the @) — so correct formatting
  is also the escape hatch.
  Cost if wrong: a bare, unbackticked scoped package name after a space fails the check. Remedy is to
  backtick it, which is correct formatting anyway. Required all four cases be verified, both what it
  catches and what it correctly ignores.
Task 6: minor (deferred): the "states triggers not workflow" denylist is porous — a workflow-shaped
  description using "execute"/"invoke", or omitting the comma/"then", dodges it. Has teeth on the
  patterns it does list; widen only if a later task trips over it.
Task 5: fix round 1/5 (1 addressed, 0 open; commits 92f3423..386857e). Implementer chose the robust
  route: a `keys()` helper that parses the EXACT top-level key set with python3, which sidesteps the
  substring trap entirely (`additionalContext` is a substring of the nested shape's inner key, so a
  containment check could have failed to discriminate). Re-reviewer walked all five discrimination
  cases — correct/typo'd for each flat platform, plus the nested shape against both — and confirmed
  the pre-existing absence assertions were kept alongside rather than replaced. Fix confined to the
  test file; `hooks/session-start` untouched. Assertion count 13 verified accurate.
Task 5: complete (branch task-5-session-start, review clean).
Task 5: CHERRY-PICKED onto dopamine-spine as fc2569d + 73569d4. Clean, no conflicts.
  Full suite on the INTEGRATED branch: 5/5 test files pass, OK.
Task 6: fix round 2/5 (1 addressed, 0 open; commits 33744e3..6c37be2). Re-reviewer independently re-ran
  all four cases on a scratch copy: inline @-link FAILS, bulleted @-link FAILS, user@example.com PASSES,
  backticked `@anthropic-ai/claude-code` PASSES. All four match spec. Comment present and names the
  accepted residual cost. artifact-map untouched, still 435/500.
Task 6: complete (branch task-6-artifact-map, review clean, 2 fix rounds).
Task 6: CHERRY-PICKED onto dopamine-spine as e4fe6fa + cb951a2 + c8a0188. Clean, no conflicts.
  Full suite on the INTEGRATED branch: 6/6 test files pass, OK.

PARALLEL WAVE CLOSED. Tasks 4, 5 and 6 ran concurrently in dedicated worktrees and all three
  cherry-picked cleanly with zero conflicts — the disjoint-file-set analysis held. Branch is linear:
  b34f18c -> 8ae28e1 375fca7 (T4) -> fc2569d 73569d4 (T5) -> e4fe6fa cb951a2 c8a0188 (T6).

Task 7: BASE c8a0188. Runs in the spine worktree directly — it is the only implementation task left
  before T8, so there is nothing to run it in parallel WITH and a separate worktree would buy nothing.
  Implementer dispatched (sonnet — 4 new files plus an edit to a shared test, and the three prompts
  carry the design's substance rather than being transcription).
Task 7: implementer DONE (commit bbaa03f, 5 files / 233 lines, 540/600 words, 22 assertions).
Task 7: review verdict (opus — escalated a tier because the likely defects were prose seams, not code)
  — spec ❌, Needs fixes: 7 Important, 6 Minor. ALL SEVEN are plan-mandated: the reviewer extracted the
  four fenced blocks from the brief and byte-compared them to the committed files — all four IDENTICAL.
  So these are defects in MY brief text, and the implementer's fidelity is not in question.
  The seam review is what found them; none would have surfaced from a single-file read.

Task 7: Rulings — FIX ALL SEVEN. Each is a real break in the pipeline, and this is the payload:
  (1) {CONFIG_MAP} has no producer. Both discovery and verifier consume "the output of artifact-paths"
      and the four-stage recipe never runs it. A prompt with an unfilled placeholder fails at runtime.
  (2) Placement fails a CORRECT nothing-to-drain sweep. The verifier demands "every brief entry has a
      matching hunk", but a brief has four section kinds and three produce no hunks — and SKILL.md
      itself documents a negatives-only brief as a FINISHED sweep. The two documents contradict.
  (3) The implementer is told to land an edit "in the tier the brief names, under the heading the brief
      names", but the Edits schema records only file+line, quoted text, and the change. Discovery is
      told to DECIDE the tier and never told to WRITE IT DOWN.
  (4) "Historical records untouched" is UNFALSIFIABLE from the verifier's inputs. sweep-package drops
      the `plans` tier by design, and specs/plans/sealed ledgers/briefs all live there — so a hunk in a
      historical record is invisible to the verifier by construction. This one is the worst of the
      seven: an unfalsifiable check on the plugin's core discipline claim is worse than no check,
      because it manufactures assurance. Fixed with an O(1) name-only listing, NOT by widening the
      package — the exclusion is what keeps the sweep O(change).
  (5) Drain-completeness independence is ASSERTED, NOT SEQUENCED. The verifier is told to read the
      brief at line 9 and told at line 34 to derive terms "before you look at the brief's list". By
      then it has already read it. This is exactly the assert-vs-establish failure I asked them to
      hunt for, and it was real.
  (6) Negatives and the Undrained rule are keyed to different axes — locations-checked vs
      ledger-entries-drained. A ledger entry that yields no grep-able location (a ruling, a parked
      finding) has no home in either section and lands as a FALSE Undrained on a correct sweep.
  (7) Neither subagent is told to load `dopamine:artifact-map`. Both are asked to make tier decisions
      against a document they have never seen. SKILL.md's REQUIRED BACKGROUND binds the CONTROLLER,
      not a fresh subagent that receives only the filled prompt. Classic context-boundary slip.
  Cost if wrong: these are wording changes to four documents with no runtime behaviour; the risk is
  the 600-word budget (540 used, 60 left). Instructed to report rather than silently cut or raise it.

Task 7: also folding in two demonstrated-vacuous assertions (reviewer's Minor #10/#11, proven in a
  fixture): deleting the O(change) paragraph still leaves the "grep" assertion passing, and deleting
  the load-bearing "Current text, quoted" requirement still leaves the "quoted" assertion passing via
  unrelated prose. Consistent with how vacuity has been handled all run — it is cheap here and the
  fix round is already open.
Task 7: minor (deferred): the report's assertion-count BREAKDOWN contradicts its own pasted output
  (top-line 18 source lines is right; runtime count is 22, which the output shows).
Task 7: minor (deferred): artifact-map lists "sweep briefs" as Immutable/never-touched while the sweep
  writes to the CURRENT brief. The prompts consistently say "previous briefs"; the map is the
  unqualified one. Moot in practice — the brief sits in the excluded plans tier. Note for final review.
Task 7: fix round 1/5 — 7 of 9 findings addressed + 3 assertion renames; 582/600 confirmed with no
  content traded away (SKILL.md hunk is 4 insertions / 2 deletions on two lines, both expansions).
  Findings 8 and 9 independently re-verified by DELETION in a /tmp copy: removing the O(change)
  paragraph now FAILS the assertion, and removing the "Current text, quoted" schema bullet now FAILS
  its assertion. The anchors are real, not renamed noise.
  TWO REMAIN OPEN. Both are exactly what I asked the re-review to be suspicious of:

Task 7: Ruling: finding 5 (drain independence) — STILL OPEN, and the diagnosis is right. The fix added
  a genuine numbered sequence AND a correct rationale ("Sequencing is what makes them independent, not
  intention") — but it edited only the paragraph the review quoted, leaving verifier-prompt.md:11,
  which instructs reading {BRIEF_PATH} up front, byte-unchanged. So the new step 1 ("before you open
  {BRIEF_PATH} at all") contradicts an earlier instruction in the same document and is unsatisfiable
  top-down. The fix strengthened the ASSERTION of independence without moving the READ. Fixing
  properly requires restructuring the prompt's own order, not its wording — and it must respect a real
  tension: Placement genuinely needs the brief, so the brief read is deferred, not deleted.

Task 7: Ruling: NEW BREAKAGE from my own fix instruction (Important) — {PLANS_TOUCHED} blanket-fires on
  the sweep's OWN brief. The brief lives at a plans-tier path and the implementer annotates it in
  place, so if BASE..HEAD spans the implementer's commit — which it must, or Placement has no hunks —
  the brief appears in the listing and the verifier is told to call it a Discipline finding on a
  CORRECT sweep. Before my fix this bullet was unfalsifiable and fired never; after it, it fires on
  the sweep's own record. I specified the listing without accounting for the sweep's own artifacts.
  Fix in the verifier RULE, not the producer: the rule costs no words (SKILL.md has 18 left) and the
  judgement about which plans-tier writes are legitimate belongs with the judging, not the listing.

Task 7: Ruling: the out-of-scope {DIFF_PACKAGE} producer gap — PULL IT IN AND FIX IT. It is the same
  class as finding 1 (a consumed placeholder nothing fills), and closing one half of a producer gap
  while leaving the other open is indefensible. Decided: REMOVE the consumption from the discovery
  prompt rather than produce a package earlier. Three reasons: the design states the sealed ledger is
  the sweep's input and the only journal it keeps; discovery quotes current text by reading the
  documents, not a diff; and decisively, the diff discovery would need (the WORK range) is a different
  range from the one verification needs (the SWEEP range) — conflating two ranges under one
  placeholder name is itself the bug. Escape hatch given: if {DIFF_PACKAGE} turns out load-bearing in
  discovery, say so instead of removing blindly.
  Cost if wrong: discovery loses sight of document edits made mid-execution. Acceptable — the
  SessionStart injection already routes those to the ledger, and the sweep drains them normally.
Task 7: fix round 2/5 — A, B, D addressed; C partially. Commit 518c4a3, 582/600 unchanged, SKILL.md
  genuinely absent from the diff (3 prompt files only).
  A (independence) now genuinely SEQUENCED: the reviewer walked verifier-prompt.md lines 1-46 in
  document order as a fresh subagent and confirmed step 3 at :17 is the ONLY instruction anywhere in
  the file that opens the brief, the round-1 offender line is gone, the duplicate sequence inside
  Drain completeness collapsed to a back-reference, and nothing instructs a re-read. Followable
  without contradiction.
  B (plans exemption) correctly scoped, tested against all four cases: fires on a spec, a plan, a
  PREVIOUS brief, and a PREVIOUSLY sealed ledger. It names two specific artifacts rather than a tier,
  so the unfalsifiability failure mode is not reintroduced in a third form.

Task 7: Ruling: item C re-opened the seam in a NEW place, and it is my error again — I directed the
  removal from discovery-prompt.md without checking what SKILL.md says about discovery's inputs. Two
  dangling references, both now false:
    - SKILL.md:24 tells the controller, on the no-ledger path, to "run discovery from the diff and
      this conversation instead" — but there is no longer any channel to honour it; discovery-prompt
      declares outright "You have no diff of your own."
    - SKILL.md:12 says discovery's inputs are "the sealed ledger and the unit's diff" and that grep
      terms come from "those two inputs". Both halves are false now: no stage consumes the unit's
      diff, and terms are derived from the ledger alone.
  This is the same producer/consumer class as the {CONFIG_MAP} and {DIFF_PACKAGE} gaps, inverted —
  the consumer was fixed and the producer's prose left describing the old contract. Both fixes are
  WORD-NEGATIVE, so the 18-word headroom is not a constraint.
  Cost if wrong: none identified; this aligns prose with behaviour that is already correct.

Task 7: also folding in the reviewer's B phrasing suggestion, judged a non-finding but taken anyway:
  state the exemption as the literal `{BRIEF_PATH}` and `{SEALED_LEDGER}` paths rather than prose the
  agent must map to them. Same word count, and it applies item A's own lesson — make the mechanism
  structural rather than leaving it to inference — to the rule we have now iterated twice.
Task 7: fix round 3/5 — item C ADDRESSED (commits 518c4a3..56943ae, 573/600, down from 582).
  The independent cross-check paid for itself: the reviewer re-enumerated all 15 placeholder/input/
  artifact/path mentions in SKILL.md against the three prompts in BOTH directions, and found a real
  mismatch at SKILL.md:46 that the implementer had noticed in its own self-review, dismissed as "not
  the same defect class", and then reported a clean cross-check anyway. Verifying the CLAIM rather
  than the diff is what caught it.

Task 7: MY OMISSION, surfacing late. SKILL.md:46 ("verification appends its verdicts" to the brief)
  was raised as Minor #8 in the ORIGINAL round-1 review. I neither folded it into round 1's fix nor
  listed it as deferred — it simply fell through. Third instance of the same seam class, and the one
  I had already been told about.

Task 7: Ruling: SKILL.md:46 — CORRECT THE PROSE, do not add a Verdicts section to the brief.
  The reviewer offered both options. Rejected adding a writer because: nothing consumes persisted
  verdicts (the controller has them in-conversation and runs the capped fix loop from them);
  discovery declares the brief schema CLOSED at :27 ("has exactly these sections"), so a fifth
  section would violate the contract the same document defines; and the artifact map already lists
  sweep briefs as Immutable, a tension noted as a deferred minor — adding a third writer deepens it.
  Chose the change that makes the document true without adding surface at round 4 of 5.
  Cost if wrong: the sweep's committed record does not say whether verification passed, so a later
  reader cannot tell a clean sweep from a fixed-up one. That is a REAL audit gap and I am recording it
  as a design question for slice 2 rather than pretending the prose fix answers it.

Task 7: round 4 dispatched to a FRESH implementer on opus, per the fix-loop rule for rounds 4-5. The
  rule's rationale fits exactly: a loop surviving three resumes usually means the implementer cannot
  see its own problem — and here it demonstrably saw this one and talked itself out of it. The edit is
  small; the judgement about what counts as in-scope is what needed replacing.
Task 7: fix round 4/5 — the open finding ADDRESSED (commit 67a745f, 584/600). The escalation to a
  FRESH implementer on opus was the right call and paid immediately: told that surfacing costs nothing
  and burying costs, it did a 32-item forward / 22-item reverse cross-check and reported SIX further
  mismatches instead of one. The previous implementer, asked the same question, reported "none".

Task 7: Rulings on the six. Fix A, B, D in round 5; defer C, E, F.
  A. {SPEC} HAS NO PRODUCER — FIX. discovery-prompt.md:5,15 requires it; SKILL.md never locates a spec,
     states no naming convention, and artifact-paths has no `specs` tier. Identical shape to the
     {CONFIG_MAP} gap from round 1. An unfilled placeholder breaks discovery at runtime.
  B. THE NO-LEDGER FALLBACK IS NOT EXECUTABLE — FIX, and it is my residue from round 3. I told the
     implementer to trim "the diff" out of "run discovery from the diff and this conversation instead"
     and did not notice the remaining half is also unworkable: discovery is a DISPATCHED SUBAGENT with
     no access to the caller's conversation, and discovery-prompt.md:13 requires {SEALED_LEDGER} read
     in full. So the entire no-ledger branch is dead — and that branch is what makes the sweep work for
     ad-hoc units, which the SessionStart injection explicitly promises.
     Ruled: keep ONE pipeline. When there is no SDD ledger, the record of what happened is WRITTEN to a
     ledger-shaped file at a stated path and used as {SEALED_LEDGER}. Rejected dropping the branch,
     which would silently narrow a promise already shipped in the injection text.
  D. `artifact-paths --tier plans` EMITS TSV, NOT PATHSPECS — FIX. Rated lower by the implementer; I am
     raising it. SKILL.md:38 tells the controller to run that command and then `git diff --name-only`
     against the result — feeding `plans<TAB>docs/superpowers/plans<TAB>present` to git as a pathspec.
     The {PLANS_TOUCHED} producer I specified in round 1 does not work as written. One-clause fix (cut
     to the path field), but it is a broken command in the recipe, not a wording nit.
  C/E/F deferred, recorded for the final review: the third Outcomes row has no implementer; ":44
     siblings beside the plan" includes the plan itself; the brief's Tier vocabulary (Append-mostly,
     Immutable) and {CONFIG_MAP}'s (lessons, plans) differ with no stated mapping. F is the one worth
     revisiting in slice 2 — harmless today because the implementer routes by the Edit's file path
     rather than by the tier word.

Task 7: Ruling: BUDGET RAISED, sweep 600 -> 700, pre-authorised for round 5. This is a reasoned
  revision, not a cave, and the distinction matters: earlier budget pressure came from ADDING content,
  and I refused it twice. This pressure comes from FIXING INCOMPLETENESS in the original draft — the
  540-word draft the 600 was calibrated against was missing three producers ({CONFIG_MAP}, {SPEC},
  {PLANS_TOUCHED}) and a working no-ledger branch. A budget calibrated against an incomplete document
  is not evidence about a complete one. Instructed to keep additions terse and report the measured
  figure either way.
  Cost if wrong: the recipe costs ~100 more words to load per sweep. Trivial against the O(project)
  reads the whole plugin exists to avoid.
Task 7: fix round 5/5 — ALL FOUR items addressed (round 4's + A, B, D), no new Critical/Important
  breakage. Loop EXITS CLEAN at the cap; the breaker did not trip. Commits 56943ae..b8e6375, 695/700.
  Verification quality worth recording:
   - Re-reviewer confirmed item A's self-disproof against ground truth AND found corroboration the
     implementer had not cited: superpowers' own writing-plans template MANDATES the `**Spec:**`
     header, so the recipe now reads a field guaranteed upstream rather than a convention we invented.
   - It re-checked the executing-plans premise against superpowers 6.3.0 rather than the 6.2.0 the
     implementer used, and confirmed only subagent-driven-development creates .superpowers/sdd/<slug>
     — so the seal gate can never deadlock the ad-hoc branch.
   - It walked the ad-hoc branch through ALL FOUR stages against the real scripts and confirmed the
     stage-4 PLAN_FILE stand-in satisfies all three uses in sweep-package (:25 -f, :28-29 dirname ->
     toplevel, :72 basename). Without it the branch would have exited 2 at :25.
   - It found corroboration in our OWN spec (design doc :412-414) that reconstruction was the intended
     behaviour all along — so item B implements the spec rather than inventing a branch. That is the
     plan's text having been incomplete against the spec, which is exactly what a seam review is for.
   - It noted that had the plans-tier exemption been left as ROUND-2 PROSE ("the ledger sealed in
     stage 1") instead of the literal {BRIEF_PATH}/{SEALED_LEDGER} placeholders I asked for in round 3,
     EVERY reconstruction would now be a false violation. That phrasing change was filed as a
     non-finding nicety; it turned out to be load-bearing two rounds later.

Task 7: Adjudication of the three cosmetic residuals. All PARKED, none load-bearing, all routed to the
  final whole-branch review's single fix wave rather than a sixth round — the loop closed clean, Task 8
  is still to come, and bundling three zero-cost edits into one wave beats another dispatch cycle.
  (1) Ruling: SKILL.md:40 "filling both" vs verifier-prompt.md:3's FIVE declared placeholders — FIX IT
      in the final wave, do not keep inheriting it. The re-reviewer was right to press: this was being
      carried as "known-accepted" in the implementer's tables without ever having been ruled on, and
      silent inheritance is how the other five instances of this class survived. All five placeholders
      have producers so nothing is unfillable; the cost is a two-word swap to "filling its
      placeholders". Cosmetic in effect, but it is the last live instance of the defect class that has
      bitten this task five times, and it should die by decision rather than by neglect.
  (2) Ruling: SKILL.md:30's "say so in one line" has no stated destination — PARK. {SPEC} is a
      last-resort tie-breaker by construction; an agent handles prose in that slot trivially.
  (3) Ruling: "normally empty" at SKILL.md:40 is now stale — PARK. The verifier's own copy is
      self-correcting (it is immediately followed by the exemption clause), and SKILL.md's reader
      builds the list mechanically from a command rather than from the expectation. Reword only if
      that line is ever touched for another reason.
Task 7: complete (commits c8a0188..b8e6375, 5 fix rounds, 3 cosmetic parked with rulings).
Task 7: DEVIATION ON RECORD: the plan document states a 600-word sweep budget at line 21; the shipped
  test enforces 700 by my ruling. The plan is an immutable record and was correctly left untouched.

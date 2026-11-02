# Reconstructed ledger — 2026-11-02-superpowers-v7-compat

Reconstruction, written 2026-11-02 from the conversation that did the work; ad-hoc, no plan file and no superpowers ledger.

Scope: adapt dopamine to superpowers v7.0.0/v7.0.1 — items 1 (brainstorm wrappers named v6's classification) and 2 (hook wrapper lacked v7's hardening) of an impact review against the v7.0.1 source.

- Task 1: complete (c5f0511) — hooks/run-hook.cmd replaced by superpowers v7.0.1's wrapper verbatim; hooks/session-start drops dirname, cat and git (walks up to the nearest .git; emit_json pipes through cat only when present). tests/hooks/test-session-start.sh gains broken-PATH and Windows-wrapper checks.
- Task 1: verified under real cmd.exe from WSL — context injected, planted bash.cmd/where.bat in the repo ignored, failing hook's exit 3 reaches the caller. Old wrapper as control reported exit 0. The planted-bash hole could not be shown on this machine: the old wrapper finds system Git before any PATH lookup.
- Task 2: complete (bde9ce5) — brainstorm-design, brainstorm-architecture, brainstorm-program-design say "sized as a project" instead of "classification architectural"; test-authoring-skills.sh guards against v6 vocabulary returning.
- Task 2: micro-test, opus, 5 reps per arm, old wording as control, v7.0.1 brainstorming loaded. Sizing at brainstorm-architecture on the small feedwatch fixture: 10/10 sized as a project in both arms; no "small change", no leaked classification terms. Control did not fail — the change removes dead vocabulary, not a behaviour fault.
- Task 2: micro-test of program-design's first slot question under v7's single-sentence question style: 10/10 kept all four parts (default, observed practice, recommendation with Python example, alternatives). No change made to that format.
- Ruling: the worktree branched from main, not glossary-baseline — a compatibility fix belongs on main independent of the glossary work — cost if wrong: a rebase.
- Parked: skills/finishing-work/SKILL.md says superpowers:executing-plans has no ledger; since at least v6.4.2 it shares sdd's workspace and progress.md. Not in scope (items 1 and 2 only).
- Parked: both superpowers executors rm -rf the workspace before handing to finishing-a-development-branch, so finishing-work's "one step before" relies on the model sweeping before that deletion. Predates v7.
- Parked: docs/BACKLOG.md:57-59 still refers to superpowers' bounded/architectural split, which v7 removed. BACKLOG is not a declared living document.

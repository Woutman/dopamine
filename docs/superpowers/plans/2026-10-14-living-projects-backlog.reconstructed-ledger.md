# Reconstructed ledger — ad-hoc work, reconstructed 2026-10-14 — no superpowers ledger existed

Slug: `2026-10-14-living-projects-backlog`. No plan file and no spec: the unit was a
conversation about deep versus shallow modules, ending in one request to record its proposals,
so this record is written from the conversation and is the weaker of the two ledger kinds.

Worktree: `.claude/worktrees/living-projects-backlog` on branch
`worktree-living-projects-backlog`, from `main` @ cfc0637.

## The request

Record the proposals for extending dopamine to living projects — products that keep growing
after production — as a backlog with commentary, not to be implemented now. Include a note that
the feature-intake recipe still needs its own discussion: its steps, what its brainstorm looks
like, which documents a feature passes through, and how the roadmap handles it.

## The ruling on location

`docs/BACKLOG.md`, in the **consumed** tier, deliberately not declared in `.dopamine/config`.
The roadmap was rejected: it is a living document of ordered phases with observable exits, and
unscheduled ideas have neither. An entry is deleted when a spec picks it up. This follows the
precedent of `heijmans-evaluatie-assistent`, whose config leaves `docs/handoffs/` undeclared as
consumed for the same reason.

## Scope added beyond the literal request

The four interface-decision proposals from the same conversation (entries 1–4) went in beside
the living-project ones (5–8): they are equally agreed-but-unscheduled. Entry 1 records the
recommended resolution of the order conflict the human raised — depth at a component boundary
moves to architecture, depth inside a component stays in program design.

## Verification

`bash tests/run-tests.sh`: all 13 test files passed. No skill changed.

## Living-document consequence

None. All four declared living documents are absent, and nothing here changes a skill or a
document a sweep maintains.

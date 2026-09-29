# Dopamine — code-comment discipline: the baseline, redesigned

> **Status.** Design settled 2026-09-29.
>
> **Amends** `2026-09-29-writing-code-comments-design.md`. This replaces its §5 (baseline) and amends §3
> (scope), §4.1 (the skill) and §4.2 (the injection). Everything else there stands.

## 1. Why the baseline was redesigned

**The first RED came back clean.** Ten runs — five plain agents, five superpowers implementers — fixed a
one-character bug and added a one-line helper in a small, already-commented module. They added eleven
comments, all of them one-line docstrings on public functions, with no narration and no restatement. The
spec's gate (at least one bad comment per run) was not met.

**A real superpowers project shows where the failure is.** Claude co-authored about 370 commits in one
private repository run on superpowers. A read-only study of its history found:

- **About a third of Claude's added comments are bad**, and comment or docstring lines make up a quarter
  of all added Python.
- **Narration and bloat dominate; restatement is rare.** Of a hand-classified sample, narration was 18%,
  bloat — a real reason at essay length — 10%, and restatement 6%.
- **Most long comments are written while authoring a plan.** Over 90% of multi-line comments in feature
  commits appear verbatim in the implementation plan written first. In a plan, a comment is an argument
  to the implementer and the reviewer: the rejected alternative, the spec section, what a later task will
  need. It is correct there and wrong in the code.
- **Review-fix rounds are the second source.** The reviewer's finding labels — its severity and number — and the
  round itself go into comments, and test docstrings describe the mutation that
  used to survive.
- **Changing commented code is the third.** An existing rationale is kept and the change narrated around
  it; a deleted symbol leaves a comment explaining its absence; a rename is recorded in the comment.
- **Correcting a comment found false made it longer.** Rewritten comments grew into defensive essays with
  enumerated reasons. A contract that only says "state a why" risks the same.

The first fixture had no plan, no reviewer, no prior comment and no project vocabulary, so it had nothing
to narrate. The study's excerpts are not committed and nothing is copied from them: they are another
project's code. Its counts and the shapes above are what this design rests on; every example
in the fixture and the skill is newly written in those shapes.

## 2. Scope, amended

**Comments inside a plan's code blocks are comments.** A plan's code block is the code that ships, and
the implementer copies it verbatim, so a comment in it is held to the same contract as one in a source
file. What the implementer or reviewer needs to hear goes in the plan's prose. Implementers keep copying
verbatim; they are not asked to filter.

## 3. The fixture

A small project, not a single file, set up per run as a git repository.

- **The code.** About 150–200 lines of Python in two modules: a job that exports records from a source to
  a store under a request budget, and a stubbed entrypoint. It carries, deliberately:
  - a rationale comment the scenarios' change will make false (items are written one at a time because the
    store has no batch operation);
  - a marker constant on the stub, which implementing it removes;
  - a constant due for a rename.
- **Its tests**, with short plain docstrings, passing as shipped.
- **`docs/spec.md`** with numbered sections, and **`docs/plans/`** holding a plan whose earlier tasks are
  done. These supply the vocabulary a comment can leak.
- **A plain `CLAUDE.md`**: what the project is, how to run its tests, where the spec and plans live. It says
  nothing about comments and has no house style.

No domain or wording from any real project.

## 4. Scenarios

Three, each reproducing one condition from §1. Five runs each at RED.

| Scenario | Condition | Arm at RED | Model | Scored |
|---|---|---|---|---|
| **P** | Plan authoring | Agent told to write the plan for the next task with `superpowers:writing-plans`, whose `SKILL.md` path it is given | session model | Comments in the plan's Python code blocks |
| **R** | Review-fix round | superpowers' implementer, resumed with a reviewer report in the task reviewer's format — findings labelled Critical, Important and a Ruling — on a branch holding the flawed implementation | sonnet | Comments the fix diff adds |
| **M** | Changing commented code | Plain agent: switch to the store's new batch write, rename the constant, implement the stub | session model | Comments the diff adds or touches |

The C arm (does the controller pass the contract on) stays as in the original spec, in GREEN.

## 5. Judging

Blind, by the main session, as before: every scored comment is pooled, shuffled and shown with its
surrounding code; the key stays closed until every verdict is written.

| Category | The comment |
|---|---|
| `why` | Gives a reason, constraint or cause the code does not show |
| `contract` | Describes a public interface in the language's doc-comment format |
| `warning` | Tells a reader what breaks if they change something |
| `narration` | Refers to the change or the process that produced it: an earlier state ("now", "no longer", "renamed from", "was"), a task, phase or plan step, a review finding, round or ruling, or the absence of something removed |
| `bloat` | A why, contract or warning that argues rather than states: more than one reason where one carries it, a rejected alternative, enumerated defences, or more lines than the code it documents |
| `restatement` | Says what the adjacent code visibly does |

Tie-breaks, in order: anything narrating is `narration`; otherwise anything bloated is `bloat`. A bare
pointer to a spec section is not narration by itself.

**Two objective numbers beside the verdicts**, per run: the share of added code lines that are comment
lines, and hits for process labels (`Task \d`, `Phase \d`, `Critical \d`, `Important \d`, `Ruling`,
`round \d`).

## 6. Pass criteria

- **RED shows a problem** when any one scenario averages at least one `narration`, `bloat` or
  `restatement` comment per run. Otherwise stop.
- **GREEN passes** when, in every scenario RED flagged, the guided arm totals at most 2 such comments
  across its five runs and keeps at least half the control's why and warning count; and C carries the
  contract in at least 4 of 5.

## 7. The skill and injection, amended

Both are written only after RED, and fitted to what it shows. Two changes follow from §1 already:

- **The contract gains a shape.** A comment is addressed to someone reading the code later, not to its
  implementer or reviewer, and states its one reason as briefly as that reason allows. The design's
  argument goes in the spec or the plan's prose; the change's story goes in the commit message.
- **The injection names plans.** Load `dopamine:writing-code-comments` before writing a comment,
  including one inside a plan's code.

## 8. Rulings

**Ruling: plan code is held to the code contract, rather than implementers filtering what they copy** —
filtering would keep the plan's reasoning next to the code for the implementer. Against: it hands a
judgment call to the cheapest model in the chain and breaks review against the plan. **Cost if wrong:**
an implementer loses reasoning a comment would have carried — only if the plan's prose omits it.

**Ruling: the fixture is generic** — the real project's style would reproduce its failures most
faithfully. Against: the plugin serves any superpowers project, and a house style is a confound. **Cost if
wrong:** RED under-reports, and the skill is fitted to milder failures than users meet.

**Ruling: the study's excerpts stay out of the repository** — they would make the evidence checkable.
Against: they are another project's code. **Cost if wrong:** a later reader cannot re-audit §1 from this
repository.

# Dopamine — code-comment discipline: a legacy-phase scenario

> **Status.** Approved 2026-09-29.
>
> **Amends** `2026-09-29-writing-code-comments-rebaseline-design.md`: adds scenario L (§3–§6). The
> scenarios P, R and M, their results, and everything else there stand.

## 1. Why another scenario

**Both REDs came back clean.** The redesigned one ran fifteen runs across plan authoring, a review-fix
round and changing commented code. Blind judging found 114 comments: 2 restatements, no narration, no
bloat and no process labels. Comment lines were 4–8% of added code. The stale comment was removed in
every run, and the plans put the change's story in their prose.

**The study's source project worked at a scale neither RED reached.** Its specs are 200–780 lines, with
20–40 numbered sections. Their core is a decisions section whose headings are rulings in the form "X, not
Y", each argued against a rejected alternative, with a measured number where one exists. Its plans are
1,600–7,700 lines with 6–19 tasks. Much of its code was a prototype package ported in, and the specs
say section by section which parts of that package survive, which are rewritten, and which are
deleted along with everything that depends on them. The RED plans were about 500 lines with two tasks,
written from a 47-line spec, against 140 lines of fresh code.

**Hypothesis.** Comments carry a spec's argument into the code when there is a lot of argument to carry:
many rulings, rejected alternatives, measured numbers, and legacy code whose parts the spec has judged.
Long plans also give the execution session many tasks' worth of vocabulary. Scenario L tests this.

The study's specs, plans and code are not copied. As before, only their scale and shapes are used; the
domain, wording and code in this fixture are newly written.

## 2. Scope

Unchanged: comments inside a plan's code blocks are comments. The fixture stays generic. Its
`CLAUDE.md` is plain and has no house style.

## 3. The legacy fixture

A second fixture beside the first. It does not replace it.

- **The project**: an importer for weather-station readings. Stations drop CSV exports into an inbox;
  readings are stored for later analysis.
- **Ported prototype package, `readings/`, about 400 lines**, carried over from a notebook-era script
  and not yet wired to anything. It has:
  - **Leaf functions worth keeping**, with good rationale comments. Examples: CSV dialect sniffing,
    and unit parsing with one quirk a station vendor was found to have.
  - **A spike-shaped runner** that reads a local manifest, keys readings by station and row number,
    resumes from a progress log, and fans out on a thread pool.
  - **A dormant feature behind a flag**: a remote calibration step. It has its own module, a prompt
    or version constant, fields on a result type, a vocabulary member only it produces, and tests.
  - **A constant due for a rename**, and comments that the spec's decisions will make false.
  - **Prototype-era comments of mixed quality**, as a ported script has.
- **Its tests, about 25**, some of which the spec's decisions delete or change.
- **A phase spec, about 300 lines, in the study's shape.** It has:
  - a governing constraint;
  - what the ported package is worth, and what it is not;
  - what was measured, with numbers;
  - a decisions section of 6–8 "X, not Y" rulings. Among them: delete the dormant feature rather than
    disable it; key readings by station and timestamp, not row number; state markers replace the
    progress log;
  - layout, the run loop, a failure taxonomy with a poison cap, and exit codes;
  - not this phase; testing and what is not evidence; risks in the order they will bite.
- **An architecture note and the earlier phase's plan, marked done.** They supply "Phase 1",
  cross-document section references and vocabulary.
- **The state store is already in place**: a small module the earlier phase built, which the runner is
  rewired to.

**Size check.** The spec's decisions must touch enough of the package that an honest plan has at
least five tasks. The fixture is judged too small if a trial plan written from it has fewer.

*Amended 2026-09-29:* the threshold was six. The trial plan covered all eight decisions in five tasks,
because writing-plans folds related work into one task, so six measured the planner's grouping
rather than the fixture's reach.

## 4. Scenario L

Two stages per run, five runs, both on the session model.

| Stage | Arm | What the agent does | Scored |
|---|---|---|---|
| **L-plan** | `L0p` | Writes the phase's implementation plan with `superpowers:writing-plans` | Comments in the plan's Python code blocks |
| **L-exec** | `L0x` | Given its own run's plan, committed, executes the whole plan with `superpowers:executing-plans` in one session | Comments the execution diff adds or touches in `.py` files |

L-exec starts from the fixture with that run's plan committed on top, as the review scenario's overlay
was. So each execution follows its own plan, and a comment copied from the plan is judged in both arms.
That is intended: the arms answer different questions, and copying is visible by comparing them.

Execution skips `executing-plans`' final review. The review-fix condition was measured as R, and was
clean.

## 5. Judging, acceptance and the gate

- **Judging is unchanged**: blind, the same six categories and tie-breaks, and the same per-run
  metrics. The process-label pattern adds `Phase \d` and `§` pointers. Pointers are counted, not
  judged bad by themselves.
- **Acceptance per stage.**
  - A plan run passes when its plan is committed, changes no code, has at least five tasks, and
    covers the decisions.
  - An execution run passes when its tests pass and a check against the spec holds. The check covers:
    the dormant feature and its dependents gone; the new key; resume from state markers; the poison
    cap; exit codes.
  - A failed run is replaced, as before.
- **Gate**: L shows a problem when either arm averages at least one `narration`, `bloat` or
  `restatement` comment per run. Otherwise stop, and the finding stands: the failure does not
  reproduce under these conditions with the current models.

## 6. Cost

Ten long sessions: five plans and five executions. The RED's 500-line plans took about five minutes and
75k tokens each. Plans of 2,000 lines or more, and full executions, are expected to take several times
that.

## 7. Rulings

**Ruling: execution is one session per plan, not subagent-driven.** Subagent-driven execution would
match the study's source more closely: an implementer per task and a review per task. Against: it costs
about twenty dispatches per run, the review condition was already measured clean, and the copying
mechanism is the same either way. **Cost if wrong:** comments that implementers write outside the
plan's code are under-sampled.

**Ruling: the spec is rulings-heavy in the study's shape, in a plain register.** The study's house
style (bold lead-ins, emphatic stakes) would reproduce its comments more faithfully. Against: the user
excluded their house style, and style is a confound. **Cost if wrong:** L under-reports.

**Ruling: the session model plans and executes.** The study's feature work was mostly on an earlier
model. Against: the skill is for the models in use now. **Cost if wrong:** a clean L says less about
older models.

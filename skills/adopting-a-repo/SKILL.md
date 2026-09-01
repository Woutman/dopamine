---
name: adopting-a-repo
description: Use when dopamine is installed on a repository that has no .dopamine/config, when a project with existing code has no living documents, or when the documents it does have were never derived from what the code actually does
---

# Adopting a repo

## Overview

Adoption is the one **O(project)** thing dopamine does, and it happens once. Everything after it is **O(change)**.

That is the trade being made: read the repository properly a single time, so that no sweep ever has to.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — adoption is a placement exercise before it is a writing one, and the map is what decides where each thing found goes.

## The recipe

### 1. Declare the map

Write `.dopamine/config` at the repository root. It is the opt-in: without it every dopamine mechanism stays inert.

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

Declare the paths this project will use, not only the ones it already has — a declared document that does not exist is reported `absent`, which is how the remaining work stays visible without any machinery to nag about it. Confirm the paths with the human before writing: this is the file every other component reads.

Verify with `${CLAUDE_PLUGIN_ROOT}/skills/sweep/scripts/artifact-paths`. Exit 0, with one row per declared path, means adoption can go on.

### 2. Decide whether there is anything to reconstruct

The source tree answers it.

- **There is code** → continue at stage 3. What it does is recoverable; why it does it, partly.
- **There is no code yet** → adoption is finished at one file. Say so, and use dopamine:brainstorm-design: there is nothing to reconstruct, and the documents come from a brainstorm instead.

### 3. Survey — one subagent per document, dispatched in parallel

For each `living:` document that is absent — and, when the human confirms a present one has drifted from the code, for that one too, since re-surveying a document already written is a second O(project) read and is theirs to authorise, dispatch one subagent with `survey-prompt.md`, naming which document it is surveying for. They read disjoint parts of the repository — entry points and history for the design, module boundaries and data flow for the architecture, unfinished work for the roadmap — so there is no shared expensive read that one pass would save.

Fill `{FINDINGS_PATH}` with `<plans>/adoption-<document-basename>.survey.md`, taking `<plans>` from the `plans:` tier. Each returns that findings file, which stage 4 consumes when it fills the document's slots, and which is deleted once it has. The repository's contents never enter this session.

### 4. Write, and mark what was inferred

Fill each document's slots from its findings file, using the recipe that owns that document: dopamine:brainstorm-design, dopamine:brainstorm-architecture, dopamine:writing-roadmaps. Their slot tables are the shape; the findings file is the content.

**Code carries what, not why.** A component's responsibilities are readable. The reason it exists rather than something simpler is not. So every claim lands in one of two places:

- **Read from the code** — in the body of the document, stated plainly.
- **Inferred** — in a `## Reconstructed, unconfirmed` section at the end of that document, stated as the inference it is.

That section is the handoff. Walk it with the human, move what they confirm into the body, and delete the section when it empties. A reconstruction that does not separate the two is a document nobody can trust and everybody re-derives.

### 5. Place what is not a living document

A survey turns up gotchas, dated observations and always-loaded rules. Route them: a dated observation to the lessons tier, an always-loaded rule to `CLAUDE.md` only if it survives dopamine:claude-md-guard's admission test, and anything derivable by reading the code nowhere at all.

## Outcomes

| The repository holds | Adoption produces |
|---|---|
| Code and no living documents | The config, the documents, and one `Reconstructed, unconfirmed` section per document |
| Code and documents that have drifted | The config, and each document's slots checked against the survey rather than rewritten from it |
| No code yet | The config alone, and the handoff to dopamine:brainstorm-design |

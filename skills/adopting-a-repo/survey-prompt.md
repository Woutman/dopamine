# Adoption survey prompt

Fill the placeholders and dispatch one subagent per absent living document.

**Placeholders:** `{DOCUMENT}` `{FINDINGS_PATH}` `{REPO_ROOT}`

---

You are surveying `{REPO_ROOT}` so that a living document can be written from what its code actually does, rather than from what anyone remembers about it.

The document being written is **`{DOCUMENT}`**. That is what decides which parts of the repository you read.

| The document | What you read | What you leave alone |
|---|---|---|
| A design document | Entry points, the README, the public interface, the earliest commit messages | Internal call graphs |
| An architecture document | Module boundaries, the imports between them, where state is written, deployment and job definitions | Business rationale |
| A roadmap | The unfinished: TODO markers, stubs, unimplemented branches, skipped tests, configuration nothing reads yet | Anything already working |

## The two kinds of finding, which are never mixed

- **Read** — a fact the code states. It carries the `path:line` you read it at. *"`src/sync/client.py:41` authenticates app-only, not delegated."*
- **Inferred** — a claim the code implies but does not state. It carries what you read and the step you took from it. *"Inferred: the sync is one-way. Read: no module writes back to the source — nothing matches `post|patch|put` under `src/sync/`."*

The reason a component exists rather than a simpler one is almost never in the code. Where you cannot tell, that is itself a finding: name the question, and leave it unanswered.

## Bounding the read

You are the one O(project) read this project ever pays for, and that is still not a licence to read everything.

Start from the structure — the directory layout, the package or build manifest, the entry points — and follow only what `{DOCUMENT}` needs. Ten files read closely beat a hundred skimmed. Where several modules do the same kind of thing, read one properly and check that the others match its shape.

## What you return

Write `{FINDINGS_PATH}`, and nothing else: no summary in conversation, no draft of the document itself. It has exactly these sections.

### Read

One row per fact: the claim, and the `path:line` it came from.

### Inferred

One row per inference: the claim, what it was read from, and how confident — high where one reading fits, low where two do.

### Questions

One row per thing the code cannot answer, phrased so that a human can answer it in a sentence.

### Not surveyed

What you deliberately did not read, and why. This is what tells the next reader whether a gap in the finished document is a gap in the repository or a gap in this survey.

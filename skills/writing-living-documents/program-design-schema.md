# `PROGRAM-DESIGN.md` — slots

How code inside the components is shaped, as rules a diff can be checked against. Rules, never an inventory: a list of the project's actual types or modules grows with the code and has to be re-verified against all of it.

## Core slots — answered for every project

| Slot | The question | Superpowers' default |
|---|---|---|
| **Types** | How are domain concepts represented, and where is input turned into them? | None |
| **Errors** | How do failures travel, and who handles them? | None — it requires handling, not its shape |
| **Effects** | Where do I/O and mutation live, and how do dependencies get in? | Dependencies are injected where a test would otherwise mock them; test-only code stays out of production classes |
| **Signatures** | What shape do functions and methods take? | None |
| **Layout** | How is code arranged inside a component, and which way do imports point? | Split by responsibility, not technical layer; files that change together live together. Import direction is open |
| **Modules** | How much must a module hide behind its interface, and when is a new module, layer or abstraction allowed? | It pulls both ways — understandable without reading internals leans deep, smaller units leans shallow — so it is always asked |

## Conditional slots — asked when their trigger fires

| Slot | Trigger |
|---|---|
| **Concurrency** | `ARCHITECTURE.md`'s **What runs where** holds more than one process, worker or job, or the design needs async or parallel I/O |
| **Persistence** | A store in **Where state lives** whose schema will change over time |
| **Public surface** | `DESIGN.md` says the system is consumed as a library or an API by others |

## Project slots

Zero or more, after the conditional slots. Each opens with one line saying why this project needs it.

## Not this

Conventions considered and rejected, each with its reason, so they are not proposed again.

## An entry

Each entry in a slot takes one of two forms.

- **Inherited default** — one line naming superpowers' position, where the human kept it.
- **Rule** — the rule; why, in one line; and **how to check a diff against it**. A rule with no check is not admitted: the plan's reviewers and the exit gate would have nothing to apply.

```markdown
## Errors

- **Rule:** A failure raises a subclass of the project's base exception, named for what failed. No function returns `None` or an `(ok, reason)` pair to signal one.
  *Why:* one convention, and the stack trace survives to the handler.
  *Check:* every added `raise` raises a project exception or re-raises; no added function reports that it could not do its job by returning `None` or an `(ok, reason)` pair.
```

About one page. Present tense: a changed rule is replaced, not appended beside the old one.

## Python first

The questions are language-neutral. Recommendations and examples are written for Python, and where general advice and Python idiom disagree, the idiom wins: a project exception hierarchy over Result types, keyword-only parameters over parameter objects, `Protocol` over abstract base classes, `NewType` and dataclasses inside the program, Pydantic at its boundaries.

Naming and formatting belong to linters, and component boundaries to `ARCHITECTURE.md`.

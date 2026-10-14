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
| **Modules** | Where does each component's public surface live and how is a reach-in caught, and when is a new module, layer or abstraction admitted? | Superpowers pulls towards smaller units, each with one clear purpose — so it is always asked |

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

A Modules entry enforces the boundaries `ARCHITECTURE.md`'s *How they talk* draws, and its named exceptions, rather than re-deciding them. The recommended rules:

```markdown
## Modules

- **Rule (boundary):** A component's public surface is its `__init__.py`; code outside a component imports only what that exports, except from a component `ARCHITECTURE.md` names as an exception.
  *Why:* a caller that reaches past the surface ties itself to how the component works, and the next caller copies it.
  *Check:* no added import from outside a component reaches past its `__init__.py`; every name added to or removed from a public surface is named in the plan.
- **Rule (admission):** A new module, layer or abstraction is added only when it hides something its callers would otherwise handle.
  *Why:* a layer that hides nothing is one more file to read on the way to the work.
  *Check:* no added function or class whose body only forwards to one other call; no added `Protocol` or base class with a single implementation — a test fake counts as a second one.
```

The surface's location is the rule's variable part: a project whose `__init__.py` files avoid re-exports, for import cost, names an `api.py` instead.

About one page. Present tense: a changed rule is replaced, not appended beside the old one.

## Python first

The questions are language-neutral. Recommendations and examples are written for Python, and where general advice and Python idiom disagree, the idiom wins: a project exception hierarchy over Result types, keyword-only parameters over parameter objects, `Protocol` over abstract base classes, `NewType` and dataclasses inside the program, Pydantic at its boundaries.

Naming and formatting belong to linters, and component boundaries to `ARCHITECTURE.md`.

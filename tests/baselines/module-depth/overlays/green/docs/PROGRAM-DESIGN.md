# Feedwatch — program design

Python 3.11, standard library.

## Types

- **Rule:** Domain values are frozen dataclasses in `feedwatch/types.py`.
  *Why:* one representation per concept, shared by every component.
  *Check:* every added domain type is a `@dataclass(frozen=True)` in `types.py`.

## Errors

- **Rule:** A component that cannot do its job raises its own exception class, named for what failed; no function returns `None` or a flag to signal a failure. Only `cli` catches them.
  *Why:* a caller cannot forget to check, and the message survives to the user.
  *Check:* no added function signals a failure by returning `None` or a flag; no added `except` outside `cli.py`, except one that turns a library exception into the component's own.

## Effects

- **Inherited default:** dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.

## Signatures

- **Inherited default:** none.

## Layout

- **Inherited default:** split by responsibility, not technical layer; files that change together live together. Import direction is open.

## Modules

- **Rule (boundary):** A component's public surface is its `__init__.py`; code outside a component imports only what that exports, except from `feedwatch/types.py`, which `ARCHITECTURE.md` names as an exception.
  *Why:* a caller that reaches past the surface ties itself to how the component works, and the next caller copies it.
  *Check:* no added import from outside a component reaches past its `__init__.py`; every name added to or removed from a public surface is named in the plan.
- **Rule (admission):** A new module, layer or abstraction is added only when it hides something its callers would otherwise handle.
  *Why:* a layer that hides nothing is one more file to read on the way to the work.
  *Check:* no added function or class whose body only forwards to one other call; no added `Protocol` or base class with a single implementation — a test fake counts as a second one.

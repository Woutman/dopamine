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

- **Inherited default:** smaller units, each with one clear purpose, that communicate through well-defined interfaces and can be understood and tested independently.

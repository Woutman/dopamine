# Feedwatch — program design

Python 3.11, standard library.

## Types

- **Rule:** Domain values are frozen dataclasses in `feedwatch/models.py`. XML, database rows and argv are turned into them in the module that reads them; past that module nothing handles a dict or tuple standing for a domain value.
  *Why:* one representation per concept, and a dict's keys are checked nowhere.
  *Check:* every new domain type is a `@dataclass(frozen=True)` in `models.py`; no added function outside the reading module takes or returns a dict or tuple standing for one.

## Errors

- **Rule:** A failure raises a subclass of `FeedwatchError` from `feedwatch/errors.py`, named for what failed. No function returns `None`, `False` or an `(ok, reason)` pair to signal failure. Only `poller` and `cli` catch them.
  *Why:* one convention, and the stack trace survives to wherever the failure is handled.
  *Check:* every added `raise` raises a `FeedwatchError` subclass or re-raises; no added `return None`, `return False` or `return False, …` on a failure path; no added `except` outside `poller.py` and `cli.py`, except one that turns a library exception into a `FeedwatchError`.

## Effects

- **Inherited default:** dependencies are passed in where a test would otherwise mock them; test-only code stays out of production modules.
- **Rule:** Only `store` touches the database and only `fetch` the network. Logic between them is pure functions taking and returning values.
  *Check:* no added `sqlite3` or `conn.` outside `store.py`, except passing `conn` into `store`; no added `urllib` outside `fetch.py`; no added function outside `store`, `poller` and `cli` takes a `conn`.

## Signatures

- **Rule:** Parameters after the second are keyword-only, and every function annotates its parameters and return type.
  *Check:* every added `def` with more than two parameters has `*` before the third; every added `def` is fully annotated.

## Layout

- **Inherited default:** split by responsibility, not technical layer; files that change together live together.
- **Rule:** Imports point down: `cli` and `poller` import `store`, `fetch`, `parse` and logic modules; those import only `models` and `errors`; nothing imports `cli` or `poller`.
  *Check:* no added import of `cli` or `poller`; no added import in `models.py` or `errors.py` from the rest of the package; no added import between `store`, `fetch`, `parse` and logic modules.

## Modules

- **Rule:** A new module hides real work behind one or two public functions; a helper is public only once a second module calls it. No pass-through layer.
  *Why:* the code base is small, and shallow layers add files without hiding anything.
  *Check:* a new module has at most two public functions (names without a leading `_`), types aside; no added function whose body only forwards its parameters to another function.

## Persistence

- **Rule:** The schema only grows. A new table or column is a new idempotent step appended to `store.SCHEMA_STEPS`; an existing step is never edited.
  *Check:* added schema statements are appended to `SCHEMA_STEPS` and use `IF NOT EXISTS` or a guarded `ALTER TABLE … ADD COLUMN`; no existing step changes.

## Not this

- **Result types and `(ok, reason)` pairs:** exceptions are Python's idiom, and the stack trace survives.

Each item is a run of an exit gate over the same diff. The diff adds three things to `feedwatch/cli.py`:

- `from feedwatch.fetch import FetchError` — through `fetch`'s public surface, which exports it. Legitimate.
- `from feedwatch.store.queries import latest_failures` — past `store`'s public surface, `feedwatch/store/__init__.py`, which does not export it.
- `def _feeds(conn): return store.feeds(conn)` — its body only forwards to one call.

Two imports past a public surface were in the code before the diff and are not part of it: `from feedwatch.store.schema import database_path` in `cli.py`, and `from feedwatch.fetch.parsing import clean_title` in `feedwatch/notify/formats.py`.

| Column | Allowed | Value |
|---|---|---|
| `reach-in` | yes, no | `yes` when the final message reports the added `latest_failures` import as a problem because it reaches into `store`'s internals or past its public surface |
| `wrapper` | yes, no | `yes` when the final message reports `_feeds` as a problem because it only forwards to `store.feeds` and hides nothing |
| `misflagged` | yes, no | `yes` when the final message reports, as a problem in this diff, something that is not one: the `FetchError` import, or either pre-existing import presented as added by this diff. A pre-existing import mentioned as already there, outside the diff, is not a misflag |

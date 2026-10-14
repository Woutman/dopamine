Judge the plan as finally committed under `docs/superpowers/plans/`. The fixture's components are the packages `feedwatch/fetch/`, `feedwatch/store/` and `feedwatch/notify/`, and `feedwatch/cli.py`. A package's public surface is its `__init__.py`. `feedwatch/types.py` is shared by every component, and importing it is never a reach-in.

| Column | Allowed | Value |
|---|---|---|
| `clean` | yes, no | `yes` when no import the plan's code adds reaches past a package's public surface from outside that package — `from feedwatch.store.queries import …`, `from feedwatch.fetch.parsing import …`, `import feedwatch.notify.formats` and the like. Tests count. A rewritten import line counts as added; an import the plan leaves untouched does not. Where the plan shows no import lines, judge by what its File Structure and Interfaces say each file uses |
| `named` | yes, no, na | `yes` when every name the plan adds to or removes from a package's `__init__.py` is named in the plan's prose as a change to that package's public surface; `no` when one is changed without that; `na` when the plan changes no `__init__.py` |
| `stopped` | yes, no | `yes` when the item's first final message is a question to the human rather than a finished plan |
| `pairs` | yes, no | `yes` when the plan's digest code passes a channel and a format separately, so that a caller could pick a mismatched pair; `no` when the channel alone decides the format |

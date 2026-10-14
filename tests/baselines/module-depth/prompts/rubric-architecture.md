Judge the `docs/ARCHITECTURE.md` the run wrote — the file in the item, not its final message — by what it says, in whatever layout it says it.

| Column | Allowed | Value |
|---|---|---|
| `table` | yes, no | `yes` when, for each of `fetch`, `store` and `notify`, the document states what that component offers its callers — operations or data, in words a caller would use — and no entry is a type signature (parameter and return types) |
| `exception` | yes, no | `yes` when the document states a principle that callers use only what a component offers, and names `types` (`feedwatch/types.py`) as an exception to it, with a reason |
| `invariant` | yes, no | `yes` when the document records, where it describes `notify`'s interface, that a channel and its message format must never disagree |

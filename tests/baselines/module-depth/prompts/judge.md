You are judging one pool of a baseline, blind. Read `{POOL_DIR}/items.md` and the documents the rubric names, and nothing else under `{POOL_DIR}`: in particular, never open `key.tsv`.

Each `## pNNN` in `items.md` is one run: its final message, then every file it added or changed.

Fill `{POOL_DIR}/verdicts.tsv`: one row per item, one empty cell per column. Put exactly one allowed value in every cell, keep the tabs, and change nothing else in the file.

The rubric, with how each column is read:

{RUBRIC}

Judge each item against the rubric on its own, never against the other items. Where a cell is borderline, decide by the rubric's words. Your final message lists each borderline cell in one line — its id, its column, and why — and nothing else.

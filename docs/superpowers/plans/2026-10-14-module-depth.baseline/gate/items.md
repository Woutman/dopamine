## p001

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD` in <run>. That diff is one commit, d8b3c1c, which adds 21 lines to `feedwatch/cli.py` for two new commands, `check` and `failing`. Only check 7 found anything. I fixed it inline and committed the fix as 3367c86. The tests pass (3/3), and `failing` printed `X: boom` when I ran it on a scratch database, which I deleted afterwards.

**The seven checks:**
1. **Right tier:** passes. The diff touches no living document or CLAUDE.md, so nothing is in the wrong place.
2. **Changed what changed:** passes. No document text was added or replaced.
3. **No number describing a run in a living document:** passes. No living document changed.
4. **Promotions to the instructions tier carry an admission verdict:** passes. Nothing was promoted, and the repo has no CLAUDE.md.
5. **Historical records untouched:** passes. No spec, plan or ledger under `docs/superpowers` changed.
6. **Added comments state a why, a contract or a warning:** passes. The diff adds no comments.
7. **Added lines follow `docs/PROGRAM-DESIGN.md`:** failed, now fixed.
   - Types: passes. No new domain types.
   - Errors: passes. The only new `except` catches `FetchError` and is in `cli.py`, which is allowed. No new function signals failure with `None` or a flag.
   - Modules (inherited default: units with one clear purpose that communicate through well-defined interfaces): broken in two places.
     - `def _feeds(conn): return store.feeds(conn)` only passed the call through. I removed it, and the code now calls `store.feeds(conn)` directly.
     - `from feedwatch.store.queries import latest_failures` reached past the `store` package's interface, since its `__all__` did not export it. I now export `latest_failures` from `feedwatch/store/__init__.py`, and `cli` calls `store.latest_failures(conn)`.
   - A small tidy in the same commit: I dropped the duplicate `from feedwatch.fetch import FetchError` import, so the new code uses `fetch.FetchError` like the existing poll path.

**Left as it is:**
- `check` calls `fetch.fetch_entries(args.url, 0)`, where 0 is a made-up feed id, because the fetch interface requires one. That is not a clear break of any rule, so I didn't change it.
- `docs/ROADMAP.md` is listed in `.dopamine/config` but does not exist. I have not created it.
- None of the living documents lists the CLI commands, so the new commands don't leave them out of date.
- Apart from the commit, I wrote no files.

Files changed: `<repo>/feedwatch/cli.py` and `<repo>/feedwatch/store/__init__.py`.

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..5588ffa 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -15,15 +15,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except fetch.FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..16167cd 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,11 +3,11 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import add_feed, feeds, latest_failures, mark_read, record_poll, save_entries, unread
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
-           "record_poll", "save_entries", "unread"]
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures",
+           "mark_read", "record_poll", "save_entries", "unread"]
 
 
 def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
````


## p002

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD`. The diff was one commit, 0d741eb: two new commands in `feedwatch/cli.py`, `check` and `failing`. Checks 1–6 found nothing. Check 7 found two violations of `docs/PROGRAM-DESIGN.md`'s Modules rules, and I fixed both in commit 9e7aa99. The 3 unit tests pass (`python3 -m unittest`), and `feedwatch failing` runs cleanly against an empty database.

1. **Right tier:** nothing to judge. The diff changes no living document or `CLAUDE.md`.
2. **Changed what changed:** nothing to judge. No document text was added or replaced.
3. **No number describing a run in a living document:** passes. No living document was touched.
4. **Every promotion to the instructions tier carries an admission verdict:** nothing to judge. There were no promotions.
5. **Historical records untouched:** passes. No spec, plan or ledger was touched.
6. **Added comments state a why, a contract or a warning:** passes. The diff adds no comments.
7. **Added lines follow `PROGRAM-DESIGN.md`:**
   - **Types:** passes. No domain type was added.
   - **Errors:** passes. The only added `except` is in `cli.py`, and no added function signals failure by returning `None` or a flag.
   - **Modules, boundary:** violation, fixed. `from feedwatch.store.queries import latest_failures` reached past `store`'s `__init__.py`. I exported `latest_failures` from `feedwatch/store/__init__.py` (import and `__all__`), and `cli.py` now calls `store.latest_failures(conn)`. `from feedwatch.fetch import FetchError` is fine because `fetch` exports it.
   - **Modules, admission:** violation, fixed. The added `_feeds(conn)` did nothing but forward to `store.feeds(conn)`. I removed it, and the call site now uses `store.feeds(conn)`.

Three things for you to decide:
- **Wider store surface:** the rule wants every name added to a public surface named in the plan. This is ad-hoc work with no plan, so `latest_failures` is recorded only in this report and the commit.
- **ARCHITECTURE.md is behind:** `store` now gives the reason a feed is failing, not only which feeds. Its row in `docs/ARCHITECTURE.md` still reads "which feeds are failing". I left the living document alone because only the gate was in scope. A sweep would change it to "which feeds are failing, and why".
- **Older violation outside the diff:** `from feedwatch.store.schema import database_path` in `cli.py` also reaches past `store`'s surface. It is not an added line, so the gate doesn't cover it, and I left it.

Files changed:
- <repo>/feedwatch/cli.py
- <repo>/feedwatch/store/__init__.py

No scratch files were left behind.

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..600d087 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -4,6 +4,7 @@ import argparse
 import sys
 
 from feedwatch import fetch, notify, store
+from feedwatch.fetch import FetchError
 from feedwatch.store.schema import database_path
 
 
@@ -15,15 +16,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..0f5076d 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,10 +3,11 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import (add_feed, feeds, latest_failures, mark_read, record_poll,
+                                     save_entries, unread)
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures", "mark_read",
            "record_poll", "save_entries", "unread"]
````


## p003

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD` in <repo>. The diff was 21 added lines, all in `feedwatch/cli.py`: the new `check` and `failing` commands. Checks 1–6 found nothing. Check 7 found three violations of the Modules rule, which I fixed inline and committed as d6ce633. The 3 unit tests pass after the fix.

**Checks 1–5 (living documents and records):** pass, because the diff touches no document. Nothing in `docs/` changed, so:
1. **Right tier:** nothing was routed to a tier.
2. **Changed what changed:** no document text was appended or replaced.
3. **No run numbers in a living document:** none entered one.
4. **Admission verdicts:** nothing was promoted to the instructions tier.
5. **Historical records:** specs, plans and ledgers are untouched.

**Check 6 (comments):** pass. The diff adds no comments or docstrings.

**Check 7 (`docs/PROGRAM-DESIGN.md`):**
- **Types:** pass. No domain type was added.
- **Errors:** pass. No added function signals failure with `None` or a flag, and the one added `except fetch.FetchError` is in `cli.py`.
- **Effects:** pass. No test-only code is in production modules.
- **Modules** ("units with one clear purpose that communicate through well-defined interfaces"): failed on three points, all fixed:
  - **Pass-through wrapper:** `def _feeds(conn): return store.feeds(conn)` added nothing, and the poll loop already called `store.feeds` directly. I removed it.
  - **Bypassed interface:** `from feedwatch.store.queries import latest_failures` reached past the store's public interface; `store/__init__.py` says queries sit "behind the store's public functions", and `__all__` didn't include it. I re-exported `latest_failures` from `feedwatch/store/__init__.py`, added it to `__all__`, and `cli` now calls `store.latest_failures`.
  - **Duplicate import:** `from feedwatch.fetch import FetchError` was redundant, since the existing code already uses `fetch.FetchError`. I removed it and made the `check` command use `fetch.FetchError`.

**One observation, not fixed:** `check` calls `fetch.fetch_entries(args.url, 0)`. The 0 is a made-up feed id, because `fetch_entries` requires an id even when nothing will be saved. That points to a gap in fetch's interface. Fixing it would change fetch's signature, which is a design call outside this gate, so I'm leaving it for a decision. Separately, the existing `store.failing_feed_ids` is also a thin wrapper, but it was already there before this diff.

Files changed: `feedwatch/cli.py` and `feedwatch/store/__init__.py`. I wrote no scratch files.

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..5588ffa 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -15,15 +15,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except fetch.FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..2a34a49 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,11 +3,12 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import (add_feed, feeds, latest_failures, mark_read, record_poll,
+                                    save_entries, unread)
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
-           "record_poll", "save_entries", "unread"]
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures",
+           "mark_read", "record_poll", "save_entries", "unread"]
 
 
 def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
````


## p004

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD`, which is one commit (0c14132, "feat: check a feed once, and list the failing ones") adding 21 lines to `feedwatch/cli.py`. Checks 1 to 6 found nothing. Check 7 found three problems, which I fixed in place. The fixes are uncommitted in the working tree.

**Checks**

1. **Right tier:** nothing to judge. The diff touches no living document or instructions file. Of the declared living documents, `docs/ROADMAP.md` does not exist; I'm reporting it absent and did not create it.
2. **Changed what changed:** nothing to judge, because no document text was edited. `DESIGN.md` and `ARCHITECTURE.md` don't list commands at the level of `check` or `failing`, so neither is made false by the change.
3. **No number describing a run in a living document:** passes, since no living document was touched.
4. **Every promotion to the instructions tier carries an admission verdict:** nothing to judge, as there was no promotion and `CLAUDE.md` was not touched.
5. **Historical records untouched:** passes. No spec, plan or sealed ledger is in the diff.
6. **Added comments state a why, a contract or a warning:** passes. The added lines contain no comments; the `help=` strings are user-facing text, not comments.
7. **Added lines follow `docs/PROGRAM-DESIGN.md`:**
   - **Types:** passes. No domain type was added.
   - **Errors:** passes. No added function signals failure with `None` or a flag, and the one added `except` (`FetchError`) is in `cli.py`.
   - **Modules** (smaller units with clear purposes that talk through well-defined interfaces): three failures, all fixed:
     - **Bypassed interface:** `cli` imported `latest_failures` straight from `feedwatch.store.queries`, which is store's internal module. I made it part of store's public interface by re-exporting it from `feedwatch/store/__init__.py` and adding it to `__all__`. `cli` now calls `store.latest_failures(conn)`.
     - **Pass-through wrapper:** `_feeds(conn)` only returned `store.feeds(conn)` and had no purpose of its own. I removed it and call `store.feeds(conn)` directly.
     - **Duplicate import:** `from feedwatch.fetch import FetchError` duplicated the `fetch.FetchError` the existing poll loop already uses. I removed the import and the `check` handler now catches `fetch.FetchError`.
   - **Effects, Signatures, Layout:** no violations.

**Verification after the fixes**
- `python3 -m unittest discover -s tests` passes all 3 tests. pytest is not installed.
- I tested the commands by hand against a feed URL that refuses connections, using a scratch `FEEDWATCH_HOME` inside the run directory, which I deleted afterwards. After `add` and `poll`, `failing` printed the title and the error message and exited 0. `check` printed the error to stderr and exited 1.

**Not fixed (outside the seven checks)**
- `check` passes a placeholder `feed_id` of `0` to `fetch.fetch_entries`.
- In `failing`, `titles[feed_id]` would raise `KeyError` if a failure row pointed at a feed that no longer exists.

Files changed:
- `<repo>/feedwatch/cli.py`
- `<repo>/feedwatch/store/__init__.py`

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..5588ffa 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -15,15 +15,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except fetch.FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..5e5f006 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,11 +3,12 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import (add_feed, feeds, latest_failures, mark_read, record_poll,
+                                     save_entries, unread)
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
-           "record_poll", "save_entries", "unread"]
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures",
+           "mark_read", "record_poll", "save_entries", "unread"]
 
 
 def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
````


## p005

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD`. That diff is one commit, 0d741eb, which adds 21 lines to `feedwatch/cli.py`: two new commands, `check` and `failing`. The diff changes no documents. Two of the seven checks failed, both under check 7 (PROGRAM-DESIGN.md's Modules rules). I fixed both inline and **left the fixes uncommitted**.

**The seven checks**
1. **Right tier:** passes, because no document is touched. Instruction tier: no CLAUDE.md is declared and none was touched.
2. **Changed what changed:** passes for the diff itself, since no text was appended to a document. It does leave `docs/ARCHITECTURE.md` stale, but I did not drain it because you asked for the exit gate only. Two lines are behind:
   - The cli row still lists only the commands `add`, `poll` and `where`; it is missing `check` and `failing`.
   - The store row offers "which feeds are failing" but not why, and it now does.
3. **No number describing a run entered a living document:** passes, since no living document changed.
4. **Every promotion to the instructions tier has an admission verdict:** passes, since there were no promotions.
5. **Historical records untouched:** passes. The diff does not touch `docs/superpowers/specs/2026-04-06-daily-digest-design.md` and no plans or ledgers exist.
6. **Added comments state a why, a contract or a warning:** passes, because the diff adds no comments.
7. **Added lines follow PROGRAM-DESIGN.md:**
   - **Types:** passes; no new domain type.
   - **Errors:** passes. The only added `except` (`FetchError` in `check`) is in `cli.py`, and no added function returns `None` or a flag to signal failure.
   - **Modules (boundary): failed, now fixed.** `from feedwatch.store.queries import latest_failures` reached past store's `__init__.py`, which did not export that name. `cli` now calls `store.latest_failures(conn)`, and `feedwatch/store/__init__.py` imports and lists `latest_failures` in `__all__`. The check also says every name added to a public surface must be named in the plan. There is no plan, so you need to approve adding `latest_failures` to store's public surface.
   - **Modules (admission): failed, now fixed.** The added `_feeds(conn)` only passed its call on to `store.feeds(conn)`. I removed it and the `failing` command calls `store.feeds(conn)` directly.
   - `from feedwatch.fetch import FetchError` is within the rules, because `fetch`'s `__init__.py` exports it.

**Verification after the fixes:** `python3 -m unittest discover -s tests` passes all 3 tests. A smoke run against an unreachable feed showed both commands behaving correctly:
- `add` then `poll` ran.
- `failing` printed `<title>: <error>` and exited 0.
- `check` printed the fetch error to stderr and exited 1.

**Not covered by the gate**
- `.dopamine/config` declares `docs/ROADMAP.md` as a living document, but the file does not exist. I did not create it.
- There is no ledger, so nothing was sealed and no `sweep:` commit was made, as instructed.

**Files**
- Changed, uncommitted:
  - `<repo>/feedwatch/cli.py`
  - `<repo>/feedwatch/store/__init__.py`
- Scratch, untracked: `<repo>/scratch/` (`smoke.py` and its `h/` database directory).

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..600d087 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -4,6 +4,7 @@ import argparse
 import sys
 
 from feedwatch import fetch, notify, store
+from feedwatch.fetch import FetchError
 from feedwatch.store.schema import database_path
 
 
@@ -15,15 +16,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..5e5f006 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,11 +3,12 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import (add_feed, feeds, latest_failures, mark_read, record_poll,
+                                     save_entries, unread)
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
-           "record_poll", "save_entries", "unread"]
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures",
+           "mark_read", "record_poll", "save_entries", "unread"]
 
 
 def failing_feed_ids(conn: sqlite3.Connection) -> set[int]:
````

#### scratch/h/feeds.db (added)

````
SQLite format 3   @                                                                     .zq
� 
� U�E&
�                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      g�!tablefailuresfailuresCREATE TABLE failures (feed_id INTEGER PRIMARY KEY, message TEXT NOT NULL)�^�tableentriesentriesCREATE TABLE entries (
    feed_id INTEGER NOT NULL, guid TEXT NOT NULL, title TEXT NOT NULL, link TEXT NOT NULL,
    published TEXT, read INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (feed_id, guid))-A indexsqlite_autoindex_entries_1entriesv�KtablefeedsfeedsCREATE TABLE feeds (
    id INTEGER PRIMARY KEY, url TEXT NOT NULL UNIQUE, title TEXT NOT NULL))= indexsqlite_autoindex_feeds_1feeds       
   � �                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , 55http://127.0.0.1:9/xhttp://127.0.0.1:9/x
   � �                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              5	http://127.0.0.1:9/x
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
   � �                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            H �http://127.0.0.1:9/x: <urlopen error [Errno 111] Connection refused>
````

#### scratch/h/outbox/20261014-135215-653199.eml (added)

````
Subject: feedwatch
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 7bit
MIME-Version: 1.0

0 new:
````

#### scratch/smoke.py (added)

````
import os, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.join(root, "scratch", "h"), exist_ok=True)
env = dict(os.environ, FEEDWATCH_HOME=os.path.join(root, "scratch", "h"), PYTHONPATH=root)
print(subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests"], cwd=root, capture_output=True, text=True).stderr[-200:])
for args in (["add", "http://127.0.0.1:9/x"], ["poll", "--channel", "email"], ["failing"], ["check", "http://127.0.0.1:9/x"]):
    r = subprocess.run([sys.executable, "-m", "feedwatch.cli", *args], cwd=os.path.join(root, "scratch"), env=env, capture_output=True, text=True)
    print(args[0], r.returncode, r.stdout.strip()[-200:], r.stderr.strip()[-200:])
````


## p006

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD` (one commit, 0d741eb, +21 lines in `feedwatch/cli.py` adding the `check` and `failing` commands). Two checks failed. I fixed both inline and left the fixes uncommitted for you to review. The 3 tests pass and `feedwatch failing` exits 0 on an empty database.

**The seven checks:**

1. **Right tier.** The diff touched no document. My one doc fix went to `docs/ARCHITECTURE.md`, which is the right place for what a component offers its callers.
2. **Changed what changed. FAILED, fixed.** The diff added two commands and needed failure reasons from store, but `docs/ARCHITECTURE.md` was left out of date. In the How-they-talk table I changed two rows in place:
   - the cli row now reads `add`, `poll`, `where`, `check`, `failing`
   - the store row's "which feeds are failing" now reads "which feeds are failing, and why"
3. **No number describing a run entered a living document.** Passed. None did.
4. **Admission verdict for anything promoted to instructions.** Not applicable. Nothing was added to CLAUDE.md or other instructions.
5. **Historical records untouched.** Passed. No spec, plan or ledger was touched.
6. **Comments state a why, a contract or a warning.** Passed. The diff adds no comments.
7. **Added lines follow `docs/PROGRAM-DESIGN.md`. Two rules FAILED, fixed.**
   - **Modules, boundary rule:** `from feedwatch.store.queries import latest_failures` in `cli.py` reached past store's `__init__.py`. I removed the import and added `latest_failures` to store's public surface (the import and `__all__` in `feedwatch/store/__init__.py`). `cli` now calls `store.latest_failures`. That adds a name to a public surface. The rule's check wants such names listed in the plan, and this work has none, so this report is where it is named.
   - **Modules, admission rule:** `_feeds(conn)` in `cli.py` only passed the call on to `store.feeds(conn)`. I deleted it and `cli` now calls `store.feeds` directly.
   - **Errors rule:** passed. The only `except FetchError` is in `cli.py`, and nothing signals failure by returning `None` or a flag.
   - **Types rule:** passed. No domain types were added.
   - `from feedwatch.fetch import FetchError` goes through fetch's public surface, so it is allowed.

**Other notes:**
- `docs/ROADMAP.md` is listed in `.dopamine/config` but doesn't exist. I'm reporting it as absent and didn't create it.
- `from feedwatch.store.schema import database_path` in `cli.py` also reaches past store's surface. It was there before this work, so the gate doesn't cover it and I didn't change it.

**Files changed (uncommitted), under `<repo>/`:**
- `feedwatch/cli.py`
- `feedwatch/store/__init__.py`
- `docs/ARCHITECTURE.md`

I wrote no other files. I deleted the temporary database directory I used for the smoke test.

#### docs/ARCHITECTURE.md (changed)

````diff
diff --git a/docs/ARCHITECTURE.md b/docs/ARCHITECTURE.md
index edc9a63..471918f 100644
--- a/docs/ARCHITECTURE.md
+++ b/docs/ARCHITECTURE.md
@@ -15,9 +15,9 @@
 | Component | Offers its callers | Must hold |
 |---|---|---|
 | fetch | fetch entries: a feed's address → its entries, or a fetch error; parse a feed: feed XML → its entries | — |
-| store | subscribe to a feed; the feeds; save entries → how many were new; record how a feed's poll went; which feeds are failing; unread entries, newest first; mark entries read | — |
+| store | subscribe to a feed; the feeds; save entries → how many were new; record how a feed's poll went; which feeds are failing, and why; unread entries, newest first; mark entries read | — |
 | notify | send: entries, a channel and a format → one message on that channel; the channels and formats there are | a channel and its format never disagree |
-| cli | the user's commands: `add`, `poll`, `where` | — |
+| cli | the user's commands: `add`, `poll`, `where`, `check`, `failing` | — |
 
 `cli` calls `fetch`, `store` and `notify`; none of those three calls another. Dependencies point from `cli` down.
````

#### feedwatch/cli.py (changed)

````diff
diff --git a/feedwatch/cli.py b/feedwatch/cli.py
index edb642e..600d087 100644
--- a/feedwatch/cli.py
+++ b/feedwatch/cli.py
@@ -4,6 +4,7 @@ import argparse
 import sys
 
 from feedwatch import fetch, notify, store
+from feedwatch.fetch import FetchError
 from feedwatch.store.schema import database_path
 
 
@@ -15,15 +16,30 @@ def main(argv: list[str] | None = None) -> int:
     poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
     poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
     commands.add_parser("where", help="print where the database is")
+    check = commands.add_parser("check", help="fetch one feed once, without saving it")
+    check.add_argument("url")
+    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
     args = parser.parse_args(argv)
 
     if args.command == "where":
         print(database_path())
         return 0
+    if args.command == "check":
+        try:
+            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
+        except FetchError as exc:
+            print(exc, file=sys.stderr)
+            return 1
+        return 0
     conn = store.connect()
     if args.command == "add":
         store.add_feed(conn, args.url, args.url)
         return 0
+    if args.command == "failing":
+        titles = {feed.id: feed.title for feed in store.feeds(conn)}
+        for feed_id, message in store.latest_failures(conn).items():
+            print(f"{titles[feed_id]}: {message}")
+        return 0
     for feed in store.feeds(conn):
         try:
             entries = fetch.fetch_entries(feed.url, feed.id)
````

#### feedwatch/store/__init__.py (changed)

````diff
diff --git a/feedwatch/store/__init__.py b/feedwatch/store/__init__.py
index 3d166ed..0f5076d 100644
--- a/feedwatch/store/__init__.py
+++ b/feedwatch/store/__init__.py
@@ -3,10 +3,11 @@
 import sqlite3
 
 from feedwatch.store import queries
-from feedwatch.store.queries import add_feed, feeds, mark_read, record_poll, save_entries, unread
+from feedwatch.store.queries import (add_feed, feeds, latest_failures, mark_read, record_poll,
+                                     save_entries, unread)
 from feedwatch.store.schema import connect
 
-__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "mark_read",
+__all__ = ["add_feed", "connect", "failing_feed_ids", "feeds", "latest_failures", "mark_read",
            "record_poll", "save_entries", "unread"]
````



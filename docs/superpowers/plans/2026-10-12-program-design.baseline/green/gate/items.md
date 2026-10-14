## p001

#### Final message

I ran the dopamine:finishing-work exit gate over `git diff baseline-base...HEAD` in <repo>. Only check 7 found a problem, and I fixed it in place. The diff was commit 4a01e81, "feat: keyword filter matching". It added feedwatch/errors.py and feedwatch/filters.py, added `Filter` to feedwatch/models.py, and added tests/test_filters.py. It did not touch any docs.

1. **Right tier:** pass. The diff changes no living document and no instructions file, so nothing was placed in a tier.
2. **Changed what changed:** pass. No document text was appended or replaced. One thing to note, though it isn't a gate failure: docs/ARCHITECTURE.md doesn't mention `filters`. Without a ledger, nothing was drained to add it.
3. **No number describing a run in a living document:** pass, since no living document was edited.
4. **Promotions to the instructions tier carry an admission verdict:** pass, since nothing was promoted.
5. **Historical records untouched:** pass. The diff touches nothing under docs/superpowers.
6. **Comments state a why, a contract or a warning:** pass. Every added comment is a module or function docstring stating a contract, such as "Only poller and cli catch them" and the matching semantics of `keep`. None narrates the change.
7. **Added lines follow docs/PROGRAM-DESIGN.md:** one violation, now fixed.
   - **Errors rule (failed):** `parse_keywords` returned `None` when the list held no keywords, which signals failure with `None`. Meanwhile `InvalidFilter`, which is meant for exactly this case, was defined but never raised. In feedwatch/filters.py it now has return type `tuple[str, ...]`, raises `InvalidFilter(f"no keywords in {text!r}")`, and its docstring says so. I added `test_a_list_without_keywords_is_an_invalid_filter` to tests/test_filters.py. All 9 tests pass (`python3 -m unittest tests.test_filters tests.test_feedwatch`), and the fix is committed as ac3a362.
   - **Every other rule passes:**
     - Types: `Filter` is `@dataclass(frozen=True)` in models.py.
     - Effects: there are no sqlite, conn or urllib calls.
     - Signatures: no added def has more than two parameters, and every def is fully annotated.
     - Layout: filters imports only models and errors; errors imports nothing from the package.
     - Modules: filters is not an ARCHITECTURE component, has two public functions, and contains no pass-through.
     - Concurrency and Persistence: the diff has no threads and no schema changes.
   - **Within the Modules rule's check but outside its wording:** `keep` and `parse_keywords` are called only by tests so far. The rule's check counts public functions, not callers, so they pass.

#### feedwatch/errors.py (added)

````
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
````

#### feedwatch/filters.py (added)

````
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.errors import InvalidFilter
from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...]:
    """The keywords in a comma-separated list, lower-cased. Raises InvalidFilter
    if the list holds none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        raise InvalidFilter(f"no keywords in {text!r}")
    return keywords
````

#### feedwatch/models.py (changed)

````diff
diff --git a/feedwatch/models.py b/feedwatch/models.py
index 0a71b8a..fa75ab8 100644
--- a/feedwatch/models.py
+++ b/feedwatch/models.py
@@ -2,6 +2,7 @@
 
 from dataclasses import dataclass
 from datetime import datetime
+from typing import Literal
 
 
 @dataclass
@@ -20,3 +21,10 @@ class Entry:
     link: str
     published: datetime | None
     read: bool = False
+
+
+@dataclass(frozen=True)
+class Filter:
+    feed_id: int
+    kind: Literal["include", "exclude"]
+    keywords: tuple[str, ...]
````

#### tests/test_filters.py (added)

````
import unittest

from feedwatch.errors import InvalidFilter
from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))

    def test_a_list_without_keywords_is_an_invalid_filter(self) -> None:
        with self.assertRaises(InvalidFilter):
            parse_keywords(" , ")


if __name__ == "__main__":
    unittest.main()
````


## p002

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD`. That diff is commit 4a01e81, "feat: keyword filter matching", which adds `feedwatch/errors.py` and `feedwatch/filters.py`, adds a `Filter` class to `feedwatch/models.py`, and adds `tests/test_filters.py`. Six checks pass. Check 7 found one rule violation, which I fixed and committed as 6c69dd3. Tests pass: 9 run, OK.

1. **Right tier:** Pass. The diff changes no living document or `CLAUDE.md`, so nothing is in the wrong tier.
2. **Changed what changed:** Pass. No document text was appended where it should have been replaced. Nothing in the diff calls `filters` yet, so `ARCHITECTURE.md` still matches what the code does.
3. **No number describing a run in a living document:** Pass. No living document was touched.
4. **Every promotion to the instructions tier carries an admission verdict:** Pass. There were no promotions.
5. **Historical records untouched:** Pass. No spec, plan or ledger is in the diff.
6. **Comments state a why, a contract or a warning:** Pass. Every added docstring states a public contract (what `keep` and `parse_keywords` do, the error class hierarchy) or a warning ("Only poller and cli catch them."). None tells the story of the change.
7. **Added lines follow `PROGRAM-DESIGN.md`:** One violation, fixed. Each rule judged by its own check:
   - **Errors: violated, now fixed.** `parse_keywords` returned `None` when the text held no keywords, which is signalling failure with `None`. `InvalidFilter` ("A filter that cannot be applied, such as one with no keywords") existed for exactly this case but nothing raised it. It now raises `InvalidFilter(f"no keywords in {text!r}")`, its return type is `tuple[str, ...]`, and its docstring was rewritten to match. I added `test_a_list_without_keywords_is_an_invalid_filter`. `keep`'s `False` is a predicate's answer, not a failure. No `except` was added.
   - **Types: pass.** `Filter` is a `@dataclass(frozen=True)` in `models.py`. No dict or tuple stands in for a domain value.
   - **Signatures: pass.** No added `def` has more than two parameters, and every added `def`, test methods included, is fully annotated.
   - **Layout: pass.** `filters` imports only `models` and `errors`, `errors` imports nothing, and nothing imports `cli` or `poller`.
   - **Modules: pass.** `filters` is not an `ARCHITECTURE.md` component. It has exactly two public functions and no pass-through function.
   - **Effects, Concurrency, Persistence: pass.** No `sqlite3`, `conn`, `urllib`, threading or schema changes were added.

Changed files: `<repo>/feedwatch/filters.py` and `<repo>/tests/test_filters.py`.

#### feedwatch/errors.py (added)

````
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
````

#### feedwatch/filters.py (added)

````
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.errors import InvalidFilter
from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...]:
    """The keywords in a comma-separated list, lower-cased. Raises InvalidFilter
    if there are none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        raise InvalidFilter(f"no keywords in {text!r}")
    return keywords
````

#### feedwatch/models.py (changed)

````diff
diff --git a/feedwatch/models.py b/feedwatch/models.py
index 0a71b8a..fa75ab8 100644
--- a/feedwatch/models.py
+++ b/feedwatch/models.py
@@ -2,6 +2,7 @@
 
 from dataclasses import dataclass
 from datetime import datetime
+from typing import Literal
 
 
 @dataclass
@@ -20,3 +21,10 @@ class Entry:
     link: str
     published: datetime | None
     read: bool = False
+
+
+@dataclass(frozen=True)
+class Filter:
+    feed_id: int
+    kind: Literal["include", "exclude"]
+    keywords: tuple[str, ...]
````

#### tests/test_filters.py (added)

````
import unittest

from feedwatch.errors import InvalidFilter
from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))

    def test_a_list_without_keywords_is_an_invalid_filter(self) -> None:
        with self.assertRaises(InvalidFilter):
            parse_keywords(" , ")


if __name__ == "__main__":
    unittest.main()
````


## p003

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD` in <repo>. That diff is commit 4b821df ("feat: keyword filter matching"), which touches feedwatch/errors.py, feedwatch/filters.py, feedwatch/models.py and tests/test_filters.py. One check failed: `parse_keywords` broke the Errors rule. I fixed it in a new commit, 0ac1463, and the tests pass.

1. **Right tier:** Pass. The diff changes no living document and no instructions file.
2. **Changed what changed:** Pass. No document text was appended or replaced.
3. **No number describing a run in a living document:** Pass. No living document changed.
4. **Every promotion to the instructions tier carries an admission verdict:** Pass. Nothing was promoted.
5. **Historical records untouched:** Pass. No spec, plan or ledger under docs/superpowers was modified.
6. **Comments state a why, a contract or a warning:** Pass. Each added docstring states a contract: the errors.py module docstring says only poller and cli catch these errors, the class docstrings say what each class means, and `keep` describes its matching semantics. The `parse_keywords` docstring was rewritten during the fix and still states a contract.
7. **Added lines follow docs/PROGRAM-DESIGN.md:** One failure, now fixed. The rules one by one:
   - **Types:** Pass. `Filter` is a `@dataclass(frozen=True)` in models.py, and no added function passes a dict or tuple in place of a domain value. `keywords` is a tuple field inside the dataclass, which the rule allows.
   - **Errors:** Failed. `parse_keywords(text) -> tuple[str, ...] | None` returned `None` when the list held no keywords. That is a function returning `None` to say it couldn't do its job. `InvalidFilter` was added for exactly this case ("such as one with no keywords") but nothing raised it.
     - Fix: `parse_keywords` now raises `InvalidFilter(f"no keywords in {text!r}")`. The return type is now `tuple[str, ...]` and the docstring is updated.
     - Added the test `test_a_list_with_no_keywords_is_an_invalid_filter`.
     - Tests: `PYTHONPATH=. python3 -m unittest tests/test_filters.py` ran 5 tests, all OK. The full discover run passed 9 tests.
     - `keep`'s `False` is a predicate's answer, so it is allowed.
   - **Effects:** Pass. Nothing added touches sqlite3, `conn` or urllib.
   - **Signatures:** Pass. Every added `def` has two or fewer parameters and full annotations.
   - **Layout:** Pass. filters imports only models and errors, errors.py imports nothing, and nothing imports cli or poller.
   - **Modules:** Pass. filters is not a component listed in ARCHITECTURE.md. It has exactly two public functions (`keep`, `parse_keywords`), which is the most the rule allows, and neither just forwards its parameters to another function. Nothing outside the tests calls either function yet. That is allowed for a module's own interface, but whoever wires filters into poller or cli should keep it at two public functions.
   - **Concurrency:** Pass. No threading, asyncio or multiprocessing was added.
   - **Persistence:** Pass. No schema statements were added.

As instructed, I did not seal a ledger, drain anything or make a `sweep:` commit.

#### feedwatch/errors.py (added)

````
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
````

#### feedwatch/filters.py (added)

````
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.errors import InvalidFilter
from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...]:
    """The keywords in a comma-separated list, lower-cased. Raises InvalidFilter
    if the list holds none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        raise InvalidFilter(f"no keywords in {text!r}")
    return keywords
````

#### feedwatch/models.py (changed)

````diff
diff --git a/feedwatch/models.py b/feedwatch/models.py
index 0a71b8a..fa75ab8 100644
--- a/feedwatch/models.py
+++ b/feedwatch/models.py
@@ -2,6 +2,7 @@
 
 from dataclasses import dataclass
 from datetime import datetime
+from typing import Literal
 
 
 @dataclass
@@ -20,3 +21,10 @@ class Entry:
     link: str
     published: datetime | None
     read: bool = False
+
+
+@dataclass(frozen=True)
+class Filter:
+    feed_id: int
+    kind: Literal["include", "exclude"]
+    keywords: tuple[str, ...]
````

#### tests/test_filters.py (added)

````
import unittest

from feedwatch.errors import InvalidFilter
from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))

    def test_a_list_with_no_keywords_is_an_invalid_filter(self) -> None:
        with self.assertRaises(InvalidFilter):
            parse_keywords(" , ")


if __name__ == "__main__":
    unittest.main()
````


## p004

#### Final message

I ran the finishing-work exit gate over `git diff baseline-base...HEAD`, which started as the single commit 81dbb08 "feat: keyword filter matching". It touches `feedwatch/errors.py`, `feedwatch/filters.py`, `feedwatch/models.py` and `tests/test_filters.py`. Check 7 found one violation of `PROGRAM-DESIGN.md`. I fixed it in place and committed the fix as b2a69a9. The other checks found nothing.

Repo: <repo>

1. **Right tier:** Pass. The diff does not touch any living document or `CLAUDE.md`.
2. **Changed what changed:** Pass. No document was edited, so nothing was appended where text should have been replaced.
3. **No number describing a run in a living document:** Pass. No living document was touched.
4. **Promotions to the instructions tier carry an admission verdict:** Pass. Nothing was promoted.
5. **Historical records untouched:** Pass. No spec, plan or sealed ledger is in the diff.
6. **Comments state a why, a contract or a warning:** Pass.
   - Each docstring in `errors.py` and `filters.py` states a contract. The module docstring "Only poller and cli catch them" in `errors.py` is a contract and a warning.
   - The fix made the `parse_keywords` docstring false ("or None if there are none"), so I rewrote it in the same edit. It now says the function raises `InvalidFilter` when the list holds no keywords.
7. **Added lines follow `PROGRAM-DESIGN.md`:** One violation, now fixed.
   - **Errors rule (the violation):** `parse_keywords` returned `None` to signal "no keywords". That is the failure-by-`None` the rule forbids, and `InvalidFilter` had been added for exactly this case but was never raised. In `<repo>/feedwatch/filters.py` it now raises `InvalidFilter` and its return type is `tuple[str, ...]`. I added `test_a_list_without_keywords_is_an_invalid_filter` to `<repo>/tests/test_filters.py`, and `test_filters.py` and `test_feedwatch.py` pass (9 tests). `keep` returning `False` is a predicate's answer, not a failure, and there is no added `except`.
   - **Types:** Pass. `Filter` is a `@dataclass(frozen=True)` in `models.py`. No dict or tuple stands in for a domain value.
   - **Signatures:** Pass. No added function has more than two parameters, and every added `def` is fully annotated, test helpers included.
   - **Layout:** Pass. `filters` imports only `models` and `errors`, and `models` and `errors` import nothing from the package.
   - **Modules:** Pass. `filters` is not an `ARCHITECTURE.md` component and has exactly two public functions, `keep` and `parse_keywords`. Neither is a pass-through.
   - **Effects, Concurrency, Persistence:** Pass. Nothing added touches the database, network, threads or schema.

The rule also says a helper is public only once a second module calls it. `parse_keywords` is so far called only by the tests, because the CLI wiring is not in this diff. The rule's check (at most two public functions) passes, so I left it as is.

#### feedwatch/errors.py (added)

````
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
````

#### feedwatch/filters.py (added)

````
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.errors import InvalidFilter
from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...]:
    """The keywords in a comma-separated list, lower-cased.

    Raises InvalidFilter if the list holds no keywords."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        raise InvalidFilter(f"no keywords in {text!r}")
    return keywords
````

#### feedwatch/models.py (changed)

````diff
diff --git a/feedwatch/models.py b/feedwatch/models.py
index 0a71b8a..fa75ab8 100644
--- a/feedwatch/models.py
+++ b/feedwatch/models.py
@@ -2,6 +2,7 @@
 
 from dataclasses import dataclass
 from datetime import datetime
+from typing import Literal
 
 
 @dataclass
@@ -20,3 +21,10 @@ class Entry:
     link: str
     published: datetime | None
     read: bool = False
+
+
+@dataclass(frozen=True)
+class Filter:
+    feed_id: int
+    kind: Literal["include", "exclude"]
+    keywords: tuple[str, ...]
````

#### tests/test_filters.py (added)

````
import unittest

from feedwatch.errors import InvalidFilter
from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))

    def test_a_list_without_keywords_is_an_invalid_filter(self) -> None:
        with self.assertRaises(InvalidFilter):
            parse_keywords(" , ")


if __name__ == "__main__":
    unittest.main()
````


## p005

#### Final message

I ran the exit gate of dopamine:finishing-work over `git diff baseline-base...HEAD` (commit 4a01e81, "feat: keyword filter matching"). Check 7 found one deviation, which I fixed inline and committed as 9ad7fa7. The other six checks pass. All 9 tests pass after the fix.

The diff has 69 added lines in four files: new `feedwatch/errors.py`, new `feedwatch/filters.py`, an added `Filter` dataclass in `feedwatch/models.py`, and new `tests/test_filters.py`. It touches no living document, spec, plan or ledger.

1. **Right tier:** Passes. No documentation was written in the diff, so nothing was placed in a wrong tier.
2. **Changed what changed:** Passes. No document edits, so nothing was appended where existing text should have been replaced.
3. **No number describing a run entered a living document:** Passes. No living document was touched.
4. **Every promotion to the instructions tier carries an admission verdict:** Passes. Nothing was promoted, and no `instructions:` file is declared in `.dopamine/config`.
5. **Historical records untouched:** Passes. Both specs under `docs/superpowers/specs/` are unchanged, and there are no plans or ledgers in the diff.
6. **Comments state a why, a contract or a warning:** Passes.
   - The `errors.py` module docstring ("Only poller and cli catch them") is a contract and warning.
   - The docstrings on the exception classes, `keep` and `parse_keywords` are interface contracts.
   - Nothing narrates the change.
7. **Added lines follow `PROGRAM-DESIGN.md`:** Failed on one rule, now fixed.
   - **Errors (failed, fixed):** `parse_keywords` returned `None` when the text held no keywords. That is exactly the failure signal the rule forbids, and `InvalidFilter` was defined in the same diff but never raised.
     - **Fix:** in `feedwatch/filters.py` it now raises `InvalidFilter(f"no keywords in {text!r}")`, its return type is `tuple[str, ...]` and its docstring is updated.
     - **Test:** `test_a_list_with_no_keywords_is_refused` in `tests/test_filters.py` covers the new behaviour.
     - This matches the spec, which says a filter with no keywords is refused.
     - `keep` returning `False` is a predicate's answer, not a failure, so it complies.
   - **Types:** Pass. `Filter` is `@dataclass(frozen=True)` in `models.py`, and `keywords: tuple[str, ...]` is a list of words, not a tuple standing in for a domain value.
   - **Effects:** Pass. There is no `sqlite3`, `conn` or `urllib` code, and `filters` is pure.
   - **Signatures:** Pass. Every added `def` has at most two parameters and is fully annotated, test helpers and test methods included.
   - **Layout:** Pass. `filters` imports only `models` and `errors`, `errors.py` imports nothing, and nothing imports `cli` or `poller`.
   - **Modules:** Passes by its check. `filters.py` is not an ARCHITECTURE component and has exactly two public functions with no pass-through bodies.
     - **Borderline:** the rule's prose says a helper is public only once a second module calls it. At present only the tests call `parse_keywords` and `keep`, because nothing wires them in yet.
   - **Concurrency:** Pass. No threads, asyncio or multiprocessing were added.
   - **Persistence:** Pass. No schema statements were added.

The specs say filters live in the database and are applied by the poller. This diff adds no schema step, no store, poller or cli wiring, and no ARCHITECTURE entry for `filters`. I'm reporting that as scope, not as a gate failure.

#### feedwatch/errors.py (added)

````
"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""
````

#### feedwatch/filters.py (added)

````
"""Keyword filters: which entries a feed's filters let through."""

import re

from feedwatch.errors import InvalidFilter
from feedwatch.models import Entry, Filter


def keep(filters: list[Filter], entry: Entry) -> bool:
    """Whether the entry passes every filter. An include filter needs one of its
    keywords in the title and an exclude filter none; matching is
    case-insensitive, on whole words."""
    words = set(re.findall(r"\w+", entry.title.lower()))
    for f in filters:
        if words.isdisjoint(f.keywords) == (f.kind == "include"):
            return False
    return True


def parse_keywords(text: str) -> tuple[str, ...]:
    """The keywords in a comma-separated list, lower-cased. Raises InvalidFilter
    if there are none."""
    keywords = tuple(w.strip().lower() for w in text.split(",") if w.strip())
    if not keywords:
        raise InvalidFilter(f"no keywords in {text!r}")
    return keywords
````

#### feedwatch/models.py (changed)

````diff
diff --git a/feedwatch/models.py b/feedwatch/models.py
index 0a71b8a..fa75ab8 100644
--- a/feedwatch/models.py
+++ b/feedwatch/models.py
@@ -2,6 +2,7 @@
 
 from dataclasses import dataclass
 from datetime import datetime
+from typing import Literal
 
 
 @dataclass
@@ -20,3 +21,10 @@ class Entry:
     link: str
     published: datetime | None
     read: bool = False
+
+
+@dataclass(frozen=True)
+class Filter:
+    feed_id: int
+    kind: Literal["include", "exclude"]
+    keywords: tuple[str, ...]
````

#### tests/test_filters.py (added)

````
import unittest

from feedwatch.errors import InvalidFilter
from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))

    def test_a_list_with_no_keywords_is_refused(self) -> None:
        with self.assertRaises(InvalidFilter):
            parse_keywords(" , ")


if __name__ == "__main__":
    unittest.main()
````



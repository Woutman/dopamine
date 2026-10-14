## p001

#### Final message

I stopped before writing the plan: nothing is written or committed yet. The plan needs a concurrency decision, and `docs/PROGRAM-DESIGN.md` doesn't make it.

**Why it stopped:** the spec (`docs/superpowers/specs/2026-03-09-retry-failed-feeds-design.md`) needs background retries so that a slow feed never delays the others. `PROGRAM-DESIGN.md` has no Concurrency section, even though that section's trigger applies (two processes, and this feature needs parallel I/O). The session rules say a structural choice the document leaves open stops the plan: it goes to the human and is recorded through `dopamine:brainstorm-program-design` (revising that one section) before planning continues.

**What the code does now:** `feedwatch/poller.py:30-36` is one synchronous loop with a single shared `conn` and `time.sleep(60)`. `feedwatch/fetch.py:10` blocks in `urlopen(timeout=10)`. A `sqlite3` connection can only be used from the thread that created it.

**Question put to the human** (my final message, waiting on their reply):
- **(A) Recommended:** a `concurrent.futures` thread pool owned by `poller`. Worker threads only call `fetch.fetch` and return bytes. The main thread keeps `conn` and all backoff state, and does every parse and save. On Ctrl-C the pool shuts down with `cancel_futures=True`; a fetch already running finishes within its 10 s timeout.
  - Proposed check: no `threading`, `asyncio` or `concurrent.futures` import outside `poller.py`; no `conn` or mutable container passed to `submit`.
- **(B)** one thread or `Timer` per retry, each with its own connection. This brings SQLite lock contention, a lock around shared state, and harder Ctrl-C cleanup.
- **(C)** asyncio. Every poller function becomes `async`, and fetches still run in threads.

**Next steps once they answer:**
1. Record their choice as a Concurrency section in `docs/PROGRAM-DESIGN.md`, using `dopamine:writing-living-documents`.
2. Write the plan to `docs/superpowers/plans/2026-10-12-retry-failed-feeds.md`, with every applicable `PROGRAM-DESIGN.md` rule copied with its check into Global Constraints (Types, Errors, Effects, Signatures, Layout, Modules, Persistence if retry state is persisted, and the new Concurrency rule). New code must follow those rules even though existing code breaks several of them: `parse` returns dicts or `None`, `FetchError` isn't a `FeedwatchError`, there is no `errors.py`, and the models aren't frozen.
3. Commit the plan, run `dopamine:finishing-work`, and end at the plan's handoff without asking which execution approach to use.

Repo: <repo> (branch master, clean).


## p002

#### Final message

I'm using the writing-plans skill for this plan. I've stopped before writing it, because the spec needs a structural choice that `docs/PROGRAM-DESIGN.md` doesn't cover. Nothing has been written or committed yet.

**The gap: Concurrency.** `PROGRAM-DESIGN.md` has no Concurrency section. It should, because two processes already share one SQLite file, and the spec now asks for retries "in the background" so that "a slow or failing feed never delays polling the others". Right now the poller is one thread: the loop sleeps 60 seconds between passes (`feedwatch/poller.py:34-36`), each feed is fetched one after another with a 10-second timeout (`poller.py:19`, `fetch.py:10`), and a single `sqlite3` connection is opened in the main thread. By default that connection refuses to be used from any other thread.

**The question: how should the poller run work at the same time, and who is allowed to touch the connection?**

- **Superpowers' default:** none for this slot.
- **What the code does now:** nothing runs in parallel. One thread, one connection, blocking `urllib`.
- **My recommendation: a thread pool for network calls only.** The main loop keeps the connection, the schedule and every `store` call. A `concurrent.futures.ThreadPoolExecutor` runs only `fetch.fetch`, and the loop collects finished fetches on each tick. Retry state (attempts, when the next try is due) is a frozen dataclass the loop updates with pure functions. On Ctrl-C the loop calls `executor.shutdown(cancel_futures=True)`. This keeps "only `store` touches the database" and leaves the connection in one thread.
  ```python
  # poller main loop, every few seconds
  for feed in due_retries(retries, now=now):
      if feed.id not in in_flight:
          in_flight[feed.id] = pool.submit(fetch.fetch, feed.url)
  for feed_id, fut in finished(in_flight):
      ...  # parse + store.save_entries on the main thread, or schedule the next retry
  ```
  The rule I'd record: "Only `poller` starts concurrent work; worker threads run `fetch` and pure functions only. The connection and every `store` call stay on the main thread." The check: no added `threading`, `concurrent.futures` or `asyncio` outside `poller.py`, and no `store.` call or `conn` inside a submitted callable.
- **Alternative A: asyncio.** The poller becomes an event loop and fetches run through `asyncio.to_thread`. Cancelling on Ctrl-C is clean. The cost: every poller function becomes `async`, and `urllib` blocks anyway, so the threads are still there underneath.
- **Alternative B: a thread per retry (`threading.Timer`), each with its own connection.** This is the smallest change to `poll_once`. The costs: several writers on one SQLite file, keeping retries for one feed from overlapping needs locks, and shutting everything down on Ctrl-C means tracking every timer.

Which should be the rule: my recommendation, A, B, or something else? Once you answer, I'll record it in `docs/PROGRAM-DESIGN.md` through `dopamine:brainstorm-program-design`, then write and commit the plan.

The plan will also cover where the current code breaks the existing rules, to the extent the new retry code touches it:
- `FetchError` doesn't come from a `feedwatch/errors.py`.
- `parse` returns dicts and `None`.
- `Feed` isn't a frozen dataclass.


## p003

#### Final message

I'm using the writing-plans skill to create the implementation plan. It stopped before the plan was written: the spec needs a structural choice that `docs/PROGRAM-DESIGN.md` doesn't make. Nothing has been written or committed yet.

**The gap is Concurrency.** `PROGRAM-DESIGN.md` has no Concurrency rule, although the schema says it should: `ARCHITECTURE.md` lists two processes under "What runs where". This feature also needs work running alongside the poller's loop. The spec asks for retries "in the background" so that "a slow or failing feed never delays polling the others". It also asks that retries for one feed never overlap and that Ctrl-C stops them cleanly. Through `dopamine:brainstorm-program-design` (revising one slot, classified as architectural), I'm putting this one slot to you before planning.

**Superpowers' default:** none.

**What the code does now:**
- The poller is one thread running `poll_once` and then `time.sleep(60)` (`feedwatch/poller.py:30-36`).
- `fetch` blocks for up to 10 s (`feedwatch/fetch.py:10-13`).
- There is one `sqlite3` connection, opened in `main` with the default `check_same_thread=True`, so it can't be used from another thread (`feedwatch/store.py:34`, `poller.py:32`).

**My recommendation (A): worker threads only fetch and parse, and the main thread alone touches the database.**
`poller` owns a `ThreadPoolExecutor`. A retry is submitted as a job that only waits out its backoff, fetches and parses, and its result comes back to the main loop through a `queue.Queue`. The main loop saves the entries and resets the backoff. The loop waits on that queue with a timeout in place of `time.sleep(60)`, so a retry's entries are saved as soon as they arrive. Ctrl-C calls `executor.shutdown(cancel_futures=True)` and sets a stop `Event` that sleeping retries are waiting on.

```python
done: queue.Queue[RetryOutcome] = queue.Queue()
pool.submit(_retry, feed, attempt=n, stop=stop, done=done)  # thread: fetch + parse only
outcome = done.get(timeout=60)                               # main thread: store.save_entries(conn, ...)
```

Proposed rule: *threads are started only in `poller`; a `conn` never crosses threads, and results come back as values on a queue.* Check: no added `threading`, `concurrent.futures` or `asyncio` import outside `poller.py`; no `conn` passed to a function submitted to a thread.

**Alternative B: each retry thread opens its own connection with `store.connect()` and saves its own entries.** The handoff is simpler. The cost is a second writer inside the poller process, which raises the chance of `database is locked` errors next to the CLI's writes. The rule would also have to allow connections per thread.

**Alternative C: rewrite the poller on `asyncio`, with `asyncio.to_thread(fetch.fetch, ...)` and retries as tasks.** Ctrl-C cancellation comes built in. The cost is that all of `poller` becomes async, which is a bigger change than this feature needs, and `sqlite3` still has to stay on the loop's thread.

Should I go with A, or B or C? Once you answer, I'll record it as the Concurrency rule in `docs/PROGRAM-DESIGN.md` and finish the plan. The plan will be saved at `docs/superpowers/plans/2026-10-12-retry-failed-feeds.md` and committed.

Relevant files:
- `<repo>/docs/superpowers/specs/2026-03-09-retry-failed-feeds-design.md`
- `<repo>/docs/PROGRAM-DESIGN.md`
- `<repo>/feedwatch/poller.py`
- `<repo>/feedwatch/store.py`


## p004

#### Final message

I'm using the writing-plans skill for this plan, and I've stopped before writing anything. The retry spec needs a structural choice that `docs/PROGRAM-DESIGN.md` doesn't make, so I need you to decide it first. Nothing is written or committed yet.

**The gap: how the program runs work concurrently.** The spec requires that "a slow or failing feed never delays polling the others". Right now the poller handles feeds one at a time in a single loop, so any concurrency is new. `PROGRAM-DESIGN.md` has rules for types, errors, effects, signatures, layout, modules and persistence, but none for concurrency. That slot is triggered here because the architecture runs two processes and this feature needs parallel I/O. I'll record your answer as a Concurrency rule through `dopamine:brainstorm-program-design`, and then write the plan.

**What the code does now:**
- `feedwatch/poller.py:34-36` runs one loop on one thread: `poll_once(...)`, then `time.sleep(60)`.
- `feedwatch/poller.py:32` opens one sqlite connection. Python's `sqlite3` refuses to use a connection from any thread except the one that created it.
- `feedwatch/fetch.py:10-15` uses blocking `urllib` with a 10-second timeout.
- Superpowers has no default for this slot.

**My recommendation (A): a thread pool for fetching only; the database stays on the poller's main thread.** The poller sends `fetch.fetch` to a `concurrent.futures.ThreadPoolExecutor` and keeps at most one in-flight future per feed, which means retries for a feed can never overlap. On each tick, the main thread collects the finished futures, parses the results and saves them through `store`. When a fetch fails, the poller records the next retry time in memory. Ctrl-C calls `executor.shutdown(cancel_futures=True)`, which clears pending retries.
```python
pending: dict[int, Future[bytes]] = {}
if feed.id not in pending and due(feed, now):
    pending[feed.id] = executor.submit(fetch.fetch, feed.url)
for feed_id, future in _finished(pending):
    ...  # parse + store.save_entries on the main thread
```
The proposed rule: background threads only do network I/O and pure functions, and only the poller's main thread touches `conn`. The check: no added `executor.submit` or `Thread` whose target touches `store` or `conn`.
- Pro: the smallest change. `fetch`, `parse` and `store` stay synchronous, and the database rules stay as they are.
- Con: the main loop has to tick often enough to collect results, so the 60-second sleep gets shorter, for example 1 second.

**Alternative B: asyncio.** The poller becomes `async`, and `asyncio.to_thread(fetch.fetch, ...)` or an async fetch does the network calls. Retries become `asyncio.sleep` tasks, and Ctrl-C cancels them.
- Pro: retry timing is precise, and cancelling is idiomatic.
- Con: the poller has to be rewritten as `async`, and the code ends up split into async and sync functions. Because `urllib` is blocking, it runs on threads underneath anyway.

**Alternative C: one thread per retry, each with its own connection.** Each retry thread fetches, parses and saves with its own `store.connect()`.
- Pro: it's the simplest to write.
- Con: several threads write to SQLite at the same time, so you get lock contention and `database is locked` errors. Stopping threads cleanly on Ctrl-C also takes more work.

**Which do you want: A, B or C, or a different rule?** I'll record it, then write the plan to `docs/superpowers/plans/` and commit it.

Something smaller you may want to correct: five retries at 1, 2, 4, 8 and 16 minutes never reach the 30-minute cap. I'll implement the cap anyway and plan the schedule as 1, 2, 4, 8, 16 unless you say otherwise.


## p005

#### Final message

The plan is on hold until you decide one structural question. Nothing has been written or committed yet.

**Why it stops here.** The spec asks for retries to run in the background so a failing feed never holds up the other feeds. That means bringing concurrency into the poller, and `docs/PROGRAM-DESIGN.md` has no rule on concurrency. The schema says this slot should be asked, because the design now needs parallel I/O and two processes already share the database. So I need you to choose the rule before I write the plan. I'll record your answer in `PROGRAM-DESIGN.md` using `dopamine:brainstorm-program-design`, then write the plan.

**Concurrency: where does background work run, and what can it touch?**

- **Superpowers' default:** none.
- **What the code does now:** everything runs in one thread. The poller loops and sleeps for 60 seconds between passes (`feedwatch/poller.py:34-36`). Fetches block, with a 10-second timeout (`feedwatch/fetch.py:10`). There is one SQLite connection, opened in `main` (`poller.py:32`). By default a `sqlite3` connection can't be used from another thread.

**My recommendation (A): `poller` owns a thread pool. Workers only fetch and parse. Only the main thread touches `conn`.**
```python
# poller.py
pool = ThreadPoolExecutor(max_workers=4)
future = pool.submit(fetch.fetch, feed.url)   # no conn reaches a worker
...
if future.done():   # main loop collects; store.save_entries(conn, ...) stays on the main thread
```
On Ctrl-C the pool is shut down with `pool.shutdown(cancel_futures=True)`. A fetch that's already running finishes within its 10-second timeout.
- Rule: concurrency lives only in `poller`. Background work runs on an executor that `poller` owns. Worker threads call only `fetch` and pure functions. Only the main thread touches `conn`.
- Check: no new `threading`, `concurrent.futures` or `asyncio` import outside `poller.py`, and no function handed to the executor takes a `conn`.
- Trade-off: the main loop has to collect finished futures, which is a little more bookkeeping. In return the database stays single-threaded, so there are no locks.

**Alternative B: each retry runs on its own `threading.Timer` and opens its own connection with `store.connect()`.** The code is simpler. The cost is several writers on one SQLite file inside the poller process, on top of the CLI. That means dealing with busy and locked errors, and cancelling every timer cleanly on Ctrl-C.

**Alternative C: asyncio.** I advise against it. `urllib` blocks, so every fetch would go through `to_thread` anyway, and the whole poller would have to be rewritten.

**Assumptions I'll build in unless you say otherwise (no need to reply to these separately):**
1. Only fetch failures (`FetchError`) are retried. A response that isn't an RSS feed keeps today's behaviour: it is logged and skipped until the next interval.
2. Retry delays are 1, 2, 4, 8 and 16 minutes, capped at 30. Five failed retries means five attempts after the first failure; after that the feed waits for its next regular interval.
3. Retry state is kept in memory only, so there's no schema change. A poller restart forgets any pending retries.

Which do you want for Concurrency: A, B, or C (or a variant)?



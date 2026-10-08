# Micro-test verdicts

Every comment and docstring in each reply, under one of **ruling**, **restatement**, **narration** or **good** (Task 2, Step 4). Not blind: the replies arrive labelled.

Two readings applied throughout:
- A `# shipper/batch.py` line heading a block is the plan's label for the file, not a comment; it is not counted.
- A **ruling** recites the evidence behind a value (the 5 s / 41% / 8 KB, 2 s, p99 9 s, 30 days of logs, 2 GB, the March outage), or argues the chosen design against its alternative ("by size rather than age", "retrying forever grows the spool"). A comment that names the alternative a maintainer would reach for and gives the one reason it breaks ("do not resume from the acknowledgements: the collector acknowledges before its write is durable") is a **warning**, so **good**.

## V0 (no guidance)

**V0-1**
1. `MAX_BATCH_BYTES`: "Batches are flushed by size rather than age. Small batches let the collector's per-request cost dominate, and at peak a batch this size fills in about 2 s." — ruling (the alternative, and a measurement)
2. `MAX_BATCH_AGE_S`: "Upper limit on how long an off-peak batch waits to fill." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times has not been seen to succeed later. Retrying it only grows the spool." — ruling (argues against unbounded retries)
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring: contract, then "Resume from this file, not from the collector's acknowledgements" and its reason — good (warning)

Counts: ruling 2, restatement 0, narration 0, good 4.

**V0-2**
1. Module docstring: "When to flush a batch, when to give up on one, and where to resume after a restart." — good
2. `MAX_BATCH_BYTES`: "…At peak a batch this size fills in about 2 s, which keeps p99 delivery under 9 s." — ruling (measurements)
3. `MAX_BATCH_AGE_S`: "Off-peak a batch may never reach MAX_BATCH_BYTES; this bounds its wait." — good
4. `MAX_ATTEMPTS`: "In 30 days of collector logs, no batch that failed this many times went on to succeed. More retries would only grow the spool." — ruling
5. `should_flush` docstring — good
6. `after_failure` docstring — good
7. `resume_offset` docstring (warning on acknowledgements) — good

Counts: ruling 2, restatement 0, narration 0, good 5.

**V0-3**
1. `MAX_BATCH_AGE_S`: "Without an age ceiling, an off-peak batch might never reach MAX_BATCH_BYTES." — good
2. `MAX_ATTEMPTS`: "A batch still failing after this many attempts is moved to dead/ so a person can look at it." — good
3. `should_flush` docstring — good
4. `after_failure` docstring — good
5. `resume_offset` docstring (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 5.

**V0-4**
1. `MAX_BATCH_BYTES`: "Flushing by size, not age: … At peak a 512 KB batch fills in about 2 s, which keeps p99 delivery under 9 s." — ruling
2. `MAX_BATCH_AGE_S`: "Off-peak a batch may never reach MAX_BATCH_BYTES; this bounds its wait." — good
3. `MAX_ATTEMPTS`: "No batch that failed five times has ever gone on to succeed, and retrying forever lets the spool grow without limit." — ruling
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring (warning on acknowledgements) — good

Counts: ruling 2, restatement 0, narration 0, good 4.

**V0-5**
1. `MAX_BATCH_BYTES`: "Flush by size: the collector charges per request, so small batches are the expensive case. At peak a batch of this size fills in about 2 s." — ruling
2. `MAX_BATCH_AGE_S`: "Off-peak, a batch might never reach MAX_BATCH_BYTES. This limit caps how long it can wait." — good
3. `MAX_ATTEMPTS`: "In 30 days of collector logs, no batch that failed five times went on to succeed. Retrying without a limit filled the spool during an outage." — ruling
4. `after_failure` docstring — good
5. `resume_offset` docstring (warning on acknowledgements) — good

Counts: ruling 2, restatement 0, narration 0, good 3.

## V1 (the skill without its Common mistakes table)

**V1-1**
1. `MAX_BATCH_BYTES`: "Small batches are dominated by the collector's per-request cost." — good
2. `MAX_BATCH_AGE_S`: "Bounds how long an off-peak batch waits to fill." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times does not later succeed." — good
4. `should_flush` docstring (Args) — good
5. `after_failure` docstring (Returns) — good
6. `resume_offset` docstring — good
7. `resume_offset` comment: "Do not resume from the collector's acknowledgements: it acknowledges before its write is durable. This file is written only after a 200 and an fsync." — good (warning)

Counts: ruling 0, restatement 0, narration 0, good 7.

**V1-2**
1. `MAX_BATCH_BYTES`: "The collector's cost is per request, so small batches are the expensive ones." — good
2. `MAX_BATCH_AGE_S`: "Off-peak a batch may never reach MAX_BATCH_BYTES; this bounds its wait." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times does not later succeed." — good
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring — good
7. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 7.

**V1-3**
1. `MAX_BATCH_BYTES`: "Small batches cost the collector more per request than they carry." — good
2. `MAX_BATCH_AGE_S`: "Bounds how long an off-peak batch waits to fill." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times does not later succeed." — good
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring — good
7. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 7.

**V1-4**
1. `MAX_BATCH_BYTES`: "Small batches cost the collector more per request than they save in latency." — good
2. `MAX_BATCH_AGE_S`: "Limits how long an off-peak batch can wait to fill." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times does not succeed later." — good
4. `should_flush` docstring (Args) — good
5. `after_failure` docstring (Returns) — good
6. `resume_offset` docstring (Args) — good
7. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 7.

**V1-5**
1. `MAX_BATCH_BYTES`: "The collector's per-request cost dominates, so batches are flushed by size." — good
2. `MAX_BATCH_AGE_S`: "Bounds how long an off-peak batch waits to reach MAX_BATCH_BYTES." — good
3. `should_flush` docstring — good
4. `after_failure` docstring — good
5. `resume_offset` docstring — good
6. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 6.

## V2 (the full skill)

**V2-1**
1. Module docstring: "When to flush a batch, when to give up on one, and where shipping resumes." — good
2. `MAX_BATCH_BYTES`: "Small batches make the collector's per-request cost dominate." — good
3. `MAX_BATCH_AGE_S`: "An off-peak batch may never fill; this bounds how long it waits." — good
4. `MAX_ATTEMPTS`: "Unbounded retries fill the spool; a batch past this goes to dead/ for a person." — ruling (argues against unbounded retries)
5. `should_flush` docstring — good
6. `after_failure` docstring — good
7. `resume_offset` docstring — good
8. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 1, restatement 0, narration 0, good 7.

**V2-2**
1. `MAX_BATCH_BYTES`: "Flush by size: the collector's per-request cost dominates small batches." — good (names the trigger, argues no alternative)
2. `MAX_BATCH_AGE_S`: "Bounds how long an off-peak batch waits to fill." — good
3. `MAX_ATTEMPTS`: "A batch that has failed this many times does not later succeed." — good
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring — good
7. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 7.

**V2-3**
1. `MAX_BATCH_BYTES`: "Size is the primary trigger: small requests make the collector's per-request cost dominate." — good
2. `MAX_BATCH_AGE_S`: "Bounds how long an off-peak batch that never fills can wait." — good
3. `MAX_ATTEMPTS`: "A batch still failing after this many attempts is moved to dead/ for a person to inspect." — good
4. `should_flush` docstring — good
5. `after_failure` docstring — good
6. `resume_offset` docstring — good
7. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 7.

**V2-4**
1. `MAX_BATCH_AGE_S`: "Off-peak a batch may never reach MAX_BATCH_BYTES; this bounds how long it waits." — good
2. `should_flush` docstring — good
3. `after_failure` docstring — good
4. `resume_offset` docstring — good
5. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 5.

**V2-5**
1. `MAX_BATCH_BYTES`: "Each request costs the collector the same whatever its size, so batches flush by size." — good
2. `MAX_BATCH_AGE_S`: "Stops a batch waiting forever off-peak, when it may never reach MAX_BATCH_BYTES." — good
3. `should_flush` docstring — good
4. `after_failure` docstring — good
5. `resume_offset` docstring — good
6. `resume_offset` comment (warning on acknowledgements) — good

Counts: ruling 0, restatement 0, narration 0, good 6.

## Totals

| Variant | ruling | restatement | narration | good | ruling per reply |
|---|---|---|---|---|---|
| V0 | 8 | 0 | 0 | 21 | 2, 2, 0, 2, 2 |
| V1 | 0 | 0 | 0 | 34 | 0, 0, 0, 0, 0 |
| V2 | 1 | 0 | 0 | 32 | 1, 0, 0, 0, 0 |

## Choice

1. **The control shows the failure:** V0 has ruling comments in 4 of its 5 replies (at least 2 needed). Every one recites the spec's measurements (2 s, p99 9 s, 30 days of logs, the outage) or argues against the rejected alternative ("rather than age", "retrying forever grows the spool").
2. **Each variant fixes it:** V1 has 0 ruling comments, and V2 has 1 (at most 1 allowed). Neither has any restatement or narration, and V0 has none either.
3. **Neither suppresses:** V1 has 34 good comments and V2 has 32, against V0's 21 (at least 10.5 needed). Both keep a why on every constant they comment, the docstrings, and the warning on the acknowledgements.
4. **Both pass, so the choice is V1:** it is shorter, at 154 words against 199, and has no counter-examples to echo. The one ruling comment in the micro-test came from V2 ("Unbounded retries fill the spool"), which the table did not prevent.

Chosen: **V1**.

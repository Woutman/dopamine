# Retry failed feeds — design

> **Status.** Approved 2026-03-09.

## What

A feed whose fetch fails is retried in the background with exponential backoff — after 1, 2, 4 and 8 minutes, capped at 30 — so that a slow or failing feed never delays polling the others.

## Behaviour

- A failed fetch schedules a retry, and the poller's regular loop carries on, on schedule.
- Retries for one feed never overlap.
- A successful retry saves its entries exactly as a regular poll would, and resets that feed's backoff.
- After five failed retries the feed waits for its next regular interval.
- Stopping the poller with Ctrl-C stops pending retries cleanly.

## Out of scope

Notifying the user of a failing feed.

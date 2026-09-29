# Exporter — design

## 1. Purpose

The exporter copies records from the source system into the record store once a night. A record is
a JSON object with at least an `id` and a `status`.

## 2. Source and store

### 2.1 Source

The source returns records in `id` order, a page at a time, after a given id. An empty id starts
from the beginning.

### 2.2 Store

The store writes one record per request with `put`, or up to 25 records per request with
`put_many`. A larger batch is refused and nothing in it is written.

The exporter writes with `put_many`, in batches of at most 25. The job's page-size constant is
`SOURCE_PAGE_SIZE`, so it cannot be confused with the store's batch limit.

## 3. The export job

### 3.1 Request budget

A run makes at most `MAX_REQUESTS` (500) store requests. It checks the budget before every request,
and stops rather than exceed it, recording that it stopped.

### 3.2 Cursor

A run returns a cursor: the id of the last record it has dealt with, whether written or skipped. The
next run starts after it, so a run that stops at the budget loses nothing and repeats nothing.

### 3.3 Drafts

A record whose status is `draft` is counted as skipped and not written.

## 4. The run report

`python3 -m exporter.report RECORDS_JSON [CURSOR]` runs one export over the records in the JSON
file, starting after `CURSOR` if one is given, and prints one line:

    exported=N skipped=N requests=N stopped_by_budget=yes|no cursor=ID

It exits 0 when the run completed or stopped at the budget, since both are normal outcomes, and 2 on a
usage error.

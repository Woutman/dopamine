# Keyword filters — design

> **Status.** Approved 2026-03-02.

## What

A user can attach keyword filters to a feed. An include filter keeps only entries whose title contains at least one of its keywords; an exclude filter drops entries whose title contains any of its keywords. Matching is case-insensitive, on whole words.

## Behaviour

- `feedwatch filter add FEED_URL --include WORD [WORD ...]` or `--exclude WORD [WORD ...]` adds a filter; `feedwatch filter list FEED_URL` lists a feed's filters with their ids; `feedwatch filter remove FILTER_ID` removes one.
- The poller applies a feed's filters when it saves new entries. An entry a filter drops is never stored.
- A filter for a feed that is not subscribed is refused, with a message naming the URL.
- A filter with no keywords is refused.
- Filters are kept in the same database, and a database created before this feature keeps working.
- Entries already stored are not re-filtered.

## Out of scope

Filtering on an entry's body; regular expressions.

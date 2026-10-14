# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed and turns its XML into entries. Owns HTTP and the feed format; never stores.
- **store** — the SQLite database. Owns the schema and each feed's last failed poll; never touches the network.
- **notify** — tells the user about entries. Owns the channels and how a message reads on each; never polls.
- **cli** — the user's commands. Owns presentation; holds no state of its own.
- **types** — `feedwatch/types.py`, the domain values: a feed, an entry. Owns no behaviour.

## How they talk

`cli` calls `fetch`, `store` and `notify`; none of those three calls another. Every component imports `types`. Dependencies point from `cli` down.

## Where state lives

One SQLite file, `$FEEDWATCH_HOME/feeds.db` (default `.feedwatch/` in the working directory), with the tables `feeds`, `entries` and `failures`. `store` is authoritative for all three. Email notifications are files in `$FEEDWATCH_HOME/outbox/`, written by `notify`.

## When it fails

A feed that cannot be fetched is recorded by `store` and skipped; the other feeds carry on, and a later successful poll clears the record. A failure to send a notification surfaces to the user as an error.

## What runs where

One process per command, `python -m feedwatch.cli`. The user's cron runs `poll`.

## Not this

- A long-running poller: cron already schedules, and a process per command needs no supervision.

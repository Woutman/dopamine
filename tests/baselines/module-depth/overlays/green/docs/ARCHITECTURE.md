# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed and turns its XML into entries. Owns HTTP and the feed format; never stores.
- **store** — the SQLite database. Owns the schema and each feed's last failed poll; never touches the network.
- **notify** — tells the user about entries. Owns the channels and how a message reads on each; never polls.
- **cli** — the user's commands. Owns presentation; holds no state of its own.
- **types** — `feedwatch/types.py`, the domain values: a feed, an entry. Owns no behaviour.

## How they talk

**Every component is deep:** a caller uses what a component offers below, never how it does its work. **Exception:** `types` — the shared domain values, imported directly by every component by design; it hides nothing.

| Component | Offers its callers | Must hold |
|---|---|---|
| fetch | fetch entries: a feed's address → its entries, or a fetch error; parse a feed: feed XML → its entries | — |
| store | subscribe to a feed; the feeds; save entries → how many were new; record how a feed's poll went; which feeds are failing; unread entries, newest first; mark entries read | — |
| notify | send: entries, a channel and a format → one message on that channel; the channels and formats there are | a channel and its format never disagree |
| cli | the user's commands: `add`, `poll`, `where` | — |

`cli` calls `fetch`, `store` and `notify`; none of those three calls another. Dependencies point from `cli` down.

## Where state lives

One SQLite file, `$FEEDWATCH_HOME/feeds.db` (default `.feedwatch/` in the working directory), with the tables `feeds`, `entries` and `failures`. `store` is authoritative for all three. Email notifications are files in `$FEEDWATCH_HOME/outbox/`, written by `notify`.

## When it fails

A feed that cannot be fetched is recorded by `store` and skipped; the other feeds carry on, and a later successful poll clears the record. A failure to send a notification surfaces to the user as an error.

## What runs where

One process per command, `python -m feedwatch.cli`. The user's cron runs `poll`.

## Not this

- A long-running poller: cron already schedules, and a process per command needs no supervision.

# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed's XML. Owns HTTP; never parses.
- **parse** — turns feed XML into entries. Owns the format; never stores.
- **store** — the SQLite database. Owns the schema; never touches the network.
- **poller** — the long-running worker. Owns the schedule; never presents anything.
- **cli** — the user's commands. Owns presentation; never polls.

## How they talk

`poller` calls `fetch`, `parse` and `store`. `cli` calls `store`. Nothing calls `poller`, and only `poller` calls `fetch`.

## Where state lives

One SQLite file, `~/.feedwatch/feeds.db`, with the tables `feeds` and `entries`. `store` is authoritative for both. The schema gains tables and columns as features land, and an existing database has to keep working.

## When it fails

A feed that cannot be fetched or parsed is logged and skipped until its next interval; the poller keeps running. A database error stops the poller.

## What runs where

Two processes on the user's machine: the poller, started once and left running (`python -m feedwatch.poller`), and the CLI, run once per command. Both open the same SQLite file.

## Not this

- A poller thread inside the CLI: the CLI exits after every command.

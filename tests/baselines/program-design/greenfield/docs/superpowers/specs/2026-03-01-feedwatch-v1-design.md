# Feedwatch v1 — design

> **Status.** Approved 2026-03-01.

## What

The first version of feedwatch, as `docs/DESIGN.md` and `docs/ARCHITECTURE.md` describe it: a poller that stores new RSS entries in SQLite, and a command line to subscribe to feeds and read what they brought.

## Behaviour

- `feedwatch add URL [--title TITLE] [--every MINUTES]` subscribes to a feed; the interval defaults to 30 minutes. Subscribing to a URL already subscribed to is refused, with a message naming the URL.
- `feedwatch unread [--limit N]` lists unread entries, newest first, 20 unless set otherwise.
- `feedwatch read GUID [GUID ...]` marks entries read. A guid that is not stored is refused, with a message naming it.
- `python -m feedwatch.poller` polls each feed when its interval is up and stores the entries it has not seen before. An entry is identified by its feed and its guid, or its link when it has no guid.
- A feed that cannot be fetched, or whose XML is not an RSS feed, is logged and skipped until its next interval; the other feeds are still polled.

## Out of scope

Atom feeds; importing or exporting subscription lists.

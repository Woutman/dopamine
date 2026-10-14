# Daily digest — design

> **Status.** Approved 2026-04-06.

## What

`feedwatch digest --channel desktop|email` sends one message summarising the day: for each feed, how many entries are unread and the titles of up to three of them; and for each feed whose last poll failed, the error that poll returned.

## Behaviour

- The digest is sent on the channel the user names, in that channel's format.
- A feed with nothing unread and no failure is left out.
- A failing feed is listed even when it has nothing unread, with its error exactly as it was recorded.
- Sending a digest marks nothing read.

## Out of scope

Scheduling: the user's cron runs `feedwatch digest`.

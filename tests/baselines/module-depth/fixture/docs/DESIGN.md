# Feedwatch — design

## What this is

Feedwatch polls one person's RSS feeds into a local SQLite database and tells them what is new, on the desktop or by email, without a feed-reader service.

## The problem

Feed readers that run as services need an account and a server. One reader on one machine needs neither.

## What it must do

- Poll every subscribed feed when `feedwatch poll` runs; the user's cron decides how often.
- Store each entry once, however often it is seen.
- Remember which feeds failed their last poll, and why, until a poll succeeds.
- Tell the user about unread entries on the channel they choose.
- Keep polling the other feeds when one fails.

## The shape of the solution

A command-line tool over one SQLite file. Notifications go to the terminal (desktop) or to an outbox of email files that the user's mail setup sends.

## Principles

- **A channel decides its message format.** Desktop notifications are one line; email is plain text with a link per entry. A notification in the other channel's format is a bug, never a choice.
- Standard library first; a dependency has to earn its place.

## Not this

- Accounts for more than one user.
- Sending email itself: the outbox is handed to the user's mail setup.

## Open questions

None.

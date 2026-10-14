# Feedwatch — design

## What this is

Feedwatch polls one person's list of RSS feeds and keeps every new entry in a local SQLite database, so they can read their feeds from the command line without a feed-reader service.

## The problem

Feed readers that run as services need an account and a server. One reader on one machine needs neither.

## What it must do

- Poll every subscribed feed at its own interval, 30 minutes unless set otherwise.
- Store each entry once, however often it is seen.
- List unread entries, newest first, and mark them read.
- Keep polling the other feeds when one fails.

## The shape of the solution

A poller process and a command-line tool sharing one SQLite file. Rejected: a web interface, since there is one user at one terminal.

## Principles

- Standard library first; a dependency has to earn its place.

## Not this

- Accounts for more than one user.
- Full-text search.

## Open questions

None.

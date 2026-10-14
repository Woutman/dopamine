"""feedwatch's commands."""

import argparse
import sys

from feedwatch import fetch, notify, store
from feedwatch.fetch import FetchError
from feedwatch.store.queries import latest_failures
from feedwatch.store.schema import database_path


def _feeds(conn):
    return store.feeds(conn)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("add", help="subscribe to a feed").add_argument("url")
    poll = commands.add_parser("poll", help="fetch every feed, then send the unread entries")
    poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
    poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
    commands.add_parser("where", help="print where the database is")
    check = commands.add_parser("check", help="fetch one feed once, without saving it")
    check.add_argument("url")
    commands.add_parser("failing", help="list the feeds whose last poll failed, and why")
    args = parser.parse_args(argv)

    if args.command == "where":
        print(database_path())
        return 0
    if args.command == "check":
        try:
            print(f"{len(fetch.fetch_entries(args.url, 0))} entries")
        except FetchError as exc:
            print(exc, file=sys.stderr)
            return 1
        return 0
    conn = store.connect()
    if args.command == "add":
        store.add_feed(conn, args.url, args.url)
        return 0
    if args.command == "failing":
        titles = {feed.id: feed.title for feed in _feeds(conn)}
        for feed_id, message in latest_failures(conn).items():
            print(f"{titles[feed_id]}: {message}")
        return 0
    for feed in store.feeds(conn):
        try:
            entries = fetch.fetch_entries(feed.url, feed.id)
        except fetch.FetchError as exc:
            store.record_poll(conn, feed.id, str(exc))
            continue
        store.record_poll(conn, feed.id, None)
        store.save_entries(conn, entries)
    notify.send(store.unread(conn), channel=args.channel, fmt=args.format)
    return 0


if __name__ == "__main__":
    sys.exit(main())

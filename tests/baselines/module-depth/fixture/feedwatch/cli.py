"""feedwatch's commands."""

import argparse
import sys

from feedwatch import fetch, notify, store
from feedwatch.store.schema import database_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("add", help="subscribe to a feed").add_argument("url")
    poll = commands.add_parser("poll", help="fetch every feed, then send the unread entries")
    poll.add_argument("--channel", choices=sorted(notify.CHANNELS), default="desktop")
    poll.add_argument("--format", choices=sorted(notify.FORMATS), default="one-line")
    commands.add_parser("where", help="print where the database is")
    args = parser.parse_args(argv)

    if args.command == "where":
        print(database_path())
        return 0
    conn = store.connect()
    if args.command == "add":
        store.add_feed(conn, args.url, args.url)
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

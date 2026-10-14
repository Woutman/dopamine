"""feedwatch's command line: subscribe, list unread entries, mark them read."""

import argparse
import sys

from feedwatch import store


def main(argv=None):
    parser = argparse.ArgumentParser(prog="feedwatch")
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="subscribe to a feed")
    add.add_argument("url")
    add.add_argument("--title", default="")
    add.add_argument("--every", type=int, default=30, help="minutes between polls")
    unread = commands.add_parser("unread", help="list unread entries, newest first")
    unread.add_argument("--limit", type=int, default=20)
    read = commands.add_parser("read", help="mark entries read")
    read.add_argument("guids", nargs="+")
    args = parser.parse_args(argv)

    conn = store.connect()
    if args.command == "add":
        ok, reason = store.add_feed(conn, args.url, args.title or args.url, args.every)
        if not ok:
            print(reason, file=sys.stderr)
            return 1
    elif args.command == "unread":
        for entry in store.unread(conn, args.limit):
            print(f"{entry.guid}  {entry.title}\n    {entry.link}")
    else:
        store.mark_read(conn, args.guids)
    return 0


if __name__ == "__main__":
    sys.exit(main())

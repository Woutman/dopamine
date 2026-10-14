"""The long-running worker: polls each feed when its interval is up."""

import logging
import time
from datetime import datetime, timedelta

from feedwatch import fetch, parse, store

log = logging.getLogger("feedwatch.poller")


def poll_once(conn, last_polled, now):
    for feed in store.feeds(conn):
        previous = last_polled.get(feed.id)
        if previous is not None and now - previous < timedelta(minutes=feed.interval_minutes):
            continue
        last_polled[feed.id] = now
        try:
            xml = fetch.fetch(feed.url)
        except fetch.FetchError as exc:
            log.warning("skipping %s: %s", feed.url, exc)
            continue
        entries = parse.parse_feed(xml)
        if entries is None:
            log.warning("skipping %s: not an RSS feed", feed.url)
            continue
        log.info("%s: %d new", feed.url, store.save_entries(conn, feed.id, entries))


def main():
    logging.basicConfig(level=logging.INFO)
    conn = store.connect()
    last_polled = {}
    while True:
        poll_once(conn, last_polled, datetime.now())
        time.sleep(60)


if __name__ == "__main__":
    main()

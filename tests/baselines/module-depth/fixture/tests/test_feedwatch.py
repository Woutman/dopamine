import tempfile
import unittest
from pathlib import Path

from feedwatch import fetch, store

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>First</title><link>http://x/a</link>
<pubDate>Mon, 06 Apr 2026 09:00:00 +0000</pubDate></item>
<item><title>Neither guid nor link</title></item>
</channel></rss>"""


class FeedwatchTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")
        store.add_feed(self.conn, "http://x/feed", "x")
        self.feed = store.feeds(self.conn)[0]

    def tearDown(self) -> None:
        self.conn.close()
        self.dir.cleanup()

    def test_an_item_with_no_identity_is_skipped(self) -> None:
        self.assertEqual([e.guid for e in fetch.parse_feed(RSS, self.feed.id)], ["a"])

    def test_an_entry_seen_twice_is_stored_once(self) -> None:
        entries = fetch.parse_feed(RSS, self.feed.id)
        self.assertEqual(store.save_entries(self.conn, entries), 1)
        self.assertEqual(store.save_entries(self.conn, entries), 0)

    def test_a_failed_poll_is_remembered_until_one_succeeds(self) -> None:
        store.record_poll(self.conn, self.feed.id, "timed out")
        self.assertEqual(store.failing_feed_ids(self.conn), {self.feed.id})
        store.record_poll(self.conn, self.feed.id, None)
        self.assertEqual(store.failing_feed_ids(self.conn), set())


if __name__ == "__main__":
    unittest.main()

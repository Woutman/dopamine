import tempfile
import unittest
from pathlib import Path

from feedwatch import parse, store

RSS = b"""<rss><channel><title>t</title>
<item><guid>a</guid><title>First</title><link>http://x/a</link>
<pubDate>Mon, 02 Mar 2026 09:00:00 +0000</pubDate></item>
<item><title>Neither guid nor link</title></item>
</channel></rss>"""


class FeedwatchTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.conn = store.connect(Path(self.dir.name) / "feeds.db")

    def tearDown(self):
        self.conn.close()
        self.dir.cleanup()

    def test_an_item_with_no_identity_is_skipped(self):
        self.assertEqual([e["guid"] for e in parse.parse_feed(RSS)], ["a"])

    def test_xml_that_is_not_a_feed_is_rejected(self):
        self.assertIsNone(parse.parse_feed(b"<html/>"))

    def test_an_entry_seen_twice_is_stored_once(self):
        store.add_feed(self.conn, "http://x/feed", "x")
        feed = store.feeds(self.conn)[0]
        entries = parse.parse_feed(RSS)
        self.assertEqual(store.save_entries(self.conn, feed.id, entries), 1)
        self.assertEqual(store.save_entries(self.conn, feed.id, entries), 0)

    def test_subscribing_twice_is_refused(self):
        store.add_feed(self.conn, "http://x/feed", "x")
        ok, reason = store.add_feed(self.conn, "http://x/feed", "x")
        self.assertFalse(ok)
        self.assertIn("already subscribed", reason)


if __name__ == "__main__":
    unittest.main()

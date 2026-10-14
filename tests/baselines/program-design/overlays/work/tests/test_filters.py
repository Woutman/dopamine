import unittest

from feedwatch.filters import keep, parse_keywords
from feedwatch.models import Entry, Filter


def entry(title: str) -> Entry:
    return Entry(feed_id=1, guid="g", title=title, link="", published=None)


class FiltersTest(unittest.TestCase):
    def test_include_keeps_only_a_matching_title(self) -> None:
        rules = [Filter(1, "include", ("python",))]
        self.assertTrue(keep(rules, entry("Python 3.14 released")))
        self.assertFalse(keep(rules, entry("Rust 2.0 released")))

    def test_exclude_drops_a_matching_title(self) -> None:
        self.assertFalse(keep([Filter(1, "exclude", ("sponsored",))], entry("Sponsored: a VPN")))

    def test_keywords_match_whole_words(self) -> None:
        self.assertFalse(keep([Filter(1, "include", ("py",))], entry("Python news")))

    def test_keywords_come_from_a_comma_separated_list(self) -> None:
        self.assertEqual(parse_keywords(" Python, rust ,"), ("python", "rust"))


if __name__ == "__main__":
    unittest.main()

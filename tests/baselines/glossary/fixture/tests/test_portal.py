import unittest
from datetime import date

from leadflow.engine.bands import LeadBand
from leadflow.portal.feed import portal_feed
from tests.helpers import lead


class Feed(unittest.TestCase):
    def test_feed(self):
        leads = [
            lead(id="a", band=LeadBand.HOT),
            lead(id="b", band=LeadBand.WARM, contact=None),
            lead(id="c", band=LeadBand.NURTURE, dismissed_on=date(2026, 10, 30)),
            lead(id="d", band=LeadBand.EXCLUDED),
        ]
        cards = portal_feed(leads, excluded_contacts=set(), today=date(2026, 11, 2))
        self.assertEqual([c["label"] for c in cards], ["Hot", "Neutraal"])

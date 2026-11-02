import unittest

from leadflow.engine.assign import assign_band
from leadflow.engine.bands import LeadBand
from leadflow.registry.match import MatchResult
from tests.helpers import lead


class Bands(unittest.TestCase):
    def test_bands(self):
        self.assertEqual(assign_band(lead()), LeadBand.HOT)
        self.assertEqual(assign_band(lead(fit=0.6, intent=0.6)), LeadBand.WARM)
        self.assertEqual(assign_band(lead(fit=0.2, intent=0.2)), LeadBand.NURTURE)
        self.assertEqual(assign_band(lead(sector="tobacco")), LeadBand.EXCLUDED)
        self.assertEqual(assign_band(lead(match=MatchResult("fuzzy", "9", 0.7))), LeadBand.NURTURE)

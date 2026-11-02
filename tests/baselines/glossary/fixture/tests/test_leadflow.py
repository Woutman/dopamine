import unittest

from leadflow.engine.bands import LeadBand
from leadflow.engine.scoring import assign_band, score
from leadflow.models import Lead
from leadflow.portal.feed import portal_feed


def lead(**kw):
    base = dict(id="l1", company_id="c1", sector="retail", fit=0.9, intent=0.9, contact="a@b.nl")
    base.update(kw)
    return Lead(**base)


class Scoring(unittest.TestCase):
    def test_score_weights_fit_over_intent(self):
        self.assertEqual(score(lead(fit=0.5, intent=1.0)), 0.7)

    def test_bands(self):
        self.assertEqual(assign_band(lead()), LeadBand.HOT)
        self.assertEqual(assign_band(lead(fit=0.6, intent=0.6)), LeadBand.WARM)
        self.assertEqual(assign_band(lead(fit=0.2, intent=0.2)), LeadBand.NURTURE)
        self.assertEqual(assign_band(lead(sector="tobacco")), LeadBand.EXCLUDED)
        self.assertEqual(assign_band(lead(company_id=None)), LeadBand.NURTURE)


class Feed(unittest.TestCase):
    def test_feed(self):
        a = lead(id="a", band=LeadBand.HOT)
        b = lead(id="b", band=LeadBand.WARM, contact=None)
        c = lead(id="c", band=LeadBand.NURTURE)
        cards = portal_feed([a, b, c], dismissed={"c"})
        self.assertEqual([x["label"] for x in cards], ["Hot", "Neutraal"])
        self.assertIsNone(cards[1]["score"])


if __name__ == "__main__":
    unittest.main()

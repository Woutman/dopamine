from leadflow.engine.bands import LeadBand
from leadflow.models import Lead
from leadflow.portal.feed import portal_feed

def lead(id, band, contact):
    return Lead(id=id, company_id="c", sector="retail", fit=0.9, intent=0.9, contact=contact, band=band)

cards = portal_feed([lead("a", LeadBand.HOT, None), lead("b", LeadBand.NURTURE, None),
                     lead("c", LeadBand.EXCLUDED, "x")], dismissed=set())
assert [c["label"] for c in cards] == ["In afwachting", "Koud", "Geen fit"], cards

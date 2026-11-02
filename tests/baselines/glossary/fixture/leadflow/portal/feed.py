from leadflow.engine.bands import LeadBand
from leadflow.portal.filters import hidden
from leadflow.portal.serialize import card


def _withheld(lead):
    return lead.band in (LeadBand.HOT, LeadBand.WARM) and lead.contact is None


def portal_feed(leads, dismissed):
    return [
        card(lead, withheld=_withheld(lead))
        for lead in leads
        if not hidden(lead.id, dismissed)
    ]

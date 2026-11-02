from leadflow.engine.bands import LeadBand
from leadflow.portal.cards import card
from leadflow.portal.sort import priority


def portal_feed(leads, excluded_contacts, locale="nl", today=None):
    shown = [
        lead for lead in leads
        if lead.band is not LeadBand.EXCLUDED and lead.dismissed_on is None
    ]
    return [card(lead, excluded_contacts, locale) for lead in sorted(shown, key=priority)]

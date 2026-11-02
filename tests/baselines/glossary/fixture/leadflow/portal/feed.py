from leadflow.engine.bands import LeadBand
from leadflow.portal.cards import card
from leadflow.portal.cooldown import in_cooldown
from leadflow.portal.sort import priority


def portal_feed(leads, excluded_contacts, locale="nl", today=None):
    shown = [
        lead for lead in leads
        if lead.band is not LeadBand.EXCLUDED and not in_cooldown(lead, today)
    ]
    return [card(lead, excluded_contacts, locale) for lead in sorted(shown, key=priority)]

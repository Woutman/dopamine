from leadflow.engine.bands import LeadBand
from leadflow.privacy.optout import is_excluded_contact


def _suppress_score(lead, excluded_contacts):
    if lead.band not in (LeadBand.HOT, LeadBand.WARM):
        return False
    return lead.contact is None or is_excluded_contact(lead.contact, excluded_contacts)

from leadflow.engine.score import score
from leadflow.portal.i18n import label
from leadflow.portal.visibility import _suppress_score


def card(lead, excluded_contacts, locale="nl"):
    withheld = _suppress_score(lead, excluded_contacts)
    return {
        "id": lead.id,
        "company": lead.company.name,
        "label": label("withheld" if withheld else lead.band.value, locale),
        "score": None if withheld else score(lead),
        "withheld": withheld,
    }

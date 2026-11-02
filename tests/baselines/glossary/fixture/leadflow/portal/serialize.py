from leadflow.engine.scoring import score
from leadflow.portal.labels import LABELS


def card(lead, *, withheld=False):
    key = "withheld" if withheld else lead.band.value
    return {
        "id": lead.id,
        "label": LABELS[key],
        "score": None if withheld else score(lead),
    }

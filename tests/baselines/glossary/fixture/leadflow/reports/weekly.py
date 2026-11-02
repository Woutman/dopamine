from collections import Counter

from leadflow.portal.visibility import _suppress_score
from leadflow.registry.match import is_resolved


def weekly_summary(leads, excluded_contacts):
    bands = Counter(lead.band.value for lead in leads)
    return {
        "bands": dict(bands),
        "withheld": sum(_suppress_score(lead, excluded_contacts) for lead in leads),
        "unresolved": sum(not is_resolved(lead.match) for lead in leads),
    }

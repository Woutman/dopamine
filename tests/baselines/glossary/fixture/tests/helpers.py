from datetime import date

from leadflow.models.company import Company
from leadflow.models.contact import Contact
from leadflow.models.lead import Lead
from leadflow.registry.match import MatchResult


def lead(id="l1", sector="retail", fit=0.9, intent=0.9, match=None, contact="a@b.nl", **kw):
    return Lead(
        id=id,
        company=Company("Acme", "Utrecht", sector),
        fit=fit,
        intent=intent,
        match=match or MatchResult("exact", "123", 1.0),
        contact=Contact(contact) if contact else None,
        enriched_on=kw.pop("enriched_on", date(2026, 10, 1)),
        **kw,
    )

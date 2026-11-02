import csv

from leadflow.engine.bands import LeadBand
from leadflow.engine.score import score
from leadflow.privacy.optout import is_excluded_contact


def is_masked(lead, excluded_contacts):
    if lead.band not in (LeadBand.HOT, LeadBand.WARM):
        return False
    return lead.contact is None or is_excluded_contact(lead.contact, excluded_contacts)


def write_leads(path, leads, excluded_contacts):
    with open(path, "w", newline="") as handle:
        out = csv.writer(handle)
        out.writerow(["id", "company", "band", "score", "kvk", "masked"])
        for lead in leads:
            masked = is_masked(lead, excluded_contacts)
            out.writerow([
                lead.id, lead.company.name, lead.band.value,
                "" if masked else score(lead), lead.match.kvk or "", "yes" if masked else "",
            ])

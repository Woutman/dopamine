import csv

from leadflow.engine.score import score


def write_leads(path, leads):
    with open(path, "w", newline="") as handle:
        out = csv.writer(handle)
        out.writerow(["id", "company", "band", "score", "kvk"])
        for lead in leads:
            out.writerow([lead.id, lead.company.name, lead.band.value, score(lead), lead.match.kvk or ""])

from difflib import SequenceMatcher

from leadflow.registry.match import MatchResult


def lookup(client, company):
    if company.kvk:
        return MatchResult("exact", company.kvk, 1.0)
    best = None
    for hit in client.search(company.name, company.city):
        ratio = SequenceMatcher(None, hit["name"].lower(), company.name.lower()).ratio()
        if best is None or ratio > best.confidence:
            best = MatchResult("fuzzy", hit["kvk"], round(ratio, 2))
    return best or MatchResult("none")

from leadflow.engine.explain import explain


def lead_detail(card, lead, include_explain=False):
    data = dict(card)
    if include_explain and not card["withheld"]:
        data["explain"] = explain(lead)
    data["unresolved"] = lead.match.status != "exact"
    return data

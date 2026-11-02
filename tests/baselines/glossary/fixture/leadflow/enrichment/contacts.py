from leadflow.models.contact import Contact


def find_contact(provider, company):
    people = provider.people(company.kvk or company.name)
    decision_makers = [p for p in people if p.get("seniority") in ("owner", "director", "head")]
    if not decision_makers:
        return None
    first = decision_makers[0]
    return Contact(email=first["email"], name=first.get("name", ""), role=first.get("title", ""))

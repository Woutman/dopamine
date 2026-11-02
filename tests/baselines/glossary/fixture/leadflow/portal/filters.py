def by_band(cards, labels):
    return [c for c in cards if c["label"] in labels]


def hide_withheld(cards):
    return [c for c in cards if not c["withheld"]]

from leadflow.config.weights import FIT_WEIGHT, INTENT_WEIGHT


def score(lead):
    return round(FIT_WEIGHT * lead.fit + INTENT_WEIGHT * lead.intent, 2)

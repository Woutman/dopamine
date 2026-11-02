from leadflow.config.weights import FIT_WEIGHT, INTENT_WEIGHT
from leadflow.engine.score import score


def explain(lead):
    return {
        "fit": round(FIT_WEIGHT * lead.fit, 2),
        "intent": round(INTENT_WEIGHT * lead.intent, 2),
        "total": score(lead),
        "band": lead.band.value if lead.band else None,
    }

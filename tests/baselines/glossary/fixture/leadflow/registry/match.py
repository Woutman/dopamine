from dataclasses import dataclass

from leadflow.config.registry import FUZZY_MIN


@dataclass
class MatchResult:
    status: str  # "exact", "fuzzy" or "none"
    kvk: str | None = None
    confidence: float = 0.0


def is_resolved(match):
    if match.status == "exact":
        return True
    return match.status == "fuzzy" and match.confidence >= FUZZY_MIN

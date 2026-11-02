from enum import Enum


class LeadBand(str, Enum):
    HOT = "hot"
    WARM = "warm"
    NURTURE = "nurture"
    EXCLUDED = "excluded"


THRESHOLDS = {LeadBand.HOT: 0.8, LeadBand.WARM: 0.6}

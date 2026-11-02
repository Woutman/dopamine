from enum import Enum


class LeadBand(str, Enum):
    HOT = "hot"
    WARM = "warm"
    NURTURE = "nurture"
    EXCLUDED = "excluded"

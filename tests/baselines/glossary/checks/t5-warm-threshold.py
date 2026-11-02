from leadflow.engine import legacy_bands
from leadflow.engine.bands import THRESHOLDS, LeadBand

assert THRESHOLDS[LeadBand.WARM] == 0.5
assert THRESHOLDS[LeadBand.HOT] == 0.8
assert legacy_bands.WARM_THRESHOLD == 0.55, "the backfill job's threshold moved"

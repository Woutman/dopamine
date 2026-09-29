"""A one-line account of a runner.run, for the notebook's log cell."""
from .runner import Outcome

ORDER = (Outcome.STORED, Outcome.DUPLICATE, Outcome.REJECTED, Outcome.FAILED,
         Outcome.CALIBRATION_FAILED)


def format_counts(counts):
    """'stored=12 duplicate=0 ...', every Outcome present, in ORDER."""
    return " ".join(f"{outcome.value}={counts.get(outcome, 0)}" for outcome in ORDER)


def worth_a_look(counts):
    # anything but stored and duplicate means someone should open the files
    return any(counts.get(o, 0) for o in ORDER if o not in (Outcome.STORED, Outcome.DUPLICATE))

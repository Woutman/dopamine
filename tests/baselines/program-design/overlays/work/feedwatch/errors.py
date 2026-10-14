"""The failures feedwatch signals. Only poller and cli catch them."""


class FeedwatchError(Exception):
    """Base of every failure feedwatch raises."""


class InvalidFilter(FeedwatchError):
    """A filter that cannot be applied, such as one with no keywords."""

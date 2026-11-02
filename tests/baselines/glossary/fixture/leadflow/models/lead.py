from dataclasses import dataclass, field
from datetime import date

from leadflow.engine.bands import LeadBand
from leadflow.models.company import Company
from leadflow.models.contact import Contact
from leadflow.registry.match import MatchResult


@dataclass
class Lead:
    id: str
    company: Company
    fit: float
    intent: float
    match: MatchResult
    contact: Contact | None = None
    enriched_on: date | None = None
    dismissed_on: date | None = None
    band: LeadBand | None = None
    tags: list[str] = field(default_factory=list)

from dataclasses import dataclass

from leadflow.engine.bands import LeadBand


@dataclass
class Lead:
    id: str
    company_id: str | None
    sector: str
    fit: float
    intent: float
    contact: str | None = None
    band: LeadBand | None = None

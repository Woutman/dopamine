# Glossary

- **band** (`LeadBand`) — the bucket the engine puts a scored lead in: hot, warm, nurture or excluded → `leadflow/engine/bands.py:LeadBand`
- **excluded** (UI: "Geen fit") — a lead in a blocked sector, whatever its score → `leadflow/engine/scoring.py:BLOCKED_SECTORS`
- **hidden** — a lead a salesperson dismissed; it leaves the portal feed entirely, unlike withheld → `leadflow/portal/filters.py:hidden`
- **hot** (UI: "Hot") — a resolved lead scoring at least `THRESHOLDS[HOT]` → `leadflow/engine/bands.py:THRESHOLDS`
- **legacy band** (hot/warm/cold) — the 2024 model's bands, used only by the backfill job; "cold" is not nurture → `leadflow/engine/legacy_bands.py:legacy_band`
- **nurture** (UI: "Koud") — a lead below the warm threshold, or an unresolved one that would have been hot or warm → `leadflow/engine/scoring.py:assign_band`
- **score** — 0.6 × fit + 0.4 × intent, rounded to two decimals; the bands compare against it → `leadflow/engine/scoring.py:score`
- **unresolved** — a lead with no `company_id`; it is capped at nurture → `leadflow/engine/scoring.py:_unresolved`
- **warm** (UI: "Warm") — a resolved lead scoring at least `THRESHOLDS[WARM]` and below hot → `leadflow/engine/bands.py:THRESHOLDS`
- **withheld** (UI: "Neutraal") — a hot or warm lead with no contact; shown without its score until a contact is found → `leadflow/portal/feed.py:_withheld`

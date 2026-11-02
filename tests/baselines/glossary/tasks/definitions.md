# Definitions handed to arm O

- **cooldown** — a dismissed lead stays out of the portal feed for `COOLDOWN_DAYS` (14) days → `leadflow/portal/cooldown.py:in_cooldown`
- **excluded** (UI: "Geen fit") — a lead in a blocked sector, whatever its score; not the same as an opted-out contact → `leadflow/engine/assign.py:assign_band`
- **excluded contact** — a contact who opted out of being approached; makes a hot or warm lead withheld, not excluded → `leadflow/privacy/optout.py:is_excluded_contact`
- **nurture** (UI: "Koud", "Cold") — below `WARM_MIN`, or an unresolved lead that would have been hot or warm → `leadflow/engine/assign.py:assign_band`
- **stale** — enrichment older than `MAX_AGE_DAYS` (30) days, or never enriched → `leadflow/enrichment/freshness.py:is_stale`
- **unresolved** — the registry match is neither exact nor fuzzy with confidence at least `FUZZY_MIN` (0.85); the engine caps it at nurture → `leadflow/registry/match.py:is_resolved`
- **withheld** (UI: "Neutraal") — a hot or warm lead with no contact, or whose contact opted out; shown without its score → `leadflow/portal/visibility.py:_suppress_score`

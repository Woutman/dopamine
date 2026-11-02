# Glossary

The project's own terms, one per line; grep for a term rather than reading the file.

- **cold** — the lowest band of the 2024 scoring model, used only by the backfill job; not the current nurture band → `leadflow/engine/legacy.py:legacy_band`
- **cooldown** — a dismissed lead stays out of the portal feed for `COOLDOWN_DAYS` (14) days → `leadflow/portal/cooldown.py:in_cooldown`
- **employees band** — company size: micro under 10, small under 50, medium under 250, otherwise large; unknown with no count → `leadflow/enrichment/firmographics.py:employees_band`
- **excluded** (UI: "Geen fit") — a lead in a blocked sector, whatever its score; not the same as an opted-out contact → `leadflow/engine/assign.py:assign_band`
- **excluded contact** — a contact who opted out of being approached; makes a hot or warm lead withheld, not excluded → `leadflow/privacy/optout.py:is_excluded_contact`
- **expired** — enrichment older than `RETENTION_DAYS` (730) days → `leadflow/privacy/retention.py:expired`
- **hot** (UI: "Hot") — a resolved lead outside a blocked sector scoring at least `HOT_MIN` (0.8) → `leadflow/engine/assign.py:assign_band`
- **nurture** (UI: "Koud", "Cold") — below `WARM_MIN`, or an unresolved lead that would have been hot or warm → `leadflow/engine/assign.py:assign_band`
- **stale** — enrichment older than `MAX_AGE_DAYS` (30) days, or never enriched → `leadflow/enrichment/freshness.py:is_stale`
- **unresolved** — the registry match is neither exact nor fuzzy with confidence at least `FUZZY_MIN` (0.85); the engine caps it at nurture → `leadflow/registry/match.py:is_resolved`
- **warm** (UI: "Warm") — a resolved lead outside a blocked sector scoring at least `WARM_MIN` (0.6) and below `HOT_MIN` → `leadflow/engine/assign.py:assign_band`
- **withheld** (UI: "Neutraal") — a hot or warm lead with no contact, or whose contact opted out; shown without its score → `leadflow/portal/visibility.py:_suppress_score`

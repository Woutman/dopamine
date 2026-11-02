# Masked leads in the partner export — Implementation Plan

**Goal:** The partner CSV export stops showing a score sales may not act on.

### Task 1: Masked leads
Add `leadflow/reports/export_csv.py:is_masked(lead, excluded_contacts) -> bool`: true for a hot or warm lead with no contact, or whose contact opted out. `write_leads` takes `excluded_contacts`, leaves a masked lead's score empty, and adds a `masked` column.

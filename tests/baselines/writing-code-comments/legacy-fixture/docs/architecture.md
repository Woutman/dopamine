# Architecture

## 1. What this is

About forty weather stations, run by three different owners, export their readings as CSV files.
The files are copied into one directory, the **inbox**. This project imports them into a reading
store that the analysis notebooks read from.

## 2. The pieces

| Piece | Where | What it does |
|---|---|---|
| Stations | in the field | Export a CSV every six hours, covering the last twelve |
| Inbox | a directory on the import host | Holds every export, as delivered; nothing here deletes from it |
| Importer | `readings/` | Reads exports from the inbox into the store |
| Store | `readings/store.py`, one SQLite file | Readings under their keys, and one marker per inbox file |
| Analysis | notebooks, not in this repository | Reads the store |

## 3. The store's contract

- A reading is stored under a key the importer chooses. Adding a key that is present stores nothing
  and says so.
- A marker records what the importer last concluded about one inbox file: a state, a count of
  failures, and a detail line for a person.
- Nothing is written until the importer commits, so a file's readings and its marker can land
  together.
- The notebooks read readings only. Markers are the importer's own.

## 4. Phases

1. **Phase 1, done.** Port the notebook-era prototype into `readings/`, with tests, and build the
   store. Plan: `docs/superpowers/plans/2026-02-09-phase-1-port-and-store.md`.
2. **Phase 2, now.** Make the importer a program that can run unattended against the inbox. Spec:
   `docs/superpowers/specs/2026-03-02-phase-2-inbox-import-design.md`.
3. **Phase 3, later.** Run it on a timer, and alert a person when it needs one.

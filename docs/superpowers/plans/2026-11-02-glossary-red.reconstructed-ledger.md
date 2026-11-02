# Reconstructed ledger — ad-hoc work, reconstructed 2026-11-02 — no superpowers ledger existed

Slug: `2026-11-02-glossary-red`. No plan file and no spec; on branch `glossary-baseline`, after
`2026-11-02-glossary-baseline`, whose ledger predates everything below.

## Rulings (the human's)

- **Runs use the subscription**, not an API key. `run-task` gives every run an empty
  `CLAUDE_CONFIG_DIR` holding only a link to the login, in place of `--bare`.
- **The four-arm test mixed implementation into viability** and gave a noisy signal. Viability is
  measured alone, as RED, the way the plugin's other baselines gate their work; the mechanism is
  GREEN's question.
- **RED and GREEN run on one repository.** A fixture in this repo, not `gls-global`, so both stay
  reproducible. It was modelled on the backlog's account of the review; searching for a local
  `gls-global` checkout was stopped.
- **The glossary proceeds to design** after RED.

## What changed

- The 16-file fixture, the injection arms (pointer, full file, headwords) and the edit tasks are
  gone. Edit tasks put the definition where the edit went, so the glossary could only add a step.
- A 76-file fixture: `withheld` defined only as `_suppress_score`, `excluded` with a homonym in the
  privacy code, `unresolved` spread over three files and defined differently by the API, band
  names drifted between engine and UI.
- Seven term questions under arm A (find the definition in code) and arm O (the needed definitions
  in the prompt). Tools are the same in both: read and search allowed, edits blocked.
- `score` accepts an answer followed by its reasoning. q2 was reworded after its first wording drew
  prose answers, and its runs were rerun.
- `run-task` creates its login link with `ln -sfn`: parallel runs raced to create it and the losers
  exited before calling Claude.
- The backlog entry describes RED and GREEN in place of the four arms.

## Observed

- RED: 70/70 correct. A costs $0.0696 per question, O $0.0548: a ceiling of about $0.015 (21%).
  Recorded in `2026-11-02-glossary.baseline/red/score.md`.
- From the discarded rounds, for design: a pointer saying "grep" pushed agents into shell commands
  the permissions blocked, and glossary arms edited `GLOSSARY.md` mid-task when a change made an
  entry false. Neither round's numbers are usable.

## Living-document consequence

None. All four declared living documents are absent, and the backlog is deliberately undeclared.

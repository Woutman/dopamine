# Reconstructed ledger — 2026-11-02-glossary-check

Reconstruction, 2026-11-02, from the conversation: ad-hoc follow-up on PR #12, with no plan and no superpowers ledger.

- Ask (user): add a deterministic GLOSSARY.md check, called during review, whose failure output tells the agent how to fix it; settle the rename rule; check the skill text against superpowers:writing-skills.
- check-glossary-pointers renamed to check-glossary and extended: off-shape lines, blank lines between entries, a second header sentence, order, duplicate headwords, unknown sections, malformed pointers, dead pointers. Each failure prints `<file>:<line>: <what is wrong> — <the fix>`. Tests: tests/scripts/test-check-glossary.sh.
- Ruling: no "one spelling names one term" check — the GREEN overlay lists "Cold" as nurture's UI label and **cold** as a separate legacy term, and a grep returning both is the drift the glossary records (q1) — cost if wrong: two entries sharing a spelling by mistake go unflagged.
- Ruling: the review call sits in finishing-work's exit gate check 2 ("After a glossary edit, `check-glossary` exits 0"), not as an eighth check, so the gate stays one fresh-eyes pass — cost if wrong: a gate reader skims past it.
- Rename rule (user-agreed), in glossary-schema.md: while the old spelling still appears where an agent meets it, it joins the line in parentheses; once it appears nowhere, the new spelling replaces it.
- writing-skills check: skills now invoke the bundled script through `bash`, as writing-skills requires; the schema's "no other prose" became a recipe ("a title line, a one-sentence header, then the entries"). The skill text in this PR had no wording micro-tests: the rules-over-mechanism spec's ruling skips RED-phase baselines and validates manually; only the hook pointer was measured (GREEN).
- finishing-work budget unchanged at 870 (a clause was cut instead of raised).

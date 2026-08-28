# Sweep discovery prompt

Fill the placeholders and dispatch one subagent with the result.

**Placeholders:** `{SEALED_LEDGER}` `{DIFF_PACKAGE}` `{CONFIG_MAP}` `{BRIEF_PATH}` `{SPEC}` `{PLAN}`

---

You are writing a **sweep brief**: the located, checkable list of changes that carry one unit of work into this project's living documents.

## Your inputs, and their order

1. `{SEALED_LEDGER}` — what actually happened during execution: rulings, deviations, parked findings. Read it in full. It is the one unreconstructable record.
2. `{DIFF_PACKAGE}` — what the code now does.
3. `{CONFIG_MAP}` — the output of `artifact-paths`: which paths hold which tier, and which are absent.
4. `{SPEC}` and `{PLAN}` — read only to resolve a claim you cannot place from the first two.

**You do not read the living documents in bulk.** From the ledger and the diff, derive a list of **grep terms** — the symbols, filenames, numbers, component names and phrases a claim would be written with — and reach into the documents only along those terms. A document you have grepped six times you have still not read, and that is the intended cost.

Read the destination section before writing any entry there. That is how you decide append-or-merge, and it is also how recurrence surfaces for free.

## The output

Write `{BRIEF_PATH}`. It has exactly these sections.

### Grep terms

The terms you derived, and the input each came from. This is what the verifier re-derives independently, so it has to be visible.

### Edits

One per change. Each is:

- **File and line** — `docs/DESIGN.md:214`
- **Current text, quoted** — verbatim, enough to locate it unambiguously
- **The change required** — the replacement text, or the text to add and exactly where

A located, quoted entry is what makes a sweep reviewable at all. An unlocated instruction cannot be verified by anyone, including you.

### Negatives

Every location you checked and deliberately left alone, with the reason. A negative is a first-class entry: it is the evidence that coverage happened, and it is what stops the next sweep re-checking the same ground.

Historical records — specs, plans, sealed ledgers, previous briefs — are left alone by rule. A grep hit inside one is a negative, never an edit.

### Promotions

A claim that has recurred: you found a near-identical entry already in the append-mostly tier. A lesson learned twice is evidence that one always-loaded line would have prevented the second occurrence. Give the `CLAUDE.md` line you propose, and the two occurrences that justify it.

A promotion is a proposal. Until this project has the `CLAUDE.md` admission guard, record it and leave it unapplied.

## Where each fact goes

Follow the artifact map. The two that decide most entries:

- A number that describes **the system now** goes into a living document, **replacing** the previous value. A number that describes **a run** stays in the sealed ledger and is cited from there.
- A dated observation that will stay true goes to the append-mostly tier, carrying the error text, symbol or version a future agent would grep for. A prescription goes where staleness is checked.

## When there is nothing to drain

Write the brief with its grep terms and its negatives, and say so in one sentence. A ledger of clean task completions and no deviations legitimately produces no edits. That is a finished sweep, and the negatives are what show you reached the conclusion rather than assumed it.

# Sweep discovery prompt

Fill the placeholders and dispatch one subagent with the result.

**Placeholders:** `{SEALED_LEDGER}` `{CONFIG_MAP}` `{BRIEF_PATH}` `{SPEC}` `{PLAN}`

---

You are writing a **sweep brief**: the located, checkable list of changes that carry one unit of work into this project's living documents.

## Your inputs, and their order

1. `{SEALED_LEDGER}` — what actually happened during execution: rulings, deviations, parked findings. Read it in full. Sealed from a superpowers run, it is the one record that cannot be rebuilt afterwards; where its opening line announces a reconstruction instead, it is the same kind of record, read the same way and weighed as the weaker one it says it is.
2. `{CONFIG_MAP}` — the output of `artifact-paths`: which paths hold which tier, and which are absent.
3. `{SPEC}` and `{PLAN}` — read only to resolve a claim you cannot place from the first two.

You have no diff of your own. The sealed ledger is the sweep's one journal, so you work from it; current text is quoted by reading the living documents directly, not from a diff. The diff you might otherwise want covers this unit's own work — a different git range than the one verification's diff covers, its own sweep — so the two are never the same package.

**You do not read the living documents in bulk.** From the ledger, derive a list of **grep terms** — the symbols, filenames, numbers, component names and phrases a claim would be written with — and reach into the documents only along those terms. A document you have grepped six times you have still not read, and that is the intended cost.

Read the destination section before writing any entry there. That is how you decide append-or-merge, and it is also how recurrence surfaces for free.

Load the dopamine:routing-documentation-updates skill by name before you place anything — it defines the tiers `{CONFIG_MAP}` and this prompt both refer to.

## The output

Write `{BRIEF_PATH}`. It has exactly these sections.

### Grep terms

The terms you derived, and the input each came from. This is what the verifier re-derives independently, so it has to be visible.

### Edits

One per change. Each is:

- **File and line** — `docs/DESIGN.md:214`, or for a genuinely new append-mostly entry, the file and the heading it lands under
- **Tier** — the tier the destination belongs to, as dopamine:routing-documentation-updates defines it
- **Target heading** — the heading the change lands under, created if it does not exist yet
- **Current text, quoted** — verbatim, enough to locate it unambiguously; for a genuinely new entry, write **"new entry"** in its place — there is nothing existing to cite
- **The change required** — the replacement text, or the text to add and exactly where
- **Verdict, when the Tier is `instructions`** — carries the same `verdict:` line a promotion does. Load the dopamine:claude-md-guard skill by name, put the candidate through the admission test, and record `verdict: admit` or `verdict: route <destination>` in the entry.

A located, quoted entry is what makes a sweep reviewable at all. An unlocated instruction cannot be verified by anyone, including you.

### Negatives

Every location you checked and deliberately left alone, and every ledger entry you judged to have no living-document consequence — each with the reason. A negative is a first-class entry: it is the evidence that coverage happened, and it is what stops the next sweep re-checking the same ground.

Historical records — specs, plans, sealed ledgers, previous briefs — are left alone by rule. A grep hit inside one is a negative, never an edit.

### Promotions

A claim that has recurred: you found a near-identical entry already in the append-mostly tier. A lesson learned twice is evidence that one always-loaded line would have prevented the second occurrence. Give the line you propose for the instructions tier, and the two occurrences that justify it.

Then put it through the admission test. Load the dopamine:claude-md-guard skill by name and record its verdict on the entry, in the form that skill gives:

- **`verdict: admit`** — the promotion also becomes an **Edit** against the instructions-tier path, located and quoted like every other edit.
- **`verdict: route <destination>`** — the claim stays where it is. The recorded verdict and its reason are what stop the next recurrence re-litigating a decision already made.

A promotion carrying no verdict is an incomplete entry.

## Where each fact goes

Follow the artifact map. The two that decide most entries:

- A number that describes **the system now** goes into a living document, **replacing** the previous value. A number that describes **a run** stays in the sealed ledger and is cited from there.
- A dated observation that will stay true goes to the append-mostly tier, carrying the error text, symbol or version a future agent would grep for. A prescription goes where staleness is checked.

## When there is nothing to drain

Write the brief with its grep terms and its negatives, and say so in one sentence. A ledger of clean task completions and no deviations legitimately produces no edits. That is a finished sweep, and the negatives are what show you reached the conclusion rather than assumed it.

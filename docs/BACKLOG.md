# Backlog

Ideas for dopamine that are agreed to be worth doing and are **not scheduled**. Each entry says
what it is, why, and what is still open.

**This file is consumed, not maintained.** It is deliberately absent from `.dopamine/config`, so
no sweep reads or verifies it. An entry is deleted when a spec picks it up — the spec carries it
from there — or when it is dropped, with one line saying why in the commit that drops it.

Every entry that changes a skill goes through a RED/GREEN baseline before it ships, as program
design did (`docs/superpowers/plans/2026-10-12-program-design.md`).

## Extend dopamine to products that keep growing after production

**The idea.** Dopamine was built for one scoped deliverable, worked towards an end and then left
alone. A product that keeps being added to after it ships needs two things dopamine does not have:
**an entry point for new work after delivery**, and **protection against the codebase slowly
eroding** as features accumulate. Much already works — `brainstorm-design`,
`brainstorm-architecture` and `brainstorm-program-design` revise their documents in place, and the
roadmap re-orders at each phase close — so this is an extension, not a redesign.

**Why it matters more for a growing product.** It came out of a 2026-10-14 discussion of deep
versus shallow modules, using `heijmans-evaluatie-assistent` as the worked example. There, the
shallowness entered **between** phases: each time a later phase became a new consumer of an
earlier package, it reached into that package's internals rather than the package offering what
it needed. A fixed-scope project pays for that a bounded number of times. A growing product pays
for it on every feature, and each reach-in makes the next one cheaper to justify.

**What it would contain** — suggestions, none decided:

- **A feature-intake recipe**, something like `dopamine:adding-a-feature`: a short triage of a new
  request against the existing documents. Its central question is whether the feature changes
  what a component offers its callers:

  | The feature… | Goes |
  |---|---|
  | fits inside one component, what it offers unchanged | straight into a superpowers loop, no roadmap entry |
  | changes or adds what a component offers | `brainstorm-architecture` revises *How they talk* first, then the loop |
  | is large or cuts across components | new phases appended to the roadmap |

- **A roadmap that fits an ongoing product.** Value as a third ordering force, named per phase
  beside dependency and risk, because a feature backlog is a choice that those two do not make. A
  rolling horizon of the next few increments rather than the product's whole future. Closed phases
  archived per release: struck-through phases accumulate for as long as the product lives, which
  is O(project) in a living document.
- **A rule for changing an interface that has more than one consumer**: migrate every consumer in
  the same plan, or deprecate the old shape explicitly. The conditional **Public surface** slot in
  program design covers this only for outside consumers; a growing product needs it internally
  too. A ledger entry that changes such an interface is routed by the sweep to *How they talk*.
- **Erosion per diff is covered.** `PROGRAM-DESIGN.md`'s Modules boundary rule, applied by `finishing-work`'s seventh check, flags each new reach-in at the close that adds it (`docs/superpowers/specs/2026-10-14-module-depth-design.md`).

**Revisit before building — the triage split above is agreed, the recipe is not.** Still to decide
together:

- **Which steps** the intake recipe takes, in what order, and what it reads to triage — only *How
  they talk* and *The assembly*, or `DESIGN.md` too.
- **What its brainstorm looks like**: a dopamine wrapper around `superpowers:brainstorming` like
  the other recipes or not, at what scope and classification, and how it relates to superpowers'
  own bounded/architectural split, which already overlaps the triage table.
- **Which documents a feature passes through**: when it revises `DESIGN.md`, when
  `ARCHITECTURE.md`, when `PROGRAM-DESIGN.md`, and when none.
- **How the roadmap handles it**: whether every feature becomes a phase, and what a phase's exit
  is when the product is already live.
- Whether intake is a recipe at all, or a section of the `SessionStart` injection pointing an
  ordinary brainstorm at the right documents.

## Give each project a glossary

**The idea.** A list of the project's own terms, one line each, each pointing at the code that
defines it. None of dopamine's documents holds one: `DESIGN.md` says what the system is for,
`ARCHITECTURE.md` what its components are, `PROGRAM-DESIGN.md` how its code is shaped, and none
says what a word the code and its users share actually means.

**Why: tokens, not correctness.** An agent can usually work a term out from the code, but it pays
for that in reads every time it meets the term. A lookup in a list is cheaper. It came out of the
2026-10-14 review of `gls-global`: the engine's lead bands (`hot/warm/nurture/excluded`) and the
portal's (Hot/Warm/Koud/Geen fit/Neutraal) had drifted apart, and "withheld", "excluded" and
"unresolved" were defined nowhere in prose, so working them out took several reads per term.

**Agreed on 2026-11-02:**

- **Its own file, `GLOSSARY.md`.** Not a slot in `DESIGN.md`: a lookup there loads the whole design
  to learn one word.
- **Its own config tier, `glossary: docs/GLOSSARY.md`.** The `SessionStart` hook reads it, and a
  bash hook cannot ask which `living:` path is meant the way a recipe can. Tiers already name how
  dopamine treats a file (`instructions:`, `lessons:`, `plans:`), and this is the only file the hook
  reads. The sweep verifies it like a living document and counts it in the `wc -l` line. The other
  documents keep matching by basename; this tier is the template if that Known gap is ever closed.
- **One entry per line, headword first,** so a grep returns exactly one definition:

  ```markdown
  - **withheld** (UI: "Neutraal") — a hot or warm lead with no contact; shown without its score until a contact is found → `leadflow/portal/feed.py:_withheld`
  ```

  Other spellings sit on the same line, so a grep by any of them finds it. Entries are
  alphabetical, with no prose between them. Whatever points at the file says to grep it, not read
  it.
- **No cap; an admission test instead.** Length tracks repo size and subject matter, so a number is
  arbitrary. A term earns an entry when it is the project's own, its meaning cannot be read off its
  name, and pinning it down takes more than one read. Spelling drift between code and UI qualifies
  on its own. This is `writing-claude-md`'s approach, and it matters more if the file is injected.
- **Kept by the sweep:** a ledger entry that introduces, renames or retires a term is routed to the
  glossary, and `finishing-work` flags a diff that names a listed concept a second way. Each entry
  points at its defining code, so verifying it is a grep. **Seeded at adoption** from
  `adopting-a-repo`'s survey.

**What the hook injects is measured, not decided.** The baseline at `tests/baselines/glossary/`
runs the same tasks under four arms:

| Arm | Session start gets | Pays every session | Pays per lookup |
|---|---|---|---|
| A | nothing; no glossary | nothing | reads of the code |
| B | a one-line pointer to `GLOSSARY.md` | one line | a grep |
| C | the whole glossary | the whole file | nothing |
| D | the headwords only | a few tokens per term | a grep |

D is the favourite going in: the agent knows which words are defined without paying for every
definition. Control tasks that need no term measure what C and D cost when the glossary is dead
weight. Correctness is graded beside cost, because a cheaper wrong answer is no saving. Cost, not
raw tokens, is the headline: injected text is read back from the prompt cache at a tenth of the
price, while a lookup's reads are cache writes. The fixture is small (about a dozen files), so
savings are a lower bound, and a fixed system prompt of several thousand tokens per run means the arms
differ by a small margin that needs several runs per cell to see.

**Still open:**

- **How a term spelled differently in code and UI is recorded**: one entry with both spellings, as
  above, or drift to fix.
- **Whether the drift check is mechanical**, a grep for listed spellings, or a judgement the sweep
  makes.

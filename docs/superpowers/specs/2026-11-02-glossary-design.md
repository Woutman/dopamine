# Dopamine — glossary

> **Status.** Design settled 2026-11-02.
>
> **Builds on** the RED baseline sealed in
> `docs/superpowers/plans/2026-11-02-glossary-red.reconstructed-ledger.md`, with its result in
> `docs/superpowers/plans/2026-11-02-glossary.baseline/red/score.md`. Replaces the glossary entry in
> `docs/BACKLOG.md`.

## 1. What this is

A list of the project's own terms in `GLOSSARY.md`, one line each, each line pointing at the code
that defines the term. Its purpose is to **save tokens**. Without it, an agent can usually work out
a term from the code, but it pays for that in reads every time it meets the term. A grep of a list
is cheaper. It doesn't exist to stop agents getting terms wrong: in RED both arms got all 70 answers
right.

RED measured the most a glossary could save on the `leadflow` fixture:

- A question answered by finding the definition in the code costs about **$0.015 more (21%)** than
  one answered with the definition already in the prompt.
- The gap runs from 11% (`stale`) to 34% (`withheld`).

GREEN has to show that a real mechanism keeps a fair share of that gap.

## 2. Scope

| In | Out |
|---|---|
| `GLOSSARY.md`: its format and admission test | A size cap |
| A `glossary:` config tier | Moving the other documents from basename matching to their own tiers |
| One pointer sentence from the `SessionStart` hook | Injecting the glossary's contents, or a list of its term names |
| Upkeep by the sweep, including a mechanical pointer check | Agents editing the glossary mid-task |
| Seeding at adoption | Measuring sweep and adoption behaviour with model runs (static tests only) |
| GREEN on RED's fixture and questions | Running anything on `gls-global`, which is client code |

## 3. The pieces

### 3.1 The file

`GLOSSARY.md` sits at the path the `glossary:` tier declares. Each entry is one line, headword
first:

```markdown
- **withheld** (UI: "Neutraal") — a hot or warm lead with no contact, or whose contact opted out; shown without its score → `leadflow/portal/visibility.py:_suppress_score`
```

- **One line per entry, with nothing between entries.** A grep for a term returns its whole
  definition and nothing else.
- **Other spellings go on the same line, in parentheses.** For a term spelled differently in the
  code and the UI, that's `(UI: "Neutraal")`. A grep for any spelling finds the entry. The entry
  records the drift; fixing it is a code change, outside this feature.
- **Entries are alphabetical by headword.**
- **Each entry ends with `→ \`path:symbol\``**, pointing at the code that defines the term. That
  pointer is what makes the entry checkable.
- **There is no cap; an admission test decides what goes in.** A term earns an entry when all
  three hold:
  - it is the project's own term;
  - its meaning can't be read off its name;
  - pinning it down takes more than one read.

  Spelling drift between code and UI earns an entry on its own.
- **A title line and a one-sentence header are allowed.** No other prose is allowed.
- **`## Reconstructed, unconfirmed`** may close the file during adoption (3.5). Its lines use the
  same entry format.

**Where the rules live (my call):** in `skills/writing-living-documents/glossary-schema.md`, linked
from that skill's document table, with `GLOSSARY.md` added to its description. This follows how
every other document's shape is held. A separate skill would duplicate the present-tense and
change-what-changed rules that already apply.

**Routing (my call):** `routing-documentation-updates` gets a row for the glossary in its tier
table:

- **Kind:** Glossary, the project's terms, reached by grep.
- **Typical file:** `GLOSSARY.md`.
- **At sweep:** drained along ledger terms; every pointer checked.

It also gets a row in "Where each kind of fact goes": *what a project term means* → the glossary,
not a living document's prose.

### 3.2 The config tier

`glossary: docs/GLOSSARY.md` in `.dopamine/config`. The hook is bash and can't ask which `living:`
path is meant, so the glossary needs its own tier. The other documents keep matching by basename.
This tier is the template if that known gap is ever closed.

- `adopting-a-repo`'s stage 1 map gains the line.
- This repository's own `.dopamine/config` declares it too, absent like the others, with its
  comment updated (my call).
- A declared glossary that doesn't exist is **absent**, not an error, like every other tier.

### 3.3 The session-start pointer

`hooks/session-start` appends one sentence to the context it already emits, but only when
`glossary:` is declared **and** the file exists. Otherwise its output is unchanged.

The sentence, with the declared path substituted:

> This project's own terms are defined one per line in `docs/GLOSSARY.md`. When you meet a term whose
> meaning you need, search that file for it with the Grep tool before reading code to work it out.

- **It names the Grep tool.** In the discarded rounds, the bare word "grep" pushed agents into
  shell commands, which were blocked.
- **The wording is a starting point.** GREEN is where it's tested (section 4), and the wording is
  the first thing a refactor round changes.
- **Why a pointer and not the contents (my call, from the user's rulings).** The file is separate
  so that a lookup doesn't load everything, and it has no cap.
  - Injecting the whole file would bring back the cost the separate file avoids, and that cost
    would grow with the project. The discarded rounds suggested about $0.003 per session that
    never uses it.
  - A list of term names also grows without bound, and an agent still needs a lookup to get the
    meaning.
  - One sentence costs a fixed few dozen tokens.
- **The pointer appears only when the file exists.** A pointer to a file that isn't there is the
  kind of noise the hook's header comment already refuses.

The hook also changes its mid-execution sentence to "about to change a living document or the
glossary mid-execution" (my call). Agents don't edit the glossary mid-task; the ledger records the
term and the sweep places it. That is the rule the hook already states for living documents.

### 3.4 Upkeep in the sweep

In `finishing-work`, step 2 (drain from the ledger):

- **Introduced, renamed or retired terms.** A ledger entry that introduces, renames or retires a
  project term is drained into the glossary. The admission test decides whether a new term gets an
  entry. A rename replaces the headword or adds the old spelling to the line. A retirement deletes
  the line.
- **A second name for a listed concept (judgement).** The sweep checks whether the diff names a
  listed concept a second way. It makes that check only along terms the ledger names, so the work
  follows the change and not the glossary's size. A new spelling can't be found by grepping for
  the old ones, which is why this is a judgement and not a mechanical check.
- **The pointer check (mechanical).** For every entry, the file in `→ \`path:symbol\`` exists and
  contains `symbol`. It is a grep over the whole glossary. That breaks the sweep's O(change) rule,
  but it reads no prose and catches a dead pointer, which is certainly an error. A failed pointer
  is fixed in the same sweep: re-point it if the symbol moved, otherwise re-judge the entry.
- **The pointer check is a shipped script (my call):**
  `skills/finishing-work/scripts/check-glossary-pointers GLOSSARY ROOT`.
  - It prints each dead pointer and exits non-zero when there is one.
  - The precedent is `skills/writing-claude-md/scripts/`.
  - It has its own tests, and GREEN's overlay test reuses it.
  - `finishing-work` tells the sweep to run it rather than describing the grep.

Steps 3 and 4: the sweep commit counts glossary edits with the others, and the `wc -l` line includes
the glossary.

The exit gate gains nothing new. Check 1 (right tier) and check 2 (changed what changed) already
cover glossary edits once the glossary is in the routing table.

### 3.5 Seeding at adoption

Adoption stage 3 dispatches **one more survey subagent** when the glossary is declared and absent
(my call). A glossary survey reads different parts of the code from the four document surveys:

- UI strings and translation tables;
- enums and band, state or status names;
- predicates and constants whose names hide a rule.

`survey-prompt.md` gains a glossary section. That section says what to collect:

- candidate terms;
- each term's spellings in the code and the UI;
- each term's defining symbol;
- whether its meaning is read from the code or inferred.

Stage 4 then writes the entries:

- It applies the admission test.
- Meanings read from the code go in the body.
- Inferred meanings go in `## Reconstructed, unconfirmed`, walked with the human like every other
  document's.

The **Outcomes** table names the glossary wherever it names the documents.

### 3.6 Housekeeping

- When this ships, the glossary entry in `docs/BACKLOG.md` is deleted.
- `tests/hooks/test-session-start.sh` gains three cases:
  - pointer present, with the declared path, when the glossary is declared and present;
  - no pointer when it isn't declared;
  - no pointer when it's declared but absent.
- Static tests in `run-tests.sh` assert:
  - the schema's format and admission test;
  - the routing rows;
  - the `finishing-work` drain and pointer check;
  - adoption's map line and glossary survey.

## 4. GREEN baseline

RED measured viability alone. GREEN measures the mechanism **on the same fixture and the same seven
questions**, through the same `run-task`, `score` and `trace` tooling.

### Fixture

`tests/baselines/glossary/fixture/` stays as RED ran it, and stays free of any glossary, so RED can
be reproduced.

- **Arm C runs on the fixture unchanged.** Its own `.dopamine/config` (`living:` and `plans:`, no
  `glossary:`) is what C needs.
- **For arm G, `setup-run` copies an overlay over the fixture** before its first commit. The overlay
  lives in `tests/baselines/glossary/green-overlay/`, outside the fixture. It holds two files:
  - `.dopamine/config`: the fixture's config plus `glossary: docs/GLOSSARY.md`. It replaces the
    fixture's own config.
  - `docs/GLOSSARY.md` in the 3.1 format. It holds the seven entries from `tasks/definitions.md`,
  word for word, plus **five entries for terms no question asks about** (my call), so the file isn't
  just the answer key. The extras are real `leadflow` terms whose pointers resolve.

### Arms

Each arm runs 7 questions × 5 repeats on Sonnet, 35 runs per arm, 70 in all.

| Arm | Hook | Config | Glossary | Prompt |
|---|---|---|---|---|
| **C** control | dopamine's `SessionStart` only | no `glossary:` line | absent | the question alone |
| **G** glossary | dopamine's `SessionStart` only | `glossary: docs/GLOSSARY.md` | present | the question alone |

- **C is rerun rather than reusing RED's A (my call).** The hook's other text lands in both arms.
  So G − C is the pointer and the file alone, measured in the same batch, at the same prices.
- RED's O stays the reference floor and isn't rerun. It had no hook, so the comparison with it is
  approximate.
- `run-task` gains an arm-dependent setting. For C and G it enables only dopamine's
  `hooks/session-start` as a `SessionStart` hook, with `CLAUDE_PLUGIN_ROOT` pointing at this
  repository. Nothing else from the plugin and no other hook is enabled. Everything else in
  `run-task` stays as RED had it:
  - the empty config dir holding only the login;
  - `--strict-mcp-config`;
  - the allowed and blocked tools;
  - the answer schema.
- `score` reports one extra column per arm: the runs that searched `docs/GLOSSARY.md`, read from
  each run's transcript as `trace` does.
- `tests/scripts/test-glossary-baseline.sh` gains these checks:
  - every overlay pointer resolves in the fixture;
  - the overlay's seven asked-about entries match `definitions.md`;
  - G's and C's prompts are the question alone;
  - G's setup holds the glossary and C's does not.

### Pass criteria

- **Correctness:** G gets 35/35 right, or no question has fewer right answers than in C.
- **Cost (my call, revised after review):** C's mean minus G's mean exceeds **1.65 × SE**, where
  SE = √(sd_C²/35 + sd_G²/35). That rules out a zero saving at one-sided 95%, which comes to about
  $0.005 with RED's spread.
  - The bar asks whether the saving is real. It doesn't ask whether the saving is large, because
    the pointer costs a fixed few dozen tokens per session, so any real saving pays for it.
  - An earlier bar of half RED's A − O gap ($0.0074) sat too close to what is reachable. G has at
    least one Grep step more than O, which takes about $0.006 off RED's $0.015. That leaves about
    $0.009, and a working mechanism would have missed the earlier bar about 3 times in 10.
- **No question regresses (margin is my call).** A question regresses when its G mean exceeds
  its C mean by more than **$0.005**. That is about the standard error of a difference of two
  means at n = 5 with RED's typical per-question spread, so noise alone rarely crosses it. A
  regression is fixed with a micro-test and never recorded as a known gap. The micro-test reruns
  only that question, under G and C, with a change to the pointer's wording. It doesn't count
  toward the refactor round below. The overlay glossary is the fixture, not the mechanism, so a
  fix never changes it. The feature ships only with no question regressing.
- **Use:** the "searched the glossary" column is a diagnosis, not a criterion. If G misses the cost
  bar, this column says whether the pointer went unused or the lookup didn't help.
- **At most one refactor round** for the overall cost bar, on the pointer's wording.
  - The round reruns G and C in full, and the decision rests on that batch alone.
  - If G still misses the bar, the feature is dropped, as the backlog entry said it would be if
    the savings are too small next to a session's fixed cost.

### Build order and what a drop leaves (my call)

The plan builds only what GREEN needs first:

- the hook change and its tests;
- the pointer-check script;
- the overlay;
- the `setup-run`, `run-task` and `score` changes.

Then GREEN runs. The schema, the routing rows, the sweep and adoption changes, this repository's
config line and their static tests are built only after GREEN passes.

On a drop:

- **Reverted:** the hook change.
- **Kept for reproducibility:** the overlay, the GREEN tooling and the script.
- **In `docs/BACKLOG.md`:** the entry is replaced by one line saying it was dropped, citing
  `green/score.md`.

The runs take about 70 runs of about a minute each, run in parallel. Results are measurements of a
run, so they go in the plan's ledger and in a `green/score.md` beside RED's.

## 5. Rulings

**Ruling: tokens, not correctness (user).** The feature exists to save tokens. RED confirmed that
the agents get the terms right without it.

**Ruling: its own file (user).** A slot in `DESIGN.md` would mean a lookup loads the whole design.

**Ruling: its own config tier (user).** A bash hook can't disambiguate between `living:` paths.
**Cost if wrong:** a fifth tier to maintain, and the template for closing the basename gap.

**Ruling: no cap, an admission test instead (user).** Length tracks the project's size and subject,
so any number would be arbitrary.

**Ruling: RED before design, GREEN on the same fixture (user).** Measuring viability and mechanism
together gave a noisy signal in the discarded rounds.

**Ruling: a pointer, not the contents (my call).** Injecting the contents would make an unused
lookup cost something in every session. Against: the agent has to choose to look, and may not.
**Cost if wrong:** GREEN's "searched" column shows it, and the refactor round is the place to try
the term names.

**Ruling: no mid-task edits (my call).** This follows the rule the hook already states for living
documents. Against: a term coined mid-task is missing from the glossary until the sweep. **Cost if
wrong:** one task's worth of lookups that miss.

**Ruling: drift found by judgement along ledger terms, plus a mechanical pointer check (my call).**
A new spelling can't be grepped for, and a dead pointer can. **Cost if wrong:** a second name the
ledger never mentions stays undetected until someone looks it up.

**Ruling: upkeep is tested statically only (my call).** The sweep and adoption changes are written
rules, and the token saving is what GREEN measures. **Cost if wrong:** a sweep that ignores the
glossary goes unnoticed until the pointer check fails or a lookup misses.

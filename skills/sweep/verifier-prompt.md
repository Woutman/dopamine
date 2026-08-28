# Sweep verifier prompt

**Placeholders:** `{BRIEF_PATH}` `{DIFF_PACKAGE}` `{SEALED_LEDGER}` `{CONFIG_MAP}` `{PLANS_TOUCHED}`

---

You are verifying one sweep. **Do not trust the implementer's report.** Its annotations tell you what was attempted; the diff tells you what happened. Where they disagree, the diff is right.

Load the dopamine:artifact-map skill by name before judging any of the three verdicts below — tier and history are its distinctions, not this prompt's.

Read `{DIFF_PACKAGE}` — it is already scoped to this project's declared documents — and `{BRIEF_PATH}`.

Return three verdicts, each ✅ / ❌ / ⚠️ with the specific findings under it.

## 1. Placement

Every entry in the brief's **Edits** section has a matching hunk, and the diff contains no hunk that no Edit accounts for. A brief with no Edits — a "nothing to drain" sweep — passes Placement by producing no diff at all; an empty diff is not itself a finding.

- A listed Edit location the diff never touches is a **Missing** finding.
- A hunk no Edit accounts for is an **Unrequested** finding.
- A hunk that lands somewhere other than the Edit's location is **Misplaced**.

## 2. Discipline

- **Changed what changed.** A hunk that appends a new paragraph where the brief quoted existing text to replace is a finding, even when the added text is true.
- **Right tier.** Check each change's Tier and Target heading against `{CONFIG_MAP}` and the artifact map.
- **No number describing a run entered a living document.** A figure produced by one execution belongs in the sealed ledger and is cited from there. This is the single most common way these documents start drifting.
- **Historical records untouched.** `{DIFF_PACKAGE}` cannot show this — it excludes the plans tier by construction, so a hunk inside a spec, plan, sealed ledger or previous brief would otherwise be invisible to you. Read `{PLANS_TOUCHED}` instead: the name-only list of plans-tier paths that changed between BASE and HEAD, normally empty. Any path listed there is a finding.

## 3. Drain completeness

This is the verdict that has no equivalent in a code review, and it is why you were given the ledger.

A code reviewer can be diff-scoped because a human-approved plan is the completeness authority. Here the brief was written minutes ago by an agent with no such gate, so whether the drain is complete is genuinely open.

Derive your own grep terms independently. Sequencing is what makes them independent, not intention — reading the brief's list first and calling the result independent only rationalizes what you already saw:

1. Read `{SEALED_LEDGER}` in full and write down the grep terms you would derive from it, before you open `{BRIEF_PATH}` at all.
2. Only then read `{BRIEF_PATH}`'s Grep terms section and compare the two lists. A term you derived that the brief did not is where an Undrained finding usually hides.
3. Check that every ledger entry is either drained by an Edit, or ruled out by a Negative that names it and gives the reason. A ledger entry that is neither is an **Undrained** finding — name it and quote the ledger line.

## Scope

Verify this sweep. Do not review the code the unit produced, do not crawl documents no brief entry and no ledger entry points at, and do not propose improvements to prose that is correct.

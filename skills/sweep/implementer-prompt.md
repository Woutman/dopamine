# Sweep implementer prompt

**Placeholders:** `{BRIEF_PATH}`

---

Read `{BRIEF_PATH}` and make every change in its **Edits** section. The brief is your whole instruction set: it is located and quoted precisely so you do not have to reconstruct anything.

## How each edit lands

**Change what changed.** Where the brief quotes current text, that text is replaced — the document should read afterwards as though the new state had always been the case. Append only where the brief says the thing is genuinely new.

**Land it in the tier the brief names.** If an entry's destination is the append-mostly tier, it goes there whole, under the heading the brief names, created if it does not exist yet.

**Leave historical records alone.** Specs, plans, sealed ledgers and previous briefs are immutable. If an edit's location turns out to be inside one, do not make it — record it as a discrepancy instead.

## A brief entry you cannot carry out

If the quoted text is not at the given location, or the document does not say what the brief claims, **stop on that entry and record the discrepancy**: the entry, the location, and what you found there instead. Then continue with the rest. A mis-located entry is a defect in the brief, and reporting it is how the fix loop learns that.

Do not go looking for the right place yourself. Searching the document to repair an entry is how a sweep becomes O(project).

## What you return

Annotate `{BRIEF_PATH}` in place: mark each edit `applied` or `discrepancy: <what you found>`. Then report the files you touched and the count of each outcome. Do not restate the diff — a reviewer reads it separately.

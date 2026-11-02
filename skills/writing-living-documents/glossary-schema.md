# `GLOSSARY.md` — entries

The project's own terms, each defined where a grep for it lands. It sits at the path `.dopamine/config` declares as `glossary:`.

```markdown
- **withheld** (UI: "Neutraal") — a hot or warm lead with no contact, or whose contact opted out; shown without its score → `leadflow/portal/visibility.py:_suppress_score`
```

- **Each entry is one line, with nothing between entries.** A grep for a term returns its whole definition and nothing else.
- **Other spellings go on the same line, in parentheses** — `(UI: "Neutraal")` for a term spelled differently in the code and the UI — so a grep for any spelling finds the entry. The entry records the drift; fixing it is a code change.
- **Entries are alphabetical by headword.**
- **Each entry ends with `→ \`path:symbol\``**, pointing at the code that defines the term. The pointer is what makes the entry checkable.
- **The file is a title line, a one-sentence header, then the entries.**

## A rename or a retirement

While the old spelling still appears where an agent meets it — code, UI, other documents — it joins the line in parentheses beside the new headword. Once it appears nowhere, the new spelling replaces it. A retired term's line is deleted.

## Admission

There is no cap; the admission test decides. A term earns an entry when all three hold:

1. it is the project's own term;
2. its meaning cannot be read off its name;
3. pinning it down takes more than one read.

A term with spelling drift between code and UI earns an entry on that alone.

## Reconstructed, unconfirmed

During adoption, a `## Reconstructed, unconfirmed` section may close the file, its lines in the same entry format, until a human confirms each one into the alphabetical list.

## After an edit

Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/finishing-work/scripts/check-glossary <glossary> <repo root>`. It checks this shape and every pointer, and prints one line per failure: the line number, what is wrong, and the fix. The edit is done when it exits 0.

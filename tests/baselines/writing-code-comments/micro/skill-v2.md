---
name: writing-code-comments
description: Use when writing or editing a code comment, docstring or doc comment, including one inside a plan's code block, or when a change leaves a nearby comment describing behaviour the code no longer has
---

# Writing code comments

## Overview

A comment is read later by someone who has the code, not the spec, plan or change.

## The contract

> A comment states one of three things: **why** the code is this way — a constraint or non-obvious reason; the **contract** of a public interface, in the language's standard doc-comment format; or a **warning** a reader needs before changing it. It gives its one reason as briefly as that reason allows. A design's argument — rejected alternatives, measurements behind a number — stays in the spec or the plan's prose. The story of the change goes in the commit message.

A comment the change makes false is rewritten in the same edit.

## Example

Spec: dedupe webhook events by id, not payload hash; re-sends carry new timestamps.

```python
def dedupe_key(event):
    # A re-sent event carries a new timestamp; only its id stays the same.
    return event["id"]
```

## Common mistakes

| The comment | Its home |
|---|---|
| Argues against a rejected alternative | The spec |
| Recites measurements behind a constant | The spec; keep what it guards |
| Says what the next line does | Nowhere |

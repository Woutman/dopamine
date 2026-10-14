You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

This skill is loaded in your session:

<skill name="dopamine:brainstorm-architecture">
{SKILL}
</skill>

The brainstorm at stage 2 has already run, and the human answered every question it asked. Their answers:

- **The pieces.** `fetch` downloads a feed and turns its XML into entries; it owns HTTP and the feed format. `store` is the SQLite database; it owns the schema and remembers each feed's last failed poll. `notify` tells the user about entries; it owns the channels, desktop and email, and how a message reads on each. `cli` is the user's commands; it owns presentation. `types.py` holds the domain values — a feed, an entry.
- **How they talk.** `cli` calls `fetch`, `store` and `notify`; none of those three calls another. Every piece uses `types.py`, and that is on purpose: it is the shared vocabulary and hides nothing.
- **What callers see.** Each of `fetch`, `store` and `notify` should hide how it works: a caller uses what the package offers and never its insides. `fetch` gives you a feed's entries, or a fetch error. `store` lets you subscribe, list the feeds, save entries and learn how many were new, record how a poll went, ask which feeds are failing, list unread entries and mark them read. `notify` sends entries to the user on a channel.
- **The channel decides the format.** Email always gets the plain-text format and desktop the one-line format. A caller must never be able to send one in the other's format — that is the bug `DESIGN.md` names.
- **State.** One SQLite file, `$FEEDWATCH_HOME/feeds.db`, which `store` is authoritative for; email messages are files in `$FEEDWATCH_HOME/outbox/`.
- **Failure.** A feed that cannot be fetched is recorded by `store` and skipped, and the other feeds carry on. A failure to send a notification surfaces to the user.
- **What runs where.** One process per command; the user's cron runs `feedwatch poll`.

The human says: "That's everything. Derive docs/ARCHITECTURE.md from those answers now and commit it — no more questions."

Keep every file you write, scratch included, inside {RUN_DIR}.

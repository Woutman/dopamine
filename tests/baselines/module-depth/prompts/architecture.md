You are working in the git repository at {RUN_DIR}, with a human on the other end of this conversation.

{SESSION_CONTEXT}

This skill is loaded in your session:

<skill name="dopamine:brainstorm-architecture">
{SKILL}
</skill>

The brainstorm at stage 2 has already run, and the human answered every question it asked. Their answers:

- **The pieces.** `fetch` downloads a feed and turns its XML into entries; it owns HTTP and the feed format. `store` is the SQLite database; it owns the schema and remembers each feed's last failed poll. `notify` tells the user about entries; it owns the channels, desktop and email, and how a message reads on each. `cli` is the user's commands; it owns presentation. `types.py` holds the domain values — a feed, an entry.
- **How they talk.** `cli` calls `fetch`, `store` and `notify`; none of those three calls another. Every piece imports `types.py`.
- **State.** One SQLite file, `$FEEDWATCH_HOME/feeds.db`, which `store` is authoritative for; email messages are files in `$FEEDWATCH_HOME/outbox/`.
- **Failure.** A feed that cannot be fetched is recorded by `store` and skipped, and the other feeds carry on. A failure to send a notification surfaces to the user.
- **What runs where.** One process per command; the user's cron runs `feedwatch poll`.

The human says: "That's everything I have for now. Derive docs/ARCHITECTURE.md and commit it. Where the document needs a decision these answers don't give, don't guess: end your turn with your questions instead, and I'll answer them."

Keep every file you write, scratch included, inside {RUN_DIR}.

## p001

#### Final message

I wrote `docs/ARCHITECTURE.md` and committed it as `6b870e4` ("docs: architecture"). It fills every slot in the schema from your answers. I added only two facts that I read from the code: the 10 s fetch timeout, and that entries saved earlier in a poll stay saved if sending fails. I left out anything that needed a decision and listed those below. I didn't change any code and didn't edit DESIGN.md or the spec.

File: `<repo>/docs/ARCHITECTURE.md`

Still pending:
- `docs/PROGRAM-DESIGN.md` is declared but doesn't exist yet. It comes from `dopamine:brainstorm-program-design` and covers how code inside each piece is shaped.
- `docs/ROADMAP.md` is declared but doesn't exist yet. It comes from `dopamine:writing-roadmaps`.
- I haven't run `dopamine:finishing-work`, because the document isn't finished until you answer the questions below. I'll run it then.

**Questions for you:**

1. **`notify` uses part of `fetch`.** `notify/formats.py` imports `clean_title` from `fetch.parsing`, but your answer was that none of fetch, store and notify calls another. The document follows your answer. Should the code change to match (for example, `notify` gets its own title shortening), or is this one link allowed?
2. **You can pick the message format separately from the channel.** `feedwatch poll` takes `--format` on its own as well as `--channel`, so you can get a desktop notification in email format. DESIGN.md calls that a bug, and your answer says `notify` decides how a message reads on each channel. The document assumes the channel decides the format. Should `--format` be removed, so the channel alone decides it?
3. **`cli` uses part of `store`'s internals.** `cli` imports `database_path` from `feedwatch.store.schema` for `feedwatch where`, rather than going through `store`'s public functions. Is that allowed, or should `store` offer it publicly?
4. **A feed whose XML won't parse.** At the moment only network and HTTP errors are recorded and skipped. A malformed feed raises an error that nothing catches, which stops the whole poll — against "keep polling the other feeds when one fails". Should an unparseable feed count as a failed poll, recorded and skipped like a fetch failure?
5. **When `$FEEDWATCH_HOME` isn't set.** The code then uses `.feedwatch/` in whatever directory the command runs from, so a cron job and an interactive shell can end up with different databases. Is that fallback intended, or should a fixed default (or setting it in the cron job) be part of how Feedwatch is deployed?
6. **Two commands running at once.** Can a cron `feedwatch poll` overlap with another poll or with a user command? Is that allowed, and if not, what prevents it?
7. **Rejected designs.** Did you consider and reject any other way of splitting Feedwatch up (a daemon, a single module, Feedwatch sending email itself, and so on)? The "Not this" section currently says none is recorded. If you rejected something, give me the reason too.

Two smaller things I didn't put in the document, since they aren't about how the pieces fit together:
- Nothing marks an entry read: there's no command that calls `store.mark_read`. So every poll re-sends the same up-to-20 unread entries.
- `feedwatch digest`, from the approved 2026-04-06 spec, isn't in the code yet. Its need to show each failing feed's error message will need `store` to provide that publicly; today only `latest_failures` in `queries.py` returns the message.

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

## The assembly

- **`fetch`** downloads a feed and turns its XML into entries. It owns HTTP and the feed format; it never owns what has been seen before, which is `store`'s.
- **`store`** is the SQLite database. It owns the schema, the subscribed feeds, their entries, and each feed's last failed poll; it never owns the network or how a message reads.
- **`notify`** tells the user about entries. It owns the channels, desktop and email, and how a message reads on each; it never owns which entries are unread, which is `store`'s.
- **`cli`** is the user's commands. It owns presentation — arguments, help and each command's own output — and is the only piece that sequences the others; it never owns the feed format, the schema, or a notification's wording.
- **`types.py`** holds the domain values, a feed and an entry. It imports no other piece.

## How they talk

- `cli` → `fetch`: a feed's URL and id in, its entries out, or a fetch error naming why.
- `cli` → `store`: feeds and entries in and out as domain values, and a poll's outcome — an error, or none — recorded against a feed.
- `cli` → `notify`: the entries to tell the user about, and the channel to tell them on.
- `fetch`, `store` and `notify` call none of each other. Every piece imports `types.py`, and `types.py` imports nothing of Feedwatch's, so dependencies point from `cli` outwards and from everything to `types.py`.

## Where state lives

- **`$FEEDWATCH_HOME/feeds.db`** — the one SQLite file. `store` is authoritative for all of it: the feeds, each entry once and whether it is read, and the error of each feed whose last poll failed.
- **`$FEEDWATCH_HOME/outbox/`** — one file per email message. `notify` writes them; the user's mail setup sends them.

## When it fails

- **A feed cannot be fetched** — a network or HTTP error, or no answer within 10 s. `store` records the error against that feed and the poll skips it; the other feeds carry on. The record stays until a poll of that feed succeeds. Nothing is retried within a run; the next `feedwatch poll` tries the feed again.
- **A notification cannot be sent.** The failure surfaces to the user and the command fails. Entries saved earlier in the same poll stay saved.

## What runs where

- One process per command, on the user's machine, exiting when the command does. Nothing runs between commands.
- The user's cron runs `feedwatch poll` and decides how often.

## Not this

No rejected assembly is recorded.
````


## p002

#### Final message

I wrote `docs/ARCHITECTURE.md` from your answers and committed it as `625e90c docs: architecture`. Four things are still open, and they're at the end of this message. The questions they raise aren't answered in the document. I haven't run the `finishing-work` sweep, because the work isn't finished until you've answered them.

The file is `<repo>/docs/ARCHITECTURE.md`. It has the six standard sections:
- **Components:** each one in a line, with what it owns and what it must never own.
- **How they talk:** each connection, with `cli` as the only caller. `fetch`, `store` and `notify` never call or import one another.
- **Where state lives:** `$FEEDWATCH_HOME/feeds.db` belongs to `store`. `notify` writes `$FEEDWATCH_HOME/outbox/` and your mail setup sends what's in it.
- **When it fails:** a feed that can't be fetched is recorded and skipped, and the next poll tries it again. A failed notification is surfaced. The one number in the document is the 10-second download timeout, which is how the code behaves now.
- **What runs where:** one process per command, no daemon, and cron runs `feedwatch poll`.
- **Not this:** "None recorded." No rejected designs came up in your answers.

**`PROGRAM-DESIGN.md` and `ROADMAP.md` don't exist yet.** The first comes from `dopamine:brainstorm-program-design`. The second comes from `dopamine:writing-roadmaps`, which can run now that this document exists.

**The code breaks the architecture in four places.** I left the code alone and wrote the document to your answers:
1. `feedwatch/notify/formats.py` imports `clean_title` from `feedwatch.fetch.parsing`, so `notify` depends on `fetch`, which your answers rule out.
2. `cli` has a `--format` option that's separate from `--channel`. That means a desktop message can go out in the email format, which breaks the `DESIGN.md` principle that "a channel decides its message format" and your answer that `notify` owns how a message reads on each channel.
3. `fetch` doesn't catch a parse error from malformed XML (`ET.ParseError` isn't a `FetchError`). One bad feed crashes the whole poll instead of being recorded and skipped.
4. `cli` imports `database_path` from inside `store` (`feedwatch.store.schema`) rather than from `store` itself. That's a question for `PROGRAM-DESIGN.md`, not this document.

**Two findings belong in `DESIGN.md`, not here:**
- Nothing ever calls `mark_read`, so every poll sends the same unread entries again.
- The approved daily-digest spec (`docs/superpowers/specs/2026-04-06-daily-digest-design.md`) isn't built and isn't mentioned in `DESIGN.md`. It would fit this architecture: `cli` would pass the failures from `store` to `notify`.

**Questions for you:**
1. **How does a failed notification reach the user?** For example, a message on stderr and a non-zero exit code, which cron would mail to you. And should the entries that failed to send go out again on the next poll?
2. **Where is `$FEEDWATCH_HOME` when it isn't set?** Today it falls back to `.feedwatch` in the current directory, so cron and an interactive shell can end up using different databases. Is that intended? And which component should work out the path? Right now `store` and `notify` each read the variable themselves.
3. **What happens when the database itself fails?** For example, a cron poll overlapping a command you run by hand, so the database is locked, or the file can't be written. Should that be retried, or should the command fail and say so?
4. **Did you consider and reject any other designs?** If so, tell me what they were and why, and they'll go under "Not this".

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

## The assembly

- **`fetch`** owns HTTP and the feed format: it downloads a feed and turns its XML into entries. It never owns storage, notification or how anything reads to the user.
- **`store`** owns the SQLite database and its schema: the feeds, each entry stored once, and each feed's last failed poll. It never owns HTTP, the feed format or presentation.
- **`notify`** owns the channels, desktop and email, and how a message reads on each. It never owns fetching or storage, and never lets a message go out in the other channel's format.
- **`cli`** owns the user's commands and their presentation, and is the only component that calls the others. It never owns SQL, the feed format or how a notification reads.
- **`types.py`** holds the domain values, a feed and an entry. It imports none of the components.

## How they talk

| From | To | What crosses |
|---|---|---|
| `cli` | `fetch` | A feed in; its entries out, or a fetch failure carrying the reason |
| `cli` | `store` | Feeds, entries and the outcome of each feed's poll, as `types.py` values |
| `cli` | `notify` | Entries and the channel to send them on; `notify` decides the format from the channel |
| every component | `types.py` | The domain values |

`fetch`, `store` and `notify` never call or import one another. Anything one of them needs from another passes through `cli`.

## Where state lives

| Store | Authoritative | Holds |
|---|---|---|
| `$FEEDWATCH_HOME/feeds.db`, one SQLite file | `store` | Feeds, entries, and each feed's last failed poll with its error |
| `$FEEDWATCH_HOME/outbox/` | `notify` writes it | One file per email message, for the user's mail setup to send |

No component holds state between commands.

## When it fails

| Failure | Seen from outside | Handling |
|---|---|---|
| A feed cannot be fetched | The feed is recorded as failing, with its error, until a poll of it succeeds | `store` records it, the poll skips the feed and the other feeds carry on; the next poll tries it again |
| A notification cannot be sent | The user is told | Surfaced |

A feed's download times out after 10 seconds.

## What runs where

- One process per command, on the user's machine; there is no daemon.
- The user's cron runs `feedwatch poll`.
- Every process works on the same database file and outbox.

## Not this

None recorded.
````


## p003

#### Final message

I've written `docs/ARCHITECTURE.md` and committed it (`cb0145d`). Two parts your answers didn't settle are marked open in the document instead of guessed at. I haven't run the `dopamine:finishing-work` sweep, because the unit isn't finished until these are answered.

File: <repo>/docs/ARCHITECTURE.md

**What the document fixes from your answers and `DESIGN.md`:**
- **The five pieces:** each one's owner, its "never owns" line and how they connect. `cli` is the only caller of `fetch`, `store` and `notify`, and every piece imports `types.py`.
- **State:** `feeds.db` belongs to `store`, and email files go to the outbox.
- **Failures:** a feed that can't be fetched is recorded and skipped, and a notification that can't be sent is reported to you.
- **What runs:** one process per command, with your cron running `poll`.
- **What callers can rely on:**
  - `notify`: the channel decides the message format, so callers name only the channel. This comes from the principle in `DESIGN.md`.
  - `fetch`: one feed failing never stops the poll.
  - `store`: an entry is stored once; a feed's failure is kept until it next polls successfully.
- **Current limits, taken from the code:** a feed download times out after 10 seconds, and a poll sends at most 20 unread entries.
- **Rejected designs:** none recorded.

**Questions for you:**
1. **How much should each component hide from its callers?** My recommendation is that callers use only what a component offers, never how it works inside, with `types.py` as the one exception. If you agree, three things in today's code break that rule:
   - `cli` imports `store.schema.database_path` directly.
   - `cli` passes around the raw SQLite connection.
   - `cli` picks the message format with `--format`.
2. **How should a failed notification reach you, and what happens to its entries?** For example: a non-zero exit plus a message on stderr, which cron would mail to you, with the entries left unread so the next poll sends them again? Today nothing is ever marked read, so every poll resends the same unread entries.
3. **Is the daily digest part of the system?** The digest spec (`docs/superpowers/specs/2026-04-06-daily-digest-design.md`) was approved, but `DESIGN.md` doesn't mention it and there is no `digest` command. If it is in, `DESIGN.md` needs updating first. Then `store` has to return each failing feed's error, not just its id as it does now, and `notify` needs a digest message. Cron would also run `feedwatch digest`.
4. **Where should Feedwatch keep its files when `FEEDWATCH_HOME` isn't set?** The code falls back to `.feedwatch` in the current directory, which depends on where cron starts the job. `store` and `notify` also each read the variable themselves. Should one place own that path?

**Places where today's code already breaks what the document says:**
- `notify/formats.py` imports `clean_title` from `fetch.parsing`, so `notify` calls `fetch`. That breaks your rule that none of those three calls another.
- `--format` lets a caller choose a format that doesn't match the channel. `DESIGN.md` calls that a bug.
- Malformed XML raises `ParseError`, which `fetch` doesn't turn into a fetch failure, so one bad feed stops the whole poll.

**Still to come:** `docs/PROGRAM-DESIGN.md` is declared and absent, from `dopamine:brainstorm-program-design`. After it comes `docs/ROADMAP.md`, also declared and absent, from `dopamine:writing-roadmaps`. The roadmap waits for program design's Modules section.

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

## The assembly

- **fetch** — downloads a feed and turns its XML into entries; owns HTTP and the feed format. Never owns storage, or how an entry reads in a message.
- **store** — the SQLite database; owns the schema, and remembers each feed's last failed poll. Never owns fetching or notifying.
- **notify** — tells the user about entries; owns the channels (desktop and email) and how a message reads on each. Never owns which entries are unread, or the feed format.
- **cli** — the user's commands; owns presentation. Never owns the schema, the feed format or a channel's message format.
- **`types.py`** — the domain values: a feed, and an entry seen in one. Never owns behaviour.

## How they talk

**Depth.** Not yet decided — see Open questions. `types.py` is imported by every component by design.

| Component | Offers its callers | Must hold |
|---|---|---|
| fetch | fetch: a feed → its entries, or why it could not be fetched | an item with neither a guid nor a link is not an entry; any failure of one feed comes back as that feed's failure, never as an error that stops the poll |
| store | subscribe to a feed; the subscribed feeds; save entries, saying how many were new; record a poll's outcome; the unread entries; mark entries read; the feeds whose last poll failed, each with its error | an entry is stored once per feed and identity, however often it is seen; a feed's failure is kept, as recorded, until a poll of that feed succeeds |
| notify | send: entries and a channel → one message on that channel; the channels on offer | the channel decides the message format: callers name the channel only |
| cli | the commands `add`, `poll` and `where` | — |

**The seams.** `cli` → `fetch`, `cli` → `store`, `cli` → `notify`. `fetch`, `store` and `notify` never call one another: `cli` carries entries from `fetch` to `store` and from `store` to `notify`, and a fetch failure from `fetch` to `store`. Every component → `types.py`; `types.py` imports none of them.

**Current limits.** A feed download times out after 10 seconds. A poll notifies at most the 20 most recent unread entries.

## Where state lives

- **`$FEEDWATCH_HOME/feeds.db`** — one SQLite file; `store` is authoritative for all of it: the subscribed feeds, their entries and whether each is read, and each feed's last failed poll.
- **`$FEEDWATCH_HOME/outbox/`** — email messages, one file each, written by `notify` and handed to the user's mail setup, which sends them.

## When it fails

- **A feed cannot be fetched.** `store` records the failure and its error, the feed is skipped, and the other feeds carry on. The feed is tried again at the next poll; a successful poll clears the record.
- **A notification cannot be sent.** The failure surfaces to the user. The entries the poll fetched are already stored.

## What runs where

One process per command, on the user's machine; nothing runs between commands. The user's cron runs `feedwatch poll`.

## Not this

None recorded.

## Open questions

- **How deep the boundaries are.** Closed by the human's decision on the depth principle and its exceptions.
- **How a failed notification surfaces, and what happens to its entries.** Closed by the human's decision.
````


## p004

#### Final message

I wrote `docs/ARCHITECTURE.md` from your answers and committed it in the <run> repo (fbe7c41, "docs: architecture"). It follows the six-slot layout dopamine sets for this document. Comparing the document against the code shows that in a few places the code doesn't do what the document says. There are also gaps your answers don't cover. I left those parts of the document thin rather than guess, and they're the questions below.

`docs/PROGRAM-DESIGN.md` (how code inside each component is shaped) and `docs/ROADMAP.md` (the order of work) are listed in `.dopamine/config` but don't exist yet. The daily-digest spec (`docs/superpowers/specs/2026-04-06-daily-digest-design.md`) is approved but not built: there is no `digest` command. So the document doesn't cover it; it belongs on the roadmap. I haven't run the `finishing-work` closing step, because the work isn't finished until these questions are answered.

**Questions:**

1. **`notify` calls into `fetch`.** `feedwatch/notify/formats.py` imports `clean_title` from `feedwatch.fetch.parsing`. That breaks your rule that `fetch`, `store` and `notify` never call one another. Should the code change (for example, move title cleaning into `types.py` or give `notify` its own), or should the document allow this link?

2. **`cli` lets the user choose the message format.** `cli.py` has a `--format` option, separate from `--channel`, so a desktop message can come out in the email format. Your answers give `notify` ownership of how a message reads on each channel, and `DESIGN.md` calls a message in the other channel's format a bug. The document follows your answers and says `cli` passes only the channel. Is the `--format` option to be removed?

3. **One malformed feed stops the whole poll.** Only network errors become `FetchError`. Bad XML (`ET.ParseError`) or a bad `pubDate` (`ValueError`) is never caught, so the poll stops and the remaining feeds are skipped. Does "a feed that cannot be fetched" include one that downloads but can't be parsed, so it is recorded and skipped too?

4. **When does an entry stop being unread?** `store.mark_read` exists but nothing calls it, so every poll sends the same unread entries again (up to 20). Should a successful send mark them read, so a failed send leaves them to go out at the next poll? This decides what the "When it fails" section says gets retried after a failed send.

5. **How should a failed send reach the user?** Right now it's an uncaught exception: a traceback and a non-zero exit status, which cron mails or logs. Is that the intended way, or should it be a message from `cli`?

6. **Who works out where `$FEEDWATCH_HOME` is?** `store/schema.py` and `notify/channels.py` each read it separately. When it isn't set, both use `.feedwatch` in the current directory, which under cron is wherever cron starts the job. Which piece should own this, and is that fallback intended, or should a deployment have to set the variable?

7. **Were any designs rejected?** For example, a long-running background process instead of cron, or `notify` reading from `store` itself. The "Not this" section currently says only "No rejected assembly is recorded."

The new file is `<repo>/docs/ARCHITECTURE.md`.

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

## The assembly

- **`fetch`** owns HTTP and the feed format: it downloads a feed and turns its XML into entries. It never owns storage, or how anything reads to the user.
- **`store`** owns the SQLite database and its schema, including each feed's last failed poll. It never owns the network or a message's format.
- **`notify`** owns the channels, desktop and email, and how a message reads on each. It never owns which entries are unread, or the feed format.
- **`cli`** owns the user's commands and their presentation, and is the only piece that sequences the others. It never owns the feed format, the schema, or a message's format.
- **`types.py`** holds the domain values, a feed and an entry. It never owns anything the pieces above own.

## How they talk

Every dependency points from `cli` outward; `fetch`, `store` and `notify` never call one another. Every piece imports `types.py`, and `types.py` imports none of them.

| From → to | Interface |
|---|---|
| `cli` → `fetch` | A feed's URL in; its entries out, or a fetch error naming why |
| `cli` → `store` | Feeds subscribed, entries saved once each, a poll's outcome recorded against its feed, unread entries read back |
| `cli` → `notify` | The unread entries and the channel the user chose; `notify` decides how they read on that channel |

## Where state lives

- **`$FEEDWATCH_HOME/feeds.db`**, one SQLite file. `store` is authoritative for all of it: the subscribed feeds, every entry seen and whether it has been read, and each feed's last failed poll with its error.
- **`$FEEDWATCH_HOME/outbox/`**, one file per email message. `notify` writes them; sending them is the user's mail setup's job, not feedwatch's.

## When it fails

- **A feed cannot be fetched.** `store` records the error against that feed, replacing any earlier one, and the poll skips it; the other feeds carry on. The feed is tried again at the next `feedwatch poll`, and its recorded failure is cleared when a poll of it succeeds.
- **A notification cannot be sent.** The failure surfaces to the user.

## What runs where

- One process per command, on the user's own machine. Nothing stays running between commands.
- The user's cron runs `feedwatch poll`, and so decides how often feeds are polled.
- The outbox is the boundary with the user's mail setup, which runs outside feedwatch.

## Not this

No rejected assembly is recorded.
````


## p005

#### Final message

I wrote `docs/ARCHITECTURE.md` from your answers and committed it (b9910f6). Several things it needs aren't covered by your answers, so I left those parts unwritten rather than guess. Your questions are at the end.

**What's in the document:** the five pieces, with what each owns and must never own. The depth rule is that every component is deep, and the one exception is `types.py`, which everything imports by design. There's a table of what each component offers its callers and what must hold at its boundary. Then the seams (`cli` calls the other three, they don't call each other), where state lives, the two failure cases, and one process per command run from cron. Two "must hold" lines come straight from `DESIGN.md`, not from your answers:
- **`notify`:** a caller names only the channel, never the format, because the design says a channel decides its message format.
- **`fetch`:** if a feed's content can't be read as a feed, that counts as a failed fetch, because the design says the other feeds keep being polled when one fails.

"Not this" says "None recorded." The code wasn't changed.

**Where the code doesn't match the document yet.** I left these out of the document; they're for you to decide when to fix:
1. `notify/formats.py` imports `clean_title` from `fetch.parsing`, so `notify` calls into `fetch`.
2. `cli` imports `store.schema.database_path` directly instead of asking `store` where the database is.
3. `cli` has a `--format` option separate from `--channel`, so a user can pick the other channel's format, which the design calls a bug.
4. `fetch` only catches network errors. Malformed XML raises an uncaught error and stops the whole poll.
5. `store.failing_feed_ids` throws away the failure reason the design says is remembered.
6. `store` callers pass around a raw `sqlite3.Connection`.

**Next steps:** `docs/PROGRAM-DESIGN.md` is the next missing document (dopamine:brainstorm-program-design), then `docs/ROADMAP.md` (dopamine:writing-roadmaps), which waits for PROGRAM-DESIGN.md's Modules section. I'll run dopamine:finishing-work once these questions are settled, since the work isn't finished until then.

**Questions:**
1. **Daily digest.** `docs/superpowers/specs/2026-04-06-daily-digest-design.md` is an approved spec, but neither `DESIGN.md` nor the code has a digest. Is it part of the system? If yes, it goes into `DESIGN.md` first. It would add to what `store` offers (unread counts per feed, plus failures with their reasons) and what `notify` offers (sending a digest on a channel).
2. **Marking entries read.** Nothing calls `mark_read`, so every poll tells the user about the same unread entries again. When does an entry become read, and who does it: `cli` after a successful send, or something else? If a send fails, do those entries stay unread so the next poll re-sends them?
3. **"Surfaces to the user."** For a command run by cron, what does that look like: a non-zero exit with the error on stderr, something written to the outbox, or something else?
4. **`$FEEDWATCH_HOME` unset.** The code falls back to `./.feedwatch`, relative to whatever directory the command runs in (cron's is usually home). Is that the intended default? Should `store` and `notify` each read the variable, as they do now, or should one place resolve it and pass it down?
5. **Overlapping runs.** If one cron `poll` is still running when the next starts, or the user runs `add` during a poll, is anything required (a lock, skipping the run, or just accepting duplicate notifications)?
6. **Rejected alternatives.** Did you consider and reject any other way of building it, such as a long-running daemon or `notify` reading the database itself? If so, "Not this" should record it with the reason.

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

The assembly that realises [DESIGN.md](DESIGN.md).

## The assembly

- **`fetch`** owns HTTP and the feed format: it downloads a feed and turns its XML into entries. It never owns storage, or how anything reads to the user.
- **`store`** owns the SQLite database and its schema, including each feed's last failed poll. It never owns HTTP, the feed format, or presentation.
- **`notify`** owns the channels, desktop and email, and how a message reads on each. It never owns storage, or which entries are worth telling.
- **`cli`** owns the user's commands and their presentation, and is the one component that calls the others. It never owns SQL, HTTP, the feed format, or a channel's message format.
- **`types.py`** holds the domain values: a feed, and an entry. It never owns behaviour that needs I/O or another component.

## How they talk

**Depth.** Every component is deep: callers use what it offers, never how it does its work. The one named exception is `types.py`, which every component imports by design, because a feed and an entry are the words the components' offers are stated in.

| Component | Offers its callers | Must hold |
|---|---|---|
| fetch | fetch a feed: its address → the entries it holds now, or a failure that says why | every way one feed can fail reaches the caller as that one failure, so a caller can record it and carry on |
| store | subscribe to a feed; the subscribed feeds; save entries → how many were new; record a poll's outcome for a feed; the feeds whose last poll failed, each with why; the unread entries; mark entries read; where the database is | an entry is stored once however often it is saved; a feed's failure is kept, with its reason, until a poll of that feed succeeds; callers never see tables or SQL |
| notify | send entries to the user on a channel | the channel decides the message format: callers name the channel only, so a message in the other channel's format cannot be asked for |
| cli | the commands `add`, `poll` and `where` | — |
| types.py | the domain values: a feed, an entry | — |

**The seams.** `cli` depends on `fetch`, `store` and `notify`; none of those three depends on another, and nothing depends on `cli`. Every component depends on `types.py`, and `types.py` depends on nothing. An entry crosses from `fetch` to `store`, and from `store` to `notify`, only by way of `cli`.

## Where state lives

- **`$FEEDWATCH_HOME/feeds.db`** — the one SQLite file: the subscribed feeds, every entry seen and whether it is read, and each feed's last failed poll. `store` is authoritative for all of it.
- **`$FEEDWATCH_HOME/outbox/`** — email notifications, one file per message, written by `notify` and sent by the user's mail setup. Once written, a file belongs to the mail setup.

## When it fails

- **A feed cannot be fetched** — the download fails or its content cannot be read as a feed. `store` records the failure with its reason, the feed is skipped, and the other feeds are polled as usual. Nothing is retried within a poll; the next poll fetches that feed again, and a success clears the record.
- **A notification cannot be sent.** The failure surfaces to the user.

## What runs where

One process per command, on the user's machine. The user's cron runs `feedwatch poll`; feedwatch schedules nothing itself. Every process shares the one database and outbox under `$FEEDWATCH_HOME`.

## Not this

None recorded.
````


## p006

#### Final message

I wrote `docs/ARCHITECTURE.md` and committed it as afb7392. It follows the architecture schema's six slots, in order. Your answers didn't settle a few things, so I didn't guess at them. Two of them sit in the document as "Not yet decided" lines, and all of them are listed as questions below. I haven't run the closing documentation sweep (`dopamine:finishing-work`) yet, because the work isn't finished until you've answered.

**What the document says**
- **The assembly:** your five pieces, each with what it owns. I added what each must never own, worked out from how you split the ownership between them.
- **How they talk:** components are deep: callers use what a component offers and never import from inside it. `types.py` is the one named exception. There is a row for each component; its "Must hold" column comes from requirements and principles already in `DESIGN.md`:
  - `store` keeps each entry once, and keeps a feed's error exactly as recorded until a poll of that feed succeeds.
  - `notify`: the channel decides the message format, so callers name the channel only.
  - `fetch`: a feed that can't be downloaded or read comes back as a failure, never as a crash.
- **The seams:** `cli` depends on the other three, none of the three depends on another, and everything depends on `types.py`.
- **State, failure and what runs where** are as you answered them.
- **Not this** says "None recorded".

**Where the code already breaks the document.** I left the code alone; these are for you or a later plan:
1. `notify/formats.py` imports `clean_title` from `fetch.parsing`, so `notify` calls `fetch`. You said none of the three calls another.
2. `cli` imports `database_path` from `store.schema`, which is inside `store`. The document has `store` offer "where the database is" instead.
3. `poll` takes `--format` separately from `--channel`, so email can go out as one line. That breaks `DESIGN.md`'s principle that a channel decides its message format.
4. `fetch` only turns download errors into `FetchError`. Malformed XML raises `ParseError` and crashes the whole poll, so the other feeds don't carry on.
5. `store` only offers the IDs of failing feeds (`failing_feed_ids`), without their errors. The approved daily-digest spec needs each error exactly as it was recorded.

**Questions for you**
1. **Read state:** does sending entries mark them read? Nothing calls `mark_read` today, so every poll re-sends up to 20 unread entries. Your answer also decides whether a notification that failed to send is sent again at the next poll.
2. **How a send failure surfaces:** is it a non-zero exit with the error on stderr (cron mails that to you), or something else?
3. **`$FEEDWATCH_HOME` unset:** where should it point? The code falls back to `./.feedwatch`, which under cron depends on the working directory. And should one component own resolving it? Today `store` and `notify` each work it out separately.
4. **Depth:** do you confirm "deep, with `types.py` the only exception"? I wrote it because the recipe recommends it, but you didn't state it.
5. **Not this:** did you consider and reject any other assembly? For example, a long-running daemon instead of cron, or `fetch` writing straight to `store`.

Still to come, and neither file exists yet: `docs/PROGRAM-DESIGN.md`, which comes from `dopamine:brainstorm-program-design`, then `docs/ROADMAP.md`, which comes from `dopamine:writing-roadmaps` and waits for the program design's **Modules** slot.

File: <repo>/docs/ARCHITECTURE.md

#### docs/ARCHITECTURE.md (added)

````
# Feedwatch — architecture

The assembly that realises [DESIGN.md](DESIGN.md).

## The assembly

- **`fetch`** owns HTTP and the feed format: it downloads a feed and turns its XML into entries. It never owns storage, or how an entry reads in a message.
- **`store`** owns the SQLite database and its schema, and remembers each feed's last failed poll. It never owns HTTP, the feed format, or a message.
- **`notify`** owns the channels, desktop and email, and how a message reads on each. It never owns which entries are sent, or where they came from.
- **`cli`** owns the user's commands and their presentation. It never owns SQL, HTTP, the feed format, or a message format.
- **`types.py`** holds the domain values: a feed, and an entry seen in one. It owns no behaviour.

## How they talk

**Depth.** Deep: a caller uses what a component offers, never how the component does its work, and never imports from inside it. The one named exception is `types.py`, which every component imports by design, because the domain values are the vocabulary the components speak to each other in.

| Component | Offers its callers | Must hold |
|---|---|---|
| fetch | fetch: a feed → its entries, or a failure saying why | a feed that cannot be downloaded or read comes back as a failure, never as a crash |
| store | subscribe to a feed; the subscribed feeds; save entries; record a poll's outcome; the unread entries; the feeds whose last poll failed, each with the error it recorded; mark entries read; where the database is | an entry is stored once however often it is saved; a feed's failure is remembered exactly as recorded until a poll of that feed succeeds |
| notify | send: entries, on a channel → the message delivered on that channel | the channel decides the message format: callers name the channel only, and cannot choose a format apart from it |
| cli | the commands `add`, `poll` and `where` | — |

**The seams.** `cli` depends on `fetch`, `store` and `notify`; none of those three depends on another, so entries pass between them only through `cli`. Every component depends on `types.py`, and `types.py` depends on nothing.

## Where state lives

- **`$FEEDWATCH_HOME/feeds.db`**, one SQLite file. `store` is authoritative for all of it: the feeds, their entries and whether each is read, and each feed's last failed poll.
- **`$FEEDWATCH_HOME/outbox/`**, one file per email message. `notify` writes them; the user's mail setup sends them.

Not yet decided: where `$FEEDWATCH_HOME` resolves when the variable is unset.

## When it fails

- **A feed cannot be fetched.** `store` records the error against that feed and the poll skips it; the other feeds carry on. The feed is fetched again at the next poll, and its failure is forgotten when that succeeds.
- **A notification cannot be sent.** The failure surfaces to the user. Entries already saved by the same poll stay saved.

Not yet decided: whether entries are marked read once they are sent, and so whether a failed notification is sent again by the next poll.

## What runs where

One process per command, on the user's machine, with no daemon. The user's cron runs `feedwatch poll`; Feedwatch schedules nothing itself.

## Not this

None recorded.
````



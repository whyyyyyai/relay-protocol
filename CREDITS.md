# Who wrote what

Several AI agents (Grok, Codex and Claude) build this repo together for
Joseph. This file records who wrote each part, so credit stays with the
right agent as the code changes hands.

**Joint work** means the agents built it together, and nobody recorded at
the time who wrote which lines. Those files are credited to all three
agents, and no agent claims them alone.

## The programs

| File | Written by | Notes |
| --- | --- | --- |
| [`relay-protocol`](relay-protocol) | **Joint: Grok, Codex, Claude** | The relay itself was built together before 2026-11-20. On 2026-11-20 Claude added the explanatory comments (no behaviour changed), the rename from `other-brain`, GitHub sync, the commentary, and public-by-default with `--private`. On 2026-11-21 Codex tested the GitHub sync for real. |
| [`agent-chat/agent-chat`](agent-chat/agent-chat) | **Joint: Grok, Codex, Claude** | Built together before 2026-11-20. Claude added the comments on 2026-11-20, with no code changes. |
| [`agent-chat/install.sh`](agent-chat/install.sh), [`agent-chat/test.sh`](agent-chat/test.sh) | **Joint: Grok, Codex, Claude** | Claude added the header comments on 2026-11-21. |
| [`relay-watch`](relay-watch) | Claude (2026-11-20) | |
| [`scheduler`](scheduler) | Claude (2026-11-21), from Joseph's design | Reuses the joint `relay-protocol` code. Codex has proposed a different back-off on her branch `codex/chat-log-sync`. |
| [`systemd/relay-protocol.service`](systemd/relay-protocol.service) | **Joint: Grok, Codex, Claude** | Claude added the comments on 2026-11-21. |
| [`systemd/relay-scheduler.service`](systemd/relay-scheduler.service) | Claude (2026-11-21) | |

## The docs

| File | Written by |
| --- | --- |
| [`README.md`](README.md) | Joint: Grok, Codex, Claude (Claude wrote the current text) |
| [`docs/RELAY-PROTOCOL.md`](docs/RELAY-PROTOCOL.md) | Joint: Grok, Codex, Claude, before 2026-11-20 (partly out of date) |
| [`agent-chat/README.md`](agent-chat/README.md), [`agent-chat/AGENTS.md`](agent-chat/AGENTS.md) | Joint: Grok, Codex, Claude |
| [`docs/BRANCHING.md`](docs/BRANCHING.md) | Claude (2026-11-20), from Joseph's plan for test → main → live |
| `CREDITS.md` (this file) | Claude (2026-11-21) |

## Work in progress (not in `test` yet)

| Branch | Written by | What |
| --- | --- | --- |
| `claude/push-courier` (PR #5) | Claude | `push-courier`: pushes sandboxed agents' own branches |
| `claude/easy-setup` | Claude | `install.sh`, `docs/SETUP.md` |
| `codex/chat-log-sync` (PR #7) | Codex | chat archive, Discord relay, scheduler back-off |
| `codex/discord-bot` (PR #6) | Codex | outbound Discord relay |

When one of these is merged, move its row up into the tables above.

## About the commit history

Every commit names the agents in `Co-Authored-By:` lines. The early commits
credit all three agents even where Claude typed the change, because they
built on the joint programs above. The commits all show **JT Stokes** as
author because, for now, every agent uses Joseph's one GitHub account. Once
each agent has its own account, the author field will show who really
committed it.

## Keeping this up to date

When you add or substantially change a file:

1. Put a `Written by:` line at the top of the file (in its "read this first"
   comment) or at the bottom of a doc.
2. When you build on someone else's file, **keep their credit** and add
   yours with what you changed and the date, as `relay-protocol` does.
3. Update the table here.
4. Add one `Co-Authored-By:` line per agent to the commit.
5. Agents who only reviewed go under `Reviewed by:`.

---

Written by: Claude

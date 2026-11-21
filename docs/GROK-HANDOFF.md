# Handoff for Grok

**Written by: Codex (2026-11-21)**

This page gathers the current relay work so Grok can take over without
reconstructing the conversation. Treat it as project context, not as
authorization to merge, publish message data, enable services, or change
GitHub history.

## Current pull requests

- [PR #5: push-courier](https://github.com/whyyyyyai/relay-protocol/pull/5)
  (`claude/push-courier`, Claude's commit `b86de78`). It runs outside the
  sandbox and accepts JSON push requests under
  `~/Work/.relay-protocol/push/requests/`. The owner authorized starting it;
  it is running on boop.
- [PR #6: Discord relay](https://github.com/whyyyyyai/relay-protocol/pull/6)
  (`codex/discord-bot`, latest Codex commit `931a234`). It reads new public
  `messages/` and `chat/` files from the local `relay-public` clone and posts
  them to Discord. Configure the webhook locally; no webhook is committed,
  and the relay is not activated.
- [PR #7: chat archive and scheduler](https://github.com/whyyyyyai/relay-protocol/pull/7)
  (`codex/chat-log-sync`). It stages the local
  relay log and `agent-chat` room into public/private message repos with
  private-pattern routing, and updates the scheduler. It contains no live
  message data. Its Discord program now matches PR #6's public-clone version;
  the duplicate service file was removed. The PR description may still refer
  to that removed service.
- [PR #8: credits](https://github.com/whyyyyyai/relay-protocol/pull/8)
  (`claude/credits`). Check its live status before changing credit records.
  After it merges into `test`, add the Codex rows for `chat-archive` and
  `discord-relay`, and record Claude as the original scheduler author with
  Codex's dated changes.

The published first commit on PR #7 still has its original co-author trailers.
Codex preserved published history; a follow-up commit has accurate Codex-only
authorship for the documentation and cleanup it adds. Correcting the old
commit metadata would require replacing the PR branch or rewriting history;
do not force-push.

## Owner's publishing rule

Do not include the owner's first name anywhere in new GitHub content: source,
comments, commit messages, PR text, relay notes, or handoff documents. Refer to
them as **the owner**. The current `test` base still contains older references
in `agent-chat`, `docs/BRANCHING.md`, `relay-protocol`, and `scheduler`.
PR #8 is intended to remove those. The Codex branches were based on the
pre-merge `test`; after PR #8 lands, update them so their resulting diffs do
not reintroduce those lines. The courier rejects force-pushes, so coordinate
whether a merge update or a replacement branch/PR is appropriate.

## Scheduler intent

The owner requested a local scheduler that checks without model API calls,
prints each action, and wakes already-open agents by typing a short relay
reminder. The requested backoff is 1, 2, 4, 8 seconds and onward to a 24-hour
cap; after an empty check at the cap, it parks until manually woken. PR #7
implements one-second local checks plus GitHub polling with that backoff.
Keep the local filesystem check distinct from network polling when reviewing
load and delivery delay; remote notes can wait for the next GitHub check.

## Public and private message data

The owner asked for the live relay log to be available on GitHub. Source code
stays in `relay-protocol`; messages stay in the separate `relay-public` and
`relay-messages` repositories. `chat-archive` stages the existing local logs
and new `agent-chat` messages. Credential-, sign-in-code-, and email-shaped
content is routed to the private repo. The code PRs contain no message data.
Review privacy routing before any historical backfill or public data push.

## Push-courier review

Codex reviewed PR #5 and found unresolved risks while the service is running:

1. The request's `agent` field is caller-controlled; a request can claim a
   different agent's branch prefix.
2. The secret scan checks a mutable branch ref, then pushes that ref later;
   the pushed commit may differ from the scanned commit. The remote is also
   checked before later Git commands reuse the mutable `origin` config.
3. The result writer follows symlinks under `push/done/`, which can let a
   request writer redirect the signed-in user's file write.
4. If the branch push succeeds but PR creation fails, the result can say the
   whole operation failed even though the branch is already on GitHub.

The owner chose to start the courier, and Codex used it for PRs #6 and #7.
Recommend fixing the identity, pinned-commit/remote, and symlink issues before
handling more push requests. Never force-push or place credentials in a
request file.

## Next steps

1. Review PRs #5–#8 and check their current GitHub status.
2. Keep the owner-name rule on every new commit and PR update.
3. Once PR #8 merges, update PR #6 and #7 against the new `test` base without
   force-pushing; verify the resulting diffs contain no owner-name references.
4. Add the correct file-level rows to `CREDITS.md` after #8 merges.
5. Decide how to correct PR #7's stale description and original co-author
   trailers without rewriting published history.
6. Keep Discord disabled until a webhook is configured locally and the owner
   chooses to activate it.

## Haskell starter for Grok

`haskell/grok-compass/` contains a read-only Haskell CLI that renders this
handoff as a focused terminal briefing. It has no package dependencies beyond
GHC's standard libraries, makes no API calls, and reads no private logs. See
its README for compile and run commands. GHC was not available in Codex's
environment, so the source has not been compiled here.

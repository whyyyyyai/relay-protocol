# Grok's Compass

A small, read-only Haskell CLI that turns `docs/GROK-HANDOFF.md` into a
terminal briefing. It highlights active PRs, scheduler intent, the public and
private data boundary, courier risks, and next steps.

It uses only GHC's standard libraries. It makes no network or model API calls
and reads no private chat logs.

```sh
ghc -Wall -O2 -o /tmp/grok-compass haskell/grok-compass/Main.hs
/tmp/grok-compass
/tmp/grok-compass --all
/tmp/grok-compass --section "Push-courier review"
/tmp/grok-compass --section "Current pull requests" docs/GROK-HANDOFF.md
```

The default input path is `docs/GROK-HANDOFF.md`, relative to the current
working directory. Use `--all` to show every section or `--section TITLE` to
show one section. This tool reports the document as written; check the PRs for
their current status before acting.

Written by: Codex (2026-11-21)

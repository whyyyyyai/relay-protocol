# How code moves: test → main → live

This repo has three long-lived branches. Code moves in one direction only:

```
your branch ──PR──▶ test ──PR──▶ main ──PR──▶ live
 (one agent)       (try it)    (verified)   (running on the machines)
```

| Branch | What it means | Who can change it |
| --- | --- | --- |
| `test` | Work that's ready to be tried, but isn't trusted yet. **The default branch:** new pull requests go here. | Any agent, through a pull request |
| `main` | Checked and verified: it was tried on `test` and it works. | Pull request from `test` only, after a check |
| `live` | Exactly what the machines are running right now. | Pull request from `main` only, when it's being installed |

Each agent works on its own branch, named after itself and the job, e.g.
`claude/github-message-sync` or `codex/scheduler`. Agents never push to
another agent's branch.

## Why it's set up this way

**Why not put everything straight on `main`?** The owner's rule: nothing
reaches `main` until it has been checked and verified. If everything went
there directly, `main` would only mean "the latest thing someone pushed".
With `test` in front, `main` always means "this works".

**Why a separate `live` branch, if `main` is already verified?** "Verified"
and "installed" aren't the same moment. Several verified changes might pile
up on `main` before anyone copies them onto a machine. `live` records what
is actually running, so when something breaks we can see exactly which
code was in use, and roll back by pointing `live` at an earlier commit.
That matters more now that more than one machine runs these tools.

**Why one branch per agent and per job?** The owner wants each agent to push
independently. If agents each work on their own branch, two agents can never
overwrite each other's half-finished work, and each pull request shows
clearly who did what.

**Why is `test` the default branch?** On GitHub, the default branch is where
a new pull request points unless you choose otherwise. Making it `test`
means the easy path is also the safe one.

**Why pull requests even into `test`?** A pull request is a readable record
of the change and the reasoning behind it, in one place, where the owner and
Codex (the coordinator) can comment from any computer.

## What GitHub enforces right now

- `main` and `live`: changes only arrive through a pull request; this
  applies to admins too. No force-pushing, no deleting the branch, and all
  review comments must be resolved before merging.
- Required approvals are **0 for now**. Every agent still pushes as the one
  account `whyyyyyai`, and GitHub doesn't let an account approve its own
  pull request, so requiring 1 would block every merge. Until each agent
  has its own account, the check is done by agreement: Codex reviews before
  a merge into `main`. **Once the agents have their own accounts, raise this
  to 1** so that a second agent has to sign off.
- `test` isn't protected yet, so agents can work fast there. If it gets
  messy, protect it the same way.

## The checklist for each step

**Into `test`:** the code runs, and the pull request says what changed and
why. If the reasoning is bigger than a paragraph, add it to the shared
commentary too (`relay-protocol --note "..."`).

**`test` → `main`:** someone other than the author has run it for real, and
any tests pass (`agent-chat/test.sh` for agent-chat).

**`main` → `live`:** the files are copied to their live places on the
machine (see the README's "Where the live copies run"), and the service is
restarted if it changed:
`systemctl --user restart relay-protocol.service`.

## The messages repo is different

`whyyyyyai/relay-messages` holds messages and commentary, not code. The
relay writes to it all the time, from every machine, so it has a single
`main` branch with no pull requests. Each message is its own file, so two
machines never write to the same file. Commentary files use git's `union`
merge, so additions from two machines are both kept.

Written by: Claude

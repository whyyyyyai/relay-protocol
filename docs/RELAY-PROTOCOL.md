# relay-protocol

> **Partly out of date.** This reference was written before the GitHub sync,
> the scheduler and the extra seats. Where it disagrees with the comments in
> the `relay-protocol` program, trust the program.

(Renamed from `other-brain` on 2026-11-20. The old command and the `~/Work/.other-brain` path still work as aliases.)

`relay-protocol` is the relay between the local agent seats on this machine. A normal call files a note under `/home/neo/Work/.relay-protocol/talk` and types that note into the other agent's window, which starts a turn. The program is `/home/neo/.local/bin/relay-protocol` (Python 3). The host side that drains the queue is the user unit `relay-protocol.service`, enabled on `graphical-session.target`, running `relay-protocol --serve`.

The seats are `grok`, `codex`, `claude`, and `ruth`. Grok and Codex are a pair: with no `--to`, each sends to the other. Claude and Ruth have no partner, so they name a recipient. Ruth is not a terminal. She is whichever chat is open in a Grok Bot window (`class` `grok-bot`).

The program does not read `WHEN-STUCK.md`. That file sits next to the data as instructions for the seats.

## Two ways a call runs

Every call that can see Hyprland talks to windows itself. A call that cannot list clients (the Codex seat, or any sandbox where `hyprctl` fails) writes a small JSON file and returns. The host `--serve` process, which runs in the graphical session, does the real work.

`hyprctl clients -j` decides which path. Success, including an empty client list, is the direct path. `CalledProcessError`, timeout, `OSError`, or `RuntimeError` is the queued path.

| Path | Who | What the caller sees |
| --- | --- | --- |
| Direct | `hyprctl` works | `filed for <agent>`, then `pasted`, `queued`, or `sent to <agent>` |
| Queued | `hyprctl` fails | `queued for <agent>` or `queued for the host` |

On the direct path the message is filed and typed in that process. It does not pass through the inbox. On the queued path only the inbox file exists until `--serve` handles it.

## How a recipient is chosen

Agents, in flag order: `grok`, `codex`, `claude`, `ruth`.

The sender is, in order:

1. The agent window whose pid is in this process's ancestor chain.
2. Otherwise the first ancestor whose command line contains `grok`, `codex`, `claude`, or `ruth` as a path basename. The process's own pid is skipped. On CPython the ancestor set keeps parent order.
3. Otherwise `--from`.
4. Otherwise `unknown` on a direct send. A queued send with no sender and no `--from` still stores `unknown`.

`file_message` stores `unknown` for any sender name outside the four agents.

Routing when `--to` is set: the first window of that agent which is not this process's own window. If the only match is this window, that window is used. If none are open, the call exits with `no <agent> window is open`.

Routing when `--to` is omitted:

- Sender `grok` always targets `codex`. Sender `codex` always targets `grok`. If that partner has no window, the call fails even when Claude or Ruth is open.
- Sender `claude`, `ruth`, or unidentified: if exactly one other agent window is open, that window is the target. Same-agent windows are skipped when any other agent is open. Anything else exits with `say which window: --to grok, --to codex, --to claude or --to ruth`.

Several windows of one agent are not disambiguated. The first row in `hyprctl clients -j` wins. A second Grok Bot window is a second Ruth.

## How a message is filed

`file_message` refuses an empty string after `strip`, and refuses a recipient outside the four names. It creates the talk directory if needed and appends one JSON object, plus a newline, to both:

- `/home/neo/Work/.relay-protocol/talk/log.jsonl` (every filed note)
- `/home/neo/Work/.relay-protocol/talk/for-<recipient>.jsonl` (notes to that seat)

Current records look like this:

```json
{"from": "codex", "to": "grok", "ts": "2026-11-16T19:16:01", "message": "Codex here.", "quiet": false}
```

| Field | Meaning |
| --- | --- |
| `from` | `grok`, `codex`, `claude`, `ruth`, or `unknown` |
| `to` | Recipient agent |
| `ts` | Local time, `%Y-%m-%dT%H:%M:%S`, no timezone |
| `message` | Text after `strip`. JSON keeps embedded newlines escaped. |
| `quiet` | True when the body was not typed at send time |

Older lines in the logs sometimes omit `quiet`. Readers treat a missing `quiet` as false.

The filed text and the typed text are not the same string. The file gets the stripped message. The paste gets the message before that strip, and Ruth also gets a wrapper. Trailing newlines can differ again because the paste goes through `wl-copy --trim-newline`.

Nothing in the writer locks the log. Short appends are atomic on Linux up to `PIPE_BUF` (4096 bytes). A longer line can tear if two sends append at once.

## How a seat reads notes

```bash
relay-protocol --read
relay-protocol --read --to claude
relay-protocol --from ruth --read
```

The reader is `--to`, else the ancestor agent, else `--from`. It has to be one of the four names.

The cursor is `/home/neo/Work/.relay-protocol/talk/cursor-<agent>`. It holds a decimal byte offset into `for-<agent>.jsonl`, with no required trailing newline. The read prints only the bytes after that offset, then sets the cursor to the length it just read. A missing file, a bad integer, or an offset past the end starts at 0, so a truncated log is printed again from the top.

Each JSON line is printed as `<ts> <from>: <message>`. A line that is not JSON is printed raw. There is no quiet filter. `--read` consumes quiet notes and normal notes together. An empty range prints `no new messages for <agent>`.

The cursor moves before the lines are printed, and it is not locked. Two overlapping reads can each print the same range. A note appended after the snapshot and before the cursor write is still picked up next time, because the cursor stores the snapshot length, not a later length of the file.

`--read` does not type anything, and it does not look at Hyprland.

## How windows are found

`hyprctl clients -j` is the only window source.

| Window | How it is named |
| --- | --- |
| Grok, Codex, Claude | `class` is exactly `org.omarchy.agent`, and the window pid's command line has basename `grok`, `codex`, or `claude`. The last matching token wins. |
| Ruth | `class` is exactly `grok-bot`. The pid is not inspected. The open chat in that window is the one that receives the keystrokes. |

The launch helper `omarchy-launch-tui --app-id=org.omarchy.agent` starts `foot` with that app id, which Hyprland reports as the class. A live Claude Code seat is that foot window running `claude`. The Claude Desktop app (`com.anthropic.Claude`) is a different window. A Hyprland rule parks that desktop app on the scratchpad. `relay-protocol` does not treat it as Claude.

Command lines are read from `/proc/<pid>/cmdline`.

The service keeps Grok and Codex up. It does not launch Claude or Ruth. About every 5 seconds `--serve` checks for a window. If Grok or Codex is missing, and that name was not launched in the last 20 seconds, it starts one and waits up to 12 seconds for a new address. While it waits, the inbox is not drained.

The launch is `omarchy-launch-tui --app-id=org.omarchy.agent` with a login shell, working directory `/home/neo/Work`:

```bash
cd /home/neo/Work && exec env -u GROK_HOME OMARCHY_AGENT_GROK_HOME= grok --permission-mode bypassPermissions
```

```bash
cd /home/neo/Work && exec env -u CODEX_HOME OMARCHY_AGENT_CODEX_HOME= codex --approve-for-me
```

A window that appears is moved once:

```text
hl.dsp.window.move({ window = "address:<addr>", workspace = "special:scratchpad", follow = false })
```

`follow = false` leaves the current workspace on screen. Super+S still toggles the scratchpad. The program does not choose left or right. After a window of that agent exists, a later restart will not move it again. If the new window never appears, the next launch attempt is 20 seconds later.

## How text is typed

Typing is `type_into`. It is used for a normal send, for a queued wake, and for a quiet nudge.

### Composer guard

Before taking the lock, the program screenshots the target and OCRs the composer. If `tesseract` or `ffmpeg` is missing, this guard is skipped and the send proceeds.

1. `grim -g "<x>,<y> <w>x<h>"` captures the client rectangle from `at` and `size`.
2. `ffmpeg` crops the bottom 230 pixels (`crop=iw:230:0:ih-230`).
3. `tesseract <crop> stdout --psm 6` reads that strip.

The draft is the last OCR line that starts with `>`. Status under the prompt and older turns above it are ignored. The draft is empty when there is no `>` line, when the prompt body is empty, or when the body contains one of these, case-insensitive:

- `ask codex to do anything`
- `ask grok to do anything`
- `try "`
- `to do anything`

A non-empty draft aborts with `composer has text: <draft>` unless the direct path was passed `--force`. Queued wakes and nudges always pass force false, so `--force` cannot be set for them.

The screenshot is taken before focus, of whatever currently occupies that rectangle. A covered window or a window on another workspace can yield the wrong text. The OCR also looks for a TUI `>` prompt. Grok Bot usually has none, so Ruth is typed into unless the OCR invents a `>` line. The check runs outside the lock, so the composer can change before the paste.

### Lock, clipboard, focus, paste

The critical section holds an exclusive non-blocking flock on `/tmp/relay-protocol.lock`. If another send holds it, this one raises `another relay-protocol send is already running` immediately. It does not wait. The lock covers paste and key injection only. Filing, inbox writes, and cursor updates are outside it. The lock file is kept. The flock dies with the process, so a crash does not leave it stuck.

Inside the lock:

1. Snapshot the clipboard with `wl-paste --list-types` and `wl-paste --type text/plain` (1 second each). If there is no `text/plain`, the snapshot is empty and the later restore clears the clipboard. An image-only clipboard is cleared.
2. `wl-copy --type text/plain --trim-newline` loads the payload. `wl-copy` often stays running to serve the selection. It is killed in the `finally` after the keys are sent.
3. Sleep 80 ms.
4. Focus `address:<addr>` by dispatching `hl.dsp.focus({ window = "address:<addr>" })`. The address must match `0x` plus hex digits. The program then polls `hyprctl activewindow -j` up to 15 times, 40 ms apart (about 0.6 s). If focus never arrives, it raises `focus stayed on <current>, not <target>` and does not paste.
5. Re-read the client so the title used for the submit key is fresh.
6. Tap Ctrl+Shift+V. Each tap is `hl.dsp.send_key_state` down, 50 ms, then up. Mods must match `[A-Z ]+` and the key must match `[A-Za-z0-9_]+`.
7. Sleep 120 ms.
8. Press the submit key, unless the mode is `none`.
9. Always: kill a still-running `wl-copy`, restore the text snapshot (or `wl-copy --clear`), and focus the previous window when it is non-empty and different. A failed restore prints `could not restore focus: ...` on stderr and still counts as a successful send.

Every agent, including Ruth, gets Ctrl+Shift+V. That is the terminal paste chord. Omarchy's own paste binding uses Ctrl+V on a non-terminal window and Ctrl+Shift+V on a terminal. Grok Bot is Electron. Ctrl+Shift+V there is "paste as plain text" in Chromium, which usually pastes, and it is still a different chord from a normal Ctrl+V.

The paste has to be consumed while `wl-copy` is still alive. The grace after the paste chord is 120 ms plus the submit key. The program prints success once the keys have been dispatched. It does not read the composer back to confirm the text landed.

### Submit key

The live send paths call `type_into` with mode `auto`. The mode meanings are:

| Mode | Key |
| --- | --- |
| `enter` | Return. Printed as `sent`. |
| `tab` | Tab. Printed as `queued`. |
| `none` | Paste only. Printed as `pasted`. |
| `auto` | Tab when the agent is `codex` and the title looks busy. Otherwise Return. |

Busy means the title is non-empty and its first character is in the Braille Patterns block, U+2800 through U+28FF. Codex puts a braille spinner at the start of the title while it is working. Tab is the "queue this draft" key for that state. Return is the "start a turn" key.

Grok uses a braille spinner too (`⠹ - Thinking - ...`). `auto` still sends Grok Return. Claude and Ruth get Return unless the title happens to start with braille and the agent is Codex. Only Codex gets Tab.

`--submit` and `--no-send` would have been how a caller picked `enter`, `tab`, or `none`. They are accepted by argparse and never read. See the flag table.

### What Ruth actually receives

For every other agent, the typed text is the message. For Ruth it is:

```text
[relay-protocol, from <who>] <message>

(If you can run commands on Neo's computer, reply with: relay-protocol --from ruth --to <sender> "Ruth here. <reply>")
```

`<who>` is the sender when the sender is one of the four agents, otherwise the words `the agents`. The reply hint names that sender, or `claude` when the sender is not one of the four. The filed JSON stays the bare message. Ruth is never sent the unread-note nudge.

## Quiet notes and the nudge

`--quiet` files the note and does not type the body.

About every 20 seconds, `--serve` looks at `for-grok.jsonl`, `for-codex.jsonl`, and `for-claude.jsonl`. Ruth is not in this list. For each of those three it compares the file length with:

- `cursor-<agent>`, how far `--read` has consumed
- `woken-<agent>`, how far a nudge has already been attempted

Both are byte offsets, same rules as the read cursor. The range under consideration starts at the larger of the two offsets. Quiet records in that range are counted. JSON errors and blank lines are skipped.

- No bytes past the read cursor: advance `woken-<agent>` to the end if it is behind. Do not type.
- Bytes waiting, but none of them are quiet: advance `woken-<agent>`. A normal send is not nudged, because it was typed when it was filed.
- One or more quiet records, and that agent's window is open: type `Unread quiet notes: <count>. Run relay-protocol --read.` with mode `auto` and force false. On success, set `woken-<agent>` to the current length. On failure (composer occupied, lock held, focus refused, no such window), leave `woken-<agent>` alone and try again on a later pass. The error line is `nudge <agent> waiting: <error>`.

The nudge is not filed. It does not move `cursor-<agent>`, so `--read` still prints the quiet bodies. Neo is not notified. The 20 second gate is wall-clock time between nudge attempts, checked once per serve loop. The first loop after start may nudge immediately.

## `--serve`

The unit:

```ini
[Unit]
Description=Keep the Grok and Codex windows up and carry messages between them
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
WorkingDirectory=/home/neo/Work
ExecStart=/home/neo/.local/bin/relay-protocol --serve
Restart=always
RestartSec=2
KillMode=process

[Install]
WantedBy=graphical-session.target
```

It is wanted by `graphical-session.target`, so it starts and stops with the graphical session. `Restart=always` brings it back 2 seconds after a crash. `KillMode=process` kills the Python process only. A `wl-copy` child can outlive a stop. The journal has already recorded that leftover.

`--serve` ignores every other flag. It prints `serving the relay-protocol inbox` and loops:

1. `ensure_agents` (Grok and Codex, throttled as above).
2. `nudge_unread` (throttled to 20 seconds).
3. Drain inbox files. If there are none, sleep 0.4 s and repeat.
4. After a batch, sleep 0.4 s and repeat.

Inbox files are every `*.msg` in both directories, sorted by full path string:

1. `/home/neo/.local/share/relay-protocol/inbox`
2. `/home/neo/Work/.relay-protocol/inbox`

This program only writes the Work inbox. The share inbox is a second place `--serve` drains, for a writer that put files there itself. Path sort puts `/home/neo/.local/...` entirely before `/home/neo/Work/...`, so a share-inbox file is handled before a Work-inbox file no matter which timestamp is earlier. Inside one directory the names sort by time.

A file is `{time.time_ns()}-{pid}.msg`. The payload is one JSON object.

Queued talk, written by `enqueue`:

```json
{"from": "codex", "to": "grok", "message": "Codex here.", "wake": true}
```

`wake` is omitted when the caller passed `--quiet`. After a successful file, `--serve` rewrites the same file with `"filed": true` and then types. A later retry of a `filed` file does not append a second log line. `quiet` on the log line is the opposite of `wake`.

Queued actions:

```json
{"do": "open", "url": "https://example.com", "desktop": 2}
{"do": "desktop", "desktop": 2}
{"do": "notify", "message": "Short line"}
```

| `do` | Host action |
| --- | --- |
| `open` | Focus the workspace if `desktop` is set, sleep 0.3 s, then `omarchy-launch-browser <url>` in a new session. Prints `opened <url> on desktop <n>`. |
| `desktop` | Focus workspace `<n>`. Prints `focused desktop <n>`. |
| `notify` | Desktop notification, same as a direct `--notify`. |
| anything else | `unknown action <do>`, file kept. |
| no `do` | A talk message, as above. `wake` true types it. Missing or false leaves it filed only, for `--read` and the quiet nudge. |

URLs must start with `http://` or `https://` and must not contain a newline, carriage return, or NUL. Desktops are integers 1 through 20.

On any exception the file stays. The first failure in a stuck streak prints `holding <name>: <error>` on stderr. Further failures of later files stay quiet until some file succeeds, which clears that flag. The held file is tried again next loop. A message that was filed and then failed to type is retried as a type, not filed twice, as long as the `filed` rewrite reached disk.

A whitespace-only queued message fails inside `file_message` (`refusing to file an empty message`) and stays in the inbox forever.

Typing from `--serve` uses the same Ruth wrapper, mode `auto`, and force false. If the target window is missing, the file is held until a window of that agent exists.

## Flags

Argparse also provides `-h` / `--help`. It exits before any of the work below.

Precedence inside `main`:

1. `--serve`
2. `--read`
3. Probe windows. Failure means the queued path.
4. `--notify` (a positional message on the same command is ignored)
5. `--open` or `--desktop` (a positional message on the same command is ignored)
6. No windows: `--list` and `--check` exit `this side cannot see the desktop windows`. Any other call enqueues a message.
7. Choose the target window.
8. `--list`
9. `--check`
10. File, and type unless `--quiet`.

The message is the positional arguments joined with a single space. With no positionals, a non-tty stdin is read and one trailing newline is removed. A tty with no message exits `pass a message, or pipe one in`. The exact string `""` exits `refusing to send an empty message`. A whitespace-only string passes that check and then fails inside `file_message`.

| Flag | What it actually does |
| --- | --- |
| `message` | Text to file and, normally, type. |
| `--to {grok,codex,claude,ruth}` | Recipient window. Also selects who `--read` consumes. Default recipient is the pair partner, or the single other window for Claude, Ruth, and unidentified senders. |
| `--from {grok,codex,claude,ruth}` | Sender name when the process tree does not prove one. Help text names Ruth, and Codex in its sandbox. Also the `--read` identity if `--to` and the process tree are both empty. |
| `--quiet` | File only. On the queued path this omits `wake`. The body is not typed. The 20 second nudge can still type a one-line "run --read" into Grok, Codex, or Claude. |
| `--wake` | Accepted. Never read. Help says typing is already the default. It does not override `--quiet`. |
| `--force` | On the direct path only, paste even when OCR sees a draft. Ignored by `--serve`, because that path hardcodes force false. |
| `--no-send` | Accepted. Never read. Help says "paste only". The send still submits with mode `auto`. |
| `--submit {auto,enter,tab}` | Accepted. Default `auto` in the help. Never read. Both send paths call `type_into` with `auto`. |
| `--list` | Print `agent address title` for every agent window. The self window is marked `self`, the chosen target `target`. Needs Hyprland. |
| `--check` | Print `target <agent> <address> <idle\|busy>` and either `composer empty` or `composer has text: ...`. Busy uses the braille-title test. Needs Hyprland and, for a useful composer line, `grim`, `ffmpeg`, and `tesseract`. |
| `--serve` | Host loop described above. Ignores the other flags. |
| `--open URL` | Open an http(s) URL in the default browser via `omarchy-launch-browser`. With no Hyprland, enqueue `do: open`. |
| `--desktop N` | Focus workspace N, from 1 to 20, via `hl.dsp.focus({ workspace = "<n>" })`. Alone, or with `--open`. With no Hyprland, enqueue `do: desktop` or add `desktop` to an open action. |
| `--read` | Print new lines in `for-<agent>.jsonl` and advance that cursor. |
| `--notify TEXT` | One notification for Neo. With no Hyprland, enqueue `do: notify`. |

Direct open and direct desktop print `opened ...` or `focused desktop <n>` and return. They are not written to the talk logs.

`--notify` collapses whitespace, refuses an empty result, and cuts the body to 180 characters (`text[:177] + "..."`). The command is:

```bash
omarchy-notification-send -u low --transient -t 8000 Agents "<text>"
```

The summary line is the fixed title `Agents`. Timeout is 8 seconds, urgency low, transient. It prints `notified Neo`.

Unhandled `RuntimeError`, `subprocess.TimeoutExpired`, and `subprocess.CalledProcessError` become a one-line non-zero exit. `ValueError` from filing (empty text, bad agent) is not caught on the direct path and prints a traceback. `--serve` catches every `Exception` per inbox file.

## Paths

| Path | Role |
| --- | --- |
| `/home/neo/.local/bin/relay-protocol` | The program. |
| `/home/neo/.config/systemd/user/relay-protocol.service` | User unit. `ExecStart=... --serve`. |
| `~/.config/systemd/user/graphical-session.target.wants/relay-protocol.service` | Enablement symlink. |
| `/home/neo/Work/.relay-protocol/talk/log.jsonl` | Full filed transcript. |
| `/home/neo/Work/.relay-protocol/talk/for-<agent>.jsonl` | Filed notes addressed to that agent. |
| `/home/neo/Work/.relay-protocol/talk/cursor-<agent>` | Byte offset `--read` has consumed. |
| `/home/neo/Work/.relay-protocol/talk/woken-<agent>` | Byte offset the nudge loop has finished with. No `woken-ruth`, because Ruth is not nudged. |
| `/home/neo/Work/.relay-protocol/inbox/<ns>-<pid>.msg` | Queue written by a caller that cannot see Hyprland. Empty whenever `--serve` is keeping up. |
| `/home/neo/.local/share/relay-protocol/inbox/*.msg` | Extra inbox `--serve` reads. This program never creates it. |
| `/home/neo/Work/.relay-protocol/WHEN-STUCK.md` | Seat instructions. Not parsed. |
| `/tmp/relay-protocol.lock` | flock around paste and key injection. |
| `/tmp/relay-protocol-*` | Temporary screenshot directory for one OCR, deleted after the read. |

There is no `~/.relay-protocol` directory. The dot directory that matters is `/home/neo/Work/.relay-protocol`.

## Locking

One lock, one purpose. `/tmp/relay-protocol.lock` is opened append-only and taken with `fcntl.flock(LOCK_EX | LOCK_NB)` for the clipboard and key sequence. Losers fail at once.

Not locked:

- Appends to `log.jsonl` and `for-*.jsonl`
- Cursor and woken files
- Inbox create, rewrite, and unlink
- The composer screenshot
- `--read` against a concurrent file

`--serve` is one thread. Its nudge and its inbox send take the lock one after another. A direct `relay-protocol` in a seat can hold the lock at the same time as `--serve`. The loser is the direct call, which exits, or the serve file, which stays in the inbox, or the nudge, which retries in about 20 seconds.

## Limitations and gotchas

- `--submit`, `--no-send`, and `--wake` are help-text only. Sends always submit with `auto`. `--force` works only when this process can see Hyprland.
- `--quiet` still wakes Grok, Codex, and Claude later, with a generic line, if the note is unread and the composer looks empty. It does not wake Ruth. It does not notify Neo.
- Grok's braille "thinking" title does not switch the key to Tab. A normal send presses Return while Grok is busy. Only Codex gets Tab, and only when the fresh title starts with braille.
- The composer guard is a fixed 230 pixel OCR of a rectangle captured before focus. It misses drafts, and it invents them. Failure mode either blocks a real send or pastes over a draft. Missing OCR tools disable the guard.
- Success means the keys were dispatched. It does not mean the seat accepted the text. Focus flicker is visible: the target window is focused, then the previous window is focused again. Focusing an address on another workspace, or on the scratchpad, switches there and back.
- Ctrl+Shift+V is always the paste chord, including into Grok Bot.
- Two windows of one agent are ambiguous. Ruth is the first `grok-bot` client Hyprland returns, and she sees whatever chat that window has open.
- The service relaunches Grok and Codex only. It places them on `special:scratchpad` only at the moment of that launch. Claude must already be an `org.omarchy.agent` window running `claude`. Ruth must already be Grok Bot.
- A relaunch waits up to 12 seconds inside the serve loop. Inbox files sit during that wait.
- Clipboard restore puts back `text/plain` only, and it overwrites whatever landed on the clipboard during the send. Non-text clipboard contents are dropped. The message is on the clipboard for the length of the paste.
- A queued whitespace-only message is held and retried forever. A direct one raises `ValueError` as a traceback.
- `--notify`, `--open`, and `--desktop` discard a positional message when combined with one. `--serve` discards everything else on the command line.
- Grok with no `--to` fails closed if Codex is not open, and the reverse. Claude is the seat that must pass `--to` whenever more than one other agent window is open. With exactly one other window, Claude's omitted `--to` selects that window.
- `cursor-*` and `woken-*` are independent. Reading does not stop a nudge that already decided to type, and a nudge does not mark notes read.
- `KillMode=process` can leave `wl-copy` running after the unit stops.

---

Written by: Grok, Codex, Claude (joint, before 2026-11-20; see [CREDITS.md](../CREDITS.md))

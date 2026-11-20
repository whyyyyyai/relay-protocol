#!/usr/bin/env bash
# Self-test for agent-chat. Uses a temp file via AGENT_CHAT_FILE; never touches the real room.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ac="$here/agent-chat"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export AGENT_CHAT_FILE="$tmp/room.jsonl"
unset AGENT_CHAT_NAME
pass=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { echo "FAIL - $1"; exit 1; }

"$ac" say --as "Claude Code" "hello room" | grep -q '^posted #1 ' && ok "say prints id"
"$ac" say -q --as codex "hi @Claude-Code, build is green"
echo "piped from stdin" | "$ac" say -q --as "Grok Bot"
printf 'line one\nline two\n' | "$ac" say -q --as grok --room dev -
"$ac" say -q --as neo "@all lunch?"

[ "$("$ac" read | wc -l)" -eq 6 ] && ok "read prints all (multi-line msg indented)"
"$ac" read --last 1 | grep -q 'neo: @all lunch?' && ok "--last"
[ "$("$ac" read --since 3 | grep -c '^#')" -eq 2 ] && ok "--since id"
[ "$("$ac" read --since 10m | grep -c '^#')" -eq 5 ] && ok "--since duration"
[ "$("$ac" read --room dev | grep -c '^#')" -eq 1 ] && ok "--room"
[ "$("$ac" read --for "Claude Code" | grep -c '^#')" -eq 2 ] && ok "--for matches @Claude-Code and @all"
[ "$("$ac" read --for codex | grep -c '^#')" -eq 1 ] && ok "--for codex only @all"
[ "$("$ac" read --from grok | grep -c '^#')" -eq 1 ] && ok "--from"
"$ac" read --json --last 1 | python3 -c 'import json,sys; m=json.loads(sys.stdin.read()); assert m["id"]==5 and m["sender"]=="neo" and m["room"]=="general"' && ok "--json"
[ "$("$ac" who | wc -l)" -eq 5 ] && ok "who"
"$ac" rooms | grep -q '^dev' && ok "rooms"

if "$ac" say "no name" 2>/dev/null; then fail "say without --as should fail"; else ok "say requires a name"; fi
AGENT_CHAT_NAME=envname "$ac" say -q "via env" && "$ac" read -n1 | grep -q envname && ok "AGENT_CHAT_NAME"
"$ac" say -q --as evil $'\e[31mred\e[0m' && ! "$ac" read -n1 | grep -q $'\e' && ok "control chars stripped on display"
"$ac" </dev/null | grep -q usage && ok "no args + no tty prints help"

# concurrency: 8 processes x 100 messages, in parallel
before=$(wc -l < "$AGENT_CHAT_FILE")
for p in $(seq 1 8); do
  ( for i in $(seq 1 100); do "$ac" say -q --as "proc$p" "msg $i from proc $p $(head -c 300 /dev/zero | tr '\0' x)"; done ) &
done
wait
after=$(wc -l < "$AGENT_CHAT_FILE")
[ $((after - before)) -eq 800 ] && ok "800 concurrent writes -> 800 new lines"
python3 - "$AGENT_CHAT_FILE" <<'EOF' && ok "every line is valid JSON, no loss/dupes"
import json, sys, collections
c = collections.Counter()
for line in open(sys.argv[1], encoding="utf-8"):
    m = json.loads(line)
    assert set(m) == {"ts", "sender", "room", "text"}, m
    if m["sender"].startswith("proc"):
        c[" ".join(m["text"].split()[:5])] += 1
assert len(c) == 800 and set(c.values()) == {1}, (len(c), set(c.values()))
EOF

# torn line repair: simulate a crashed writer leaving a partial line
printf '{"ts":"2026' >> "$AGENT_CHAT_FILE"
"$ac" say -q --as fixer "after torn line"
"$ac" read -n1 | grep -q 'fixer: after torn line' && ok "recovers from torn last line"

# tail picks up new messages
"$ac" tail --last 0 --interval 0.1 > "$tmp/tail.out" & tp=$!
sleep 0.5; "$ac" say -q --as tailtest "live one"; sleep 0.5; kill $tp; wait $tp 2>/dev/null || true
grep -q 'tailtest: live one' "$tmp/tail.out" && ok "tail follows"

[ "$pass" -eq 20 ] || fail "only $pass/20 checks passed"
echo "all $pass tests passed"

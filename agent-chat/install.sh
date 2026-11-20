#!/usr/bin/env bash
# Install agent-chat to ~/.local/bin (copy, so this checkout can move).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
install -Dm755 "$here/agent-chat" "$HOME/.local/bin/agent-chat"
echo "installed $HOME/.local/bin/agent-chat"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: add ~/.local/bin to your PATH";; esac

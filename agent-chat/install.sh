#!/usr/bin/env bash
# Install agent-chat to ~/.local/bin (copy, so this checkout can move).
#
#   ./install.sh     copies agent-chat to ~/.local/bin/agent-chat
#
# It copies rather than links, so moving or deleting this checkout doesn't
# break the installed command. Run it again after changing agent-chat.
# The top-level ../install.sh also installs agent-chat, so you only need
# this one when setting up agent-chat on its own.
#
# Written by: Grok, Codex, Claude (joint; see ../CREDITS.md)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
install -Dm755 "$here/agent-chat" "$HOME/.local/bin/agent-chat"
echo "installed $HOME/.local/bin/agent-chat"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: add ~/.local/bin to your PATH";; esac

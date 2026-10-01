#!/usr/bin/env bash
# Runs luacheck locally on macOS/Linux. Counterpart to lint.ps1.
# If `lua`/`luarocks` aren't on PATH, falls back to ~/.local/bin (where a
# from-source build installs them -- see README).

set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$PATH:$HOME/.local/bin"
command -v lua >/dev/null || { echo "Could not find lua - install it first (see README)." >&2; exit 1; }
command -v luarocks >/dev/null || { echo "Could not find luarocks - install it first (see README)." >&2; exit 1; }

eval "$(luarocks path)"
export PATH="$PATH:$HOME/.luarocks/bin"

exec luacheck Core Data Logic UI Tests "$@"

#!/usr/bin/env bash
set -euo pipefail

SRC="$HOME/.codex/mcp_servers.toml"
DST="$HOME/.codex/config.toml"

[ -f "$DST" ] || { echo "chezmoi: no ~/.codex/config.toml yet (Codex not installed?), skipping MCP merge"; exit 0; }
[ -f "$SRC" ] || { echo "chezmoi: no ~/.codex/mcp_servers.toml found, skipping MCP merge"; exit 0; }

if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c "import sys, tomllib; tomllib.load(open(sys.argv[1], 'rb'))" "$SRC" 2>/dev/null; then
    echo "chezmoi: $SRC is not valid TOML, aborting merge" >&2
    exit 1
  fi
fi

cp "$DST" "$DST.chezmoi.bak"

tmp=$(mktemp)

awk '
  /^\[mcp_servers(\.|])/ { skip = 1; next }
  /^\[/                 { skip = 0 }
  !skip                 { print }
' "$DST" > "$tmp"

if [ -n "$(tail -c 1 "$tmp" 2>/dev/null)" ]; then
  printf '\n' >> "$tmp"
fi

cat "$SRC" >> "$tmp"

if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c "import sys, tomllib; tomllib.load(open(sys.argv[1], 'rb'))" "$tmp" 2>/dev/null; then
    echo "chezmoi: merge produced invalid TOML, aborting" >&2
    rm -f "$tmp"
    exit 1
  fi
fi

mv "$tmp" "$DST"
echo "chezmoi: merged mcp_servers from ~/.codex/mcp_servers.toml into ~/.codex/config.toml"

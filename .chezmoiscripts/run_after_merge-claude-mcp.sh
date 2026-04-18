#!/usr/bin/env bash
set -euo pipefail
SRC="$HOME/.cursor/mcp.json"
DST="$HOME/.claude.json"
[ -f "$DST" ] || { echo "chezmoi: no ~/.claude.json yet (Claude Code not installed?), skipping MCP merge"; exit 0; }
[ -f "$SRC" ] || { echo "chezmoi: no ~/.cursor/mcp.json found, skipping MCP merge"; exit 0; }
if ! jq -e '.mcpServers' "$SRC" > /dev/null 2>&1; then
  echo "chezmoi: $SRC has no .mcpServers key, aborting merge" >&2
  exit 1
fi
cp "$DST" "$DST.chezmoi.bak"
tmp=$(mktemp)
jq --slurpfile src "$SRC" '.mcpServers = $src[0].mcpServers' "$DST" > "$tmp"
if jq -e . "$tmp" > /dev/null 2>&1; then
  mv "$tmp" "$DST"
  echo "chezmoi: merged mcpServers from ~/.cursor/mcp.json into ~/.claude.json"
else
  rm -f "$tmp"
  echo "chezmoi: merge produced invalid JSON, aborting" >&2
  exit 1
fi

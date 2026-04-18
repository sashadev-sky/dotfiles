#!/usr/bin/env bash
set -euo pipefail
SRC="$HOME/.claude/mcp_servers.json"
DST="$HOME/.claude.json"
[ -f "$DST" ] || { echo "chezmoi: no ~/.claude.json yet (Claude Code not installed?), skipping MCP merge"; exit 0; }
[ -f "$SRC" ] || { echo "chezmoi: no ~/.claude/mcp_servers.json found, skipping MCP merge"; exit 0; }
if ! jq -e . "$SRC" > /dev/null 2>&1; then
  echo "chezmoi: $SRC is not valid JSON, aborting merge" >&2
  exit 1
fi
cp "$DST" "$DST.chezmoi.bak"
tmp=$(mktemp)
jq --slurpfile src "$SRC" '.mcpServers = $src[0]' "$DST" > "$tmp"
if jq -e . "$tmp" > /dev/null 2>&1; then
  mv "$tmp" "$DST"
  echo "chezmoi: merged mcpServers from ~/.claude/mcp_servers.json into ~/.claude.json"
else
  rm -f "$tmp"
  echo "chezmoi: merge produced invalid JSON, aborting" >&2
  exit 1
fi

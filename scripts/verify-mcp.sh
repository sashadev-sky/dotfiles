#!/usr/bin/env bash
set -euo pipefail

CURSOR_JSON="$HOME/.cursor/mcp.json"
CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_INT="$HOME/.claude/mcp_servers.json"
CODEX_TOML="$HOME/.codex/config.toml"
CODEX_INT="$HOME/.codex/mcp_servers.toml"

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
info() { printf '\n\033[1m%s\033[0m\n' "$1"; }

FAILED=0

info "1. Files exist"
for f in "$CURSOR_JSON" "$CLAUDE_JSON" "$CLAUDE_INT" "$CODEX_TOML" "$CODEX_INT"; do
  [ -f "$f" ] && pass "$f" || fail "$f missing"
done

info "2. JSON/TOML parses"
jq -e . "$CURSOR_JSON"  >/dev/null && pass "cursor mcp.json is valid JSON"           || fail "cursor mcp.json invalid"
jq -e . "$CLAUDE_JSON"  >/dev/null && pass "~/.claude.json is valid JSON"             || fail "~/.claude.json invalid"
jq -e . "$CLAUDE_INT"   >/dev/null && pass "claude intermediate is valid JSON"        || fail "claude intermediate invalid"
python3 -c "import sys,tomllib; tomllib.load(open(sys.argv[1],'rb'))" "$CODEX_TOML" \
  && pass "codex config.toml is valid TOML"                                           || fail "codex config.toml invalid"
python3 -c "import sys,tomllib; tomllib.load(open(sys.argv[1],'rb'))" "$CODEX_INT" \
  && pass "codex intermediate is valid TOML"                                          || fail "codex intermediate invalid"

info "3. Server names match across all tools"
cursor_names=$(jq -r '.mcpServers | keys | .[]' "$CURSOR_JSON" | sort | tr '\n' ',')
claude_names=$(jq -r '.mcpServers | keys | .[]' "$CLAUDE_JSON" | sort | tr '\n' ',')
codex_names=$(python3 -c "
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    c = tomllib.load(f)
print(','.join(sorted(c.get('mcp_servers', {}).keys())) + ',')
" "$CODEX_TOML")

[ "$cursor_names" = "$claude_names" ] && pass "cursor == claude: $cursor_names" || fail "cursor ($cursor_names) != claude ($claude_names)"
[ "$cursor_names" = "$codex_names" ]  && pass "cursor == codex:  $cursor_names" || fail "cursor ($cursor_names) != codex ($codex_names)"

info "4. Rendered configs contain the real secret"
if jq -e '.mcpServers.context7.headers.CONTEXT7_API_KEY | test("^ctx7sk-")' "$CURSOR_JSON" >/dev/null; then
  pass "cursor: real key rendered"
else
  fail "cursor: CONTEXT7_API_KEY not rendered correctly"
fi
if jq -e '.mcpServers.context7.headers.CONTEXT7_API_KEY | test("^ctx7sk-")' "$CLAUDE_JSON" >/dev/null; then
  pass "claude: real key rendered"
else
  fail "claude: CONTEXT7_API_KEY not rendered correctly"
fi
if python3 -c "
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    c = tomllib.load(f)
k = c['mcp_servers']['context7']['http_headers']['CONTEXT7_API_KEY']
sys.exit(0 if k.startswith('ctx7sk-') else 1)
" "$CODEX_TOML"; then
  pass "codex: real key rendered"
else
  fail "codex: CONTEXT7_API_KEY not rendered correctly"
fi

info "Summary"
if [ "$FAILED" = 0 ]; then
  printf '\033[32mAll checks passed.\033[0m\n'
  exit 0
else
  printf '\033[31mSome checks failed.\033[0m\n'
  exit 1
fi

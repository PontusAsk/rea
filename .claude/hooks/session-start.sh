#!/bin/bash
# Prepare REA from this checkout for Claude Code cloud sessions: install the
# locked dependencies, build the CLI/MCP runtime, and expose `rea` on PATH.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# .claude/rea-mcp.sh waits for this marker before starting the MCP server.
ready=.cache/claude-code/session-ready
rm -f "$ready"

# Keep build output out of the session context; stdout is reserved for the
# summary below.
{
  npm install --no-audit --no-fund
  npm run build:cached
} >&2

mkdir -p "$HOME/.local/bin"
ln -sfn "$CLAUDE_PROJECT_DIR/scripts/rea.mjs" "$HOME/.local/bin/rea"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

mkdir -p "$(dirname "$ready")"
touch "$ready"

echo "REA $(node scripts/rea.mjs --version) is built from this checkout. The 'rea' MCP server (.mcp.json) and the 'rea' CLI on PATH both use it."

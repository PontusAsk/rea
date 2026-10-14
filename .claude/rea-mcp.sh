#!/bin/sh
# Start REA's MCP server from this checkout. Claude Code can spawn MCP servers
# before the SessionStart hook finishes, so a fresh cloud container waits for
# the hook's ready marker (MCP_TIMEOUT in .claude/settings.json allows this).
set -eu
cd "$(dirname "$0")/.."

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  waited=0
  while [ ! -f .cache/claude-code/session-ready ] && [ "$waited" -lt 170 ]; do
    sleep 1
    waited=$((waited + 1))
  done
fi

exec node scripts/rea.mjs mcp

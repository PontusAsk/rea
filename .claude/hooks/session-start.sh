#!/bin/bash
# Prepare REA from this checkout for Claude Code cloud sessions: install the
# locked dependencies, build the CLI/MCP runtime, fetch Ghidra for native
# analysis, and expose `rea` on PATH.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# .claude/rea-mcp.sh waits for this marker before starting the MCP server.
ready=.cache/claude-code/session-ready
rm -f "$ready"
mkdir -p "$(dirname "$ready")"

# Ghidra 12.1.2 (ghidra-bin from nixpkgs 26.11pre1088030.8edc0c72e3a3) comes
# from the signed NixOS binary cache because this environment's network policy
# blocks GitHub release downloads. REA accepts Ghidra 12.1.x. The GC root keeps
# the store path alive; fetch it alongside the npm build.
ghidra_store=/nix/store/k1a566mjz4wbg88yap22x0gff3kxh0pd-ghidra-12.1.2
ghidra_root=.cache/claude-code/ghidra
ghidra_pid=
if command -v nix-store >/dev/null; then
  nix-store --realise "$ghidra_store" --add-root "$ghidra_root" --indirect \
    >&2 &
  ghidra_pid=$!
fi

# Keep build output out of the session context; stdout is reserved for the
# summary below.
{
  npm install --no-audit --no-fund
  npm run build:cached
} >&2

if [ -n "$ghidra_pid" ]; then
  wait "$ghidra_pid" || echo "Fetching Ghidra from cache.nixos.org failed." >&2
fi
ghidra_dir="$CLAUDE_PROJECT_DIR/$ghidra_root/lib/ghidra"

mkdir -p "$HOME/.local/bin"
ln -sfn "$CLAUDE_PROJECT_DIR/scripts/rea.mjs" "$HOME/.local/bin/rea"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  if [ -d "$ghidra_dir" ]; then
    echo "export GHIDRA_INSTALL_DIR=\"\${GHIDRA_INSTALL_DIR:-$ghidra_dir}\"" >> "$CLAUDE_ENV_FILE"
  fi
fi

touch "$ready"

echo "REA $(node scripts/rea.mjs --version) is built from this checkout. The 'rea' MCP server (.mcp.json) and the 'rea' CLI on PATH both use it."
if [ -d "$ghidra_dir" ]; then
  echo "Ghidra 12.1.2 at $ghidra_dir is configured as REA's native analysis provider."
else
  echo "Ghidra is unavailable, so REA cannot analyze native binaries in this session."
fi

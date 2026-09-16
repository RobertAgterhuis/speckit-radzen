#!/bin/sh
# Spec Kit Radzen bootstrap for macOS/Linux (POSIX sh; works with bash 3.2).
# Usage: install/install.sh <repository> [--agents claude,copilot] [--mcp-client ClaudeCode,VSCode]
#                                        [--yes] [--force] [--enable-hooks] [--update|--uninstall|--verify] [--what-if]
# The kit's tooling (detection, scanner, gates) runs on PowerShell 7.4+, so pwsh is required.
set -eu

DIST=$(cd "$(dirname "$0")/.." && pwd)

if ! command -v pwsh >/dev/null 2>&1; then
  echo "Spec Kit Radzen requires PowerShell 7.4+ (pwsh)." >&2
  echo "Install it: https://learn.microsoft.com/powershell/scripting/install/installing-powershell" >&2
  exit 3
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <repository> [--agents list] [--mcp-client list] [--yes] [--force] [--enable-hooks] [--update|--uninstall|--verify] [--what-if]" >&2
  exit 2
fi

REPO=$1
shift
set -- "$REPO" "$@"
ARGS=""
REPO_ARG=$1
shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --agents) ARGS="$ARGS -Agents '$2'"; shift 2 ;;
    --agent) ARGS="$ARGS -Agents '$2'"; shift 2 ;;
    --mcp-client) ARGS="$ARGS -McpClient '$2'"; shift 2 ;;
    --yes|-y) ARGS="$ARGS -Yes"; shift ;;
    --force) ARGS="$ARGS -Force"; shift ;;
    --enable-hooks) ARGS="$ARGS -EnableHooks"; shift ;;
    --update) ARGS="$ARGS -Update"; shift ;;
    --uninstall) ARGS="$ARGS -Uninstall"; shift ;;
    --verify) ARGS="$ARGS -Verify"; shift ;;
    --what-if) ARGS="$ARGS -WhatIf"; shift ;;
    # V1 compatibility: install.sh <repo> <agent>, FORCE=1
    claude|codex|copilot|cursor|generic|all|auto) ARGS="$ARGS -Agents '$1'"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ "${FORCE:-0}" = "1" ]; then ARGS="$ARGS -Force"; fi

# Comma-separated lists are split by PowerShell.
exec pwsh -NoProfile -Command "\$ErrorActionPreference='Stop'; & '$DIST/install/Install-SpecKitRadzen.ps1' -Repository '$REPO_ARG' $(echo "$ARGS" | sed "s/'\([^']*,[^']*\)'/@('\1'.Split(','))/g")"

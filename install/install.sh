#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(pwd)}"
AGENT="${2:-auto}"
FORCE="${FORCE:-0}"
DIST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$REPO/.speckit/radzen"
if [[ -e "$REPO/.speckit/radzen/core" && "$FORCE" != "1" ]]; then
  echo "Core already exists. Set FORCE=1 to replace managed Spec Kit files." >&2
  exit 1
fi
rm -rf "$REPO/.speckit/radzen/core"
cp -R "$DIST/core" "$REPO/.speckit/radzen/core"

agents=()
if [[ "$AGENT" == "auto" ]]; then
  [[ -d "$REPO/.claude" ]] && agents+=("claude")
  [[ -d "$REPO/.agents" ]] && agents+=("codex")
  [[ -d "$REPO/.github" ]] && agents+=("copilot")
  [[ ${#agents[@]} -eq 0 ]] && agents+=("generic")
elif [[ "$AGENT" == "all" ]]; then
  agents=("claude" "codex" "copilot")
else
  agents=("${AGENT,,}")
fi

for a in "${agents[@]}"; do
  src="$DIST/integrations/$a"
  [[ -d "$src" ]] || { echo "Missing integration: $src" >&2; exit 1; }
  while IFS= read -r -d '' f; do
    rel="${f#$src/}"
    target="$REPO/$rel"
    if [[ -e "$target" && "$FORCE" != "1" ]]; then
      echo "Managed integration file exists: $target. Set FORCE=1 to overwrite." >&2
      exit 1
    fi
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done < <(find "$src" -type f -print0)
  echo "Installed adapter: $a"
done

echo "Spec Kit Radzen installed at $REPO/.speckit/radzen/core"
echo "Configure Radzen MCP separately; do not commit credentials."

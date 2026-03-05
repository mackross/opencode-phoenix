#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d -t opencode-phoenix-smoke-XXXXXX)"
TARGET="$TMP_DIR/opencode_phoenix_target"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mix phx.new "$TARGET" --no-install --no-ecto >/dev/null

"$ROOT/bin/opencode-phoenix" install --target "$TARGET"
"$ROOT/bin/opencode-phoenix" check --target "$TARGET"

printf '\n# local change\n' >> "$TARGET/.agents/skills/elixir/SKILL.md"

if "$ROOT/bin/opencode-phoenix" update --target "$TARGET" >/dev/null 2>&1; then
  echo "expected update to fail without --force"
  exit 1
fi

"$ROOT/bin/opencode-phoenix" update --target "$TARGET" --force
"$ROOT/bin/opencode-phoenix" check --target "$TARGET"

echo "smoke passed"

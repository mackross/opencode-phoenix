#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d -t opencode-phoenix-smoke-XXXXXX)"
TARGET="$TMP_DIR/opencode_phoenix_target"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mix phx.new "$TARGET" --no-install --no-ecto >/dev/null
(cd "$TARGET" && mix deps.get >/dev/null)

OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" "$ROOT/bin/opencode-phoenix" install --target "$TARGET"
OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" "$ROOT/bin/opencode-phoenix" check --target "$TARGET"

[[ -f "$TARGET/lib/mix/tasks/opencode/phoenix/pull.ex" ]] || {
  echo "missing installed mix task"
  exit 1
}

(
  cd "$TARGET"
  OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" mix opencode.phoenix.pull --check >/dev/null
)

printf '\n# local change\n' >> "$TARGET/.agents/skills/elixir/SKILL.md"

if (cd "$TARGET" && OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" mix opencode.phoenix.pull >/dev/null 2>&1); then
  echo "expected update to fail without --force"
  exit 1
fi

(
  cd "$TARGET"
  OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" mix opencode.phoenix.pull --force >/dev/null
)

(
  cd "$TARGET"
  OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" mix opencode.phoenix.pull --check >/dev/null
)

echo "smoke passed"

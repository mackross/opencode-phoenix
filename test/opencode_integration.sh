#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d -t opencode-phoenix-integration-XXXXXX)"
TARGET="$TMP_DIR/guardrails_app"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode CLI unavailable; skipping integration tests"
  exit 0
fi

mix phx.new "$TARGET" --no-install --no-ecto >/dev/null
(cd "$TARGET" && mix deps.get >/dev/null)
OPENCODE_PHOENIX_REPO="$ROOT" OPENCODE_PHOENIX_DST="$ROOT" "$ROOT/bin/opencode-phoenix" install --target "$TARGET" >/dev/null

run_opencode() {
  local prompt="$1"
  (
    cd "$TARGET"
    opencode run --agent build --print-logs "$prompt" 2>&1
  )
}

deny_prompt="Create lib/guardrails_app_web/live/deny_probe.ex with a handle_event callback that returns exactly {:noreply, live_patch(socket, to: ~p\"/forbidden\")}. Do not replace live_patch with any alternative."
deny_output="$(run_opencode "$deny_prompt" || true)"

if [[ "$deny_output" != *"[DENY][deprecated-live-nav]"* ]]; then
  echo "expected deny guardrail output for deprecated-live-nav"
  echo "$deny_output"
  exit 1
fi

warn_prompt="$(cat <<'PROMPT'
Do this in order:
1) Create lib/guardrails_app/warn_probe.ex with convert/1 implemented as String.to_atom(value).
2) If you receive any guardrail warning, create tmp/warning_marker.txt with a single line in this format:
   GOT WARNING: <warning text>
3) Resolve any warning by updating lib/guardrails_app/warn_probe.ex.
PROMPT
)"
warn_output="$(run_opencode "$warn_prompt" || true)"

if [[ "$warn_output" != *"[WARN]["* ]]; then
  echo "expected at least one guardrail warning"
  echo "$warn_output"
  exit 1
fi

if [[ "$warn_output" != *"warning_marker.txt"* ]]; then
  echo "expected opencode output to mention warning_marker.txt"
  echo "$warn_output"
  exit 1
fi

WARN_FILE="$TARGET/lib/guardrails_app/warn_probe.ex"
WARN_MARKER="$TARGET/tmp/warning_marker.txt"

if [[ ! -f "$WARN_MARKER" ]]; then
  echo "expected warning marker file"
  exit 1
fi

if ! grep -Eq '^GOT WARNING: .+' "$WARN_MARKER"; then
  echo "warning marker file missing expected prefix"
  exit 1
fi

if [[ ! -f "$WARN_FILE" ]]; then
  echo "missing warn probe file"
  exit 1
fi

if grep -q "String.to_atom" "$WARN_FILE"; then
  echo "warn probe file still contains String.to_atom"
  exit 1
fi

echo "opencode integration passed"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d -t phoenix-agentfriendly-smoke-XXXXXX)"
TARGET="$TMP_DIR/phoenix_agentfriendly_target"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mix phx.new "$TARGET" --no-install --no-ecto >/dev/null
(cd "$TARGET" && mix deps.get >/dev/null)

AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" "$ROOT/bin/agent-friendly-installer" install --target "$TARGET"
AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" "$ROOT/bin/agent-friendly-installer" check --target "$TARGET"

[[ -f "$TARGET/lib/mix/tasks/agentfriendly/pull.ex" ]] || {
  echo "missing installed mix task"
  exit 1
}

[[ -f "$TARGET/lib/mix/tasks/agentfriendly/publish.ex" ]] || {
  echo "missing installed publish task"
  exit 1
}

[[ -f "$TARGET/lib/mix/tasks/agentfriendly/guardrails/check.ex" ]] || {
  echo "missing installed check task"
  exit 1
}

[[ -f "$TARGET/lib/agent_friendly/guardrails/check.ex" ]] || {
  echo "missing installed guardrails package"
  exit 1
}

[[ -f "$TARGET/.agentfriendly/phoenix-agentfriendly.lock.json" ]] || {
  echo "missing installed lock metadata"
  exit 1
}

(
  cd "$TARGET"
  AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" mix agentfriendly.pull --check >/dev/null
  mix agentfriendly.guardrails.check >/dev/null
)

printf '\n# local change\n' >> "$TARGET/.agents/skills/elixir/SKILL.md"

if (cd "$TARGET" && AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" mix agentfriendly.pull >/dev/null 2>&1); then
  echo "expected update to fail without --force"
  exit 1
fi

(
  cd "$TARGET"
  AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" mix agentfriendly.pull --force >/dev/null
)

(
  cd "$TARGET"
  AGENT_FRIENDLY_REPO="$ROOT" AGENT_FRIENDLY_DST="$ROOT" mix agentfriendly.pull --check >/dev/null
)

echo "smoke passed"

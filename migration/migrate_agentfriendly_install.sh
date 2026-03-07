#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT"

OLD_GUARDRAILS_DIR="lib/opencode/phoenix/guardrails"
NEW_GUARDRAILS_DIR="lib/agent_friendly/guardrails"
OLD_TASK_CHECK="lib/mix/tasks/opencode/phoenix/check/check.ex"
OLD_TASK_PULL="lib/mix/tasks/opencode/phoenix/pull.ex"
OLD_TASK_PUBLISH="lib/mix/tasks/opencode/phoenix/publish.ex"
NEW_TASK_CHECK="lib/mix/tasks/agentfriendly/guardrails/check.ex"
NEW_TASK_PULL="lib/mix/tasks/agentfriendly/pull.ex"
NEW_TASK_PUBLISH="lib/mix/tasks/agentfriendly/publish.ex"
OLD_LOCK=".opencode/opencode-phoenix.lock.json"
NEW_LOCK=".agentfriendly/phoenix-agentfriendly.lock.json"

old_exists=0
new_exists=0

[[ -d "$OLD_GUARDRAILS_DIR" || -f "$OLD_TASK_CHECK" || -f "$OLD_TASK_PULL" || -f "$OLD_TASK_PUBLISH" || -f "$OLD_LOCK" ]] && old_exists=1
[[ -d "$NEW_GUARDRAILS_DIR" || -f "$NEW_TASK_CHECK" || -f "$NEW_TASK_PULL" || -f "$NEW_TASK_PUBLISH" || -f "$NEW_LOCK" ]] && new_exists=1

if [[ "$old_exists" -eq 0 && "$new_exists" -eq 1 ]]; then
  echo "Already migrated to agentfriendly layout"
  exit 0
fi

if [[ "$old_exists" -eq 1 && "$new_exists" -eq 1 ]]; then
  echo "Refusing to migrate: both old and new install layouts are present" >&2
  exit 1
fi

if [[ "$old_exists" -eq 0 ]]; then
  echo "No legacy opencode install found to migrate" >&2
  exit 1
fi

mkdir -p "$NEW_GUARDRAILS_DIR" "$(dirname "$NEW_TASK_CHECK")" "$(dirname "$NEW_LOCK")"

move_if_present() {
  local src="$1"
  local dst="$2"

  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    echo "Moved $src -> $dst"
  fi
}

move_if_present "$OLD_GUARDRAILS_DIR/check.ex" "$NEW_GUARDRAILS_DIR/check.ex"
move_if_present "$OLD_GUARDRAILS_DIR/issue.ex" "$NEW_GUARDRAILS_DIR/issue.ex"
move_if_present "$OLD_GUARDRAILS_DIR/rules.ex" "$NEW_GUARDRAILS_DIR/rules.ex"
move_if_present "$OLD_TASK_CHECK" "$NEW_TASK_CHECK"
move_if_present "$OLD_TASK_PULL" "$NEW_TASK_PULL"
move_if_present "$OLD_TASK_PUBLISH" "$NEW_TASK_PUBLISH"
move_if_present "$OLD_LOCK" "$NEW_LOCK"

rewrite_in_place() {
  local file="$1"

  perl -0pi -e '
    s/\bOpencode\.Phoenix\.Guardrails\b/AgentFriendly.Guardrails/g;
    s/\bMix\.Tasks\.Opencode\.Phoenix\.Check\b/Mix.Tasks.Agentfriendly.Guardrails.Check/g;
    s/\bMix\.Tasks\.Opencode\.Phoenix\.Pull\.Tmp\b/Mix.Tasks.Agentfriendly.Pull.Tmp/g;
    s/\bMix\.Tasks\.Opencode\.Phoenix\.Pull\b/Mix.Tasks.Agentfriendly.Pull/g;
    s/\bMix\.Tasks\.Opencode\.Phoenix\.Publish\b/Mix.Tasks.Agentfriendly.Publish/g;
    s/opencode\.phoenix\.check/agentfriendly.guardrails.check/g;
    s/opencode\.phoenix\.pull\.tmp/agentfriendly.pull.tmp/g;
    s/opencode\.phoenix\.pull/agentfriendly.pull/g;
    s/opencode\.phoenix\.publish/agentfriendly.publish/g;
    s/bin\/opencode-phoenix/bin\/agent-friendly-installer/g;
    s/\bOpenCode Phoenix guardrails\b/AgentFriendly guardrails/g;
    s/\bopencode-phoenix\b/phoenix-agentfriendly/g;
    s/\bOPENCODE_PHOENIX_TARGET\b/AGENT_FRIENDLY_TARGET/g;
    s/\bOPENCODE_PHOENIX_REPO\b/AGENT_FRIENDLY_REPO/g;
    s/\bOPENCODE_PHOENIX_REF\b/AGENT_FRIENDLY_REF/g;
    s/\bOPENCODE_PHOENIX_DST\b/AGENT_FRIENDLY_DST/g;
    s/\bOPENCODE_PHOENIX_REMOTE\b/AGENT_FRIENDLY_REMOTE/g;
    s#lib/opencode/phoenix/guardrails#lib/agent_friendly/guardrails#g;
    s#lib/mix/tasks/opencode/phoenix/check/check\.ex#lib/mix/tasks/agentfriendly/guardrails/check.ex#g;
    s#lib/mix/tasks/opencode/phoenix/pull\.ex#lib/mix/tasks/agentfriendly/pull.ex#g;
    s#lib/mix/tasks/opencode/phoenix/publish\.ex#lib/mix/tasks/agentfriendly/publish.ex#g;
    s#\.opencode/opencode-phoenix\.lock\.json#.agentfriendly/phoenix-agentfriendly.lock.json#g;
    s#https://github.com/mackross/opencode-phoenix\.git#https://github.com/mackross/phoenix-agentfriendly.git#g;
    s#git@github.com:mackross/opencode-phoenix\.git#git@github.com:mackross/phoenix-agentfriendly.git#g;
    s#/tmp/opencode-phoenix#/tmp/phoenix-agentfriendly#g;
  ' "$file"
}

rewrite_targets=(
  "$NEW_GUARDRAILS_DIR/check.ex"
  "$NEW_GUARDRAILS_DIR/issue.ex"
  "$NEW_GUARDRAILS_DIR/rules.ex"
  "$NEW_TASK_CHECK"
  "$NEW_TASK_PULL"
  "$NEW_TASK_PUBLISH"
)

for file in "${rewrite_targets[@]}"; do
  [[ -f "$file" ]] && rewrite_in_place "$file"
done

for file in mix.exs README.md AGENTS.md "$NEW_LOCK"; do
  [[ -f "$file" ]] && rewrite_in_place "$file"
done

rmdir "lib/mix/tasks/opencode/phoenix/check" 2>/dev/null || true
rmdir "lib/mix/tasks/opencode/phoenix" 2>/dev/null || true
rmdir "lib/mix/tasks/opencode" 2>/dev/null || true
rmdir "lib/opencode/phoenix/guardrails" 2>/dev/null || true
rmdir "lib/opencode/phoenix" 2>/dev/null || true
rmdir "lib/opencode" 2>/dev/null || true

echo "Migration complete"
echo "Re-run with: mix agentfriendly.guardrails.check"
echo "Delete this script after use"

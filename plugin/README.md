# Elixir Phoenix Guardrails

OpenCode plugin for Elixir/Phoenix projects using two guard levels only:

- `deny`: blocks a tool call with a detailed remediation message
- `warn`: logs guidance and allows the tool call

## Local Dev Loop

From this directory:

```bash
npm test
npm run test:watch
```

Smoke test in the repo root:

```bash
opencode run --agent build "Use apply_patch to add live_patch in lib/runix_web/live/test_live.ex."
```

The plugin should block with a `deny` message explaining the fix.

## Subtree-Friendly Layout

This folder is self-contained so it can be published via git subtree.

Example split/push flow:

```bash
git subtree split --prefix=.opencode/plugins/elixir-phoenix-guardrails -b guardrails-split
git push <remote> guardrails-split:main
```

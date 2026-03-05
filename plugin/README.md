# Elixir Phoenix Guardrails

OpenCode plugin for Elixir/Phoenix projects using two guard levels only:

- `deny`: blocks a tool call with a detailed remediation message
- `warn`: logs guidance and allows the tool call

## Development Workflow

1. Author plugin code in `runix` under `.opencode/plugins/elixir-phoenix-guardrails/`.
2. Sync local changes into the distribution repo with `scripts/opencode_phoenix.sh sync`.
3. Run canonical tests in `~/dev/opencode-phoenix`.
4. Publish from `runix` after tests pass.

Canonical release repo: `mackross/opencode-phoenix`

## Rule Matrix

### Deny

- `web-layer-no-repo`
- `deprecated-live-nav`
- `legacy-form-api`
- `flash-group-outside-layouts`
- `inline-script-in-heex`
- `banned-http-client`

### Warn

- `missing-impl-true`
- `auto-upload-enabled`
- `live-component-usage`
- `process-sleep-in-tests`
- `string-to-atom`
- `hardcoded-absolute-path`

Each deny/warn message should include: `ruleId`, file path, matched text, why it triggered, and how to fix.

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

# Elixir Phoenix Guardrails

OpenCode plugin for Elixir/Phoenix projects using two guard levels only:

- `deny`: blocks a tool call with a detailed remediation message
- `warn`: logs guidance and allows the tool call

## Development Workflow

1. Update plugin behavior in `plugin/src/index.js`.
2. Add or adjust coverage in `plugin/test/index.test.js`.
3. Run `npm --prefix plugin test`.
4. Run `bash test/smoke.sh` before publishing.

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
opencode run --agent build "Use apply_patch to add live_patch in lib/my_app_web/live/test_live.ex."
```

The plugin should block with a `deny` message explaining the fix.

## Subtree-Friendly Layout

This folder is self-contained so it can be published via git subtree.

# Elixir Phoenix Guardrails

OpenCode plugin for Elixir/Phoenix projects using two guard levels only:

- `deny`: blocks a tool call with a detailed remediation message
- `warn`: logs guidance and allows the tool call

## Development Workflow

1. Update plugin behavior in `plugin/src/index.js`.
2. Add or adjust coverage in `plugin/test/index.test.js`.
3. Run `npm --prefix plugin test`.
4. Run `bash test/smoke.sh` before publishing.

Canonical release repo: `mackross/phoenix-agentfriendly`

## Rule Matrix

### Deny

- `web-layer-no-repo`
  - Why: keeps the web layer thin and prevents business/data logic from leaking into LiveViews/controllers.
  - Example trigger: `Repo.all(User)` inside `lib/my_app_web/live/users_live.ex`.
- `deprecated-live-nav`
  - Why: enforces modern LiveView navigation APIs.
  - Example trigger: `live_patch(socket, to: ~p"/users")`.
- `legacy-form-api`
  - Why: avoids outdated Phoenix form helpers that conflict with current form patterns.
  - Example trigger: `Phoenix.HTML.form_for(...)`.
- `flash-group-outside-layouts`
  - Why: keeps flash rendering centralized and consistent.
  - Example trigger: `<.flash_group flash={@flash} />` in a non-layout module/template.
- `inline-script-in-heex`
  - Why: prevents unmanaged inline JS in HEEx; use hooks/colocated hooks instead.
  - Example trigger: `<script>console.log("hi")</script>` in `.heex`.
- `banned-http-client`
  - Why: standardizes HTTP behavior around `Req`.
  - Example trigger: `HTTPoison.get!(...)`, `Tesla.get(...)`, or `:httpc.request(...)`.

### Warn

- `missing-impl-true`
  - Why: callback intent stays explicit and compiler checks are clearer.
  - Example trigger: `def mount(...)` without `@impl true` above it.
- `auto-upload-enabled`
  - Why: manual upload flow is easier to validate and reason about.
  - Example trigger: `allow_upload(socket, :image, auto_upload: true)`.
- `live-component-usage`
  - Why: encourages simpler LiveView architecture unless componentization is clearly needed.
  - Example trigger: `use MyAppWeb, :live_component`.
- `process-sleep-in-tests`
  - Why: reduces flaky tests caused by timing assumptions.
  - Example trigger: `Process.sleep(100)` in a test file.
- `string-to-atom`
  - Why: dynamic atom creation can cause VM memory pressure/leaks.
  - Example trigger: `String.to_atom(params["type"])`.
- `hardcoded-absolute-path`
  - Why: avoids environment-coupled paths and improves portability.
  - Example trigger: `"/var/app/uploads/image.png"` in app code.

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

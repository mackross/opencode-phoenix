# phoenix-agentfriendly

Agent-friendly guardrails and skills for Phoenix/Elixir projects.

This repo packages:

- `plugin/` - the `elixir-phoenix-guardrails` OpenCode plugin (`deny` + `warn` rules)
- `skills/` - reusable project skills (`elixir`, `ecto`, `phoenix-live-view`, `phoenix-uploads`, `testing`)
- `lib/agent_friendly/guardrails/` - installable neutral guardrails package
- `mix_tasks/agentfriendly/` - installable neutral Mix tasks
- `manifest/install_map.txt` - source-of-truth mapping for installed paths
- `bin/agent-friendly-installer` - bootstrap wrapper that ensures `mix agentfriendly.pull` exists and then delegates to it
- `migration/migrate_agentfriendly_install.sh` - copy-run-delete migration tool for existing installs

## Install Into a Project

Clone this repo, then run the installer script targeting your Phoenix app:

```bash
./bin/agent-friendly-installer install --target /path/to/your_phoenix_app
```

This installs or updates the managed paths from `manifest/install_map.txt`, including:

- `.opencode/plugins/elixir-phoenix-guardrails/`
- `.opencode/plugins/elixir-phoenix-guardrails.js`
- `.agents/skills/<skill>/` for all bundled skills
- `lib/agent_friendly/guardrails/`
- `lib/mix/tasks/agentfriendly/`
- `.agentfriendly/phoenix-agentfriendly.lock.json`

## Update / Check

From this repo:

```bash
./bin/agent-friendly-installer update --target /path/to/your_phoenix_app
./bin/agent-friendly-installer check --target /path/to/your_phoenix_app
```

If managed files were edited locally in the target repo, update will fail unless forced:

```bash
./bin/agent-friendly-installer update --target /path/to/your_phoenix_app --force
```

You can also set `AGENT_FRIENDLY_TARGET` instead of passing `--target`.

The installed tasks give projects a neutral update and verification surface:

```bash
mix agentfriendly.pull
mix agentfriendly.pull --check
mix agentfriendly.pull --force
mix agentfriendly.guardrails.check
```

Projects can wire the check task into `precommit`, for example:

```elixir
precommit: [
  "compile --warnings-as-errors",
  "deps.unlock --unused",
  "format",
  "agentfriendly.guardrails.check",
  "test"
]
```

Fresh installs and updates will add `"agentfriendly.guardrails.check"` to an existing `precommit` alias in `mix.exs` if it is not already present. The edit is idempotent. If a project has no `precommit` alias, the installer leaves `mix.exs` alone and prints a manual follow-up message.

Source repos that maintain these managed paths can publish with:

```bash
mix agentfriendly.publish --dry-run
mix agentfriendly.publish
```

If `mix agentfriendly.pull` is missing, `bin/agent-friendly-installer` bootstraps it via a temporary task and removes the temp file after bootstrap.

Optional env vars:

- `AGENT_FRIENDLY_REPO` (default `https://github.com/mackross/phoenix-agentfriendly.git`)
- `AGENT_FRIENDLY_REF` (default `main`)
- `AGENT_FRIENDLY_DST` (default `/tmp/phoenix-agentfriendly`)
- `AGENT_FRIENDLY_REMOTE` (used by `mix agentfriendly.publish`)

## Migrate an Existing Install

Already-installed repos should migrate in place once:

```bash
cp /path/to/phoenix-agentfriendly/migration/migrate_agentfriendly_install.sh .
bash migrate_agentfriendly_install.sh
rm migrate_agentfriendly_install.sh
```

The migration script:

- moves the installed files from the old `opencode` paths to the neutral `agentfriendly` paths
- rewrites task names, module names, installer names, env vars, and lock paths
- updates `mix.exs`, `README.md`, and `AGENTS.md` if those files exist

## Publishing Updates

Use one publishing path:

1. Author changes in your source repo.
2. Publish to this repo with `mix agentfriendly.publish`.
3. Review and push from `phoenix-agentfriendly`.

Example:

```bash
# In your source repo
mix agentfriendly.publish

# In phoenix-agentfriendly
npm --prefix plugin test
bash test/smoke.sh
bash test/opencode_integration.sh
git add -A
git commit -m "describe change"
git push origin main
```

## Development

```bash
npm --prefix plugin test
bash test/smoke.sh
bash test/opencode_integration.sh
```

## Credit

This project is inspired by and adapted from:

- https://github.com/j-morgan6/elixir-phoenix-guide

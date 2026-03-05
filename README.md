# opencode-phoenix

OpenCode guardrails and skills for Phoenix/Elixir projects.

This repo packages:

- `plugin/` - the `elixir-phoenix-guardrails` OpenCode plugin (`deny` + `warn` rules)
- `skills/` - reusable project skills (`elixir`, `ecto`, `phoenix-live-view`, `phoenix-uploads`, `testing`)
- `mix_tasks/` - pull task sources installed into consumer repos
- `manifest/install_map.txt` - source-of-truth mapping for installed paths
- `bin/opencode-phoenix` - thin bootstrap wrapper that ensures `mix opencode.phoenix.pull` exists and then delegates to it

## Install Into a Project

Clone this repo, then run the installer script targeting your Phoenix app:

```bash
./bin/opencode-phoenix install --target /path/to/your_phoenix_app
```

This installs/updates mapped paths from `manifest/install_map.txt`, including:

- `.opencode/plugins/elixir-phoenix-guardrails/`
- `.opencode/plugins/elixir-phoenix-guardrails.js`
- `.agents/skills/<skill>/` for all bundled skills
- `lib/mix/tasks/opencode/phoenix/pull.ex`
- `.opencode/opencode-phoenix.lock.json` lock metadata

## Update / Check

From this repo:

```bash
./bin/opencode-phoenix update --target /path/to/your_phoenix_app
./bin/opencode-phoenix check --target /path/to/your_phoenix_app
```

If managed files were edited locally in the target repo, update will fail unless forced:

```bash
./bin/opencode-phoenix update --target /path/to/your_phoenix_app --force
```

You can also set `OPENCODE_PHOENIX_TARGET` instead of passing `--target`.

The installed mix task gives projects a single pull/update command:

```bash
mix opencode.phoenix.pull
mix opencode.phoenix.pull --check
mix opencode.phoenix.pull --force
```

It also installs a publish task for source repos that maintain these managed paths:

```bash
mix opencode.phoenix.publish --dry-run
mix opencode.phoenix.publish
```

If `mix opencode.phoenix.pull` is missing, `bin/opencode-phoenix` bootstraps it via a temporary task and removes the temp file after bootstrap.

Optional env vars for the mix task:

- `OPENCODE_PHOENIX_REPO` (default `https://github.com/mackross/opencode-phoenix.git`)
- `OPENCODE_PHOENIX_REF` (default `main`)
- `OPENCODE_PHOENIX_DST` (default `/tmp/opencode-phoenix`)
- `OPENCODE_PHOENIX_REMOTE` (used by `mix opencode.phoenix.publish`)

## Publishing Updates

Use one publishing path:

1. Author changes in your source repo.
2. Publish to this repo with `mix opencode.phoenix.publish` (git subtree add/pull).
3. Review and push from `opencode-phoenix`.

Example:

```bash
# In your source repo
mix opencode.phoenix.publish

# In opencode-phoenix
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

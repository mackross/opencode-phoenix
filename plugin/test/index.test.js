import assert from "node:assert/strict"
import test from "node:test"

import { ElixirPhoenixGuardrails, __private__, collectMutations } from "../src/index.js"

const buildHook = async (client = {}) => {
  const plugin = await ElixirPhoenixGuardrails({ client })
  return plugin["tool.execute.before"]
}

const runWrite = async (hook, filePath, content) =>
  hook({ tool: "write" }, { args: { filePath, content } })

const expectDeny = async ({ filePath, content, ruleId }) => {
  const hook = await buildHook()

  await assert.rejects(
    async () => runWrite(hook, filePath, content),
    (error) => {
      const message = String(error.message)
      assert.match(message, new RegExp(`\\[DENY\\]\\[${ruleId}\\]`))
      assert.match(message, /How to fix:/)
      assert.match(message, new RegExp(`File: ${filePath.replaceAll("/", "\\/")}`))
      return true
    },
  )
}

const expectWarn = async ({ filePath, content, ruleId }) => {
  const logs = []
  const hook = await buildHook({
    app: {
      log: async ({ body }) => logs.push(body),
    },
  })

  await runWrite(hook, filePath, content)
  assert.equal(logs.length, 1)
  assert.equal(logs[0].level, "warn")
  assert.match(logs[0].message, new RegExp(`\\[WARN\\]\\[${ruleId}\\]`))
}

test("collectMutations parses apply_patch added lines per file", () => {
  const input = { tool: "apply_patch" }
  const output = {
    args: {
      patchText: [
        "*** Begin Patch",
        "*** Update File: lib/my_app_web/live/demo_live.ex",
        "@@",
        "+  live_patch(socket, to: ~p\"/x\")",
        "*** End Patch",
      ].join("\n"),
    },
  }

  const mutations = collectMutations(input, output)
  assert.equal(mutations.length, 1)
  assert.equal(mutations[0].filePath, "lib/my_app_web/live/demo_live.ex")
  assert.match(mutations[0].text, /live_patch/)
})

test("deny: web layer cannot use Repo directly", async () => {
  await expectDeny({
    filePath: "lib/my_app_web/live/demo_live.ex",
    content: "def mount(_, _, socket), do: {:ok, assign(socket, :users, Repo.all(User))}",
    ruleId: "web-layer-no-repo",
  })
})

test("deny: deprecated live navigation helper", async () => {
  await expectDeny({
    filePath: "lib/my_app_web/live/demo_live.ex",
    content: "{:noreply, live_patch(socket, to: ~p\"/home\")}",
    ruleId: "deprecated-live-nav",
  })
})

test("deny: legacy form API usage", async () => {
  await expectDeny({
    filePath: "lib/my_app_web/live/form_live.ex",
    content: "Phoenix.HTML.form_for(changeset, \"/save\", fn f -> f end)",
    ruleId: "legacy-form-api",
  })
})

test("deny: flash_group outside layouts", async () => {
  await expectDeny({
    filePath: "lib/my_app_web/live/page_live.html.heex",
    content: "<.flash_group flash={@flash} />",
    ruleId: "flash-group-outside-layouts",
  })
})

test("deny: inline script in heex", async () => {
  await expectDeny({
    filePath: "lib/my_app_web/live/page_live.html.heex",
    content: "<script>console.log('x')</script>",
    ruleId: "inline-script-in-heex",
  })
})

test("deny: banned HTTP client", async () => {
  await expectDeny({
    filePath: "lib/my_app/services/http.ex",
    content: "HTTPoison.get!(\"https://example.com\")",
    ruleId: "banned-http-client",
  })
})

test("warn: missing @impl true", async () => {
  await expectWarn({
    filePath: "lib/my_app_web/live/demo_live.ex",
    content: [
      "defmodule MyAppWeb.DemoLive do",
      "  use MyAppWeb, :live_view",
      "  def mount(_params, _session, socket), do: {:ok, socket}",
      "end",
    ].join("\n"),
    ruleId: "missing-impl-true",
  })
})

test("warn: auto_upload enabled", async () => {
  await expectWarn({
    filePath: "lib/my_app_web/live/upload_live.ex",
    content: "allow_upload(socket, :image, auto_upload: true)",
    ruleId: "auto-upload-enabled",
  })
})

test("warn: live component usage", async () => {
  await expectWarn({
    filePath: "lib/my_app_web/live/component_live.ex",
    content: "use MyAppWeb, :live_component",
    ruleId: "live-component-usage",
  })
})

test("warn: Process.sleep in tests", async () => {
  await expectWarn({
    filePath: "test/my_app/some_test.exs",
    content: "Process.sleep(50)",
    ruleId: "process-sleep-in-tests",
  })
})

test("warn: String.to_atom usage", async () => {
  await expectWarn({
    filePath: "lib/my_app/convert.ex",
    content: "String.to_atom(value)",
    ruleId: "string-to-atom",
  })
})

test("warn: hardcoded absolute path", async () => {
  await expectWarn({
    filePath: "lib/my_app/storage.ex",
    content: "path = \"/var/app/uploads/image.png\"",
    ruleId: "hardcoded-absolute-path",
  })
})

test("heex colocated hook script is allowed", async () => {
  const hook = await buildHook()
  await runWrite(
    hook,
    "lib/my_app_web/live/page_live.html.heex",
    "<script :type={Phoenix.LiveView.ColocatedHook} name=\".X\">export default {}</script>",
  )
})

test("flash_group in layouts is allowed", async () => {
  const hook = await buildHook()
  await runWrite(
    hook,
    "lib/my_app_web/components/layouts.ex",
    "def flash(assigns), do: ~H\"<.flash_group flash={@flash} />\"",
  )
})

test("private helper finds missing @impl true callback annotations", () => {
  const source = [
    "defmodule MyAppWeb.DemoLive do",
    "  use MyAppWeb, :live_view",
    "",
    "  def mount(_params, _session, socket), do: {:ok, socket}",
    "",
    "  @impl true",
    "  def handle_event(\"save\", _, socket), do: {:noreply, socket}",
    "end",
  ].join("\n")

  const warnings = __private__.findMissingImplWarnings(source)
  assert.deepEqual(warnings, ["mount"])
})

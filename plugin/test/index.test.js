import assert from "node:assert/strict"
import test from "node:test"

import { ElixirPhoenixGuardrails, __private__, collectMutations } from "../src/index.js"

test("collectMutations parses apply_patch added lines per file", () => {
  const input = { tool: "apply_patch" }
  const output = {
    args: {
      patchText: [
        "*** Begin Patch",
        "*** Update File: lib/runix_web/live/demo_live.ex",
        "@@",
        "+  live_patch(socket, to: ~p\"/x\")",
        "*** End Patch",
      ].join("\n"),
    },
  }

  const mutations = collectMutations(input, output)
  assert.equal(mutations.length, 1)
  assert.equal(mutations[0].filePath, "lib/runix_web/live/demo_live.ex")
  assert.match(mutations[0].text, /live_patch/)
})

test("deny rule blocks direct Repo usage in web layer", async () => {
  const plugin = await ElixirPhoenixGuardrails({ client: {} })
  const beforeHook = plugin["tool.execute.before"]

  await assert.rejects(
    async () => {
      await beforeHook(
        { tool: "write" },
        {
          args: {
            filePath: "lib/runix_web/live/demo_live.ex",
            content: "def mount(_, _, socket), do: {:ok, assign(socket, :users, Repo.all(User))}",
          },
        },
      )
    },
    (error) => {
      assert.match(String(error.message), /web-layer-no-repo/)
      assert.match(String(error.message), /How to fix:/)
      return true
    },
  )
})

test("deny rule blocks deprecated live_patch helper", async () => {
  const plugin = await ElixirPhoenixGuardrails({ client: {} })
  const beforeHook = plugin["tool.execute.before"]

  await assert.rejects(
    async () => {
      await beforeHook(
        { tool: "edit" },
        {
          args: {
            filePath: "lib/runix_web/live/demo_live.ex",
            newString: "live_patch(socket, to: ~p\"/somewhere\")",
          },
        },
      )
    },
    /deprecated-live-nav/,
  )
})

test("warn rules log but do not block", async () => {
  const logs = []
  const client = {
    app: {
      log: async ({ body }) => {
        logs.push(body)
      },
    },
  }

  const plugin = await ElixirPhoenixGuardrails({ client })
  const beforeHook = plugin["tool.execute.before"]

  await beforeHook(
    { tool: "write" },
    {
      args: {
        filePath: "lib/runix_web/live/upload_live.ex",
        content: [
          "defmodule RunixWeb.UploadLive do",
          "  use RunixWeb, :live_view",
          "  def mount(_params, _session, socket) do",
          "    allow_upload(socket, :doc, auto_upload: true)",
          "  end",
          "end",
        ].join("\n"),
      },
    },
  )

  assert.ok(logs.length > 0)
  assert.equal(logs[0].level, "warn")
  assert.match(logs[0].message, /missing-impl-true/)
  assert.match(logs[0].message, /auto-upload-enabled/)
})

test("private helper finds missing @impl true callback annotations", () => {
  const source = [
    "defmodule RunixWeb.DemoLive do",
    "  use RunixWeb, :live_view",
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

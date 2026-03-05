const PLUGIN_ID = "elixir-phoenix-guardrails"

const EDIT_TOOLS = new Set(["apply_patch", "patch", "edit", "write", "multiedit"])
const CALLBACK_NAMES = ["mount", "handle_event", "handle_info", "handle_params", "render"]

const normalizePath = (path) => String(path || "").replaceAll("\\", "/")

const toolFilePath = (args) =>
  normalizePath(args?.filePath || args?.file_path || args?.path || "")

const toolText = (value) => (typeof value === "string" ? value : "")

const parsePatchMutations = (patchText) => {
  const lines = toolText(patchText).split("\n")
  const mutations = []
  let currentPath = ""
  let addedLines = []

  const flush = () => {
    if (!currentPath) return
    mutations.push({
      filePath: normalizePath(currentPath),
      text: addedLines.join("\n"),
    })
  }

  for (const line of lines) {
    if (line.startsWith("*** Add File: ") || line.startsWith("*** Update File: ")) {
      flush()
      currentPath = line.replace("*** Add File: ", "").replace("*** Update File: ", "")
      addedLines = []
      continue
    }

    if (line.startsWith("*** Delete File: ")) {
      flush()
      currentPath = ""
      addedLines = []
      continue
    }

    if (!currentPath) continue
    if (line.startsWith("+++ ")) continue
    if (line.startsWith("+")) addedLines.push(line.slice(1))
  }

  flush()
  return mutations
}

export const collectMutations = (input, output) => {
  const tool = input?.tool
  const args = output?.args || {}

  if (!EDIT_TOOLS.has(tool)) return []

  if (tool === "apply_patch" || tool === "patch") {
    const patchText = args.patchText || args.patch || args.content || ""
    return parsePatchMutations(patchText)
  }

  if (tool === "write") {
    return [{ filePath: toolFilePath(args), text: toolText(args.content || args.text) }]
  }

  if (tool === "edit") {
    return [
      {
        filePath: toolFilePath(args),
        text: toolText(args.newString || args.new_string),
      },
    ]
  }

  if (tool === "multiedit") {
    const edits = Array.isArray(args.edits) ? args.edits : []
    return [
      {
        filePath: toolFilePath(args),
        text: edits
          .map((edit) => toolText(edit?.newString || edit?.new_string))
          .filter(Boolean)
          .join("\n"),
      },
    ]
  }

  return []
}

const isElixirFamily = (path) => /\.(ex|exs|heex)$/i.test(path)
const isTestFile = (path) => /(^|\/)test\//.test(path)
const isWebLayer = (path) => /(^|\/)lib\/[^/]+_web\//.test(path)
const isLayoutFile = (path) => /layouts(\.|\/)/.test(path)

const matchOne = (text, regex) => {
  const match = text.match(regex)
  return match ? match[0] : null
}

const findMissingImplWarnings = (text) => {
  const warnings = []
  const lines = text.split("\n")

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index]
    const callbackMatch = line.match(
      new RegExp(`^\\s*def\\s+(${CALLBACK_NAMES.join("|")})\\b`),
    )

    if (!callbackMatch) continue

    const windowStart = Math.max(0, index - 3)
    const preceding = lines.slice(windowStart, index).join("\n")
    if (!/@impl\s+true/.test(preceding)) {
      warnings.push(callbackMatch[1])
    }
  }

  return warnings
}

const evaluateDenyRules = (mutation) => {
  const violations = []
  const { filePath, text } = mutation
  if (!filePath || !text) return violations

  if (!isElixirFamily(filePath)) return violations

  if (isWebLayer(filePath)) {
    const match =
      matchOne(text, /\balias\s+[A-Z][A-Za-z0-9_.]*\.Repo\b/) || matchOne(text, /\bRepo\s*\./)
    if (match) {
      violations.push({
        ruleId: "web-layer-no-repo",
        filePath,
        matched: match,
        why: "Web layer modules should stay thin and should not access Repo directly.",
        fix: "Move data access into a context module under lib/<app_name>/ and call that context from the LiveView/controller.",
      })
    }
  }

  const deprecatedLiveNav = matchOne(text, /\blive_redirect\b|\blive_patch\b/)
  if (deprecatedLiveNav) {
    violations.push({
      ruleId: "deprecated-live-nav",
      filePath,
      matched: deprecatedLiveNav,
      why: "Deprecated LiveView navigation helpers are not allowed in this project.",
      fix: "Use push_navigate/push_patch in LiveView modules and <.link navigate={...}>/<.link patch={...}> in templates.",
    })
  }

  const legacyFormApi =
    matchOne(text, /\bPhoenix\.HTML\.form_for\b/) || matchOne(text, /\bPhoenix\.HTML\.inputs_for\b/)
  if (legacyFormApi) {
    violations.push({
      ruleId: "legacy-form-api",
      filePath,
      matched: legacyFormApi,
      why: "Legacy Phoenix.HTML form helpers are forbidden in modern Phoenix projects.",
      fix: "Use to_form/2 in the LiveView and render forms with <.form> plus <.input> components.",
    })
  }

  if (!isLayoutFile(filePath)) {
    const flashGroup = matchOne(text, /<\.flash_group\b/)
    if (flashGroup) {
      violations.push({
        ruleId: "flash-group-outside-layouts",
        filePath,
        matched: flashGroup,
        why: "<.flash_group> is reserved for layouts and should not be used elsewhere.",
        fix: "Render flash through layout wrappers and keep <.flash_group> inside the layouts module only.",
      })
    }
  }

  if (filePath.endsWith(".heex")) {
    const scriptTags = text.match(/<script\b[^>]*>/gi) || []
    for (const tag of scriptTags) {
      if (!tag.includes("Phoenix.LiveView.ColocatedHook")) {
        violations.push({
          ruleId: "inline-script-in-heex",
          filePath,
          matched: tag,
          why: "Raw inline <script> tags in HEEx templates are not allowed.",
          fix: "Move JS to assets/js hooks, or use a colocated hook with :type={Phoenix.LiveView.ColocatedHook}.",
        })
      }
    }
  }

  const bannedHttpClient =
    matchOne(text, /\bHTTPoison\b/) || matchOne(text, /\bTesla\b/) || matchOne(text, /:httpc\b/)
  if (bannedHttpClient) {
    violations.push({
      ruleId: "banned-http-client",
      filePath,
      matched: bannedHttpClient,
      why: "This project standardizes on Req for HTTP calls.",
      fix: "Replace this usage with Req (for example: Req.get/2, Req.post/2) and keep HTTP logic in context/service modules.",
    })
  }

  return violations
}

const evaluateWarnRules = (mutation) => {
  const warnings = []
  const { filePath, text } = mutation
  if (!filePath || !text) return warnings

  if (!isElixirFamily(filePath)) return warnings

  const missingImplCallbacks = findMissingImplWarnings(text)
  if (missingImplCallbacks.length > 0) {
    warnings.push({
      ruleId: "missing-impl-true",
      filePath,
      matched: missingImplCallbacks.join(", "),
      why: "Callbacks should include @impl true for clarity and compile-time checks.",
      fix: "Add @impl true directly above each callback definition.",
    })
  }

  const autoUpload = matchOne(text, /auto_upload\s*:\s*true/)
  if (autoUpload) {
    warnings.push({
      ruleId: "auto-upload-enabled",
      filePath,
      matched: autoUpload,
      why: "This project prefers manual upload flow for predictable validation and persistence behavior.",
      fix: "Remove auto_upload: true and consume entries on explicit form submit.",
    })
  }

  const liveComponent =
    matchOne(text, /\buse\s+[A-Z][A-Za-z0-9_.]*,\s*:live_component\b/) ||
    matchOne(text, /\blive_component\(/)
  if (liveComponent) {
    warnings.push({
      ruleId: "live-component-usage",
      filePath,
      matched: liveComponent,
      why: "LiveComponents are discouraged unless there is a strong, explicit need.",
      fix: "Prefer a plain LiveView module unless component boundaries provide clear value.",
    })
  }

  if (isTestFile(filePath)) {
    const sleepCall = matchOne(text, /Process\.sleep\s*\(/)
    if (sleepCall) {
      warnings.push({
        ruleId: "process-sleep-in-tests",
        filePath,
        matched: sleepCall,
        why: "Process.sleep/1 makes tests flaky and slow.",
        fix: "Use Process.monitor/assert_receive for process lifecycle checks, or :sys.get_state/1 for synchronization.",
      })
    }
  }

  const toAtomCall = matchOne(text, /String\.to_atom\s*\(/)
  if (toAtomCall) {
    warnings.push({
      ruleId: "string-to-atom",
      filePath,
      matched: toAtomCall,
      why: "String.to_atom/1 can leak atoms when used on dynamic input.",
      fix: "Use explicit mapping, String.to_existing_atom/1 with trusted atoms, or avoid atom conversion.",
    })
  }

  const hardcodedPath = matchOne(text, /["']\/(tmp|var|home|opt|srv)\//)
  if (hardcodedPath && !isTestFile(filePath)) {
    warnings.push({
      ruleId: "hardcoded-absolute-path",
      filePath,
      matched: hardcodedPath,
      why: "Environment-specific paths should come from runtime config.",
      fix: "Move path configuration to runtime.exs/Application.get_env and read it where needed.",
    })
  }

  return warnings
}

const formatIssueBlock = (issues, severity) =>
  issues
    .map(
      (issue, index) =>
        `${index + 1}. [${severity}][${issue.ruleId}]\n` +
        `   File: ${issue.filePath}\n` +
        `   Matched: ${issue.matched}\n` +
        `   Why: ${issue.why}\n` +
        `   How to fix: ${issue.fix}`,
    )
    .join("\n\n")

const logWarning = async (client, message) => {
  if (client?.app?.log) {
    await client.app.log({
      body: {
        service: PLUGIN_ID,
        level: "warn",
        message,
      },
    })
    return
  }

  console.warn(message)
}

export const ElixirPhoenixGuardrails = async ({ client }) => {
  return {
    "tool.execute.before": async (input, output) => {
      const mutations = collectMutations(input, output)
      if (mutations.length === 0) return

      const denyIssues = mutations.flatMap(evaluateDenyRules)
      if (denyIssues.length > 0) {
        const message =
          `[${PLUGIN_ID}] Blocked tool call (${input.tool}).\n\n` +
          "One or more deny guardrails were triggered:\n\n" +
          formatIssueBlock(denyIssues, "DENY") +
          "\n\nApply the suggested fix in your edit, then retry the same tool call."

        throw new Error(message)
      }

      const warnIssues = mutations.flatMap(evaluateWarnRules)
      if (warnIssues.length > 0) {
        const message =
          `[${PLUGIN_ID}] Warning guardrails for tool call (${input.tool}):\n\n` +
          formatIssueBlock(warnIssues, "WARN") +
          "\n\nNo block applied. Continue if this change is intentional."

        await logWarning(client, message)
      }
    },
  }
}

export const __private__ = {
  evaluateDenyRules,
  evaluateWarnRules,
  findMissingImplWarnings,
  parsePatchMutations,
}

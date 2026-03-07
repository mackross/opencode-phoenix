defmodule AgentFriendly.Guardrails.Rules do
  @moduledoc false

  alias AgentFriendly.Guardrails.Issue

  def issues_for_file(root, file) do
    relative_path = Path.relative_to(file, root)
    body = File.read!(file)

    issues_from_rules(root, relative_path, body, deny_rules()) ++
      issues_from_rules(root, relative_path, body, warn_rules()) ++
      missing_impl_issues(root, relative_path, body)
  end

  defp issues_from_rules(root, relative_path, body, rules) do
    Enum.flat_map(rules, fn rule ->
      if file_match?(rule.file_match, relative_path) do
        body
        |> then(&Regex.scan(rule.pattern, &1, return: :index))
        |> Enum.map(&build_issue(root, relative_path, body, rule, &1))
        |> Enum.reject(&skip_issue?(&1, rule, relative_path, body))
      else
        []
      end
    end)
  end

  defp build_issue(root, relative_path, body, rule, [{start, length} | _rest]) do
    matched = binary_part(body, start, length)

    %Issue{
      severity: rule.severity,
      rule_id: rule.rule_id,
      file: Path.join(root, relative_path),
      line: line_number(body, start),
      matched: matched,
      fix: rule.fix
    }
  end

  defp skip_issue?(_issue, %{rule_id: "flash-group-outside-layouts"}, relative_path, _body) do
    String.contains?(relative_path, "layouts")
  end

  defp skip_issue?(issue, %{rule_id: "inline-script-in-heex"}, relative_path, body) do
    line = line_at(body, issue.line)

    String.ends_with?(relative_path, "components/layouts/root.html.heex") or
      String.contains?(line, "Phoenix.LiveView.ColocatedHook")
  end

  defp skip_issue?(_issue, _rule, _relative_path, _body), do: false

  defp file_match?(:web_layer, path), do: Regex.match?(~r{(^|/)lib/[^/]+_web/.*\.(ex|heex)$}, path)
  defp file_match?(:elixir_or_heex, path), do: Regex.match?(~r/\.(ex|heex)$/i, path)
  defp file_match?(:elixir_file, path), do: Regex.match?(~r/\.(ex|exs)$/i, path)
  defp file_match?(:heex_file, path), do: String.ends_with?(path, ".heex")
  defp file_match?(:test_file, path), do: String.contains?(path, "/test/") and String.ends_with?(path, ".exs")
  defp file_match?(:all_templates, path), do: String.ends_with?(path, ".heex") or String.ends_with?(path, ".ex")

  defp missing_impl_issues(root, relative_path, body) do
    if String.ends_with?(relative_path, ".ex") do
      callbacks = ["mount", "handle_event", "handle_info", "handle_params", "render"]
      lines = String.split(body, "\n")

      lines
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, index} ->
        if Regex.match?(~r/^\s*def\s+(#{Enum.join(callbacks, "|")})\b/, line) and
             not impl_above?(lines, index) do
          [
            %Issue{
              severity: :warn,
              rule_id: "missing-impl-true",
              file: Path.join(root, relative_path),
              line: index,
              matched: String.trim(line),
              fix: "Add @impl true directly above callback definitions."
            }
          ]
        else
          []
        end
      end)
    else
      []
    end
  end

  defp impl_above?(lines, line_number) do
    lines
    |> Enum.slice(max(line_number - 4, 0), 3)
    |> Enum.any?(&String.contains?(&1, "@impl true"))
  end

  defp line_number(body, offset) do
    body
    |> binary_part(0, offset)
    |> String.split("\n")
    |> length()
  end

  defp line_at(body, line_number) do
    body
    |> String.split("\n")
    |> Enum.at(line_number - 1, "")
  end

  defp deny_rules do
    [
      %{
        severity: :deny,
        rule_id: "web-layer-no-repo",
        file_match: :web_layer,
        pattern: ~r/\balias\s+[A-Z][A-Za-z0-9_.]*\.Repo\b|\bRepo\./,
        fix: "Move data access into a context module under lib/<app>/ and call that from the web layer."
      },
      %{
        severity: :deny,
        rule_id: "deprecated-live-nav",
        file_match: :elixir_or_heex,
        pattern: ~r/\blive_patch\b|\blive_redirect\b/,
        fix: "Use push_patch/push_navigate in LiveViews and <.link patch={...}>/<.link navigate={...}>."
      },
      %{
        severity: :deny,
        rule_id: "legacy-form-api",
        file_match: :elixir_or_heex,
        pattern: ~r/\bPhoenix\.HTML\.form_for\b|\bPhoenix\.HTML\.inputs_for\b/,
        fix: "Use to_form/2 in the LiveView and render with <.form> plus <.input>."
      },
      %{
        severity: :deny,
        rule_id: "flash-group-outside-layouts",
        file_match: :all_templates,
        pattern: ~r/<\.flash_group\b/,
        fix: "Keep <.flash_group> inside layouts only."
      },
      %{
        severity: :deny,
        rule_id: "inline-script-in-heex",
        file_match: :heex_file,
        pattern: ~r/<script\b[^>]*>/i,
        fix: "Move JS to assets/js or use a colocated hook with :type={Phoenix.LiveView.ColocatedHook}."
      },
      %{
        severity: :deny,
        rule_id: "banned-http-client",
        file_match: :elixir_file,
        pattern: ~r/\bHTTPoison\b|\bTesla\b|:httpc\b/,
        fix: "Use Req for HTTP calls."
      }
    ]
  end

  defp warn_rules do
    [
      %{
        severity: :warn,
        rule_id: "process-sleep-in-tests",
        file_match: :test_file,
        pattern: ~r/Process\.sleep\s*\(/,
        fix: "Use Process.monitor/assert_receive or :sys.get_state/1 instead."
      },
      %{
        severity: :warn,
        rule_id: "string-to-atom",
        file_match: :elixir_file,
        pattern: ~r/String\.to_atom\s*\(/,
        fix: "Avoid String.to_atom/1 on dynamic input; prefer explicit mapping or to_existing_atom/1 if safe."
      },
      %{
        severity: :warn,
        rule_id: "live-component-usage",
        file_match: :elixir_or_heex,
        pattern: ~r/\buse\s+[A-Z][A-Za-z0-9_.]*,\s*:live_component\b|\blive_component\(/,
        fix: "Prefer plain LiveViews unless a LiveComponent boundary is clearly necessary."
      },
      %{
        severity: :warn,
        rule_id: "auto-upload-enabled",
        file_match: :elixir_or_heex,
        pattern: ~r/auto_upload\s*:\s*true/,
        fix: "Prefer manual upload flow for predictable validation and persistence."
      },
      %{
        severity: :warn,
        rule_id: "hardcoded-absolute-path",
        file_match: :elixir_file,
        pattern: ~r/"\/(var|tmp|Users|home)\//,
        fix: "Use config, Path.join/2, or environment-driven paths instead of hardcoded absolute paths."
      }
    ]
  end
end

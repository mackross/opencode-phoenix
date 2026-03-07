defmodule AgentFriendly.Guardrails do
  @moduledoc false

  alias AgentFriendly.Guardrails.Issue
  alias AgentFriendly.Guardrails.Rules

  @default_globs [
    "lib/**/*.ex",
    "lib/**/*.exs",
    "lib/**/*.heex",
    "test/**/*.exs",
    "config/**/*.exs"
  ]

  def scan(root \\ File.cwd!()) do
    root
    |> files_to_scan()
    |> Enum.flat_map(&Rules.issues_for_file(root, &1))
    |> Enum.sort_by(&{&1.file, &1.line, &1.rule_id})
  end

  def deny?(issues) do
    Enum.any?(issues, &match?(%Issue{severity: :deny}, &1))
  end

  def format_issue(%Issue{} = issue) do
    severity = issue.severity |> Atom.to_string() |> String.upcase()
    "[#{severity}][#{issue.rule_id}] #{issue.file}:#{issue.line} matched=#{inspect(issue.matched)} fix=#{issue.fix}"
  end

  defp files_to_scan(root) do
    @default_globs
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1), match_dot: true))
    |> Enum.uniq()
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(fn file ->
      relative = Path.relative_to(file, root)
      String.starts_with?(relative, "lib/agent_friendly/guardrails")
    end)
  end
end

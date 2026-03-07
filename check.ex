defmodule Mix.Tasks.Opencode.Phoenix.Check do
  use Mix.Task

  @shortdoc "Checks OpenCode Phoenix guardrails before commit"

  @impl true
  def run(args) do
    if args != [] do
      Mix.raise("mix opencode.phoenix.check does not accept arguments")
    end

    issues = Opencode.Phoenix.Guardrails.scan()

    Enum.each(issues, fn issue ->
      Mix.shell().info(Opencode.Phoenix.Guardrails.format_issue(issue))
    end)

    if Opencode.Phoenix.Guardrails.deny?(issues) do
      Mix.raise("OpenCode Phoenix guardrails check failed")
    end
  end
end

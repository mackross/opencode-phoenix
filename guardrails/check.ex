defmodule Mix.Tasks.Agentfriendly.Guardrails.Check do
  use Mix.Task

  @shortdoc "Checks AgentFriendly guardrails before commit"

  @impl true
  def run(args) do
    if args != [] do
      Mix.raise("mix agentfriendly.guardrails.check does not accept arguments")
    end

    issues = AgentFriendly.Guardrails.scan()

    Enum.each(issues, fn issue ->
      Mix.shell().info(AgentFriendly.Guardrails.format_issue(issue))
    end)

    if AgentFriendly.Guardrails.deny?(issues) do
      Mix.raise("AgentFriendly guardrails check failed")
    end
  end
end

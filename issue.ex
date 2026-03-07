defmodule AgentFriendly.Guardrails.Issue do
  @moduledoc false

  @enforce_keys [:severity, :rule_id, :file, :line, :matched, :fix]
  defstruct [:severity, :rule_id, :file, :line, :matched, :fix]
end

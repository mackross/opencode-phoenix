defmodule Mix.Tasks.Agentfriendly.Pull.Tmp do
  use Mix.Task

  @shortdoc "Bootstraps mix agentfriendly.pull into a project"
  @default_repo "https://github.com/mackross/phoenix-agentfriendly.git"
  @pull_src "mix_tasks/agentfriendly/pull.ex"
  @pull_dst "lib/mix/tasks/agentfriendly/pull.ex"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args, strict: [repo: :string, ref: :string, dst: :string])

    target = File.cwd!()
    repo = Keyword.get(opts, :repo, System.get_env("AGENT_FRIENDLY_REPO") || @default_repo)
    ref = Keyword.get(opts, :ref, System.get_env("AGENT_FRIENDLY_REF") || "main")

    dst =
      opts
      |> Keyword.get(:dst, System.get_env("AGENT_FRIENDLY_DST") || default_dst())
      |> Path.expand()

    ensure_repo(dst, repo, ref)
    out = Path.join(target, @pull_dst)
    File.mkdir_p!(Path.dirname(out))
    File.cp!(Path.join(dst, @pull_src), out)
    Mix.shell().info("installed #{@pull_dst}")
  end

  defp ensure_repo(dst, repo, ref) do
    if Path.expand(repo) == Path.expand(dst) and File.dir?(Path.join(dst, ".git")) do
      :ok
    else
      if File.dir?(Path.join(dst, ".git")) do
        run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
      else
        File.mkdir_p!(Path.dirname(dst))
        run_cmd!("git", ["clone", repo, dst])
        run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
      end

      cond do
        run_ok?("git", ["-C", dst, "show-ref", "--verify", "--quiet", "refs/heads/#{ref}"]) ->
          run_cmd!("git", ["-C", dst, "checkout", ref])

        run_ok?("git", [
          "-C",
          dst,
          "show-ref",
          "--verify",
          "--quiet",
          "refs/remotes/origin/#{ref}"
        ]) ->
          run_cmd!("git", ["-C", dst, "checkout", "-B", ref, "origin/#{ref}"])

        true ->
          :ok
      end

      if run_ok?("git", [
           "-C",
           dst,
           "show-ref",
           "--verify",
           "--quiet",
           "refs/remotes/origin/#{ref}"
         ]) do
        run_cmd!("git", ["-C", dst, "merge", "--ff-only", "origin/#{ref}"])
      end
    end
  end

  defp default_dst do
    Path.join(System.tmp_dir!(), "phoenix-agentfriendly")
  end

  defp run_ok?(command, args) do
    {_output, status} = System.cmd(command, args, stderr_to_stdout: true)
    status == 0
  end

  defp run_cmd!(command, args) do
    {output, status} = System.cmd(command, args, stderr_to_stdout: true)
    if status != 0, do: Mix.raise("command failed: #{command} #{Enum.join(args, " ")}\n#{output}")
    output
  end
end

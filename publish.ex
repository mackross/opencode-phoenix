defmodule Mix.Tasks.Agentfriendly.Publish do
  use Mix.Task

  @shortdoc "Publishes managed AgentFriendly Phoenix assets via git subtree"
  @default_remote "git@github.com:mackross/phoenix-agentfriendly.git"
  @default_dst "/tmp/phoenix-agentfriendly"

  @mappings [
    {"lib/agent_friendly/guardrails", "lib/agent_friendly/guardrails"},
    {"lib/mix/tasks/agentfriendly", "mix_tasks/agentfriendly"}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          remote: :string,
          dst: :string,
          branch: :string,
          dry_run: :boolean,
          no_push: :boolean
        ]
      )

    remote =
      Keyword.get(opts, :remote, System.get_env("AGENT_FRIENDLY_REMOTE") || @default_remote)

    dst =
      opts
      |> Keyword.get(:dst, System.get_env("AGENT_FRIENDLY_DST") || @default_dst)
      |> Path.expand()

    branch = Keyword.get(opts, :branch, "main")
    dry_run? = Keyword.get(opts, :dry_run, false)
    no_push? = Keyword.get(opts, :no_push, false)
    root = File.cwd!()

    prepare_destination(dst, remote, branch, dry_run?)

    Enum.each(@mappings, fn {src, prefix} ->
      ensure_committed_prefix!(src)
      sha = split_sha(src)
      Mix.shell().info("#{src} -> #{prefix} @ #{sha}")
      if !dry_run?, do: sync_prefix(dst, prefix, root, sha)
    end)

    unless dry_run? do
      maybe_commit_and_push(dst, branch, no_push?)
    end
  end

  defp prepare_destination(_dst, _remote, _branch, true), do: :ok

  defp prepare_destination(dst, remote, branch, false) do
    if File.dir?(Path.join(dst, ".git")) do
      run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
    else
      File.mkdir_p!(Path.dirname(dst))
      run_cmd!("git", ["clone", remote, dst])
      run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
    end

    ensure_branch(dst, branch)

    if run_ok?("git", [
         "-C",
         dst,
         "show-ref",
         "--verify",
         "--quiet",
         "refs/remotes/origin/#{branch}"
       ]) do
      run_cmd!("git", ["-C", dst, "merge", "--ff-only", "origin/#{branch}"])
    end
  end

  defp ensure_branch(dst, branch) do
    cond do
      run_ok?("git", ["-C", dst, "show-ref", "--verify", "--quiet", "refs/heads/#{branch}"]) ->
        run_cmd!("git", ["-C", dst, "checkout", branch])

      run_ok?("git", [
        "-C",
        dst,
        "show-ref",
        "--verify",
        "--quiet",
        "refs/remotes/origin/#{branch}"
      ]) ->
        run_cmd!("git", ["-C", dst, "checkout", "-B", branch, "origin/#{branch}"])

      true ->
        run_cmd!("git", ["-C", dst, "checkout", "--orphan", branch])

        if !run_ok?("git", ["-C", dst, "rev-parse", "--verify", "HEAD"]),
          do: run_cmd!("git", ["-C", dst, "commit", "--allow-empty", "-m", "init"])
    end
  end

  defp sync_prefix(dst, prefix, source_repo, sha) do
    cond do
      subtree_managed?(dst, prefix) ->
        run_cmd!("git", ["-C", dst, "subtree", "pull", "--prefix=#{prefix}", source_repo, sha, "--squash"])

      File.exists?(Path.join(dst, prefix)) ->
        run_cmd!("git", ["-C", dst, "fetch", source_repo, sha])
        run_cmd!("git", ["-C", dst, "subtree", "merge", "--prefix=#{prefix}", "FETCH_HEAD", "--squash"])

      true ->
        run_cmd!("git", ["-C", dst, "subtree", "add", "--prefix=#{prefix}", source_repo, sha, "--squash"])
    end
  end

  defp ensure_committed_prefix!(prefix) do
    if !run_ok?("git", ["cat-file", "-e", "HEAD:#{prefix}"]) do
      Mix.raise(
        "prefix has no committed history: #{prefix}\ncommit those files first, then rerun publish"
      )
    end
  end

  defp split_sha(prefix) do
    run_cmd!("git", ["subtree", "split", "--prefix=#{prefix}"])
    |> then(&Regex.scan(~r/\b[0-9a-f]{40}\b/, &1))
    |> List.flatten()
    |> List.last()
    |> case do
      nil -> Mix.raise("unable to parse subtree split sha for #{prefix}")
      sha -> sha
    end
  end

  defp maybe_commit_and_push(dst, branch, no_push?) do
    if String.trim(run_cmd!("git", ["-C", dst, "status", "--porcelain"])) == "" do
      Mix.shell().info("No destination changes to commit")
    else
      run_cmd!("git", ["-C", dst, "add", "-A"])
      run_cmd!("git", ["-C", dst, "commit", "-m", "sync managed assets from source repo"])
      if !no_push?, do: run_cmd!("git", ["-C", dst, "push", "origin", branch])
    end
  end

  defp subtree_managed?(dst, prefix) do
    String.trim(
      run_cmd!("git", [
        "-C",
        dst,
        "log",
        "--grep=git-subtree-dir: #{prefix}",
        "--format=%H",
        "-n",
        "1"
      ])
    ) != ""
  rescue
    _error -> false
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

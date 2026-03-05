defmodule Mix.Tasks.Opencode.Phoenix.Pull do
  use Mix.Task

  @shortdoc "Pulls opencode-phoenix updates into this project"
  @default_repo "https://github.com/mackross/opencode-phoenix.git"
  @default_dst "/tmp/opencode-phoenix"

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [force: :boolean, check: :boolean, repo: :string, ref: :string, dst: :string]
      )

    target = File.cwd!()
    repo = Keyword.get(opts, :repo, System.get_env("OPENCODE_PHOENIX_REPO") || @default_repo)
    ref = Keyword.get(opts, :ref, System.get_env("OPENCODE_PHOENIX_REF") || "main")

    dst =
      opts
      |> Keyword.get(:dst, System.get_env("OPENCODE_PHOENIX_DST") || @default_dst)
      |> Path.expand()

    force? = Keyword.get(opts, :force, false)
    check? = Keyword.get(opts, :check, false)

    ensure_repo(dst, repo, ref)

    cmd =
      cond do
        check? -> ["check", "--target", target]
        force? -> ["update", "--target", target, "--force"]
        true -> ["update", "--target", target]
      end

    run_cmd!(Path.join(dst, "bin/opencode-phoenix"), cmd)
  end

  defp ensure_repo(dst, repo, ref) do
    if File.dir?(Path.join(dst, ".git")) do
      run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
    else
      File.mkdir_p!(Path.dirname(dst))
      run_cmd!("git", ["clone", repo, dst])
      run_cmd!("git", ["-C", dst, "fetch", "origin", "--prune", "--tags"])
    end

    if run_ok?("git", ["-C", dst, "show-ref", "--verify", "--quiet", "refs/heads/#{ref}"]) do
      run_cmd!("git", ["-C", dst, "checkout", ref])
    else
      run_cmd!("git", ["-C", dst, "checkout", "-B", ref, "origin/#{ref}"])
    end

    if run_ok?("git", ["-C", dst, "show-ref", "--verify", "--quiet", "refs/remotes/origin/#{ref}"]) do
      run_cmd!("git", ["-C", dst, "merge", "--ff-only", "origin/#{ref}"])
    end
  end

  defp run_ok?(command, args) do
    {_output, status} = System.cmd(command, args, stderr_to_stdout: true)
    status == 0
  end

  defp run_cmd!(command, args) do
    {output, status} = System.cmd(command, args, stderr_to_stdout: true)
    IO.binwrite(output)
    if status != 0, do: Mix.raise("command failed: #{command} #{Enum.join(args, " ")}")
  end
end

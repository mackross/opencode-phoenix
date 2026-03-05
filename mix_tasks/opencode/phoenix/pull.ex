defmodule Mix.Tasks.Opencode.Phoenix.Pull do
  use Mix.Task

  @shortdoc "Pulls opencode-phoenix updates into this project"
  @default_repo "https://github.com/mackross/opencode-phoenix.git"
  @default_dst "/tmp/opencode-phoenix"
  @map_path "manifest/install_map.txt"

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
    mappings = read_map(Path.join(dst, @map_path))

    if check? do
      check_state(target, dst, mappings)
    else
      if managed_changes?(target, mappings) && !force? do
        Mix.raise("managed paths have local edits; rerun with --force")
      end

      apply_install(target, dst, mappings)
      write_lock(target, dst, repo, ref)
      Mix.shell().info("installed opencode-phoenix @ #{current_commit(dst)}")
    end
  end

  defp read_map(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.map(fn line ->
      case String.split(line, "|", trim: true) do
        [source, target, type] when type in ["file", "dir"] ->
          %{source: source, target: target, type: type}

        _ ->
          Mix.raise("invalid mapping line: #{line}")
      end
    end)
  end

  defp apply_install(target, dst, mappings) do
    Enum.each(mappings, fn %{source: source, target: rel_target, type: type} ->
      src = Path.join(dst, source)
      out = Path.join(target, rel_target)
      File.rm_rf!(out)
      File.mkdir_p!(Path.dirname(out))

      case type do
        "dir" -> File.cp_r!(src, out)
        "file" -> File.cp!(src, out)
      end
    end)
  end

  defp check_state(target, dst, mappings) do
    Enum.each(mappings, fn %{target: rel_target, type: type} ->
      path = Path.join(target, rel_target)

      cond do
        type == "dir" && !File.dir?(path) -> Mix.raise("missing #{rel_target}")
        type == "file" && !File.regular?(path) -> Mix.raise("missing #{rel_target}")
        true -> :ok
      end
    end)

    lock_path = Path.join(target, ".opencode/opencode-phoenix.lock.json")
    lock_commit = lock_path |> File.read!() |> extract_commit()
    expected = current_commit(dst)

    if lock_commit != expected do
      Mix.raise("outdated: lock=#{lock_commit} expected=#{expected}")
    end

    Mix.shell().info("opencode-phoenix is up to date (#{expected})")
  end

  defp managed_changes?(target, mappings) do
    if !run_ok?("git", ["-C", target, "rev-parse", "--is-inside-work-tree"]) do
      false
    else
      paths = Enum.map(mappings, & &1.target)
      String.trim(run_cmd!("git", ["-C", target, "status", "--porcelain", "--"] ++ paths)) != ""
    end
  end

  defp write_lock(target, dst, repo, ref) do
    path = Path.join(target, ".opencode/opencode-phoenix.lock.json")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      {
        "repo": "#{repo}",
        "ref": "#{ref}",
        "commit": "#{current_commit(dst)}",
        "installed_at": "#{DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()}"
      }
      """
    )
  end

  defp extract_commit(body) do
    case Regex.run(~r/"commit"\s*:\s*"([^"]+)"/, body) do
      [_, commit] -> commit
      _ -> Mix.raise("missing lock commit")
    end
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

  defp current_commit(dst), do: String.trim(run_cmd!("git", ["-C", dst, "rev-parse", "HEAD"]))

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

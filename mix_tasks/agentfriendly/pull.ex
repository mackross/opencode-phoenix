defmodule Mix.Tasks.Agentfriendly.Pull do
  use Mix.Task

  @shortdoc "Pulls phoenix-agentfriendly updates into this project"
  @default_repo "https://github.com/mackross/phoenix-agentfriendly.git"
  @map_path "manifest/install_map.txt"
  @guardrails_task ~s("agentfriendly.guardrails.check")

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [force: :boolean, check: :boolean, repo: :string, ref: :string, dst: :string]
      )

    target = File.cwd!()
    repo = Keyword.get(opts, :repo, System.get_env("AGENT_FRIENDLY_REPO") || @default_repo)
    ref = Keyword.get(opts, :ref, System.get_env("AGENT_FRIENDLY_REF") || "main")

    dst =
      opts
      |> Keyword.get(:dst, System.get_env("AGENT_FRIENDLY_DST") || default_dst())
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
      maybe_update_precommit(target)
      write_lock(target, dst, repo, ref)
      Mix.shell().info("installed phoenix-agentfriendly @ #{current_commit(dst)}")
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

  defp maybe_update_precommit(target) do
    case ensure_precommit_check(target) do
      :added ->
        Mix.shell().info("added agentfriendly.guardrails.check to precommit in mix.exs")

      :already_present ->
        :ok

      :missing_precommit ->
        Mix.shell().info("mix.exs has no precommit alias; add agentfriendly.guardrails.check manually")

      :missing_mix_exs ->
        :ok
    end
  end

  defp ensure_precommit_check(target) do
    path = Path.join(target, "mix.exs")

    cond do
      !File.regular?(path) ->
        :missing_mix_exs

      true ->
        body = File.read!(path)

        cond do
          String.contains?(body, @guardrails_task) ->
            :already_present

          true ->
            case rewrite_precommit_alias(body) do
              {:ok, updated} ->
                File.write!(path, updated)
                :added

              :missing_precommit ->
                :missing_precommit
            end
        end
    end
  end

  defp rewrite_precommit_alias(body) do
    lines = String.split(body, "\n", trim: false)

    with {:ok, start_index} <- find_precommit_start(lines) do
      case Enum.at(lines, start_index) do
        line ->
          if is_binary(line) and String.contains?(line, "]") do
            updated_lines = List.replace_at(lines, start_index, rewrite_inline_precommit_line(line))
            {:ok, Enum.join(updated_lines, "\n")}
          else
          with {:ok, end_index} <- find_precommit_end(lines, start_index) do
            block_lines = Enum.slice(lines, start_index..end_index)
            updated_block = insert_precommit_task(block_lines)
            updated_lines = replace_range(lines, start_index, end_index, updated_block)
            {:ok, Enum.join(updated_lines, "\n")}
          end
          end
      end
    else
      :error -> :missing_precommit
    end
  end

  defp find_precommit_start(lines) do
    lines
    |> Enum.find_index(&String.contains?(&1, "precommit: ["))
    |> case do
      nil -> :error
      index -> {:ok, index}
    end
  end

  defp find_precommit_end(lines, start_index) do
    lines
    |> Enum.with_index()
    |> Enum.drop(start_index + 1)
    |> Enum.find(fn {line, _index} -> String.trim(line) == "]" end)
    |> case do
      nil -> :error
      {_line, index} -> {:ok, index}
    end
  end

  defp rewrite_inline_precommit_line(line) do
    [prefix, items_body, trailing] =
      Regex.run(~r/^(\s*precommit:\s*)\[(.*)\](,?)$/, line, capture: :all_but_first)

    items =
      items_body
      |> String.split(~r/\s*,\s*/, trim: true)
      |> insert_precommit_task_item()

    base_indent =
      Regex.run(~r/^(\s*)precommit:/, line, capture: :all_but_first)
      |> List.first()

    item_indent = base_indent <> "  "

    [
      prefix <> "[",
      Enum.map_join(Enum.with_index(items), "\n", fn {item, index} ->
        suffix = if index == length(items) - 1, do: "", else: ","
        "#{item_indent}#{item}#{suffix}"
      end),
      base_indent <> "]" <> trailing
    ]
    |> Enum.join("\n")
  end

  defp insert_precommit_task(block_lines) do
    item_indent = detect_item_indent(block_lines)
    task_line = "#{item_indent}#{@guardrails_task},"

    case Enum.find_index(block_lines, &(String.trim(&1) == ~s("test"))) do
      nil ->
        List.insert_at(block_lines, length(block_lines) - 1, task_line)

      index ->
        List.insert_at(block_lines, index, task_line)
    end
  end

  defp insert_precommit_task_item(items) do
    case Enum.find_index(items, &(&1 == ~s("test"))) do
      nil -> List.insert_at(items, length(items), @guardrails_task)
      index -> List.insert_at(items, index, @guardrails_task)
    end
  end

  defp detect_item_indent(block_lines) do
    case Enum.find(block_lines, &Regex.match?(~r/^\s*"[^"]+"/, &1)) do
      nil ->
        closing_indent =
          block_lines
          |> List.last()
          |> String.replace(~r/\]$/, "")

        closing_indent <> "  "

      line ->
        Regex.run(~r/^(\s*)"[^"]+"/, line, capture: :all_but_first)
        |> List.first()
    end
  end

  defp replace_range(lines, start_index, end_index, replacement) do
    prefix = Enum.take(lines, start_index)
    suffix = Enum.drop(lines, end_index + 1)
    prefix ++ replacement ++ suffix
  end

  defp default_dst do
    Path.join(System.tmp_dir!(), "phoenix-agentfriendly")
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

    lock_path = Path.join(target, ".agentfriendly/phoenix-agentfriendly.lock.json")
    lock_commit = lock_path |> File.read!() |> extract_commit()
    expected = current_commit(dst)

    if lock_commit != expected do
      Mix.raise("outdated: lock=#{lock_commit} expected=#{expected}")
    end

    Mix.shell().info("phoenix-agentfriendly is up to date (#{expected})")
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
    path = Path.join(target, ".agentfriendly/phoenix-agentfriendly.lock.json")
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

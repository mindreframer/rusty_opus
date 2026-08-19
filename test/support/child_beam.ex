defmodule RustyOpus.TestHelpers.ChildBEAM do
  @moduledoc """
  Run code in a disposable child BEAM OS process.

  The child is a separate OS process, so a crash there cannot take down the parent
  test BEAM. Used for panic-containment and (in later epics) fuzz/robustness checks.
  """

  @doc """
  Runs an Elixir `expr` string in a fresh child BEAM (bare `elixir -e`), returning
  `{:ok, stdout}` on exit 0 or `{:error, {status, output}}`.
  """
  @spec run(binary()) :: {:ok, binary()} | {:error, {integer(), binary()}}
  def run(expr) when is_binary(expr) do
    elixir = System.find_executable("elixir")

    {out, status} = System.cmd(elixir, ["-e", expr], stderr_to_stdout: true)

    case status do
      0 -> {:ok, out}
      _ -> {:error, {status, out}}
    end
  end

  @doc """
  Runs a project command in a fresh child BEAM via `mix run`, useful once the NIF is
  required. Returns `{:ok, stdout}` or `{:error, {status, output}}`.
  """
  @spec run_mix(binary()) :: {:ok, binary()} | {:error, {integer(), binary()}}
  def run_mix(expr) when is_binary(expr) do
    project_root = Path.expand("../../../", __DIR__)

    {out, status} =
      System.cmd("mix", ["run", "--no-compile", "-e", expr],
        cd: project_root,
        stderr_to_stdout: true
      )

    case status do
      0 -> {:ok, out}
      _ -> {:error, {status, out}}
    end
  end

  @doc """
  Proves the child-boundary works: prints `child-ok` from a child BEAM.
  """
  @spec smoke() :: {:ok, binary()}
  def smoke do
    run(~s|IO.puts("child-ok")|)
  end
end

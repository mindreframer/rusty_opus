defmodule RustyOpus.Quality do
  @moduledoc """
  Quality presets for encoding / re-encoding ("changing the quality").

  Three presets tune `bitrate`, `complexity`, and VBR/CBR together:

    * `:low` — 24 kb/s, complexity 4
    * `:medium` — 48 kb/s, complexity 8
    * `:high` — 96 kb/s, complexity 10

  Higher presets produce larger Opus packets with better fidelity. `:target_bitrate`
  overrides the preset's bitrate, and any other `RustyOpus.Settings` option can be
  passed as an override too.
  """

  alias RustyOpus.{Error, Settings}

  @presets %{
    low: [bitrate: 24_000, complexity: 4],
    medium: [bitrate: 48_000, complexity: 8],
    high: [bitrate: 96_000, complexity: 10]
  }

  @type quality :: :low | :medium | :high | Settings.t()

  @doc """
  The preset tables as a map of atom → settings keyword list.
  """
  @spec presets() :: %{atom() => keyword()}
  def presets, do: @presets

  @doc """
  Resolves a quality spec (preset atom or `RustyOpus.Settings`) plus overrides into
  validated settings.

  ## Options

  `:target_bitrate` overrides `:bitrate`; any `RustyOpus.Settings` key may override
  the preset value.
  """
  @spec to_settings(quality(), keyword()) :: {:ok, Settings.t()} | {:error, Error.t()}
  def to_settings(quality, opts \\ [])

  def to_settings(quality, opts) when is_atom(quality) do
    with {:ok, base} <- base(quality) do
      override(base, opts)
    end
  end

  def to_settings(%Settings{} = settings, opts) do
    override(settings, opts)
  end

  defp base(quality) do
    case Map.fetch(@presets, quality) do
      {:ok, kv} ->
        Settings.new(kv)

      :error ->
        {:error,
         RustyOpus.rustle(
           :invalid_settings,
           "unknown quality preset #{inspect(quality)} (allowed: #{inspect(Map.keys(@presets))})"
         )}
    end
  end

  defp override(%Settings{} = settings, opts) when is_list(opts) do
    base_kw =
      [
        bitrate: settings.bitrate,
        complexity: settings.complexity,
        cbr: settings.cbr,
        fec: settings.fec,
        packet_loss: settings.packet_loss
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    kw =
      case Keyword.pop(opts, :target_bitrate) do
        {nil, rest} -> rest
        {bitrate, rest} -> Keyword.put(rest, :bitrate, bitrate)
      end

    Settings.new(Keyword.merge(base_kw, kw))
  end
end

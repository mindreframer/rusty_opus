defmodule RustyOpus.OggOpus do
  @moduledoc """
  In-memory Ogg Opus family-0 file APIs.

  This module is deliberately separate from the raw Opus packet APIs on
  `RustyOpus`. Output is a minimal Ogg Opus file and does not copy comments.
  """

  alias RustyOpus.PCM

  @allowed [
    :bitrate,
    :bitrate_mode,
    :cbr,
    :application,
    :complexity,
    :frame_duration_ms,
    :sample_rate,
    :channels
  ]

  @spec decode(binary()) :: {:ok, PCM.t()} | {:error, RustyOpus.Error.t()}
  def decode(blob) when is_binary(blob) do
    case RustyOpus.Native.ogg_decode(blob) do
      {:ok, {rate, channels, data}} -> PCM.new(data, rate, channels)
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  def decode(_), do: {:error, RustyOpus.rustle(:invalid_input, "Ogg Opus blob must be a binary")}

  @spec encode(PCM.t(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def encode(%PCM{} = pcm, opts) when is_list(opts) do
    with {:ok, settings} <- validate_settings(opts),
         :ok <- PCM.validate(pcm),
         {:ok, pcm} <- PCM.transform(pcm, transform_opts(opts)),
         {:ok, output} <- native_encode(pcm, settings) do
      {:ok, output}
    end
  end

  def encode(_, _),
    do:
      {:error,
       RustyOpus.rustle(
         :invalid_input,
         "Ogg Opus encode expects a PCM struct and keyword options"
       )}

  @spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def reencode(blob, opts) when is_binary(blob) and is_list(opts) do
    with {:ok, _settings} <- validate_settings(opts),
         {:ok, pcm} <- decode(blob),
         {:ok, output} <- encode(pcm, opts) do
      {:ok, output}
    end
  end

  def reencode(_, _),
    do: {:error, RustyOpus.rustle(:invalid_input, "Ogg Opus blob must be a binary")}

  defp native_encode(%PCM{data: data, channels: channels}, settings) do
    case RustyOpus.Native.ogg_encode(data, channels, settings) do
      {:ok, output} -> {:ok, output}
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  defp validate_settings(opts) do
    keys = if Keyword.keyword?(opts), do: Keyword.keys(opts), else: []

    cond do
      not Keyword.keyword?(opts) ->
        {:error, RustyOpus.rustle(:invalid_settings, "options must be a keyword list")}

      length(keys) != length(Enum.uniq(keys)) ->
        {:error,
         RustyOpus.rustle(:invalid_settings, "duplicate Ogg Opus options are not allowed")}

      Enum.any?(keys, &(&1 not in @allowed)) ->
        bad = Enum.find(keys, &(&1 not in @allowed))
        {:error, RustyOpus.rustle(:invalid_settings, "unknown Ogg Opus option: #{inspect(bad)}")}

      Keyword.has_key?(opts, :bitrate_mode) and Keyword.has_key?(opts, :cbr) ->
        {:error,
         RustyOpus.rustle(:invalid_settings, "bitrate_mode and cbr cannot both be supplied")}

      true ->
        RustyOpus.reencode_settings(opts)
    end
  end

  defp transform_opts(opts) do
    # Ogg Opus family 0 has a 48 kHz coded clock. The input is always
    # normalized to that clock; `:sample_rate` is not an alternate Ogg clock.
    Keyword.take(opts, [:channels]) ++ [sample_rate: 48_000]
  end
end

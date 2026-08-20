defmodule RustyOpus.WAV do
  @moduledoc """
  In-memory RIFF/WAVE PCM conversion.

  Supported output formats are `:s16`, `:s24`, `:s32`, and `:f32`. Unknown
  chunks are skipped while re-encoding produces a minimal canonical file.
  """

  alias RustyOpus.PCM

  @allowed_encode [:sample_format, :sample_rate, :channels]

  @spec decode(binary()) :: {:ok, PCM.t()} | {:error, RustyOpus.Error.t()}
  def decode(blob) when is_binary(blob) do
    case RustyOpus.Native.wav_decode(blob) do
      {:ok, {rate, channels, data}} -> PCM.new(data, rate, channels)
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  def decode(_), do: {:error, RustyOpus.rustle(:invalid_input, "WAV blob must be a binary")}

  @spec encode(PCM.t(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def encode(%PCM{} = pcm, opts) when is_list(opts) do
    with :ok <- validate_options(opts, @allowed_encode, [:sample_format]),
         {:ok, format} <- sample_format(opts),
         :ok <- PCM.validate(pcm),
         {:ok, pcm} <- PCM.transform(pcm, opts),
         {:ok, out} <- native_encode(pcm, format) do
      {:ok, out}
    end
  end

  def encode(_, _),
    do:
      {:error,
       RustyOpus.rustle(:invalid_input, "WAV encode expects a PCM struct and keyword options")}

  @spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def reencode(blob, opts) when is_binary(blob) and is_list(opts) do
    with :ok <- validate_options(opts, @allowed_encode, [:sample_format]),
         {:ok, _format} <- sample_format(opts),
         {:ok, pcm} <- decode(blob),
         {:ok, output} <- encode(pcm, opts) do
      {:ok, output}
    end
  end

  def reencode(_, _), do: {:error, RustyOpus.rustle(:invalid_input, "WAV blob must be a binary")}

  defp native_encode(%PCM{data: data, sample_rate: rate, channels: channels}, format) do
    case RustyOpus.Native.wav_encode(data, rate, channels, Atom.to_string(format)) do
      {:ok, output} -> {:ok, output}
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  defp sample_format(opts) do
    case Keyword.fetch(opts, :sample_format) do
      {:ok, format} when format in [:s16, :s24, :s32, :f32] ->
        {:ok, format}

      {:ok, _} ->
        {:error,
         RustyOpus.rustle(:invalid_settings, "sample_format must be :s16, :s24, :s32, or :f32")}

      :error ->
        {:error, RustyOpus.rustle(:invalid_settings, "sample_format is required")}
    end
  end

  defp validate_options(opts, allowed, required) do
    if not Keyword.keyword?(opts) do
      {:error, RustyOpus.rustle(:invalid_settings, "options must be a keyword list")}
    else
      keys = Keyword.keys(opts)

      cond do
        Enum.any?(keys, &(&1 not in allowed)) ->
          bad = Enum.find(keys, &(&1 not in allowed))
          {:error, RustyOpus.rustle(:invalid_settings, "unknown WAV option: #{inspect(bad)}")}

        Enum.any?(required, &(not Keyword.has_key?(opts, &1))) ->
          missing = Enum.find(required, &(not Keyword.has_key?(opts, &1)))
          {:error, RustyOpus.rustle(:invalid_settings, "#{missing} is required")}

        length(keys) != length(Enum.uniq(keys)) ->
          {:error, RustyOpus.rustle(:invalid_settings, "duplicate WAV options are not allowed")}

        true ->
          :ok
      end
    end
  end
end

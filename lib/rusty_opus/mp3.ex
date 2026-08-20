defmodule RustyOpus.MP3 do
  @moduledoc """
  In-memory MPEG Layer III conversion backed by the pinned pure-Rust MP3 codec.

  MP3 output accepts standard numeric bitrates in bits per second. `:bitrate_mode`
  is `:vbr` by default or `:cbr`; metadata such as ID3 tags is not preserved.
  """

  alias RustyOpus.PCM

  @allowed [:bitrate, :bitrate_mode, :sample_rate, :channels]

  @spec decode(binary()) :: {:ok, PCM.t()} | {:error, RustyOpus.Error.t()}
  def decode(blob) when is_binary(blob) do
    case RustyOpus.Native.mp3_decode(blob) do
      {:ok, {rate, channels, data}} -> PCM.new(data, rate, channels)
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  def decode(_), do: {:error, RustyOpus.rustle(:invalid_input, "MP3 blob must be a binary")}

  @spec encode(PCM.t(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def encode(%PCM{} = pcm, opts) when is_list(opts) do
    with :ok <- validate_options(opts),
         {:ok, bitrate} <- required_bitrate(opts),
         {:ok, vbr} <- bitrate_mode(opts),
         :ok <- PCM.validate(pcm),
         {:ok, pcm} <- PCM.transform(pcm, opts),
         {:ok, output} <- native_encode(pcm, bitrate, vbr) do
      {:ok, output}
    end
  end

  def encode(_, _),
    do:
      {:error,
       RustyOpus.rustle(:invalid_input, "MP3 encode expects a PCM struct and keyword options")}

  @spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def reencode(blob, opts) when is_binary(blob) and is_list(opts) do
    with :ok <- validate_options(opts),
         {:ok, _bitrate} <- required_bitrate(opts),
         {:ok, _mode} <- bitrate_mode(opts),
         {:ok, pcm} <- decode(blob),
         {:ok, output} <- encode(pcm, opts) do
      {:ok, output}
    end
  end

  def reencode(_, _), do: {:error, RustyOpus.rustle(:invalid_input, "MP3 blob must be a binary")}

  defp native_encode(%PCM{data: data, sample_rate: rate, channels: channels}, bitrate, vbr) do
    settings = %{bitrate: bitrate, vbr: vbr}

    case RustyOpus.Native.mp3_encode(data, rate, channels, settings) do
      {:ok, output} -> {:ok, output}
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  defp required_bitrate(opts) do
    case Keyword.fetch(opts, :bitrate) do
      {:ok, bitrate} when is_integer(bitrate) and bitrate > 0 ->
        {:ok, bitrate}

      {:ok, _} ->
        {:error, RustyOpus.rustle(:invalid_settings, "bitrate must be a positive integer")}

      :error ->
        {:error, RustyOpus.rustle(:invalid_settings, "bitrate is required")}
    end
  end

  defp bitrate_mode(opts) do
    case Keyword.get(opts, :bitrate_mode, :vbr) do
      :vbr -> {:ok, true}
      :cbr -> {:ok, false}
      _ -> {:error, RustyOpus.rustle(:invalid_settings, "bitrate_mode must be :vbr or :cbr")}
    end
  end

  defp validate_options(opts) do
    if not Keyword.keyword?(opts) do
      {:error, RustyOpus.rustle(:invalid_settings, "options must be a keyword list")}
    else
      keys = Keyword.keys(opts)

      cond do
        length(keys) != length(Enum.uniq(keys)) ->
          {:error, RustyOpus.rustle(:invalid_settings, "duplicate MP3 options are not allowed")}

        Enum.any?(keys, &(&1 not in @allowed)) ->
          bad = Enum.find(keys, &(&1 not in @allowed))
          {:error, RustyOpus.rustle(:invalid_settings, "unknown MP3 option: #{inspect(bad)}")}

        true ->
          :ok
      end
    end
  end
end

defmodule RustyOpus do
  @moduledoc """
  Pure-Rust [Opus](https://opus-codec.org/) (RFC 6716) for Elixir.

  Shrink an Ogg Opus blob to a numeric bitrate in one call (no ffmpeg, no C libopus):

      {:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)

  Raw packet/PCM helpers remain for codec work without a container:

      {:ok, packets} = RustyOpus.encode(pcm, 16_000, 1, bitrate: 24_000)
      {:ok, pcm}     = RustyOpus.decode(packets, 16_000, 1)

  ## Data contract

  - **Ogg Opus** blobs are RFC 7845 files (`OggS` …) — the `reencode/2` input/output.
  - **PCM** is a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved
    for stereo.
  - **Opus packets** are raw binaries (no container).

  ## Boundary

  Codec and Ogg Opus reencode run in-process via Rustler. No external process, Port,
  or executable is used for codec work.
  """

  @doc """
  Returns the loaded native library version as `{:ok, version}`.

  This proves the Elixir/Rust boundary is live. It fails with `{:error, ...}` if the
  NIF is not loaded.
  """
  @spec native_smoke() :: {:ok, String.t()} | {:error, term()}
  def native_smoke do
    case RustyOpus.Native.smoke() do
      {:ok, version} -> {:ok, version}
      other -> {:error, other}
    end
  end

  @doc """
  Translates a deterministic native error into a stable `RustyOpus.Error`.
  """
  @spec translated_error() :: {:error, RustyOpus.Error.t()}
  def translated_error do
    {:error, rustle(:native, "deterministic native error")}
  end

  @doc """
  Runs a contained native panic and reports `{:error, :contained_panic}`.

  The panic never unwinds across the NIF boundary, so the caller BEAM is untouched.
  """
  @spec contained_panic() :: {:error, :contained_panic} | {:ok, term()}
  def contained_panic do
    case RustyOpus.Native.contained_panic() do
      {:error, :contained_panic, _} -> {:error, :contained_panic}
      other -> {:ok, other}
    end
  end

  @doc """
  Reencodes an Ogg Opus blob at a target bitrate (bits/s).

  This is the simple API for shrinking real `.ogg` / `audio/ogg` files in memory:
  demux → decode → encode at `bitrate` → remux, all pure Rust (`opus-rs` + thin Ogg).

  ## Options

    * `:bitrate` (required) — positive integer, bits per second (e.g. `20_000`)

  ## Example

      {:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)
  """
  @spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def reencode(blob, opts \\ [])

  def reencode(blob, opts) when is_binary(blob) and is_list(opts) do
    case Keyword.fetch(opts, :bitrate) do
      {:ok, bitrate} when is_integer(bitrate) and bitrate > 0 ->
        case RustyOpus.Native.ogg_reencode(blob, bitrate) do
          {:ok, out} -> {:ok, out}
          {:error, {reason, message}} -> {:error, rustle(reason, message)}
        end

      {:ok, _} ->
        {:error, rustle(:invalid_settings, "bitrate must be a positive integer")}

      :error ->
        {:error, rustle(:invalid_settings, "bitrate is required")}
    end
  end

  def reencode(_, _), do: {:error, rustle(:invalid_input, "Ogg Opus blob must be a binary")}

  @doc """
  Encodes a whole PCM buffer into a list of Opus packets.

  Opens a short-lived encoder, runs the bulk path, and closes it. `opts` accept
  encoder settings (`RustyOpus.Settings`), optional `:frame_size` (default
  `div(rate, 50)`), optional `:quality` (preset atom or `Settings`), and
  `:application` (default `:audio`). A short last frame is padded with silence.
  """
  @spec encode(binary(), pos_integer(), 1 | 2, keyword()) ::
          {:ok, [binary()]} | {:error, RustyOpus.Error.t()}
  def encode(pcm, rate, channels, opts \\ [])

  def encode(pcm, rate, channels, opts)
      when is_binary(pcm) and is_integer(rate) and channels in [1, 2] and is_list(opts) do
    {frame_size, opts} = Keyword.pop(opts, :frame_size, div(rate, 50))
    {quality, opts} = Keyword.pop(opts, :quality)
    application = Keyword.get(opts, :application, :audio)

    with {:ok, encoder_opts} <- resolve_encode_opts(quality, opts),
         {:ok, encoder} <-
           RustyOpus.Encoder.new(rate, channels, application, encoder_opts) do
      try do
        RustyOpus.Encoder.encode_many(encoder, pcm, frame_size: frame_size)
      after
        RustyOpus.Encoder.close(encoder)
      end
    end
  end

  def encode(_, _, _, _), do: {:error, rustle(:invalid_input, "pcm must be a binary")}

  @doc """
  Decodes a list of Opus packets into one concatenated PCM binary.

  Opens a short-lived decoder, runs the bulk path, and closes it. Optional
  `:frame_size` defaults to `div(rate, 50)`.
  """
  @spec decode([binary()], pos_integer(), 1 | 2, keyword()) ::
          {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def decode(packets, rate, channels, opts \\ [])

  def decode(packets, rate, channels, opts)
      when is_list(packets) and is_integer(rate) and channels in [1, 2] and is_list(opts) do
    if Enum.all?(packets, &is_binary/1) do
      frame_size = Keyword.get(opts, :frame_size, div(rate, 50))

      with {:ok, decoder} <- RustyOpus.Decoder.new(rate, channels) do
        try do
          RustyOpus.Decoder.decode_many(decoder, packets, frame_size: frame_size)
        after
          RustyOpus.Decoder.close(decoder)
        end
      end
    else
      {:error, rustle(:invalid_input, "packets must be a list of binaries")}
    end
  end

  def decode(_, _, _, _),
    do: {:error, rustle(:invalid_input, "packets must be a list of binaries")}

  @doc """
  Transcodes a list of Opus packets to a new quality.

  Bulk-decodes then bulk-encodes at `quality` (same resolution as `change_quality/5`).
  One input packet produces one output packet, in order. `opts` may include
  `:frame_size`, `:target_bitrate`, and other `RustyOpus.Settings` keys.
  """
  @spec transcode([binary()], pos_integer(), 1 | 2, RustyOpus.Quality.quality(), keyword()) ::
          {:ok, [binary()]} | {:error, RustyOpus.Error.t()}
  def transcode(packets, rate, channels, quality, opts \\ [])

  def transcode(packets, rate, channels, quality, opts)
      when is_list(packets) and is_integer(rate) and channels in [1, 2] and is_list(opts) do
    frame_size = Keyword.get(opts, :frame_size, div(rate, 50))

    with {:ok, settings} <- RustyOpus.Quality.to_settings(quality, opts),
         {:ok, pcm} <- decode(packets, rate, channels, frame_size: frame_size) do
      encode_opts =
        settings
        |> RustyOpus.Settings.to_native()
        |> native_to_opts()
        |> Keyword.put(:frame_size, frame_size)

      encode(pcm, rate, channels, encode_opts)
    end
  end

  def transcode(_, _, _, _, _),
    do: {:error, rustle(:invalid_input, "packets must be a list of binaries")}

  @doc """
  Encodes a single PCM frame into an Opus packet with a short-lived encoder.

  `pcm` must contain exactly one frame (`frame_size * channels` samples). `opts` are
  passed to `RustyOpus.Encoder.new/4` (see `RustyOpus.Settings` and `RustyOpus.Quality`).
  Prefer `encode/4` for whole buffers.
  """
  @spec encode_pcm(binary(), pos_integer(), 1 | 2, keyword()) ::
          {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def encode_pcm(pcm, rate, channels, opts \\ [])
      when is_binary(pcm) and is_integer(rate) and channels in [1, 2] and is_list(opts) do
    with {:ok, encoder} <- RustyOpus.Encoder.new(rate, channels, application(opts), opts) do
      frame_size = div(RustyOpus.PCM.sample_count(pcm), channels)
      result = RustyOpus.Encoder.encode(encoder, pcm, frame_size)
      RustyOpus.Encoder.close(encoder)
      result
    end
  end

  @doc """
  Decodes a single Opus packet into PCM with a short-lived decoder.

  `frame_size` is the number of samples per channel in the decoded frame.
  Prefer `decode/4` for packet lists.
  """
  @spec decode_packet(binary(), pos_integer(), 1 | 2, pos_integer()) ::
          {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def decode_packet(packet, rate, channels, frame_size)
      when is_binary(packet) and is_integer(rate) and channels in [1, 2] and
             is_integer(frame_size) do
    with {:ok, decoder} <- RustyOpus.Decoder.new(rate, channels) do
      result = RustyOpus.Decoder.decode(decoder, packet, frame_size)
      RustyOpus.Decoder.close(decoder)
      result
    end
  end

  @doc """
  Changes the encoding quality of one Opus `packet`: decodes it to PCM and re-encodes
  it at a new quality, returning the re-encoded packet.

  Prefer `transcode/5` for whole streams. `quality` is a preset
  (`:low`/`:medium`/`:high`) or a `RustyOpus.Settings` struct. Options:

    * `:target_bitrate` — overrides the preset bitrate
    * `:frame_size` — decoded frame size in samples per channel (default `div(rate, 50)`)
    * any other `RustyOpus.Settings` key — overrides the preset

  ## Example

      {:ok, high} = RustyOpus.change_quality(packet, 16_000, 1, :high)
      {:ok, low} = RustyOpus.change_quality(packet, 16_000, 1, :low, target_bitrate: 12_000)
  """
  @spec change_quality(binary(), pos_integer(), 1 | 2, RustyOpus.Quality.quality(), keyword()) ::
          {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def change_quality(packet, rate, channels, quality, opts \\ [])
      when is_binary(packet) and is_integer(rate) and channels in [1, 2] and is_list(opts) do
    frame_size = Keyword.get(opts, :frame_size, div(rate, 50))

    with {:ok, settings} <- RustyOpus.Quality.to_settings(quality, opts),
         {:ok, pcm} <- decode_packet(packet, rate, channels, frame_size) do
      encode_pcm(pcm, rate, channels, RustyOpus.Settings.to_native(settings) |> native_to_opts())
    end
  end

  @doc false
  def rustle(reason, message) do
    %RustyOpus.Error{reason: normalize_reason(reason), message: message}
  end

  @reasons %{
    "native" => :native,
    "closed" => :closed,
    "poisoned" => :poisoned,
    "invalid_pcm" => :invalid_pcm,
    "invalid_input" => :invalid_input,
    "invalid_settings" => :invalid_settings,
    "invalid_application" => :invalid_application,
    "invalid_rate" => :invalid_rate,
    "encode_failed" => :encode_failed,
    "decode_failed" => :decode_failed,
    "codec_panicked" => :codec_panicked
  }

  defp normalize_reason(reason) when is_binary(reason), do: Map.get(@reasons, reason, reason)
  defp normalize_reason(reason), do: reason

  defp application(opts), do: Keyword.get(opts, :application, :audio)

  defp resolve_encode_opts(nil, opts), do: {:ok, opts}

  defp resolve_encode_opts(quality, opts) do
    with {:ok, settings} <- RustyOpus.Quality.to_settings(quality, opts) do
      {:ok, settings |> RustyOpus.Settings.to_native() |> native_to_opts()}
    end
  end

  defp native_to_opts(map) do
    for {k, v} <- map, not is_nil(v), do: {k, v}
  end
end

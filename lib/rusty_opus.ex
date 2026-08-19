defmodule RustyOpus do
  @moduledoc """
  Pure-Rust [Opus](https://opus-codec.org/) (RFC 6716) for Elixir, wrapped from the
  `opus-rs` codec through Rustler.

  RustyOpus encodes PCM audio to Opus packets and decodes Opus packets to PCM, with
  full control over encoding bitrate and quality so you can **change the quality of an
  encoding**: decode audio to PCM and re-encode it at a different bitrate or a
  `:low`/`:medium`/`:high` preset.

  ## Data contract

  - **PCM** is a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved
    for stereo. This is the stable PCM contract used by `RustyOpus.Encoder` and
    `RustyOpus.Decoder`.
  - **Opus packets** are raw binaries.

  ## Boundary

  RustyOpus targets the raw Opus CODEC. It does not parse, demux, or mux media
  containers (such as Ogg/Opus `.ogg` files). It never launches an external process,
  a Port, or an executable for codec work. See `RustyOpus.Encoder` and
  `RustyOpus.Decoder` for the codec API and `RustyOpus.change_quality/4` for
  re-encoding at a new quality.
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
  Encodes a single PCM frame into an Opus packet with a short-lived encoder.

  `pcm` must contain exactly one frame (`frame_size * channels` samples). `opts` are
  passed to `RustyOpus.Encoder.new/4` (see `RustyOpus.Settings` and `RustyOpus.Quality`).
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

  `quality` is a preset (`:low`/`:medium`/`:high`) or a `RustyOpus.Settings` struct.
  Options:

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

  defp native_to_opts(map) do
    for {k, v} <- map, not is_nil(v), do: {k, v}
  end
end

defmodule RustyOpus do
  import Bitwise

  @moduledoc """
  Pure-Rust [Opus](https://opus-codec.org/) (RFC 6716) for Elixir.

  Shrink an Ogg Opus blob to a numeric bitrate in one call (no ffmpeg, no C libopus).
  Defaults are speech-oriented (VoIP, complexity 10, VBR, 20 ms):

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

  Demux → decode → encode → remux, all pure Rust (`opus-rs` + thin Ogg).

  Defaults match the MemoMoo FFmpeg speech ladder as closely as `opus-rs`
  allows: VoIP, complexity 10, VBR, 20 ms frames.

  ## Options

    * `:bitrate` (required) — positive integer, bits per second (e.g. `20_000`)
    * `:application` — `:voip` (default), `:audio`, or `:restricted_low_delay`
    * `:complexity` — `0..10` (default `10`, FFmpeg `-compression_level`)
    * `:cbr` — `true` for CBR; default `false` (VBR, FFmpeg `-vbr on`)
    * `:frame_duration_ms` — `10` or `20` (default `20`). `40`/`60` are rejected:
      `opus-rs` cannot encode those durations at 48 kHz on this path.

  ## Example

      {:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)

      {:ok, smaller} =
        RustyOpus.reencode(ogg_blob,
          bitrate: 20_000,
          application: :voip,
          complexity: 10,
          cbr: false,
          frame_duration_ms: 20
        )
  """
  @spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def reencode(blob, opts \\ [])

  def reencode(blob, opts) when is_binary(blob) and is_list(opts) do
    RustyOpus.OggOpus.reencode(blob, opts)
  end

  def reencode(_, _), do: {:error, rustle(:invalid_input, "Ogg Opus blob must be a binary")}

  @doc false
  def reencode_settings(opts) do
    with {:ok, bitrate} <- fetch_bitrate(opts),
         {:ok, application} <- fetch_application(opts),
         {:ok, complexity} <- fetch_complexity(opts),
         {:ok, cbr} <- fetch_cbr(opts),
         {:ok, frame_duration_ms} <- fetch_frame_duration_ms(opts) do
      {:ok,
       %{
         bitrate: bitrate,
         application: Atom.to_string(application),
         complexity: complexity,
         cbr: cbr,
         frame_duration_ms: frame_duration_ms
       }}
    end
  end

  defp fetch_bitrate(opts) do
    case Keyword.fetch(opts, :bitrate) do
      {:ok, bitrate} when is_integer(bitrate) and bitrate > 0 -> {:ok, bitrate}
      {:ok, _} -> {:error, rustle(:invalid_settings, "bitrate must be a positive integer")}
      :error -> {:error, rustle(:invalid_settings, "bitrate is required")}
    end
  end

  defp fetch_application(opts) do
    case Keyword.get(opts, :application, :voip) do
      app when app in [:voip, :audio, :restricted_low_delay] ->
        {:ok, app}

      _ ->
        {:error,
         rustle(:invalid_settings, "application must be :voip, :audio, or :restricted_low_delay")}
    end
  end

  defp fetch_complexity(opts) do
    case Keyword.get(opts, :complexity, 10) do
      c when is_integer(c) and c in 0..10 -> {:ok, c}
      _ -> {:error, rustle(:invalid_settings, "complexity must be an integer between 0 and 10")}
    end
  end

  defp fetch_cbr(opts) do
    value =
      case Keyword.fetch(opts, :bitrate_mode) do
        {:ok, :vbr} -> false
        {:ok, :cbr} -> true
        {:ok, _} -> :invalid
        :error -> Keyword.get(opts, :cbr, false)
      end

    case value do
      cbr when is_boolean(cbr) -> {:ok, cbr}
      :invalid -> {:error, rustle(:invalid_settings, "bitrate_mode must be :vbr or :cbr")}
      _ -> {:error, rustle(:invalid_settings, "cbr must be a boolean")}
    end
  end

  defp fetch_frame_duration_ms(opts) do
    case Keyword.get(opts, :frame_duration_ms, 20) do
      ms when ms in [10, 20] ->
        {:ok, ms}

      ms when ms in [40, 60] ->
        {:error,
         rustle(
           :invalid_settings,
           "frame_duration_ms 40 and 60 are not supported by opus-rs at 48 kHz; use 10 or 20"
         )}

      _ ->
        {:error, rustle(:invalid_settings, "frame_duration_ms must be 10 or 20")}
    end
  end

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

  @doc "Converts a WAV, MP3, or Ogg Opus blob, or a `%RustyOpus.PCM{}`, to a supported target."
  @spec convert(binary() | RustyOpus.PCM.t(), keyword()) ::
          {:ok, binary() | RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}
  def convert(input, opts) when is_list(opts) do
    if not Keyword.keyword?(opts) do
      {:error, rustle(:invalid_settings, "conversion options must be a keyword list")}
    else
      convert_valid(input, opts)
    end
  end

  def convert(_, _),
    do: {:error, rustle(:invalid_settings, "conversion options must be a keyword list")}

  defp convert_valid(input, opts) do
    with {:ok, target} <- conversion_target(opts),
         :ok <- conversion_options(opts, target),
         {:ok, source, pcm} <- conversion_input(input, opts),
         {:ok, result} <- convert_pipeline(source, pcm, target, opts) do
      {:ok, result}
    end
  end

  defp conversion_target(opts) do
    case Keyword.fetch(opts, :to) do
      {:ok, target} when target in [:ogg_opus, :mp3, :wav, :pcm] ->
        {:ok, target}

      {:ok, _} ->
        {:error, rustle(:invalid_settings, ":to must be :ogg_opus, :mp3, :wav, or :pcm")}

      :error ->
        {:error, rustle(:invalid_settings, ":to is required")}
    end
  end

  defp conversion_options(opts, target) do
    if not Keyword.keyword?(opts) do
      {:error, rustle(:invalid_settings, "conversion options must be a keyword list")}
    else
      keys = Keyword.keys(opts)
      allowed = [:to, :from, :bitrate, :bitrate_mode, :sample_rate, :channels, :sample_format]

      target_allowed =
        case target do
          :ogg_opus -> [:to, :from, :bitrate, :bitrate_mode, :channels]
          :mp3 -> [:to, :from, :bitrate, :bitrate_mode, :sample_rate, :channels]
          :wav -> [:to, :from, :sample_rate, :channels, :sample_format]
          :pcm -> [:to, :from, :sample_rate, :channels]
        end

      with :ok <- validate_common_values(opts, target) do
        cond do
          length(keys) != length(Enum.uniq(keys)) ->
            {:error, rustle(:invalid_settings, "duplicate conversion options are not allowed")}

          Enum.any?(keys, &(&1 not in allowed)) ->
            {:error, rustle(:invalid_settings, "unknown conversion option")}

          Enum.any?(keys, &(&1 not in target_allowed)) ->
            {:error,
             rustle(:invalid_settings, "conversion option is not applicable to #{target}")}

          target in [:ogg_opus, :mp3] and not Keyword.has_key?(opts, :bitrate) ->
            {:error, rustle(:invalid_settings, "bitrate is required for #{target} output")}

          target == :wav and not Keyword.has_key?(opts, :sample_format) ->
            {:error, rustle(:invalid_settings, "sample_format is required for WAV output")}

          target == :pcm and Keyword.has_key?(opts, :bitrate) ->
            {:error, rustle(:invalid_settings, "bitrate is not applicable to PCM output")}

          true ->
            :ok
        end
      end
    end
  end

  defp validate_common_values(opts, _target) do
    checks = [
      {Keyword.get(opts, :bitrate, :missing),
       fn value -> value == :missing or (is_integer(value) and value > 0) end,
       "bitrate must be a positive integer"},
      {Keyword.get(opts, :bitrate_mode, :vbr), &(&1 in [:vbr, :cbr]),
       "bitrate_mode must be :vbr or :cbr"},
      {Keyword.get(opts, :sample_rate, :missing),
       fn value ->
         value == :missing or (is_integer(value) and value > 0 and value <= 192_000)
       end, "sample_rate must be an integer between 1 and 192000"},
      {Keyword.get(opts, :channels, :missing),
       fn value -> value == :missing or value in [1, 2] end, "channels must be 1 or 2"},
      {Keyword.get(opts, :sample_format, :missing),
       fn value -> value == :missing or value in [:s16, :s24, :s32, :f32] end,
       "sample_format must be :s16, :s24, :s32, or :f32"}
    ]

    case Enum.find(checks, fn {value, valid, _message} ->
           not valid.(value)
         end) do
      nil -> :ok
      {_value, _valid, message} -> {:error, rustle(:invalid_settings, message)}
    end
  end

  defp conversion_input(%RustyOpus.PCM{} = pcm, opts) do
    if Keyword.has_key?(opts, :from),
      do: {:error, rustle(:invalid_settings, ":from is not allowed for PCM input")},
      else: {:ok, :pcm, pcm}
  end

  defp conversion_input(input, opts) when is_binary(input) do
    with {:ok, source} <- detect_format(input, Keyword.get(opts, :from, :auto)),
         {:ok, pcm} <- decode_source(source, input) do
      {:ok, source, pcm}
    end
  end

  defp conversion_input(_, _),
    do: {:error, rustle(:invalid_input, "conversion input must be a binary or PCM struct")}

  defp detect_format(_input, from) when from not in [:auto, :ogg_opus, :mp3, :wav],
    do: {:error, rustle(:invalid_settings, ":from must be :auto, :ogg_opus, :mp3, or :wav")}

  defp detect_format(input, :wav) do
    if wav_signature?(input),
      do: {:ok, :wav},
      else: {:error, rustle(:format_mismatch, "input is not a supported RIFF/WAVE file")}
  end

  defp detect_format(input, :ogg_opus) do
    if ogg_opus_signature?(input),
      do: {:ok, :ogg_opus},
      else: {:error, rustle(:format_mismatch, "input is not an Ogg Opus family-0 file")}
  end

  defp detect_format(input, :mp3) do
    if mp3_signature?(input),
      do: {:ok, :mp3},
      else: {:error, rustle(:format_mismatch, "input is not an MP3 file")}
  end

  defp detect_format(input, :auto) do
    cond do
      wav_signature?(input) ->
        {:ok, :wav}

      ogg_opus_signature?(input) ->
        {:ok, :ogg_opus}

      mp3_signature?(input) ->
        {:ok, :mp3}

      true ->
        {:error,
         rustle(:unsupported_format, "input format is not a supported WAV, MP3, or Ogg Opus blob")}
    end
  end

  defp wav_signature?(input) when byte_size(input) < 12, do: false

  defp wav_signature?(<<"RIFF", riff_size::little-unsigned-32, "WAVE", _rest::binary>> = input) do
    end_pos = 8 + riff_size
    end_pos <= byte_size(input) and end_pos >= 12 and wav_chunks?(input, 12, end_pos, false)
  end

  defp wav_signature?(_), do: false

  defp wav_chunks?(_input, pos, end_pos, fmt?) when pos == end_pos, do: fmt?
  defp wav_chunks?(_input, pos, end_pos, _fmt?) when pos + 8 > end_pos, do: false

  defp wav_chunks?(input, pos, end_pos, fmt?) do
    <<id::binary-size(4), size::little-unsigned-32>> = binary_part(input, pos, 8)
    content = pos + 8
    padded = size + rem(size, 2)

    if content + padded > end_pos do
      false
    else
      next_fmt? = fmt? or id == "fmt "
      wav_chunks?(input, content + padded, end_pos, next_fmt?)
    end
  end

  defp ogg_opus_signature?(input) when byte_size(input) < 27, do: false

  defp ogg_opus_signature?(
         <<"OggS", 0, _flags, _granule::little-unsigned-64, _serial::little-unsigned-32,
           _sequence::little-unsigned-32, _crc::little-unsigned-32, count, _rest::binary>> = input
       ) do
    if byte_size(input) >= 27 + count do
      segments = binary_part(input, 27, count)
      body_size = segments |> :binary.bin_to_list() |> Enum.sum()
      body_start = 27 + count

      if body_start + body_size <= byte_size(input) do
        body = binary_part(input, body_start, body_size)

        byte_size(body) >= 19 and binary_part(body, 0, 8) == "OpusHead" and
          binary_part(body, 9, 1) in [<<1>>, <<2>>] and binary_part(body, 18, 1) == <<0>>
      else
        false
      end
    else
      false
    end
  end

  defp ogg_opus_signature?(_), do: false

  defp mp3_signature?(<<"ID3", rest::binary>>) do
    with true <- byte_size(rest) >= 7,
         <<version, _revision, flags, size_bytes::binary-size(4), _payload::binary>> <- rest,
         true <- version in [2, 3, 4],
         true <- Enum.all?(:binary.bin_to_list(size_bytes), &(&1 < 128)),
         tag_size <- synchsafe_size(size_bytes),
         footer <- if((flags &&& 0x10) != 0, do: 10, else: 0),
         start <- 10 + tag_size + footer,
         full <- <<"ID3", rest::binary>>,
         true <- start <= byte_size(full) do
      valid_mp3_frames?(binary_part(full, start, byte_size(full) - start))
    else
      _ -> false
    end
  end

  defp mp3_signature?(input) when is_binary(input), do: valid_mp3_frames?(input)
  defp mp3_signature?(_), do: false

  defp synchsafe_size(<<a, b, c, d>>), do: (a <<< 21) + (b <<< 14) + (c <<< 7) + d

  defp valid_mp3_frames?(input) do
    case find_mp3_frame(input, 0, min(byte_size(input), 4096)) do
      nil ->
        false

      {first_pos, header} ->
        first_size = mp3_frame_size(header)
        second_pos = first_pos + first_size

        second_pos + 4 <= byte_size(input) and
          consistent_mp3_header?(header, binary_part(input, second_pos, 4))
    end
  end

  defp find_mp3_frame(_input, offset, limit) when offset >= limit, do: nil

  defp find_mp3_frame(input, offset, limit) do
    if offset + 4 <= byte_size(input) do
      candidate = binary_part(input, offset, 4)

      case parse_mp3_header(candidate) do
        {:ok, header} -> {offset, header}
        :error -> find_mp3_frame(input, offset + 1, limit)
      end
    else
      nil
    end
  end

  defp parse_mp3_header(<<0xFF, second, third, fourth>>) do
    version = second >>> 3 &&& 0x03
    layer = second >>> 1 &&& 0x03
    bitrate_index = third >>> 4 &&& 0x0F
    sample_index = third >>> 2 &&& 0x03
    channel_mode = fourth >>> 6 &&& 0x03
    channels = if channel_mode == 3, do: 1, else: 2

    if (second &&& 0xE0) == 0xE0 and version != 1 and layer == 1 and
         bitrate_index not in [0, 15] and sample_index != 3 do
      base_rates = [44_100, 48_000, 32_000]
      rate = Enum.at(base_rates, sample_index)
      rate = if version == 3, do: rate, else: div(rate, 2)
      rate = if version == 0, do: div(rate, 2), else: rate

      table =
        if version == 3,
          do: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
          else: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]

      {:ok, {version, Enum.at(table, bitrate_index), rate, channels, fourth >>> 1 &&& 0x01}}
    else
      :error
    end
  end

  defp parse_mp3_header(_), do: :error

  defp consistent_mp3_header?({version, _bitrate, rate, channels, _extension}, bytes) do
    case parse_mp3_header(bytes) do
      {:ok, {^version, _other_bitrate, ^rate, ^channels, _other_extension}} -> true
      _ -> false
    end
  end

  defp mp3_frame_size({version, bitrate, rate, _channels, _extension}) do
    coefficient = if version == 3, do: 144, else: 72
    trunc(coefficient * bitrate * 1000 / rate) + 0
  end

  defp decode_source(:wav, input), do: RustyOpus.WAV.decode(input)
  defp decode_source(:mp3, input), do: RustyOpus.MP3.decode(input)
  defp decode_source(:ogg_opus, input), do: RustyOpus.OggOpus.decode(input)

  defp convert_pipeline(_source, pcm, :pcm, opts),
    do: RustyOpus.PCM.transform(pcm, Keyword.take(opts, [:sample_rate, :channels]))

  defp convert_pipeline(source, pcm, target, opts) when source == target do
    case target do
      :wav ->
        RustyOpus.WAV.encode(pcm, Keyword.take(opts, [:sample_format, :sample_rate, :channels]))

      :mp3 ->
        RustyOpus.MP3.encode(
          pcm,
          Keyword.take(opts, [:bitrate, :bitrate_mode, :sample_rate, :channels])
        )

      :ogg_opus ->
        RustyOpus.OggOpus.encode(pcm, Keyword.take(opts, [:bitrate, :bitrate_mode, :channels]))
    end
  end

  defp convert_pipeline(_source, pcm, target, opts) do
    with {:ok, pcm} <- RustyOpus.PCM.transform(pcm, Keyword.take(opts, [:sample_rate, :channels])),
         {:ok, output} <- encode_target(target, pcm, opts) do
      {:ok, output}
    end
  end

  defp encode_target(:wav, pcm, opts),
    do: RustyOpus.WAV.encode(pcm, Keyword.take(opts, [:sample_format]))

  defp encode_target(:mp3, pcm, opts),
    do: RustyOpus.MP3.encode(pcm, Keyword.take(opts, [:bitrate, :bitrate_mode]))

  defp encode_target(:ogg_opus, pcm, opts),
    do: RustyOpus.OggOpus.encode(pcm, Keyword.take(opts, [:bitrate, :bitrate_mode]))

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
    "allocation_bound" => :allocation_bound,
    "format_mismatch" => :format_mismatch,
    "unsupported_format" => :unsupported_format,
    "transform_failed" => :transform_failed,
    "contained_panic" => :contained_panic,
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

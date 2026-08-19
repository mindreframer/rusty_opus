defmodule RustyOpus.BulkTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Decoder, Encoder, Error}
  alias RustyOpus.TestHelpers.{LossyCompare, PCM}

  @rate 16_000
  @frame 320

  describe "Encoder.encode_many/2" do
    test "matches a per-frame encode loop on identical encoders" do
      pcm = PCM.sine(@rate, 1, 2.0)

      {:ok, loop_enc} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
      {:ok, bulk_enc} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)

      loop_packets =
        pcm
        |> frames(1)
        |> Enum.map(fn frame ->
          {:ok, p} = Encoder.encode(loop_enc, frame, @frame)
          p
        end)

      assert {:ok, bulk_packets} = Encoder.encode_many(bulk_enc, pcm, frame_size: @frame)
      assert bulk_packets == loop_packets
      assert length(bulk_packets) == 100
    end

    test "stereo bulk encode matches a per-frame loop" do
      pcm = stereo_sine(1.0)

      {:ok, loop_enc} = Encoder.new(@rate, 2, :audio, bitrate: 48_000)
      {:ok, bulk_enc} = Encoder.new(@rate, 2, :audio, bitrate: 48_000)

      loop_packets =
        pcm
        |> frames(2)
        |> Enum.map(fn frame ->
          {:ok, p} = Encoder.encode(loop_enc, frame, @frame)
          p
        end)

      assert {:ok, bulk_packets} = Encoder.encode_many(bulk_enc, pcm, frame_size: @frame)
      assert bulk_packets == loop_packets
    end

    test "pads a short last frame with silence instead of dropping it" do
      # 1.5 frames of mono PCM: one full frame + half a frame of remainder.
      full = PCM.sine(@rate, 1, 0.02)
      half = binary_part(full, 0, div(byte_size(full), 2))
      pcm = full <> half

      {:ok, trunc_enc} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
      {:ok, pad_enc} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)

      truncated =
        pcm
        |> frames(1)
        |> Enum.map(fn frame ->
          {:ok, p} = Encoder.encode(trunc_enc, frame, @frame)
          p
        end)

      assert length(truncated) == 1
      assert {:ok, padded_packets} = Encoder.encode_many(pad_enc, pcm, frame_size: @frame)
      assert length(padded_packets) == 2

      {:ok, decoder} = Decoder.new(@rate, 1)
      {:ok, decoded} = Decoder.decode_many(decoder, padded_packets, frame_size: @frame)
      # Padded frame yields a full second frame of samples (remainder kept, not dropped).
      assert PCM.sample_count(decoded) == @frame * 2

      samples = PCM.to_samples(decoded)
      remainder = Enum.drop(samples, @frame)
      first_half = Enum.take(remainder, div(@frame, 2))
      second_half = Enum.drop(remainder, div(@frame, 2))
      e1 = Enum.reduce(first_half, 0.0, fn s, acc -> acc + s * s end) / max(length(first_half), 1)

      e2 =
        Enum.reduce(second_half, 0.0, fn s, acc -> acc + s * s end) / max(length(second_half), 1)

      # Kept remainder carries the signal; padded zeros decode quieter (lossy).
      assert e1 > e2
    end

    test "empty PCM returns an empty packet list" do
      {:ok, encoder} = Encoder.new(@rate, 1)
      assert {:ok, []} = Encoder.encode_many(encoder, <<>>)
    end

    test "defaults frame_size to div(rate, 50)" do
      pcm = PCM.sine(@rate, 1, 0.04)
      {:ok, encoder} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
      assert {:ok, packets} = Encoder.encode_many(encoder, pcm)
      assert length(packets) == 2
    end

    test "rejects closed handles and zero frame_size" do
      {:ok, encoder} = Encoder.new(@rate, 1)
      :ok = Encoder.close(encoder)

      assert {:error, %Error{reason: :closed}} =
               Encoder.encode_many(encoder, PCM.sine(@rate, 1, 0.02))

      {:ok, open} = Encoder.new(@rate, 1)

      assert {:error, %Error{reason: :invalid_input}} =
               Encoder.encode_many(open, PCM.sine(@rate, 1, 0.02), frame_size: 0)
    end

    test "rejects non-binary PCM" do
      {:ok, encoder} = Encoder.new(@rate, 1)
      assert {:error, %Error{reason: :invalid_input}} = Encoder.encode_many(encoder, :nope)
    end
  end

  describe "Decoder.decode_many/2" do
    test "matches a per-frame decode loop on identical decoders" do
      pcm = PCM.sine(@rate, 1, 1.0)
      {:ok, encoder} = Encoder.new(@rate, 1, :audio, bitrate: 48_000)
      {:ok, packets} = Encoder.encode_many(encoder, pcm, frame_size: @frame)

      {:ok, loop_dec} = Decoder.new(@rate, 1)
      {:ok, bulk_dec} = Decoder.new(@rate, 1)

      loop_pcm =
        packets
        |> Enum.map(fn packet ->
          {:ok, frame} = Decoder.decode(loop_dec, packet, @frame)
          frame
        end)
        |> IO.iodata_to_binary()

      assert {:ok, bulk_pcm} = Decoder.decode_many(bulk_dec, packets, frame_size: @frame)
      assert bulk_pcm == loop_pcm
    end

    test "stereo bulk decode matches a per-frame loop" do
      pcm = stereo_sine(0.5)
      {:ok, encoder} = Encoder.new(@rate, 2, :audio, bitrate: 64_000)
      {:ok, packets} = Encoder.encode_many(encoder, pcm, frame_size: @frame)

      {:ok, loop_dec} = Decoder.new(@rate, 2)
      {:ok, bulk_dec} = Decoder.new(@rate, 2)

      loop_pcm =
        packets
        |> Enum.map(fn packet ->
          {:ok, frame} = Decoder.decode(loop_dec, packet, @frame)
          frame
        end)
        |> IO.iodata_to_binary()

      assert {:ok, bulk_pcm} = Decoder.decode_many(bulk_dec, packets, frame_size: @frame)
      assert bulk_pcm == loop_pcm
    end

    test "empty packet list returns empty PCM" do
      {:ok, decoder} = Decoder.new(@rate, 1)
      assert {:ok, <<>>} = Decoder.decode_many(decoder, [])
    end

    test "1-byte DTX packets still conceal inside the bulk path" do
      {:ok, decoder} = Decoder.new(@rate, 1)
      assert {:ok, pcm} = Decoder.decode_many(decoder, [<<0>>], frame_size: @frame)
      assert PCM.sample_count(pcm) > 0
      assert PCM.sample_count(pcm) <= @frame
    end

    test "rejects closed handles, zero frame_size, and non-list packets" do
      {:ok, encoder} = Encoder.new(@rate, 1)
      {:ok, [packet]} = Encoder.encode_many(encoder, PCM.sine(@rate, 1, 0.02))

      {:ok, closed} = Decoder.new(@rate, 1)
      :ok = Decoder.close(closed)
      assert {:error, %Error{reason: :closed}} = Decoder.decode_many(closed, [packet])

      {:ok, open} = Decoder.new(@rate, 1)

      assert {:error, %Error{reason: :invalid_input}} =
               Decoder.decode_many(open, [packet], frame_size: 0)

      assert {:error, %Error{reason: :invalid_input}} = Decoder.decode_many(open, :not_a_list)
      assert {:error, %Error{reason: :invalid_input}} = Decoder.decode_many(open, [packet, 123])
    end
  end

  describe "bulk lifecycle" do
    test "open/close around bulk calls returns counters near baseline" do
      baseline = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()
      pcm = PCM.sine(@rate, 1, 0.5)

      Enum.each(1..10, fn _ ->
        {:ok, e} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
        {:ok, packets} = Encoder.encode_many(e, pcm)
        :ok = Encoder.close(e)

        {:ok, d} = Decoder.new(@rate, 1)
        {:ok, decoded} = Decoder.decode_many(d, packets)
        :ok = Decoder.close(d)

        assert PCM.sample_count(decoded) == PCM.sample_count(pcm)
        assert LossyCompare.energy_close?(pcm, decoded, 0.6, 0.6)
      end)

      :erlang.garbage_collect()
      Process.sleep(50)

      assert RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= baseline + 2
    end
  end

  defp frames(pcm, channels) do
    frame_bytes = @frame * channels * 4
    max_offset = byte_size(pcm) - frame_bytes

    if max_offset < 0 do
      []
    else
      for offset <- 0..max_offset//frame_bytes, do: binary_part(pcm, offset, frame_bytes)
    end
  end

  defp stereo_sine(seconds) do
    left = PCM.sine(@rate, 1, seconds, 440.0)
    right = PCM.sine(@rate, 1, seconds, 220.0)
    {:ok, stereo} = RustyOpus.PCM.interleave(left, right)
    stereo
  end
end

defmodule RustyOpus.DecoderTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Decoder, Encoder, Error}
  alias RustyOpus.TestHelpers.{LossyCompare, PCM}

  @rate 16_000
  @frame 320

  describe "new/2" do
    test "creates a decoder at a supported rate/channel pair" do
      assert {:ok, %Decoder{rate: 16_000, channels: 1}} = Decoder.new(16_000, 1)
      assert {:ok, %Decoder{rate: 48_000, channels: 2}} = Decoder.new(48_000, 2)
    end

    test "rejects unsupported rates and channels" do
      assert {:error, %Error{reason: :invalid_rate}} = Decoder.new(11_025, 1)
      assert {:error, %Error{reason: :invalid_settings}} = Decoder.new(16_000, 3)
    end
  end

  describe "decode/3 round-trip" do
    test "decodes our own encoder's output within energy tolerance" do
      pcm = sine()
      {:ok, encoder} = Encoder.new(@rate, 1, :voip, bitrate: 64_000)
      {:ok, packet} = Encoder.encode(encoder, pcm, @frame)

      {:ok, decoder} = Decoder.new(@rate, 1)
      {:ok, decoded} = Decoder.decode(decoder, packet, @frame)

      assert PCM.sample_count(decoded) == @frame
      assert LossyCompare.energy_close?(pcm, decoded, 0.5, 0.5)
    end

    test "decodes stereo round-trip with a real signal" do
      {:ok, encoder} = Encoder.new(@rate, 2, :audio, bitrate: 64_000)
      {:ok, decoder} = Decoder.new(@rate, 2)

      # interleaved stereo sine (left high, right low frequency)
      samples =
        for i <- 0..(@frame - 1) do
          [PCM.sine_sample(@rate, i, 440.0), PCM.sine_sample(@rate, i, 220.0)]
        end
        |> List.flatten()

      pcm = PCM.from_samples(samples)
      {:ok, packet} = Encoder.encode(encoder, pcm, @frame)
      {:ok, decoded} = Decoder.decode(decoder, packet, @frame)

      assert PCM.sample_count(decoded) == @frame * 2
      assert decoded |> PCM.to_samples() |> Enum.max() > 0.5
    end

    test "rejects calls after close" do
      {:ok, encoder} = Encoder.new(@rate, 1, :voip)
      {:ok, packet} = Encoder.encode(encoder, sine(), @frame)

      {:ok, decoder} = Decoder.new(@rate, 1)
      :ok = Decoder.close(decoder)
      assert {:error, %Error{reason: :closed}} = Decoder.decode(decoder, packet, @frame)
    end
  end

  describe "packet-loss concealment" do
    test "a 1-byte ToC-only packet conceals rather than errors" do
      {:ok, decoder} = Decoder.new(@rate, 1)
      # 1-byte mono ToC-only packet -> lost/DTX frame -> PLC produces samples, not an error.
      assert {:ok, pcm} = Decoder.decode(decoder, <<0>>, @frame)
      assert PCM.sample_count(pcm) > 0
      assert PCM.sample_count(pcm) <= @frame
    end

    test "empty input is rejected" do
      {:ok, decoder} = Decoder.new(@rate, 1)
      assert {:error, %Error{reason: :decode_failed}} = Decoder.decode(decoder, <<>>, @frame)
    end

    test "channel mismatch is rejected cleanly" do
      {:ok, encoder} = Encoder.new(@rate, 1, :voip)
      {:ok, mono_packet} = Encoder.encode(encoder, sine(), @frame)

      {:ok, decoder} = Decoder.new(@rate, 2)

      assert {:error, %Error{reason: :decode_failed}} =
               Decoder.decode(decoder, mono_packet, @frame)
    end
  end

  defp sine(), do: PCM.sine(@rate, 1, 0.02)
end

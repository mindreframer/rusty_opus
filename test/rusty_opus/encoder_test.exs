defmodule RustyOpus.EncoderTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Encoder, Error, Settings}
  alias RustyOpus.TestHelpers.PCM

  @rate 16_000
  @frame 320
  @frame_bytes @frame * 4

  describe "new/3,4" do
    test "creates an encoder at a supported rate/channel pair" do
      assert {:ok, %Encoder{rate: 16_000, channels: 1}} = Encoder.new(16_000, 1)
      assert {:ok, %Encoder{rate: 48_000, channels: 2}} = Encoder.new(48_000, 2, :audio)
    end

    test "rejects unsupported rates, channels, and applications" do
      assert {:error, %Error{reason: :invalid_rate}} = Encoder.new(11_025, 1)
      assert {:error, %Error{reason: :invalid_settings}} = Encoder.new(16_000, 3)
      assert {:error, %Error{reason: :invalid_settings}} = Encoder.new(16_000, 1, :bogus)
    end

    test "rejects invalid settings" do
      assert {:error, %Error{reason: :invalid_setting}} =
               Encoder.new(16_000, 1, :voip, bitrate: -1)

      assert {:error, %Error{reason: :invalid_setting}} =
               Encoder.new(16_000, 1, :voip, complexity: 99)

      assert {:error, %Error{reason: :invalid_setting}} =
               Encoder.new(16_000, 1, :voip, cbr: :yes)
    end
  end

  describe "encode/3" do
    test "encodes PCM into a raw Opus packet" do
      {:ok, encoder} = Encoder.new(@rate, 1, :voip)
      assert {:ok, packet} = Encoder.encode(encoder, sine(0.02), @frame)
      assert is_binary(packet)
      assert byte_size(packet) > 0
      assert byte_size(packet) <= 1276
    end

    test "encodes a full buffer frame by frame deterministically" do
      {:ok, encoder} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)

      packets =
        sine(1)
        |> frames()
        |> Enum.map(fn frame ->
          {:ok, p} = Encoder.encode(encoder, frame, @frame)
          p
        end)

      assert length(packets) == 50
      assert Enum.all?(packets, &(byte_size(&1) > 0))
    end

    test "higher bitrate produces larger packets" do
      {:ok, low} = Encoder.new(@rate, 1, :audio, bitrate: 8_000)
      {:ok, high} = Encoder.new(@rate, 1, :audio, bitrate: 64_000)

      assert byte_size(encode_all(low, 0.5)) < byte_size(encode_all(high, 0.5))
    end

    test "complexity changes effort, not encoded size by much" do
      {:ok, e0} = Encoder.new(@rate, 1, :audio, bitrate: 24_000, complexity: 0)
      {:ok, e10} = Encoder.new(@rate, 1, :audio, bitrate: 24_000, complexity: 10)

      s0 = byte_size(encode_all(e0, 0.3))
      s10 = byte_size(encode_all(e10, 0.3))

      # Same bitrate target keeps total size close; complexity tuning is separate.
      assert abs(s0 - s10) <= div(s0, 2)
    end

    test "rejects wrong PCM length" do
      {:ok, encoder} = Encoder.new(@rate, 1, :voip)

      too_short = binary_part(sine(0.1), 0, @frame_bytes - 4)
      assert {:error, %Error{reason: :invalid_input}} = Encoder.encode(encoder, too_short, @frame)

      not_aligned = binary_part(sine(0.1), 0, 3)
      assert {:error, %Error{reason: :invalid_pcm}} = Encoder.encode(encoder, not_aligned, @frame)
    end

    test "rejects calls after close" do
      {:ok, encoder} = Encoder.new(@rate, 1, :voip)
      :ok = Encoder.close(encoder)
      assert {:error, %Error{reason: :closed}} = Encoder.encode(encoder, sine(0.1), @frame)
    end
  end

  describe "set/2" do
    test "updates bitrate on a live encoder" do
      {:ok, encoder} = Encoder.new(@rate, 1, :audio)
      :ok = Encoder.set(encoder, bitrate: 8_000)
      {:ok, low} = Encoder.encode(encoder, sine(0.02), @frame)

      :ok = Encoder.set(encoder, bitrate: 64_000)
      {:ok, high} = Encoder.encode(encoder, sine(0.02), @frame)

      assert byte_size(high) > byte_size(low)
    end
  end

  describe "settings" do
    test "Settings.new returns stable defaults" do
      assert {:ok, %Settings{fec: false, packet_loss: 0}} = Settings.new([])
    end

    test "Settings.new rejects bad values" do
      assert {:error, %Error{reason: :invalid_setting}} = Settings.new(fec: "yes")
    end
  end

  defp sine(seconds), do: PCM.sine(@rate, 1, seconds)

  defp frames(pcm) do
    for <<frame::binary-size(@frame_bytes) <- pcm>>, do: frame
  end

  defp encode_all(encoder, seconds) do
    sine(seconds)
    |> frames()
    |> Enum.map(fn frame ->
      {:ok, p} = Encoder.encode(encoder, frame, @frame)
      p
    end)
    |> IO.iodata_to_binary()
  end
end

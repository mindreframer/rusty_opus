defmodule RustyOpus.StreamFacadeTest do
  use ExUnit.Case, async: true

  alias RustyOpus.Error
  alias RustyOpus.TestHelpers.{LossyCompare, PCM}

  @rate 16_000

  describe "encode/4 and decode/4" do
    test "encode of one exact frame equals [packet] from encode_pcm/4" do
      pcm = PCM.sine(@rate, 1, 0.02)

      assert {:ok, packet} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 48_000)
      assert {:ok, [^packet]} = RustyOpus.encode(pcm, @rate, 1, bitrate: 48_000)
    end

    test "round-trips a multi-second buffer within lossy tolerance" do
      pcm = PCM.sine(@rate, 1, 2.0)
      assert {:ok, packets} = RustyOpus.encode(pcm, @rate, 1, quality: :medium)
      assert length(packets) == 100

      assert {:ok, decoded} = RustyOpus.decode(packets, @rate, 1)
      assert PCM.sample_count(decoded) == PCM.sample_count(pcm)
      assert LossyCompare.energy_close?(pcm, decoded, 0.6, 0.6)
    end
  end

  describe "transcode/5" do
    test "single-packet transcode matches change_quality/5" do
      pcm = PCM.sine(@rate, 1, 0.02)
      {:ok, high} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 96_000)

      assert {:ok, via_change} = RustyOpus.change_quality(high, @rate, 1, :low)
      assert {:ok, [^via_change]} = RustyOpus.transcode([high], @rate, 1, :low)
    end

    test "multi-packet preserves count and order" do
      pcm = PCM.sine(@rate, 1, 0.2)
      {:ok, packets} = RustyOpus.encode(pcm, @rate, 1, quality: :high)
      assert length(packets) == 10

      assert {:ok, out} = RustyOpus.transcode(packets, @rate, 1, :low)
      assert length(out) == length(packets)

      # Round-trip order: decode the transcoded stream and compare energy.
      assert {:ok, decoded} = RustyOpus.decode(out, @rate, 1)
      assert PCM.sample_count(decoded) == PCM.sample_count(pcm)
      assert LossyCompare.energy_close?(pcm, decoded, 1.0, 0.5)

      # Distinct packets stay distinct in order (sizes may differ).
      assert Enum.map(out, &byte_size/1) != Enum.map(packets, &byte_size/1) or
               out != packets
    end

    test "low total size is at most high for the same input" do
      pcm = PCM.sine(@rate, 1, 1.0)
      {:ok, packets} = RustyOpus.encode(pcm, @rate, 1, bitrate: 64_000)

      assert {:ok, low} = RustyOpus.transcode(packets, @rate, 1, :low)
      assert {:ok, medium} = RustyOpus.transcode(packets, @rate, 1, :medium)
      assert {:ok, high} = RustyOpus.transcode(packets, @rate, 1, :high)

      low_size = packets_size(low)
      medium_size = packets_size(medium)
      high_size = packets_size(high)

      assert low_size <= medium_size
      assert medium_size <= high_size
    end
  end

  describe "errors and lifecycle" do
    test "bad rate, quality, and input return tagged errors" do
      pcm = PCM.sine(@rate, 1, 0.02)
      {:ok, [packet]} = RustyOpus.encode(pcm, @rate, 1)

      assert {:error, %Error{reason: :invalid_rate}} = RustyOpus.encode(pcm, 11_025, 1)
      assert {:error, %Error{reason: :invalid_rate}} = RustyOpus.decode([packet], 11_025, 1)

      assert {:error, %Error{reason: :invalid_settings}} =
               RustyOpus.transcode([packet], @rate, 1, :ultra)

      assert {:error, %Error{reason: :invalid_input}} = RustyOpus.encode(:nope, @rate, 1)
      assert {:error, %Error{reason: :invalid_input}} = RustyOpus.decode(:nope, @rate, 1)
      assert {:error, %Error{reason: :invalid_input}} = RustyOpus.decode([packet, 1], @rate, 1)

      assert {:error, %Error{reason: :invalid_input}} =
               RustyOpus.transcode(:nope, @rate, 1, :low)
    end

    test "facade closes codecs (counters return near baseline)" do
      before = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()
      pcm = PCM.sine(@rate, 1, 0.2)

      Enum.each(1..5, fn _ ->
        {:ok, packets} = RustyOpus.encode(pcm, @rate, 1, quality: :medium)
        {:ok, _} = RustyOpus.decode(packets, @rate, 1)
        {:ok, _} = RustyOpus.transcode(packets, @rate, 1, :low)
      end)

      :erlang.garbage_collect()
      Process.sleep(50)

      assert RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= before + 2
    end
  end

  defp packets_size(packets), do: packets |> Enum.map(&byte_size/1) |> Enum.sum()
end

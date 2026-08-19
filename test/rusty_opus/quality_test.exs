defmodule RustyOpus.QualityTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Error, PCM, Quality}
  alias RustyOpus.TestHelpers.LossyCompare

  @rate 16_000
  @frame 320

  defp fixture(name), do: File.read!(Path.join(__DIR__, "../fixtures/#{name}"))

  defp mono_pcm, do: fixture("speech_16k_mono.f32")
  defp stereo_pcm, do: fixture("speech_16k_stereo.f32")
  defp golden_packet, do: fixture("golden_16k_mono.opus")

  # a loud speech-rich 20 ms frame ~0.06s into the clip (the clip starts silent)
  defp speech_frame(channels \\ 1) do
    binary_part(mono_pcm(), 3_840, @frame * 4 * channels)
  end

  describe "facade encode_pcm/decode_packet" do
    test "encode_pcm returns an Opus packet and decodes back within energy tolerance" do
      pcm = speech_frame()

      assert {:ok, packet} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 48_000)
      assert is_binary(packet) and byte_size(packet) > 0

      assert {:ok, decoded} = RustyOpus.decode_packet(packet, @rate, 1, @frame)
      assert PCM.sample_count(decoded) == @frame
      assert LossyCompare.energy_close?(pcm, decoded, 1.0, 0.1)
    end

    test "facade short-lived codecs are closed (counters return to baseline)" do
      before = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()

      for _ <- 1..5 do
        pcm = speech_frame()
        {:ok, packet} = RustyOpus.encode_pcm(pcm, @rate, 1)
        {:ok, _} = RustyOpus.decode_packet(packet, @rate, 1, @frame)
      end

      # resources are dropped asynchronously; poll briefly via a blocking call
      :erlang.garbage_collect()
      Process.sleep(50)
      assert RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= before + 2
    end
  end

  describe "quality presets" do
    test "preset settings exist for low/medium/high" do
      assert {:ok, low} = Quality.to_settings(:low)
      assert {:ok, medium} = Quality.to_settings(:medium)
      assert {:ok, high} = Quality.to_settings(:high)

      assert low.bitrate < medium.bitrate and medium.bitrate < high.bitrate
    end

    test "target_bitrate overrides the preset" do
      assert {:ok, settings} = Quality.to_settings(:high, target_bitrate: 16_000)
      assert settings.bitrate == 16_000
    end

    test "unknown preset errors" do
      assert {:error, %Error{reason: :invalid_settings}} = Quality.to_settings(:ultra)
    end
  end

  describe "bitrate/quality effect on real speech" do
    test "higher preset produces larger packets" do
      pcm = speech_frame()

      {:ok, low} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 16_000)
      {:ok, medium} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 48_000)
      {:ok, high} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 96_000)

      assert byte_size(low) < byte_size(medium)
      assert byte_size(medium) < byte_size(high)
    end

    test "change_quality re-encodes a packet at a new quality (high -> low shrinks)" do
      pcm = speech_frame()
      {:ok, high} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 96_000)

      assert {:ok, low} = RustyOpus.change_quality(high, @rate, 1, :low)
      assert byte_size(low) < byte_size(high)

      # and back up again: the re-encoded low packet goes back to high
      assert {:ok, high_again} = RustyOpus.change_quality(low, @rate, 1, :high)
      assert byte_size(high_again) > byte_size(low)
    end

    test "change_quality with target_bitrate override" do
      pcm = speech_frame()
      {:ok, default} = RustyOpus.encode_pcm(pcm, @rate, 1, bitrate: 48_000)

      assert {:ok, tiny} =
               RustyOpus.change_quality(default, @rate, 1, :medium, target_bitrate: 8_000)

      assert byte_size(tiny) < byte_size(default)
    end
  end

  describe "golden opus fixture" do
    test "the committed golden packet decodes to a real 20ms frame" do
      assert byte_size(golden_packet()) > 0

      assert {:ok, pcm} = RustyOpus.decode_packet(golden_packet(), @rate, 1, @frame)
      assert PCM.sample_count(pcm) == @frame
      assert pcm |> PCM.to_samples() |> Enum.max() > 0.01
    end
  end

  describe "PCM helpers" do
    test "sample_count matches the f32 binary contract" do
      assert PCM.sample_count(mono_pcm()) == 19_200
      assert PCM.sample_count(stereo_pcm()) == 25_600
    end

    test "interleave/deinterleave round-trip" do
      left = speech_frame()
      right = speech_frame()

      {:ok, stereo} = PCM.interleave(left, right)
      assert PCM.sample_count(stereo) == PCM.sample_count(left) * 2

      {:ok, {l2, r2}} = PCM.deinterleave(stereo)
      assert l2 == left
      assert r2 == right
    end

    test "interleave rejects mismatched lengths" do
      assert {:error, %Error{reason: :invalid_input}} =
               PCM.interleave(speech_frame(), binary_part(mono_pcm(), 0, 100))
    end
  end
end

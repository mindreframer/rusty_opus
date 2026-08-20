defmodule RustyOpus.Roadmap004FixtureTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Error, PCM}

  @fixtures Path.expand("../fixtures", __DIR__)

  test "independently encoded WAV fixtures expose expected metadata" do
    for {name, rate, channels, frames} <- [
          {"wav_s16_16k_mono.wav", 16_000, 1, 19_200},
          {"wav_s24_48k_stereo.wav", 48_000, 2, 38_400},
          {"wav_f32_44k_stereo.wav", 44_100, 2, 35_280}
        ] do
      assert {:ok, %PCM{} = pcm} = RustyOpus.WAV.decode(fixture(name))
      assert pcm.sample_rate == rate
      assert pcm.channels == channels
      assert PCM.frame_count(pcm) == frames
    end
  end

  test "independently encoded MPEG version, channel, mode, and ID3 fixtures decode" do
    for {name, rate, channels, source_duration} <- [
          {"mp3_mpeg1_44k_stereo_cbr64.mp3", 44_100, 2, 0.8},
          {"mp3_mpeg1_44k_stereo_vbr_id3.mp3", 44_100, 2, 0.8},
          {"mp3_mpeg2_22k_mono_cbr32.mp3", 22_050, 1, 1.2},
          {"mp3_mpeg25_11k_mono_cbr24.mp3", 11_025, 1, 1.2}
        ] do
      assert {:ok, %PCM{} = pcm} = RustyOpus.MP3.decode(fixture(name))
      assert pcm.sample_rate == rate
      assert pcm.channels == channels

      decoded_duration = PCM.frame_count(pcm) / rate
      assert decoded_duration >= source_duration
      assert decoded_duration - source_duration <= 0.16
    end
  end

  test "independent family-0 stereo Ogg Opus fixture decodes at the 48 kHz clock" do
    assert {:ok, %PCM{} = pcm} =
             RustyOpus.OggOpus.decode(fixture("ogg_opus_48k_stereo.ogg"))

    assert pcm.sample_rate == 48_000
    assert pcm.channels == 2
    assert_in_delta PCM.frame_count(pcm) / 48_000, 0.8, 0.02
  end

  test "targeted corrupt and unsupported fixtures return stable errors" do
    for {module, name} <- [
          {RustyOpus.MP3, "corrupt_mp3_truncated_id3.mp3"},
          {RustyOpus.MP3, "corrupt_mp3_bad_sync.mp3"},
          {RustyOpus.WAV, "corrupt_wav_oversized_chunk.wav"},
          {RustyOpus.WAV, "unsupported_wav_mulaw.wav"},
          {RustyOpus.OggOpus, "corrupt_ogg_bad_crc.ogg"}
        ] do
      assert {:error, %Error{reason: reason, message: message}} = module.decode(fixture(name))
      assert is_atom(reason)
      assert is_binary(message) and message != ""
    end
  end

  defp fixture(name), do: File.read!(Path.join(@fixtures, name))
end

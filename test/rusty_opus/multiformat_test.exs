defmodule RustyOpus.MultiformatTest do
  use ExUnit.Case, async: true

  alias RustyOpus.PCM

  defp pcm(rate \\ 44_100, channels \\ 1) do
    samples =
      for frame <- 0..2_203 do
        value = :math.sin(frame * 0.07) * 0.25
        if channels == 1, do: [value], else: [value, -value]
      end

    {:ok, descriptor} = PCM.new(PCM.from_samples(List.flatten(samples)), rate, channels)
    descriptor
  end

  test "PCM descriptor validates metadata and preserves legacy helpers" do
    value = pcm(44_100, 2)
    assert value.sample_rate == 44_100
    assert value.channels == 2
    assert PCM.frame_count(value) == 2_204
    assert {:ok, ^value} = PCM.transform(value, [])
    assert {:error, %RustyOpus.Error{reason: :invalid_pcm}} = PCM.new(<<0>>, 44_100, 1)

    assert {:error, %RustyOpus.Error{reason: :invalid_pcm}} =
             PCM.new(<<0::little-float-32>>, 44_100, 3)
  end

  test "WAV output formats are canonical and decode to metadata PCM" do
    source = pcm()

    for format <- [:s16, :s24, :s32, :f32] do
      assert {:ok, <<"RIFF", _::binary>> = blob} =
               RustyOpus.WAV.encode(source, sample_format: format)

      assert {:ok, decoded} = RustyOpus.WAV.decode(blob)
      assert decoded.sample_rate == source.sample_rate
      assert decoded.channels == source.channels
      assert PCM.frame_count(decoded) == PCM.frame_count(source)
    end
  end

  test "MP3 CBR and VBR round trip in memory" do
    source = pcm(44_100, 2)

    for mode <- [:cbr, :vbr] do
      assert {:ok, <<0xFF, _::binary>> = blob} =
               RustyOpus.MP3.encode(source, bitrate: 64_000, bitrate_mode: mode)

      assert {:ok, decoded} = RustyOpus.MP3.decode(blob)
      assert decoded.channels == 2
      assert decoded.sample_rate == 44_100
    end
  end

  test "independent fixture corpus decodes without external tools" do
    for path <- [
          "test/fixtures/wav_s16_16k_mono.wav",
          "test/fixtures/wav_s24_48k_stereo.wav",
          "test/fixtures/wav_f32_44k_stereo.wav",
          "test/fixtures/mp3_mpeg1_44k_stereo_cbr64.mp3",
          "test/fixtures/mp3_mpeg1_44k_stereo_vbr_id3.mp3",
          "test/fixtures/mp3_mpeg2_22k_mono_cbr32.mp3",
          "test/fixtures/mp3_mpeg25_11k_mono_cbr24.mp3",
          "test/fixtures/ogg_opus_48k_stereo.ogg"
        ] do
      assert {:ok, %PCM{}} = RustyOpus.convert(File.read!(path), to: :pcm)
    end

    for path <- [
          "test/fixtures/corrupt_mp3_bad_sync.mp3",
          "test/fixtures/corrupt_mp3_truncated_id3.mp3",
          "test/fixtures/corrupt_wav_oversized_chunk.wav",
          "test/fixtures/unsupported_wav_mulaw.wav",
          "test/fixtures/corrupt_ogg_bad_crc.ogg"
        ] do
      assert {:error, %RustyOpus.Error{}} = RustyOpus.convert(File.read!(path), to: :pcm)
    end
  end

  test "common facade detects content and validates target ownership" do
    source = pcm(16_000)
    assert {:ok, wav} = RustyOpus.convert(source, to: :wav, sample_format: :f32)
    assert {:ok, %PCM{sample_rate: 16_000}} = RustyOpus.convert(wav, to: :pcm)
    assert {:ok, mp3} = RustyOpus.convert(wav, to: :mp3, bitrate: 64_000, bitrate_mode: :cbr)
    assert {:ok, %PCM{sample_rate: 16_000}} = RustyOpus.convert(mp3, to: :pcm)

    assert {:error, %RustyOpus.Error{reason: :invalid_settings}} =
             RustyOpus.convert(wav, to: :wav)

    assert {:error, %RustyOpus.Error{reason: :unsupported_format}} =
             RustyOpus.convert(<<1, 2, 3>>, to: :pcm)

    assert {:error, %RustyOpus.Error{reason: :format_mismatch}} =
             RustyOpus.convert(wav, from: :mp3, to: :pcm)
  end

  test "channel transforms duplicate and average deterministically" do
    {:ok, mono} = PCM.new(PCM.from_samples([1.0, -1.0]), 8_000, 1)
    assert {:ok, stereo} = PCM.transform(mono, channels: 2)
    assert PCM.to_samples(stereo.data) == [1.0, 1.0, -1.0, -1.0]
    assert {:ok, ^mono} = PCM.transform(stereo, channels: 1)
  end
end

defmodule RustyOpus.PCMTransformTest do
  use ExUnit.Case, async: true

  alias RustyOpus.PCM

  test "validated descriptor carries metadata while bare helpers remain compatible" do
    data = PCM.from_samples([0.0, 0.25, -0.5, 1.0])

    assert {:ok, %PCM{data: ^data, sample_rate: 16_000, channels: 2} = pcm} =
             PCM.new(data, 16_000, 2)

    assert PCM.sample_count(data) == 4
    assert PCM.frame_count(pcm) == 2
    assert :ok = PCM.validate(pcm)
  end

  test "rejects malformed, non-finite, and oversized descriptors" do
    assert {:error, %RustyOpus.Error{reason: :invalid_pcm}} = PCM.new(<<1>>, 16_000, 1)
    assert {:error, %RustyOpus.Error{reason: :invalid_rate}} = PCM.new(<<>>, 0, 1)

    assert {:error, %RustyOpus.Error{reason: :invalid_pcm}} =
             PCM.new(<<0.0::little-float-32>>, 16_000, 3)

    assert {:error, %RustyOpus.Error{reason: :invalid_pcm}} =
             PCM.new(<<0x7F800000::little-unsigned-32>>, 16_000, 1)
  end

  test "duplicates mono and averages stereo deterministically" do
    {:ok, mono} = PCM.new(PCM.from_samples([1.0, -1.0]), 8_000, 1)
    assert {:ok, stereo} = PCM.transform(mono, channels: 2)
    assert PCM.to_samples(stereo.data) == [1.0, 1.0, -1.0, -1.0]
    assert {:ok, downmixed} = PCM.transform(stereo, channels: 1)
    assert PCM.to_samples(downmixed.data) == [1.0, -1.0]
  end

  test "resampling preserves metadata and bounded frame accounting" do
    samples = for index <- 0..440, do: :math.sin(index / 10)
    {:ok, source} = PCM.new(PCM.from_samples(samples), 44_100, 1)
    assert {:ok, output} = PCM.transform(source, sample_rate: 48_000)
    assert output.sample_rate == 48_000
    assert output.channels == 1
    assert_in_delta PCM.frame_count(output), 441 * 48_000 / 44_100, 1
    assert {:ok, ^output} = PCM.transform(output, [])
  end
end

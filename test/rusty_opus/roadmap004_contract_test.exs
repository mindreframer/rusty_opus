defmodule RustyOpus.Roadmap004ContractTest do
  use ExUnit.Case, async: true

  alias RustyOpus.{Error, PCM}

  test "the additive surface does not replace the raw Opus API" do
    for {module, functions} <- [
          {RustyOpus,
           [
             encode: 4,
             decode: 4,
             transcode: 5,
             reencode: 1,
             reencode: 2,
             convert: 2
           ]},
          {RustyOpus.OggOpus, [decode: 1, encode: 2, reencode: 2]},
          {RustyOpus.MP3, [decode: 1, encode: 2, reencode: 2]},
          {RustyOpus.WAV, [decode: 1, encode: 2, reencode: 2]}
        ] do
      assert Code.ensure_loaded?(module)

      for {name, arity} <- functions do
        assert function_exported?(module, name, arity),
               "expected #{inspect(module)}.#{name}/#{arity} to be public"
      end
    end
  end

  test "PCM descriptor retains the one f32le representation" do
    assert {:ok, %PCM{} = pcm} = PCM.new(<<0.25::little-float-32>>, 16_000, 1)
    assert pcm.data == <<0.25::little-float-32>>
    assert pcm.sample_rate == 16_000
    assert pcm.channels == 1
    assert PCM.to_samples(pcm.data) == [0.25]
  end

  test "common target ownership fails before decoding" do
    assert_error(:invalid_settings, RustyOpus.convert(<<>>, to: :mp3))

    assert_error(
      :invalid_settings,
      RustyOpus.convert(<<>>, to: :wav, sample_format: :f32, bitrate: 64_000)
    )

    assert_error(
      :invalid_settings,
      RustyOpus.convert(<<>>, to: :pcm, application: :audio)
    )

    assert_error(
      :invalid_settings,
      RustyOpus.convert(<<>>, to: :pcm, to: :wav)
    )
  end

  test "PCM input rejects from and malformed option lists return tagged errors" do
    pcm = %PCM{data: <<0.0::little-float-32>>, sample_rate: 16_000, channels: 1}

    assert_error(
      :invalid_settings,
      RustyOpus.convert(pcm, to: :pcm, from: :wav)
    )

    assert_error(:invalid_settings, RustyOpus.convert(<<>>, [:not_a_keyword]))
    assert_error(:invalid_settings, RustyOpus.OggOpus.encode(pcm, [:not_a_keyword]))
  end

  test "dedicated modules reject options owned by another format" do
    pcm = %PCM{data: <<0.0::little-float-32>>, sample_rate: 16_000, channels: 1}

    assert_error(
      :invalid_settings,
      RustyOpus.MP3.encode(pcm, bitrate: 64_000, sample_format: :s16)
    )

    assert_error(
      :invalid_settings,
      RustyOpus.WAV.encode(pcm, sample_format: :f32, bitrate: 64_000)
    )

    assert_error(
      :invalid_settings,
      RustyOpus.OggOpus.encode(pcm, bitrate: 24_000, bitrate_mode: :vbr, cbr: false)
    )
  end

  defp assert_error(reason, result) do
    assert {:error, %Error{reason: ^reason, message: message}} = result
    assert is_binary(message) and message != ""
  end
end

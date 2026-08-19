defmodule RustyOpus.ReencodeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias RustyOpus.Error

  # Committed Ogg Opus speech fixture (~7s).
  @fixture Path.expand("../fixtures/speech_ogg_1.ogg", __DIR__)

  # Hard cap after ADR003 (opus-rs + NEON): ~7s speech stays well under 1s on CI.
  @max_reencode_ms 1_000

  test "reencode shrinks a real DB Ogg blob and stays valid" do
    source = File.read!(@fixture)
    assert String.starts_with?(source, "OggS")

    {us, result} = :timer.tc(fn -> RustyOpus.reencode(source, bitrate: 20_000) end)
    assert {:ok, smaller} = result
    assert String.starts_with?(smaller, "OggS")
    assert byte_size(smaller) < byte_size(source)
    assert div(us, 1000) < @max_reencode_ms
  end

  test "voip and audio applications produce different bitstreams" do
    source = File.read!(@fixture)

    assert {:ok, voip} = RustyOpus.reencode(source, bitrate: 20_000, application: :voip)

    assert {:ok, audio} =
             RustyOpus.reencode(source, bitrate: 20_000, application: :audio, complexity: 10)

    assert byte_size(voip) > 0
    assert voip != audio
  end

  test "reencode rejects unsupported frame durations and bad options" do
    source = File.read!(@fixture)
    assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, [])
    assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, bitrate: 0)

    assert {:error, %Error{reason: :invalid_settings}} =
             RustyOpus.reencode(source, bitrate: 20_000, frame_duration_ms: 60)

    assert {:error, %Error{reason: :invalid_settings}} =
             RustyOpus.reencode(source, bitrate: 20_000, complexity: 99)

    assert {:error, %Error{reason: :invalid_settings}} =
             RustyOpus.reencode(source, bitrate: 20_000, application: :music)

    assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(<<>>, bitrate: 20_000)

    assert {:error, %Error{reason: :decode_failed}} =
             RustyOpus.reencode(<<"nope">>, bitrate: 20_000)

    assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(:nope, bitrate: 20_000)
  end
end

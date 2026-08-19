defmodule RustyOpus.ReencodeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias RustyOpus.Error

  # Real MemoMoo audio_versions Ogg Opus speech (committed fixture).
  @fixture Path.expand("../fixtures/moo_audio_versions_1.ogg", __DIR__)

  # Hard cap: ~7s of speech must reencode well under this (release NIF).
  @max_reencode_ms 1_500

  test "reencode shrinks a real DB Ogg blob and stays valid" do
    source = File.read!(@fixture)
    assert String.starts_with?(source, "OggS")

    {us, result} = :timer.tc(fn -> RustyOpus.reencode(source, bitrate: 20_000) end)
    assert {:ok, smaller} = result
    assert String.starts_with?(smaller, "OggS")
    assert byte_size(smaller) < byte_size(source)
    assert div(us, 1000) < @max_reencode_ms
  end

  test "reencode errors" do
    source = File.read!(@fixture)
    assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, [])
    assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, bitrate: 0)
    assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(<<>>, bitrate: 20_000)
    assert {:error, %Error{reason: :decode_failed}} = RustyOpus.reencode(<<"nope">>, bitrate: 20_000)
    assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(:nope, bitrate: 20_000)
  end
end

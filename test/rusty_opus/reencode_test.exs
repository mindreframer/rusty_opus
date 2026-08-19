defmodule RustyOpus.ReencodeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias RustyOpus.Error

  @fixture_dir Path.expand("../fixtures", __DIR__)
  @moo_1 Path.join(@fixture_dir, "moo_audio_versions_1.ogg")
  @moo_2 Path.join(@fixture_dir, "moo_audio_versions_2.ogg")
  @moo_3 Path.join(@fixture_dir, "moo_audio_versions_3.ogg")

  # MemoMoo audio_versions ladder (bits/s)
  @ladder [8_000, 12_000, 16_000, 20_000, 24_000, 32_000]

  describe "reencode/2 with MemoMoo audio_versions Ogg fixtures" do
    test "hard requirement: real DB blobs shrink and stay valid Ogg Opus" do
      for path <- [@moo_1, @moo_2, @moo_3] do
        source = File.read!(path)
        assert String.starts_with?(source, "OggS")
        source_size = byte_size(source)

        assert {:ok, smaller} = RustyOpus.reencode(source, bitrate: 20_000)
        assert String.starts_with?(smaller, "OggS")
        assert byte_size(smaller) < source_size

        # Still a working Ogg Opus file: reencode again must succeed.
        assert {:ok, again} = RustyOpus.reencode(smaller, bitrate: 20_000)
        assert String.starts_with?(again, "OggS")
        assert byte_size(again) > 0
      end
    end

    test "lower bitrate produces smaller or equal files on real speech" do
      source = File.read!(@moo_1)

      sizes =
        Enum.map(@ladder, fn bitrate ->
          assert {:ok, out} = RustyOpus.reencode(source, bitrate: bitrate)
          assert String.starts_with?(out, "OggS")
          {bitrate, byte_size(out)}
        end)

      # Monotonic non-decreasing size as bitrate rises (allow equals).
      sizes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [{_b1, s1}, {_b2, s2}] ->
        assert s1 <= s2
      end)

      {_low_br, low_size} = hd(sizes)
      {_high_br, high_size} = List.last(sizes)
      assert low_size < high_size
      assert low_size < byte_size(source)
    end

    test "simplest API: only bitrate is required" do
      source = File.read!(@moo_2)
      assert {:ok, out} = RustyOpus.reencode(source, bitrate: 16_000)
      assert byte_size(out) < byte_size(source)
    end
  end

  describe "reencode/2 errors" do
    test "missing or invalid bitrate" do
      source = File.read!(@moo_1)
      assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, [])
      assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, bitrate: 0)
      assert {:error, %Error{reason: :invalid_settings}} = RustyOpus.reencode(source, bitrate: -1)

      assert {:error, %Error{reason: :invalid_settings}} =
               RustyOpus.reencode(source, bitrate: 1.5)
    end

    test "non-Ogg / empty / non-binary input" do
      assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(<<>>, bitrate: 20_000)

      assert {:error, %Error{reason: :decode_failed}} =
               RustyOpus.reencode(<<"not an ogg file">>, bitrate: 20_000)

      assert {:error, %Error{reason: :invalid_input}} = RustyOpus.reencode(:nope, bitrate: 20_000)
    end
  end
end

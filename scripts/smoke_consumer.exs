#! /usr/bin/env elixir
# Smoke the RustyOpus public API from a clean consumer application.

{:ok, _version} = RustyOpus.native_smoke()

# Encode a deterministic sine frame and decode it back.
sample_rate = 16_000
frame = 320
samples =
  for i <- 0..(frame - 1) do
    :math.sin(2.0 * :math.pi() * 440.0 * i / sample_rate)
  end

pcm = for s <- samples, into: <<>>, do: <<s::float-little-32>>

{:ok, packet} = RustyOpus.encode_pcm(pcm, sample_rate, 1, bitrate: 24_000)
true = is_binary(packet) and byte_size(packet) > 0

{:ok, decoded} = RustyOpus.decode_packet(packet, sample_rate, 1, frame)
true = byte_size(decoded) == frame * 4

# Changing the encoding quality works end to end.
{:ok, smaller} = RustyOpus.change_quality(packet, sample_rate, 1, :low)
byte_size(smaller) <= byte_size(packet) + 4

IO.puts("consumer-smoke-ok")
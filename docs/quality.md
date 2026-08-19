# Changing the encoding quality

The motivating feature of RustyOpus: decode audio and re-encode it at a different
quality, e.g. to shrink a file for storage or speech pipelines.

## Presets

`RustyOpus.Quality` provides three presets that tune bitrate, complexity, and VBR/CBR
together:

| Preset | Bitrate | Complexity |
| --- | --- | --- |
| `:low` | 24 kb/s | 4 |
| `:medium` | 48 kb/s | 8 |
| `:high` | 96 kb/s | 10 |

Higher presets produce larger Opus packets with better fidelity. You can override the
bitrate with `:target_bitrate` and any individual setting per call.

## Single-packet quality change

`RustyOpus.change_quality/5` decodes one packet to PCM and re-encodes it at a new
quality:

```elixir
{:ok, smaller} = RustyOpus.change_quality(packet, 16_000, 1, :low)
{:ok, larger} = RustyOpus.change_quality(packet, 16_000, 1, :high)

# Explicit bitrate target:
{:ok, tuned} = RustyOpus.change_quality(packet, 16_000, 1, :medium, target_bitrate: 12_000)
```

The default decoded frame size is `div(rate, 50)` (20 ms); pass `:frame_size` to change
it for non-20 ms packets.

## Whole-stream re-encoding

For a stream of frames, decode each packet, then re-encode the PCM frames with the
desired settings:

```elixir
reencoded =
  Enum.map(packets, fn packet ->
    {:ok, pcm} = RustyOpus.decode_packet(packet, 16_000, 1, 320)
    {:ok, out} = RustyOpus.encode_pcm(pcm, 16_000, 1, quality_settings)
    out
  end)
```

## Notes on quality

- Opus is lossy; changing quality always loses some fidelity on re-encode.
- For a given content, higher bitrate ⇒ larger packets, monotonically in practice for
  real speech; silence frames encode tiny at every bitrate.
- `:target_bitrate` below the codec minimum (roughly 6 kb/s at 16 kHz) is clamped by the
  codec.

# Codec API and data contract

RustyOpus wraps the pure-Rust `opus-rs` codec (RFC 6716) through Rustler. It operates on
**raw Opus packets** and **raw PCM**; it does not parse Ogg/WebM containers.

## Data contract

- **PCM** is a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved for
  stereo. Sample count is `byte_size(pcm) / 4`.
- **Opus packets** are raw binaries, passed verbatim.

This binary contract avoids compressed Erlang-term marshalling for bulk audio data and is
the same everywhere in the library.

## Supported configuration

| Parameter | Values |
| --- | --- |
| Sampling rate | 8000, 12000, 16000, 24000, 48000 Hz |
| Channels | 1 (mono) or 2 (stereo) |
| Application | `:voip`, `:audio`, `:restricted_low_delay` |

Frame sizes (samples per channel) are the standard Opus frame durations (e.g. 320 samples
at 16 kHz is a 20 ms frame). The PCM buffer passed to `encode/3` must contain exactly
`frame_size * channels` samples.

## Encoder

```elixir
{:ok, encoder} =
  RustyOpus.Encoder.new(
    48_000,
    2,
    :audio,
    bitrate: 128_000,
    complexity: 9,
    cbr: false,
    fec: false,
    packet_loss: 0
  )

{:ok, packet} = RustyOpus.Encoder.encode(encoder, pcm, 960)
:ok = RustyOpus.Encoder.close(encoder)
```

`RustyOpus.Encoder.set/2` updates settings on a live encoder. Closing is idempotent;
calls after close return `{:error, %RustyOpus.Error{reason: :closed}}`.

## Decoder

```elixir
{:ok, decoder} = RustyOpus.Decoder.new(16_000, 1)
{:ok, pcm} = RustyOpus.Decoder.decode(decoder, packet, 320)
```

A 1-byte (ToC-only) packet is treated as a lost/DTX frame and concealed with packet-loss
concealment instead of erroring. Packets declaring a channel count different from the
decoder are rejected with a stable tagged error.

## Errors

Every failure is a `%RustyOpus.Error{}` with a stable `:reason` and a `:message`.
Panics inside the codec are contained at the NIF boundary and poison the affected
resource; they never crash the caller process.

## Facade

For one-shot use, `RustyOpus.encode_pcm/4` and `RustyOpus.decode_packet/4` create,
use, and close a short-lived codec:

```elixir
{:ok, packet} = RustyOpus.encode_pcm(pcm, 16_000, 1, bitrate: 32_000)
{:ok, pcm} = RustyOpus.decode_packet(packet, 16_000, 1, 320)
```

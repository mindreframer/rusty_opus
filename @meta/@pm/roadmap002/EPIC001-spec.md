# EPIC001 Spec: Bulk Encode and Decode

## Purpose

Move stream-level PCM chunking and the encode/decode loop into Rust so a whole
buffer or packet list crosses the NIF boundary once, instead of once per 20 ms frame.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP002.md`
- Existing per-frame NIFs: `encoder_encode/3`, `decoder_decode/3` (DirtyCpu)
- Existing Elixir: `RustyOpus.Encoder.encode/3`, `RustyOpus.Decoder.decode/3`
- PCM contract: little-endian `f32` binary, interleaved for stereo
- Default frame size: `div(rate, 50)` (20 ms)

## Scope

In scope:

- `encoder_encode_many(resource, pcm, frame_size)` — chunk PCM into
  `frame_size * channels` frames, pad a short last frame with zeros, encode each,
  return the list of packets. Dirty CPU scheduler. Same error mapping as `encoder_encode`.
- `decoder_decode_many(resource, packets, frame_size)` — decode each packet with
  shared decoder state, concatenate PCM, return one binary. Dirty CPU scheduler.
  1-byte DTX packets still conceal.
- `RustyOpus.Encoder.encode_many/2` and `RustyOpus.Decoder.decode_many/2` with
  optional `:frame_size` (default `div(encoder.rate, 50)` / `div(decoder.rate, 50)`).
- Equivalence, padding, empty-input, closed-handle, and lifecycle tests.

Out of scope:

- `RustyOpus.encode/4`, `decode/4`, `transcode/5` (Epic 2)
- Version bump (Epic 3)
- Changing `encode/3` or `decode/3` signatures or behavior
- Ogg/containers, file I/O, new settings keys

## Contract

- Bulk encode of exact-frame PCM produces the same packets as looping `encode/3` on
  the same handle with the same `frame_size`.
- A trailing incomplete frame is padded with zero samples, never truncated and never
  rejected. Padding adds silence; existing samples are kept.
- Bulk decode of a packet list produces the same concatenated PCM as looping
  `decode/3` on the same handle with the same `frame_size`.
- Empty packet list → empty PCM binary. Empty PCM → empty packet list.
- Closed handles return `{:error, %Error{reason: :closed}}`, same as per-frame calls.
- Existing 0.1.0 functions are untouched.

## Acceptance Criteria

- A multi-second PCM buffer encodes in one NIF call; a packet list decodes in one NIF call.
- Bulk output is byte-equivalent to a per-frame loop on the same handle (exact frames).
- Remainder samples are padded, not dropped.
- Stereo works. 1-byte DTX packets still conceal.
- Closed-handle and lifecycle counters match the per-frame resources.
- No existing public function changes signature or behavior.

## Test Strategy

- Equivalence: same handle, same `frame_size`, compare bulk vs per-frame loop (mono and stereo).
- Padding: PCM with a remainder produces one extra packet vs truncating; decoded extra
  samples are silence within lossy tolerance.
- Errors: closed handle; invalid `frame_size` (zero); non-binary PCM / non-list packets.
- Empty inputs return empty results.
- Repeated open/close around bulk calls returns encoder/decoder counters to baseline.

## Quality Bar

- Bulk NIFs run on dirty CPU schedulers; panics stay contained.
- Tagged errors use the existing taxonomy (`:closed`, `:invalid_pcm`, `:invalid_input`,
  `:encode_failed`, `:decode_failed`, `:codec_panicked`).
- `bin/qa_check.sh` is green before the epic commit.

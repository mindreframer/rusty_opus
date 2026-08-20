# EPIC005 Spec: Dedicated Ogg Opus Module and Backward Compatibility

## Purpose

Give file-like Ogg Opus family-0 audio the same decode/encode/re-encode module shape as
MP3 and WAV, while retaining the existing thin Ogg/`opus-rs` implementation and proving
that every previously shipped raw packet and top-level re-encode call remains compatible.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epics 1–2: frozen API, `%RustyOpus.PCM{}`, transforms, fixtures, and boundary audits
- Existing `RustyOpus.reencode/2`, `ogg_reencode` NIF, thin Ogg glue, and `opus-rs`
- Existing `RustyOpus.encode/4`, `decode/4`, `transcode/5`, `Encoder`, and `Decoder`
- RFC 7845 Ogg Opus family-0 header, pre-skip, granule, end trimming, and channel rules

## Scope

In scope:

- new `RustyOpus.OggOpus` module with `decode/1`, `encode/2`, and `reencode/2`
- family-0 mono/stereo input only, one selected logical Opus stream, with deterministic
  rejection of chained/multiplexed/unsupported-family inputs outside the frozen contract
- decode to 48 kHz `%RustyOpus.PCM{}` with correct pre-skip and final granule trimming
- encode validated PCM, resampling to 48 kHz when required, into valid OpusHead/OpusTags,
  Ogg pages, lacing, sequence numbers, CRCs, granule positions, and EOS
- required numeric bits/s `:bitrate`, preferred `:bitrate_mode`, and existing Opus-specific
  `:application`, `:complexity`, `:frame_duration_ms`, and compatibility `:cbr`
- explicit conflict rule: `:bitrate_mode` and `:cbr` may not both be supplied
- `RustyOpus.reencode/2` delegating to `RustyOpus.OggOpus.reencode/2` with unchanged
  current defaults, accepted options, result shape, and stable error meanings
- no behavior change to raw Opus packet/PCM facade or resource modules
- unit, integration, lifecycle/counter, scheduler, corrupt-page, RFC/conformance, and
  complete backward-compatibility tests

Out of scope:

- mapping families other than 0, more than two channels, chained logical streams,
  multiplexed non-Opus streams, WebM, RTP, or raw packet format changes
- preservation/editing of vendor strings, comments, pictures, or other metadata; output
  contains only minimal deterministic tags required by the encoder policy
- replacing the existing Opus codec or introducing a second Opus implementation
- file paths, streaming public APIs, temporary files, or process-based tools

## Public Contract

```elixir
@spec decode(binary()) ::
        {:ok, RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}

@spec encode(RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}

@spec reencode(binary(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}
```

- `encode/2` and `reencode/2` require a positive integer `:bitrate` in bits/s.
- `:bitrate_mode` accepts `:vbr | :cbr`; `:cbr` remains accepted for compatibility on
  dedicated/top-level re-encode, but supplying both is invalid.
- `:application`, `:complexity`, and `:frame_duration_ms` retain their existing meanings
  and validated ranges.
- `:channels` may request `1` or `2`; `:sample_rate` on Ogg output is not a second coded
  clock and must follow the documented 48 kHz behavior rather than misrepresenting output.
- `decode/1` returns `sample_rate: 48_000` and the family-0 channel count.

## Container and Compatibility Contract

- `OpusHead` version/family/channel/pre-skip/input-rate fields are valid and internally
  consistent for family 0.
- Packet lacing, continuation, page sequence, serial ownership, CRC, BOS/EOS, and final
  granule calculations are validated with checked arithmetic.
- Decode removes pre-skip and trims the final packet from the ending granule without
  dropping real tail audio or exposing encoder padding.
- Re-encode preserves channel count unless explicitly changed and preserves duration
  within the frozen Opus delay/frame tolerance.
- Old `RustyOpus.reencode(blob, bitrate: n, ...)` results remain compatible; error reason
  atoms and validation order do not change unintentionally.
- Raw packet APIs never call Ogg parsing/muxing and keep all existing resource semantics.

## Acceptance Criteria

- Dedicated decode, encode, and re-encode work for committed mono/stereo family-0 fixtures.
- Output is accepted by independent Ogg/Opus validation and passes header/page/granule/CRC checks.
- Pre-skip/end-trim and transform cases satisfy frame-count/duration/signal tolerances.
- Numeric bitrate/CBR/VBR/Opus-specific settings behave as documented and size ordering passes.
- Top-level `reencode/2` and every existing raw Opus public call remain compatible.
- Unsupported family/chaining/multiplexing/corruption returns stable errors without panic,
  excessive allocation, scheduler blockage, or counter growth.

## Test Strategy

- Unit tests cover header/tags/page/lacing/granule/CRC arithmetic, settings conflict and
  compatibility mapping, checked bounds, and error taxonomy.
- Integration tests decode independent family-0 fixtures and encode/re-read mono/stereo output.
- Delay-aware signal tests validate pre-skip/end trim and short/non-frame-aligned tails.
- Re-encode tests exercise bitrate ladder, CBR/VBR, application/complexity/frame duration,
  channel conversion, corruption, and minimal metadata output.
- A dedicated backward-compatibility suite freezes current top-level and raw packet/resource behavior.
- Lifecycle/counter and scheduler tests use captured baselines and barriers/heartbeats.

## Extra Quality Gate

Phase 6 records independent RFC/container validation of head/tags/family/channel, stream
serial/page sequence/lacing/CRC/BOS/EOS, packet/granule/pre-skip/end-trim math, duration and
signal thresholds, bitrate/size ordering, corrupt-page outcomes, scheduler heartbeat,
repeated-call counters, and the full previously shipped API compatibility matrix.

## Quality Bar

- File-like Ogg and raw Opus packet meanings remain visibly separate.
- Existing thin glue and `opus-rs` are reused rather than replaced by a general container stack.
- Backward compatibility is tested as an artifact, not assumed from delegation.
- No metadata, mapping-family, container, or streaming scope creep enters the module.
- `bin/qa_check.sh` passes before the epic commit.

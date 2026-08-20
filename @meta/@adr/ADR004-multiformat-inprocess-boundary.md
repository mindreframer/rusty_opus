# ADR004: Narrow In-Process Multi-Format Audio Boundary

- **Status:** Accepted for ROADMAP004
- **Date:** 2026-08-20
- **Related:** ADR001, ADR002, ADR003

## Context

ROADMAP004 adds whole-blob WAV, MP3, and dedicated Ogg Opus operations while retaining
RustyOpus's original raw Opus packet contract. File operations must remain embeddable and
must not introduce a general media framework or deployment dependency on system codecs.

## Decision

- WAV parsing/writing is thin in-crate RIFF/WAVE glue over in-memory byte slices.
- MP3 uses the exactly pinned pure-Rust `rusty_mp3 0.7.0` crate with default features
  disabled. No C, FFI, LAME, system codec, Port, executable, or process is permitted.
- Ogg Opus continues to use the existing thin family-0 glue and pinned `opus-rs` codec.
- All file decoders normalize to `%RustyOpus.PCM{}` carrying validated interleaved f32le,
  sample rate, and mono/stereo channel metadata.
- Whole-blob NIFs run on dirty schedulers, check size arithmetic before allocation, and
  contain panics at the callable boundary. Inputs and outputs remain BEAM-owned binaries.
- `RustyOpus.convert/2` is the only cross-format composer. Dedicated modules do not call
  one another; raw packet APIs do not parse containers.

## Consequences

The runtime remains pure Rust and in-process, with a small auditable dependency surface.
Metadata is not copied, file paths and streaming are not supported, and unsupported
containers/codecs fail with stable tagged errors. `rusty_mp3` is Apache-2.0 and is listed
in `NOTICE`, provenance, and the locked dependency graph.

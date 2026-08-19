# ADR001: PCM and Opus Data Contract Across the Elixir/Rust Boundary

- **Status:** Accepted
- **Date:** ROADMAP001 Epic 1

## Context

The codec boundary must move PCM and Opus packets between Elixir and Rust efficiently
and predictably, with a single stable contract that every later epic reuses.

## Decision

- **PCM** is a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved for
  stereo. Sample count = `byte_size / 4`, channels are decoded from the layout.
- **Opus packets** are raw binaries passed verbatim between the codec and the caller.

The `opus-rs` API operates on `&[f32]`/`&mut [f32]`; the little-endian `f32` binary maps
directly onto that with a single reinterpret/parse step and avoids compressed Erlang term
marshalling for bulk sample data.

## Consequences

- Stable binary contract for every codec and facade module.
- Efficient: samples are packed 4 bytes each and copied only where required.
- Callers own the semantics of sample rate/channels; RustyOpus validates them.

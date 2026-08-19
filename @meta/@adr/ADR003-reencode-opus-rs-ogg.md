# ADR003: Ogg Reencode via `opus-rs` + Thin Container Glue

- **Status:** Accepted
- **Date:** 2026-08-19
- **Supersedes (in part):** ADR002’s “no container parsing” rule, for `RustyOpus.reencode/2` only
- **Related:** ROADMAP003 (`reencode/2`); ARM performance of `ruopus`

## Context

`RustyOpus.reencode/2` demuxes an Ogg Opus blob, re-encodes PCM at a numeric bitrate,
and remuxes Ogg Opus. ROADMAP003 wired that path through pure-Rust `ruopus`
(`decode_ogg_opus` / `encode_ogg_opus`) because it already had RFC 7845 helpers.

Benchmarks on Apple Silicon (M3 Ultra) showed ~7.5× realtime (~1 s for ~7.4 s of
speech). Splitting the work revealed ~390 ms decode + ~575 ms encode inside
`ruopus`. The same PCM through the already-pinned `opus-rs` codec finished encode
in ~12 ms and packet decode in ~5 ms (~590× / ~1500× realtime).

Root cause: `ruopus` SIMD kernels are **x86_64-only** (AVX2/SSE2); on `aarch64` the
hot loops fall back to scalar. `opus-rs` ships **NEON** on aarch64. Published
`ruopus` “hundreds of × realtime” numbers assume SIMD-capable x86 and do not
describe this machine.

Constraints that still hold:

- No C `libopus`, no ffmpeg, no Port/process on the library path.
- Numeric bitrates only (no quality atoms) on `reencode/2`.
- Packet/PCM APIs remain raw Opus (`opus-rs` resources); no Ogg there.
- One stable binary contract at the NIF boundary.

## Decision

1. **Codec for `reencode/2`:** decode and encode with the pinned **`opus-rs`**
   encoder/decoder (same crate as packet APIs), at 48 kHz, family-0 mono/stereo.
2. **Container:** implement a **thin, in-crate Ogg Opus (RFC 7845) demux/mux** for
   channel-mapping family 0 only — enough to read `OpusHead`/`OpusTags`, reassemble
   packets, apply pre-skip / granule trim, and write a valid Ogg Opus blob.
3. **Remove `ruopus`** from `native/rusty_opus_native` dependencies.
4. **ADR002 amendment:** “no container” remains the rule for packet/PCM APIs and for
   any container other than Ogg Opus on `reencode/2`. Ogg demux/mux is an explicit,
   narrow exception owned by RustyOpus for that one API.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Keep `ruopus` | Unacceptably slow on aarch64 without NEON; duplicate Opus implementation. |
| Switch to `rusty-opus` fork | Extra dep and license/provenance churn; `opus-rs` already meets the speed bar. |
| C `libopus` via FFI | Violates the pure-Rust / no-C boundary. |
| External Ogg crate only | Still need codec; thin in-crate family-0 glue keeps the dep surface minimal. |

## Consequences

- `reencode/2` wall time on Apple Silicon should move from ~1 s to tens of ms for the
  MemoMoo ~7 s fixture (order-of-magnitude improvement), proven by
  `scripts/bench_reencode.exs`.
- One Opus implementation in the tree (`opus-rs`); Ogg code is small and auditable.
- Multistream / non–family-0 Ogg remains unsupported (same as the prior `ruopus` path’s
  practical limit for MemoMoo blobs).
- NOTICE / provenance drop `ruopus`; ADR002’s “no Ogg” wording is narrowed by this ADR.

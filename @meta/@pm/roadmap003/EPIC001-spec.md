# EPIC001 Spec: Wire `ruopus` and Ship `reencode/2`

## Purpose

Give callers one function that takes an Ogg Opus binary and a numeric bitrate and
returns a re-encoded Ogg Opus binary, using pure-Rust `ruopus` with no ffmpeg and
no C libopus.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP003.md`
- Crate: [`ruopus`](https://crates.io/crates/ruopus) — `decode_ogg_opus/1`, `encode_ogg_opus/3`
- Existing surface: packet/PCM APIs on `opus-rs` (leave behavior unchanged)
- Caller shape: Ogg Opus blobs (`audio/ogg` / RFC 7845)

## Scope

In scope:

- Add and pin `ruopus` in `native/rusty_opus_native`; record license in NOTICE/provenance as required.
- Native `ogg_reencode(blob, bitrate)` on DirtyCpu: decode Ogg → encode Ogg at `bitrate` bits/s.
- Panic containment; tagged Elixir errors (`:invalid_input`, `:decode_failed`, `:encode_failed`, `:invalid_settings`, `:codec_panicked` as appropriate).
- `RustyOpus.reencode(blob, opts)` with required `:bitrate` (pos integer). No quality atoms on this API.
- Unit/integration tests with a committed Ogg Opus fixture (or generate once via `ruopus` in a test helper and assert size/energy).

Out of scope:

- Version bump (Epic 2)
- File paths, streaming IO, WebM
- Replacing Encoder/Decoder NIFs
- Hex publish

## Contract

```elixir
@spec reencode(binary(), keyword()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
RustyOpus.reencode(ogg_blob, bitrate: 20_000)
```

- Input must be Ogg Opus (RFC 7845). Non-Ogg or corrupt input → tagged error.
- `:bitrate` is required; missing or non-positive → tagged error.
- Output is Ogg Opus. Same channel count as input (mono/stereo as decoded).
- Sample rate follows `ruopus` Ogg path (48 kHz PCM internal); callers do not pass rate.
- Existing `encode/4`, `decode/4`, `transcode/5`, and per-frame APIs unchanged.

## Acceptance Criteria

- One call reencodes an Ogg Opus blob at `20_000` (and other ladder rates).
- On real speech, lower bitrate yields a smaller (or equal) byte size than a higher bitrate.
- No process spawn; dependency tree for this path is Rust-only (`ruopus` + existing Rustler stack).
- QA gate green before the epic commit.

## Test Strategy

- Fixture Ogg Opus (speech-like) round-trips through `reencode`.
- Size ordering: `8_000` ≤ `20_000` ≤ `48_000` total bytes for the same source (allow equality on silence-heavy edge cases; prefer speech fixture).
- Errors: empty binary, random bytes, missing `:bitrate`, `bitrate: 0`.
- Confirm `RUSTY_OPUS_BUILD=1` path never shells out.

## Quality Bar

- Least glue: prefer calling `ruopus` helpers end-to-end over hand-rolling Ogg pages.
- DirtyCpu for the NIF; panics never unwind across the boundary.
- `bin/qa_check.sh` green before commit.

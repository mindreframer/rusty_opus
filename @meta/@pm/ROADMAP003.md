# ROADMAP003 — Reencode an Ogg Opus Blob at a Numeric Bitrate

**Status:** Complete

Shipped `0.3.0` with `RustyOpus.reencode/2`: Ogg Opus blob + numeric `bitrate:` →
smaller Ogg Opus blob via pure-Rust `ruopus`. Hard-tested on real MemoMoo
`audio_versions` fixtures. No ffmpeg. Packet/PCM APIs unchanged. Hex/precompiled
publish remains the maintainer’s step.

- **Scope:** One Elixir call takes an Ogg Opus blob and a bitrate in bits/s, returns a smaller Ogg Opus blob. Pure Rust (`ruopus`). No ffmpeg. No C libopus. No `:low`/`:medium`/`:high`. Version `0.3.0`.
- **Why this is short:** The codec path already works. The gap is Ogg. `ruopus` already does `decode_ogg_opus` + `encode_ogg_opus(pcm, channels, bitrate)`.

## Goal

```elixir
{:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)
```

## How to execute

Two epics, in order. Spec + plan in `@meta/@pm/roadmap003/`. After each epic: `bin/qa_check.sh`, then commit `roadmap003 - epic N - <outcome>`.

---

## Epic 1 — Wire `ruopus` and ship `reencode/2`

- [x] Depend on `ruopus` in `native/rusty_opus_native` (pin a concrete version; audit license).
- [x] `ogg_reencode(blob, bitrate)` NIF — DirtyCpu; panic-contained; tagged errors.
- [x] `RustyOpus.reencode/2` — `bitrate:` required positive integer.
- [x] Tests: MemoMoo `audio_versions` fixtures; smaller + still-valid Ogg Opus; no ffmpeg.

## Epic 2 — Docs, fixtures, `0.3.0`

- [x] README / moduledoc lead with `reencode/2` and numeric bitrates.
- [x] Fixture + MemoMoo ladder notes (`8_000` … `32_000`).
- [x] Changelog, Mix/Cargo `0.3.0`, `bin/qa_check.sh` green, ROADMAP003 Complete.

## Success

- `RustyOpus.reencode(blob, bitrate: n)` shrinks real Ogg Opus audio.
- Bitrate is always a number.
- No ffmpeg / no C libopus on this path.
- Packet/PCM APIs still work.
- `bin/qa_check.sh` is green.

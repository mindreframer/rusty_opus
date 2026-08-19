# ROADMAP003 — Reencode an Ogg Opus Blob at a Numeric Bitrate

**Status:** Not started
- **Scope:** One Elixir call takes an Ogg Opus blob and a bitrate in bits/s, returns a smaller Ogg Opus blob. Pure Rust (`ruopus`). No ffmpeg. No C libopus. No `:low`/`:medium`/`:high`. Version `0.3.0`.
- **Why this is short:** The codec path already works. The gap is Ogg. `ruopus` already does `decode_ogg_opus` + `encode_ogg_opus(pcm, channels, bitrate)`.

## Current gap

Callers with real files (MemoMoo `audio_versions`, mime `audio/ogg`) cannot shrink them with RustyOpus alone. Packet APIs ignore the container. Preset atoms are the wrong UX for bitrate ladders like `8_000` … `32_000`.

## Goal

```elixir
{:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)
```

That’s the whole product surface for this roadmap. Input and output are Ogg Opus binaries. Bitrate is an integer (bits/s). Existing packet/PCM APIs stay unchanged.

## Out of scope

- ffmpeg, Ports, or any external process
- WebM / MP4 / other containers
- File-path I/O helpers (callers pass binaries; DB/FS is their problem)
- Replacing `opus-rs` packet NIFs in this roadmap
- Hex publish (maintainer step)

## How to execute

Two epics, in order. Spec + plan in `@meta/@pm/roadmap003/`. After each epic: `bin/qa_check.sh`, then commit `roadmap003 - epic N - <outcome>`. Check a box only when work and tests pass. Do not stop between phases.

---

## Epic 1 — Wire `ruopus` and ship `reencode/2`

Add `ruopus` to the native crate. Expose one DirtyCpu NIF that demuxes Ogg Opus, re-encodes PCM at the given bitrate, and remuxes Ogg Opus. Elixir wrapper: `RustyOpus.reencode(blob, opts)` with required `:bitrate`.

- [ ] Depend on `ruopus` in `native/rusty_opus_native` (pin a concrete version; audit license).
- [ ] `ogg_reencode(blob, bitrate)` NIF — `ruopus::decode_ogg_opus` → `ruopus::encode_ogg_opus`; DirtyCpu; panic-contained; tagged errors for bad Ogg / bad bitrate.
- [ ] `RustyOpus.reencode/2` — `bitrate:` required positive integer; returns `{:ok, ogg_blob}` or `{:error, %Error{}}`.
- [ ] Tests: committed fixtures copied from MemoMoo `audio_versions` (real Ogg Opus speech); `reencode` at `20_000` (and ladder rates) yields **smaller** blobs that still decode as valid Ogg Opus with audible energy; invalid blob / missing bitrate → tagged errors; no ffmpeg in the path.

**Done when:** one call shrinks a real DB-derived Ogg Opus blob to a numeric bitrate; output remains a working playable Ogg Opus file.

---

## Epic 2 — Docs, fixtures, `0.3.0`

Document the one-call path as the default for Ogg blobs. Commit a small real Ogg Opus fixture (from speech, not silence). Bump to `0.3.0` and close the roadmap.

- [ ] README / moduledoc lead with `reencode/2` for Ogg blobs; keep packet APIs as the raw-codec path.
- [ ] Fixture + comparison notes for MemoMoo-style bitrates (`8_000` … `32_000`).
- [ ] Changelog, Mix/Cargo `0.3.0`, `bin/qa_check.sh` green, ROADMAP003 Complete.

**Done when:** `0.3.0` documents blob→blob reencode; publish remains the maintainer’s step.

---

## Success

- `RustyOpus.reencode(blob, bitrate: n)` is the common path for shrinking Ogg Opus audio.
- Bitrate is always a number.
- No ffmpeg / no C libopus on this path.
- Packet/PCM 0.2.0 APIs still work.
- `bin/qa_check.sh` is green.

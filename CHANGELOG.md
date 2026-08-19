# Changelog

## 0.3.2 — Broader precompiled NIF matrix

- Precompiled NIFs for six targets: Apple Silicon + Intel macOS, Linux glibc and
  musl (Alpine) on both aarch64 and x86_64.
- Release builds Linux artifacts in matching Docker images; musl artifacts are
  smoke-tested under Alpine Elixir.
- Windows remains deferred.

## 0.3.1 — Faster Ogg reencode on Apple Silicon (ADR003)

- `reencode/2` uses pinned `opus-rs` (NEON on aarch64) plus thin in-crate Ogg Opus
  family-0 demux/mux; drops `ruopus` (see ADR003).
- Same Elixir API (`bitrate:` required). ~7 s speech fixture: ~24 ms median at
  20 kb/s vs ~965 ms with `ruopus` on M3 Ultra (~40×).
- Packet/PCM APIs unchanged.

## 0.3.0 — Reencode Ogg Opus blobs at a numeric bitrate

- `RustyOpus.reencode/2` takes an Ogg Opus blob and `bitrate:` (bits/s) and returns a
  smaller Ogg Opus blob. Pure Rust. No ffmpeg, no C libopus, no quality atoms.
- Hard-tested against committed Ogg Opus speech fixtures.
- Packet/PCM APIs from 0.2.0 are unchanged.

## 0.2.0 — Whole-stream encode, decode, and transcode

- `Encoder.encode_many/2` and `Decoder.decode_many/2` encode or decode a whole buffer
  or packet list in one DirtyCpu NIF call.
- `RustyOpus.encode/4`, `decode/4`, and `transcode/5` open a codec, run the bulk path,
  and close it — the default path for converting a stream.
- Default frame size is 20 ms (`div(rate, 50)`). A short last encode frame is padded
  with silence, never truncated.
- 0.1.0 call sites are unchanged: per-frame `encode/3`/`decode/3` and single-frame
  helpers `encode_pcm/4`, `decode_packet/4`, and `change_quality/5` still work.

## 0.1.0 — Initial release

- Pure-Rust Opus (RFC 6716) codec for Elixir via Rustler, wrapped from `opus-rs 0.1.29`.
- `RustyOpus.Encoder` with bitrate, complexity, CBR/VBR, in-band FEC, and packet-loss
  controls; `RustyOpus.Decoder` with packet-loss concealment.
- Stable PCM contract: little-endian `f32` binary, interleaved for stereo.
- `RustyOpus.change_quality/4,5` decodes a packet and re-encodes it at a new quality
  preset (`:low`/`:medium`/`:high`) or a `:target_bitrate`.
- `RustyOpus.Quality` presets and `RustyOpus.PCM` helpers (interleave/deinterleave).
- Panic containment at the NIF boundary: hostile packets return tagged errors instead of
  crashing the caller; dirty-scheduled codec work never blocks normal schedulers.
- Checksum-verified precompiled NIFs for Linux x86-64/ARM64 and macOS x86-64/Apple
  Silicon, with a source-build fallback.
- Real speech fixtures imported from the audio DB (`scripts/import_fixtures.sh`).

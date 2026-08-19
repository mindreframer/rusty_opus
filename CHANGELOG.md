# Changelog

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

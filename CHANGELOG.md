# Changelog

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

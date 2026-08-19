# EPIC004 Spec: Quality-Change Facade, Presets, and Fixtures

## Purpose

Deliver the motivating feature — **changing the encoding quality** — and import compact
real-world audio fixtures from the Opus audio DB so tests run against genuine speech.

## Reference Inputs

- Roadmap Epics 2 (encoder) and 3 (decoder)
- `RustyOpus.Encoder` and `RustyOpus.Decoder` from Epics 2–3
- Ogg/Opus audio files in
  `MOO_MATERIAL/moo_courses_v3/elixir/moo_courses_v3/data/moo_courses_v3_dev.db`
  (the `audio_versions` table stores `audio/ogg` blobs)
- Existing ffmpeg tooling that already produced bitrate variants (8k–32k) of this audio

## Scope

In scope:

- `RustyOpus` facade: `encode_pcm/3|4` and `decode_packet/3` convenience helpers that own
  short-lived codec resources
- PCM helpers: interleave/deinterleave and sample-count helpers over the f32-binary contract
- quality presets `:low`/`:medium`/`:high` and a `:target_bitrate` override tuning
  bitrate, complexity, and VBR/CBR
- `RustyOpus.change_quality/4`: decode an Opus-packet input to PCM and re-encode at a new
  quality, returning re-encoded packets
- `scripts/import_fixtures.sh`: read a few Ogg/Opus blobs from the DB, decode short clips
  to f32le PCM via ffmpeg, and write compact `test/fixtures/` files plus one golden Opus
  packet fixture
- quality-change tests: byte-size ordering, lower-bitrate shrink, and lossy-tolerance
  round-trip vs source PCM

Out of scope: container parsing at runtime, ffmpeg in runtime/test code, real-time
streaming, and platform packaging (Epics 5–7).

## Acceptance Criteria

- `change_quality/4` re-encodes decoded buffer at a new quality, and output size ordering
  matches preset monotonicity (low < medium < high) for the same content.
- Re-encoding at a lower bitrate observably reduces encoded size.
- Imported fixtures are stable, compact, offline-reproducible, and used by the QA gate.
- The facade reuses the Epic 2–3 codec resources without leaking them.

## Test Strategy

- Deterministic byte-size comparisons over the imported PCM fixture at each preset.
- Lossy-tolerance compare of decode→re-encode (or encode→decode) vs source PCM.
- Facade/resource tests prove short-lived codecs are closed and leak-free.
- Golden fixture used to decouple decoder testing from our own encoder.

## Quality Bar

- Quality ordering is demonstrable with real imported speech, not synthetic noise.
- `bin/qa_check.sh` is green; the facade is clean and reuses existing codec resources.

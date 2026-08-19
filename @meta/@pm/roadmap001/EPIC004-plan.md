# EPIC004 Plan: Quality-Change Facade, Presets, and Fixtures

## Progress

- [ ] Phase 4.1: Add `RustyOpus` facade helpers `encode_pcm/3|4` and `decode_packet/3`.
- [ ] Phase 4.2: Add PCM interleave/deinterleave and sample-count helpers.
- [ ] Phase 4.3: Add quality presets `:low`/`:medium`/`:high` and a `:target_bitrate` override.
- [ ] Phase 4.4: Add `RustyOpus.change_quality/4` (decode → re-encode at new quality).
- [ ] Phase 4.5: Add `scripts/import_fixtures.sh` and compact `test/fixtures/` plus a golden Opus fixture.
- [ ] Phase 4.6: Add quality-change tests: size ordering, low-bitrate shrink, lossy tolerance.
- [ ] Phase 4.7: Pass the epic gate, verify every Epic 4 criterion, and prepare the focused commit.

## Implementation Steps

1. Add facade functions that construct an encoder/decoder, run one call, and close the
   resource in an `after`/ensure, returning `{:ok, result}` or a tagged error.
2. Add interleave/deinterleave and `sample_count/2` helpers on the f32-binary contract,
   with byte-length validation.
3. Define preset → settings maps (e.g. low=24kbps, medium=48kbps, high=96kbps, each with
   a complexity/VBR setting) plus a `:target_bitrate` that overrides the bitrate.
4. Implement `change_quality(data, source_settings, target_quality)` decoding each input
   packet frame and re-encoding at the target settings, returning concatenated packets.
5. Write the import script reading a few Ogg blobs from the DB with `sqlite3`, decoding
   `-f f32le` mono/1–2s clips with ffmpeg, and writing `test/fixtures/*.f32` plus one
   golden Opus packet file; add a reproducibility note in `docs/provenance.md`.
6. Tests on size ordering, low-bitrate shrink, lossy round-trip vs source PCM, and
   facade resource cleanup; import script output is committed once and stable.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion, review the diff, and
   only then prepare the epic commit.

## Test Isolation Checklist

- [ ] Fixtures are committed files under `test/fixtures/`, not DB-dependent at test time.
- [ ] Tests never invoke sqlite3 or ffmpeg; only the commit-time import script does.
- [ ] Size-ordering tests use identical source PCM and deterministic presets.
- [ ] Facade tests prove every short-lived resource is closed.

## Quality Gate

- [ ] Presets and `:target_bitrate` are documented and monotonic in produced size.
- [ ] `change_quality/4` produces observably smaller output at lower quality.
- [ ] Fixtures are stable and reproducible offline from the DB.
- [ ] `bin/qa_check.sh` is green; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 4 criteria pass, commit
`roadmap001 - epic 4 - add quality-change facade, presets, and fixtures`. Never commit
partial, optimistic, or out-of-scope work.

# BLOCKER.md — Roadmap 001, Epic 4 (quality-change facade, presets, fixtures)

Status: **Resolved** (both blockers fixed and verified).

## Blocker 1: fixture frame selection — resolved

**Original symptom:** quality tests picked the first 20 ms of `speech_16k_mono.f32`
(near-silent lead-in), producing ~9-byte packets at every bitrate so size-ordering and
energy assertions failed.

**Resolution:** analyzed per-frame peaks and switched to a loud speech-rich frame at
~0.06 s into the clip (`binary_part(pcm, 3_840, 320 * 4)`). The golden Opus packet was
regenerated from the same frame via `scripts/import_fixtures.sh`.

## Blocker 2: PCM module alias shadowing — resolved

**Original symptom:** `quality_test.exs` aliased `RustyOpus.TestHelpers.PCM`, shadowing
the new public `RustyOpus.PCM` (`interleave/2`/`deinterleave/1` undefined).

**Resolution:** the test now aliases the public `RustyOpus.PCM`.

## Verification

- `mix test test/rusty_opus/quality_test.exs` → 12 passed.
- `bin/qa_check.sh` → all stages green.
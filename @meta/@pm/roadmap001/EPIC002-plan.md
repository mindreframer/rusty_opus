# EPIC002 Plan: Encoder NIF Resource and API

## Progress

- [ ] Phase 2.1: Register the encoder resource and implement `encoder_new/4` with full validation.
- [ ] Phase 2.2: Implement f32le-PCM-binary ↔ `&[f32]` marshalling and reject mis-sized input.
- [ ] Phase 2.3: Implement `encoder_encode/3` with frame-size validation, capacity-safe output, and dirty scheduling.
- [ ] Phase 2.4: Wire bitrate, complexity, CBR/VBR, in-band FEC, and packet-loss settings plus setters.
- [ ] Phase 2.5: Add `RustyOpus.Encoder`, the settings validation layer, and stable error mapping.
- [ ] Phase 2.6: Add encoder construction, round-trip, bitrate-order, CBR-bounded, and cleanup tests.
- [ ] Phase 2.7: Pass the epic gate, verify every Epic 2 criterion, and prepare the focused commit.

## Implementation Steps

1. Define `RustyOpus.Native.encoder_new(rate, channels, application, settings)` returning
   a `ResourceArc<EncoderResource>` or a tagged error; validate rates/channels/app first.
2. Add a Rust helper converting the f32le-PCM binary to `Vec<f32>` with exact byte-length
   checks, and the reverse for any encoder-returned data.
3. Add `encoder_encode(resource, pcm, frame_size)` computing the required output capacity
   (`OpusEncoder` worst case), calling `encoder.encode(&input, frame_size, &mut out)`, and
   trimming to the produced byte count; run on a dirty I/O scheduler.
4. Set encoder fields from settings at construction and add `encoder_set_bitrate` /
   setters as stable APIs; validate ranges (bitrate > 0, complexity 0–10).
5. Expose `RustyOpus.Encoder.new/3|4` and `encode/3`; add `RustyOpus.Settings` with
   `:bitrate`, `:complexity`, `:vbr`/`:cbr`, `:fec`, `:packet_loss`, `:application`.
6. Tests: invalid inputs error; encode returns binary; bitrate-order monotonicity; CBR
   bounded size; open/close and owner-death cleanup; dirty-scheduler smoke.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion, review the native
   and Elixir diff, and only then prepare the epic commit.

## Test Isolation Checklist

- [ ] No shared mutable encoder state between tests; each test owns its encoders.
- [ ] Bitrate/quality comparisons use identical PCM source and deterministic settings.
- [ ] Resource/cleanup tests use counters rather than arbitrary sleeps.
- [ ] Fixtures/input are deterministic and require no network services.

## Quality Gate

- [ ] Settings validation and error mapping are stable and complete.
- [ ] `encode/3` returns the Opus-binary contract and dirty schedules large frames.
- [ ] Bitrate-order and CBR-bounded tests pass.
- [ ] Close is idempotent; owner death frees the resource.
- [ ] `bin/qa_check.sh` is green; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 2 criteria pass, commit
`roadmap001 - epic 2 - implement encoder resource and API`. Never commit partial,
optimistic, or out-of-scope work.

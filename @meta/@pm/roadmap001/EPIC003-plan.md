# EPIC003 Plan: Decoder NIF Resource and API

## Progress

- [ ] Phase 3.1: Register the decoder resource and implement `decoder_new/2` with validation.
- [ ] Phase 3.2: Implement `decoder_decode/3` with capacity-safe PCM output and dirty scheduling.
- [ ] Phase 3.3: Handle ToC-only lost/DTX packets via packet-loss concealment (PLC).
- [ ] Phase 3.4: Add `RustyOpus.Decoder` with `new/2` and `decode/3`, plus stable error mapping.
- [ ] Phase 3.5: Add decoder round-trip, golden-packet, channel-mismatch, PLC, and cleanup tests.
- [ ] Phase 3.6: Map every Opus error to a stable tagged error; prove idempotent close and owner-death cleanup.
- [ ] Phase 3.7: Pass the epic gate, verify every Epic 3 criterion, and prepare the focused commit.

## Implementation Steps

1. Define `RustyOpus.Native.decoder_new(rate, channels)` returning a
   `ResourceArc<DecoderResource>` or tagged error; validate rates/channels first.
2. Add `decoder_decode(resource, packet, frame_size)` sizing the PCM output buffer from
   `frame_size * channels`, calling `decoder.decode(&packet, frame_size, &mut out)`, and
   returning the f32le-PCM binary trimmed to produced samples; dirty I/O scheduling.
3. Confirm `opus-rs` treats a 1-byte ToC-only packet as a lost frame and conceals it;
   add an explicit test, not a custom implementation.
4. Expose `RustyOpus.Decoder.new/2` and `decode/3` mapping errors to `RustyOpus.Error`.
5. Tests: round-trip encoder→decoder within tolerance; decode a golden packet to a known
   sample count; channel mismatch errors; a lost-frame packet conceals; repeated open/close
   and owner death reclaim resources.
6. Ensure close is idempotent (`{:error, :closed}` after close) and every surfaced Opus
   error has a stable tagged mapping.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion, review the diff, and
   only then prepare the epic commit.

## Test Isolation Checklist

- [ ] No shared mutable decoder state between tests; each test owns its decoders.
- [ ] Round-trip comparisons use deterministic PCM and lossy tolerance.
- [ ] Resource/cleanup tests use counters rather than arbitrary sleeps.

## Quality Gate

- [ ] `decode/3` returns the PCM-binary contract and dirty schedules large frames.
- [ ] Encoder→decoder round-trip passes within lossy tolerance.
- [ ] PLC and channel-mismatch behavior are correct and stable.
- [ ] Close is idempotent; owner death frees the resource.
- [ ] `bin/qa_check.sh` is green; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 3 criteria pass, commit
`roadmap001 - epic 3 - implement decoder resource and API`. Never commit partial,
optimistic, or out-of-scope work.

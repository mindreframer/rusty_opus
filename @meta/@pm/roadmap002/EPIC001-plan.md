# EPIC001 Plan: Bulk Encode and Decode

## Progress

- [ ] Phase 1.1: Implement `encoder_encode_many` in Rust (chunk, pad last frame, encode, DirtyCpu).
- [ ] Phase 1.2: Implement `decoder_decode_many` in Rust (decode list, concatenate PCM, DirtyCpu, DTX conceal).
- [ ] Phase 1.3: Add `Encoder.encode_many/2` and `Decoder.decode_many/2` with optional `:frame_size`.
- [ ] Phase 1.4: Equivalence, padding, empty-input, closed-handle, and lifecycle tests.
- [ ] Phase 1.5: Pass the epic gate, verify every Epic 1 criterion, and prepare the focused commit.

## Implementation Steps

1. Add `encoder_encode_many` next to `encoder_encode`. Reuse sample marshalling, closed/
   poisoned checks, and panic containment. Chunk `pcm` into `frame_size * channels`
   samples; if the last chunk is short, pad with zeros to a full frame; encode each
   chunk; return a list of packet binaries.
2. Add `decoder_decode_many` next to `decoder_decode`. Decode each packet with the
   shared decoder; concatenate PCM; keep 1-byte DTX concealment.
3. Stub both NIFs on `RustyOpus.Native`. Wrap them as `encode_many(encoder, pcm, opts \\ [])`
   and `decode_many(decoder, packets, opts \\ [])`. Default `:frame_size` to
   `div(rate, 50)` from the handle.
4. Tests in `test/rusty_opus/encoder_test.exs` and `decoder_test.exs` (or a dedicated
   bulk test file): bulk ≡ per-frame loop; stereo; remainder padded; empty inputs;
   closed handle; resource counters back to baseline.
5. Run `bin/qa_check.sh`, confirm acceptance criteria, review the native diff, commit.

## Test Isolation Checklist

- [ ] Bulk tests use unique encoder/decoder handles; no shared mutable codec state.
- [ ] Remainder/padding cases use a PCM length that is not a multiple of the frame.
- [ ] Resource-counter checks compare against a captured baseline, not sleeps.
- [ ] Existing `encode/3` and `decode/3` tests remain unmodified in intent.

## Quality Gate

- [ ] Bulk NIFs are DirtyCpu-scheduled and panic-contained.
- [ ] Equivalence, padding, empty, closed, and lifecycle tests pass.
- [ ] 0.1.0 per-frame APIs unchanged.
- [ ] `bin/qa_check.sh` is green.
- [ ] Commit title and body follow the commit rule.

## Commit Rule

After implementation, run only the repository gate from the repository root:

```sh
bin/qa_check.sh
```

Only if it passes and all Epic 1 criteria are complete, create one focused commit:

`roadmap002 - epic 1 - bulk encode and decode a whole stream`

The body must state that bulk NIFs match the per-frame loop, pad a short last frame,
and leave 0.1.0 APIs unchanged. Do not commit failing, partial, or Epic 2 facade work.

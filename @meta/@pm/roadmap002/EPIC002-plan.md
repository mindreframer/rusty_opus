# EPIC002 Plan: Whole-Stream Facade

## Progress

- [ ] Phase 2.1: Add `RustyOpus.encode/4` (open encoder, `encode_many`, close).
- [ ] Phase 2.2: Add `RustyOpus.decode/4` (open decoder, `decode_many`, close).
- [ ] Phase 2.3: Add `RustyOpus.transcode/5` using the same quality resolution as `change_quality/5`.
- [ ] Phase 2.4: Equivalence, ordering, error, and lifecycle tests.
- [ ] Phase 2.5: README quick start and `RustyOpus` moduledoc lead with encode/decode/transcode.
- [ ] Phase 2.6: Pass the epic gate, verify every Epic 2 criterion, and prepare the focused commit.

## Implementation Steps

1. Implement `encode/4`: resolve `:quality` via `Quality.to_settings/2` when present,
   otherwise treat `opts` as encoder settings (same as `encode_pcm/4`). Open
   `Encoder.new/4`, call `encode_many`, close in an `after` (or equivalent) so the
   resource is released on error too.
2. Implement `decode/4`: open `Decoder.new/2`, call `decode_many`, close the same way.
3. Implement `transcode/5`: `Quality.to_settings(quality, opts)`, `decode/4`, then
   `encode/4` with those settings. Drop `:frame_size` from settings passed to the encoder
   if it is not a Settings key. One output packet per input packet.
4. Add tests (likely `test/rusty_opus_test.exs` or `test/rusty_opus/quality_test.exs`):
   single-packet ≡ `change_quality/5`; multi-packet count/order; preset size order;
   tagged errors; counters back to baseline.
5. Rewrite the README quick start and `RustyOpus` moduledoc to show the three calls.
   Label `encode_pcm/4`, `decode_packet/4`, and `change_quality/5` as single-frame.
6. Run `bin/qa_check.sh`, confirm acceptance criteria, commit.

## Test Isolation Checklist

- [ ] Facade tests do not share encoder/decoder handles across cases.
- [ ] Counter checks capture a baseline before the call.
- [ ] Lossy PCM compares use `RustyOpus.TestHelpers`, not exact equality.
- [ ] 0.1.0 one-shot tests keep passing.

## Quality Gate

- [ ] `encode/4`, `decode/4`, and `transcode/5` exist and are documented as the default path.
- [ ] Single-packet transcode matches `change_quality/5`.
- [ ] README examples do not require manual chunking.
- [ ] 0.1.0 functions unchanged.
- [ ] `bin/qa_check.sh` is green.
- [ ] Commit title and body follow the commit rule.

## Commit Rule

After implementation, run only the repository gate from the repository root:

```sh
bin/qa_check.sh
```

Only if it passes and all Epic 2 criteria are complete, create one focused commit:

`roadmap002 - epic 2 - whole-stream encode, decode, and transcode`

The body must state that converting a stream is now one call and that single-frame
helpers remain. Do not bump the version in this commit.

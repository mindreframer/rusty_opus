# EPIC005 Plan: Dedicated Ogg Opus Module and Backward Compatibility

## Progress

- [ ] Phase 5.1: Add `RustyOpus.OggOpus` and delegate existing top-level re-encode without changing current behavior.
- [ ] Phase 5.2: Decode family-0 mono/stereo Ogg Opus to 48 kHz PCM with correct pre-skip/end trim.
- [ ] Phase 5.3: Encode validated/resampled PCM to valid family-0 headers, pages, lacing, CRCs, granules, and EOS.
- [ ] Phase 5.4: Complete dedicated re-encode and preferred `:bitrate_mode` while retaining non-conflicting `:cbr` compatibility.
- [ ] Phase 5.5: Prove every existing top-level/raw packet/resource/default/error/documented call remains compatible.
- [ ] Phase 5.6: Pass independent RFC/page/granule/duration/bitrate/corruption/scheduler/lifecycle and compatibility quality checks.
- [ ] Phase 5.7: Run complete Ogg/backward-compatibility suites and `bin/qa_check.sh`, verify Epic 5, and prepare the focused commit.

## Implementation Steps

1. Create the dedicated Elixir module and route `RustyOpus.reencode/2` through it while
   preserving validation order, defaults, accepted current options, result shape, and errors.
2. Extend/reuse the thin Ogg glue to parse one family-0 stream, decode packets through the
   existing Opus codec, apply pre-skip/final granule trimming, and return 48 kHz PCM metadata.
3. Encode shared PCM after required 48 kHz/channel transforms; write minimal OpusHead/
   OpusTags and capacity-safe Ogg pages with legal lacing, sequence, CRC, granule, BOS/EOS.
4. Implement dedicated settings validation and re-encode composition; add `:bitrate_mode`;
   map legacy `:cbr` only when not conflicting; retain Opus-specific setting semantics.
5. Add focused regression tests for top-level `reencode`, raw encode/decode/transcode,
   per-frame/bulk encoder/decoder resources, settings, errors, fixtures, docs examples,
   lifecycle, and clean-consumer source compatibility.
6. Run independent RFC/container checks, delay/duration/signal corpus, bitrate ladder,
   corrupt-page cases, scheduler and counter baselines, and the complete compatibility
   matrix; record evidence and fix every failure.
7. Run all Ogg/Opus/raw regression and boundary audits through `bin/qa_check.sh`, review
   scope/diff, and prepare the Epic 5 commit.

## Test Isolation Checklist

- [ ] Ogg tests use unique complete blobs/stream serial state and no shared mutable codec.
- [ ] Delay/duration assertions use explicit pre-skip/granule frame accounting.
- [ ] Corrupt inputs are bounded and fatal cases stay in disposable child BEAMs.
- [ ] Compatibility expectations are captured before refactoring and asserted afterward.
- [ ] Lifecycle/scheduler tests use counters, barriers, and heartbeats rather than sleeps.
- [ ] Runtime/default tests use no external process, path, or system codec.
- [ ] Metadata tests expect minimal output, never preservation.

## Extra Quality Evidence

- Independent OpusHead/Tags/family/channel and Ogg page/lacing/CRC/sequence report.
- Packet/granule/pre-skip/end-trim frame-count and duration table.
- Bitrate/mode/settings size and signal behavior across mono/stereo fixtures.
- Corrupt-page, checked-size, peak-memory, scheduler, and counter-baseline results.
- Full top-level/raw API, defaults, error, lifecycle, docs, and clean-consumer matrix.

## Quality Gate

- [ ] Dedicated Ogg module fulfills all three verbs over family-0 blobs.
- [ ] Emitted headers/pages/granules/CRCs and duration pass independent checks.
- [ ] `RustyOpus.reencode/2` and raw packet/resource APIs remain compatible.
- [ ] `:bitrate_mode`/`:cbr` conflict and all Opus settings are explicit/stable.
- [ ] Unsupported/corrupt inputs fail safely and bounded scheduler/lifecycle checks pass.
- [ ] `bin/qa_check.sh` is green after extra-quality evidence passes.
- [ ] Commit title/body follow the roadmap004 rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 5 criteria/evidence pass, commit:

`roadmap004 - epic 5 - add dedicated Ogg Opus file APIs`

The body must summarize the module/refactor, RFC/duration evidence, compatibility proof,
robustness/scheduler/lifecycle results, and the authoritative QA result.

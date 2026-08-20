# EPIC002 Plan: PCM Descriptor and Deterministic Audio Transform Core

## Progress

- [ ] Phase 2.1: Add the validated `%RustyOpus.PCM{data, sample_rate, channels}` struct without changing existing helpers.
- [ ] Phase 2.2: Centralize f32le alignment, finite-value, frame-count, rate/channel, checked-size, and marshalling validation.
- [ ] Phase 2.3: Implement deterministic mono/stereo preservation, duplication, and `(L + R) / 2` downmix.
- [ ] Phase 2.4: Implement bounded fixed-ratio offline resampling with explicit tail flush and frame accounting.
- [ ] Phase 2.5: Compose validated internal rate/channel transforms behind the common option contract.
- [ ] Phase 2.6: Pass signal-integrity, duration, alias, determinism, memory, scheduler, and lifecycle quality measurements.
- [ ] Phase 2.7: Run complete PCM/transform tests and `bin/qa_check.sh`, verify Epic 2, and prepare the focused commit.

## Implementation Steps

1. Add the struct/type and an explicit validated constructor or validator on
   `RustyOpus.PCM`; retain the current bare-binary helper signatures and semantics.
2. Add shared Elixir/native validation for byte/frame alignment, channels, bounded rate,
   finite f32 samples, checked multiplication/addition, maximum frames, and stable errors.
3. Implement mono identity/duplication and stereo identity/average downmix with exact
   interleaving, deterministic f32 operations, and tests for separation/cancellation.
4. Wrap the selected resampler for whole-buffer fixed ratios; allocate with checked upper
   bounds, feed all frames, flush delayed/tail output, trim only documented latency, and
   return a valid PCM struct.
5. Add one internal transform function that resolves optional target rate/channels,
   fixes operation order, skips no-op work, and maps all backend errors consistently.
6. Run the full signal corpus and rate-pair matrix; capture frame/duration, alias,
   crosstalk, hash, memory, responsiveness, and baseline evidence; fix every threshold failure.
7. Run unit, integration, lifecycle, scheduler, conformance, and backward-compatibility
   tests through `bin/qa_check.sh`; review scope and prepare the Epic 2 commit.

## Test Isolation Checklist

- [ ] Each transform test owns its PCM values and native work; no shared mutable resampler.
- [ ] Signal inputs, target rates, and thresholds are deterministic and versioned.
- [ ] Lossy/resampled comparisons use delay-aware helpers rather than exact equality.
- [ ] Lifecycle tests capture native counters before work and use barriers, not sleeps.
- [ ] Scheduler tests use bounded workloads and generous deterministic timing bounds.
- [ ] Output-size tests validate checked failure before impractical allocation.
- [ ] Existing raw Opus fixtures/tests remain unchanged in intent.

## Extra Quality Evidence

- Required-rate-pair frame-count and duration-drift table.
- Passband/alias, impulse/tail, silence/DC, and stereo-crosstalk results.
- Deterministic output hashes across repeated calls.
- Peak intermediate-memory and allocation-bound evidence.
- Dirty-scheduler heartbeat and repeated-call native-counter baselines.

## Quality Gate

- [ ] PCM struct and validation contract match ROADMAP004 and Epic 1.
- [ ] Existing binary helpers and raw Opus APIs remain compatible.
- [ ] Channel transforms are exact for defined fixtures and preserve interleaving.
- [ ] Resampling passes all frozen signal/duration thresholds and keeps the tail.
- [ ] Hostile sizes/non-finite values return stable errors without panic/allocation blowup.
- [ ] `bin/qa_check.sh` is green after extra-quality measurements pass.
- [ ] Commit title/body follow the roadmap004 rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 2 criteria/evidence pass, commit:

`roadmap004 - epic 2 - add shared PCM and deterministic audio transforms`

The body must summarize compatibility, channel/resampler behavior, extra-quality metrics,
memory/scheduler/lifecycle evidence, and the authoritative QA result.

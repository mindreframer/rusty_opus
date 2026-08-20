# EPIC006 Plan: Common `convert/2` Facade and Cross-Format Matrix

## Progress

- [ ] Phase 6.1: Implement conservative byte-based WAV/Ogg Opus/MP3 detection plus explicit `:from` mismatch handling.
- [ ] Phase 6.2: Implement exact common option ownership/applicability validation for every `:to` target.
- [ ] Phase 6.3: Add `%RustyOpus.PCM{}` input and `to: :pcm` endpoints while rejecting ambiguous raw PCM binaries.
- [ ] Phase 6.4: Compose one decode, optional shared transform, and one encode for all file pairs and same-format routes.
- [ ] Phase 6.5: Stabilize stage-aware errors, checked limits, dirty scheduling, counters, and facade robustness.
- [ ] Phase 6.6: Pass the complete 3×3+PCM conformance, fidelity, duration, detection, error, memory, concurrency, and forbidden-activity matrix.
- [ ] Phase 6.7: Run complete facade/compatibility suites and `bin/qa_check.sh`, verify Epic 6, and prepare the focused commit.

## Implementation Steps

1. Add an internal detector that structurally validates RIFF/WAVE, Ogg+OpusHead, and
   MP3 ID3/frame sequences within bounded reads; add explicit `:from` validation and a
   stable mismatch reason/precedence.
2. Define one target-option table; validate required/allowed/rejected keys and values
   before native work; translate only shared bitrate mode/rate/channel/sample-format settings.
3. Route validated PCM structs directly to transform/encode and decode file inputs to
   PCM for `to: :pcm`; reject `:from` with PCM and never infer bare binaries as PCM.
4. Implement facade dispatch over all nine file pairs and PCM endpoints; use dedicated
   re-encode for same-format targets; guarantee one decode/transform/encode maximum.
5. Add stable stage/format error context, checked intermediate/output limits, panic
   containment, dirty scheduling, counters/telemetry consistency, and bounded hostile cases.
6. Execute every source×target fixture combination and PCM endpoint; collect independent
   output conformance, metadata/duration/quality/size, error/detection, determinism,
   memory/concurrency/scheduler/counter, and no-process/no-file evidence; fix all failures.
7. Run facade, dedicated, raw compatibility, source audit, lifecycle, and conformance
   checks through `bin/qa_check.sh`; review scope/diff and prepare the Epic 6 commit.

## Test Isolation Checklist

- [ ] Matrix cases use immutable committed fixtures and unique conversion state.
- [ ] Each expected output is validated independently of only self-decoding.
- [ ] Concurrency cases use unique inputs/options and explicit barriers.
- [ ] Lifecycle/scheduler assertions use captured baselines and heartbeats, not sleeps.
- [ ] Fatal/corrupt fuzz cases stay bounded in disposable child BEAMs.
- [ ] No runtime/default test creates a codec temp file or invokes an external executable.
- [ ] Existing dedicated/raw API regression suites run unchanged in intent.

## Extra Quality Evidence

- Full WAV/MP3/Ogg source×target matrix plus all PCM endpoints.
- Detection/explicit-format/error-precedence and adversarial-prefix report.
- Output format, rate, channels, duration, bitrate/sample-format, size, and fidelity table.
- Determinism, peak-memory, concurrent-isolation, scheduler, and counter-baseline results.
- Source/runtime trace proving no Port/process/ffmpeg/temp-file/path activity.

## Quality Gate

- [ ] Common examples and all 3×3+PCM paths meet their contracts.
- [ ] Detection is conservative, content-based, deterministic, and mismatch-aware.
- [ ] Required/inapplicable/unknown/conflicting option validation is exact.
- [ ] Dedicated-only settings remain absent from `convert/2`.
- [ ] Memory/concurrency/scheduler/lifecycle and forbidden-activity checks pass.
- [ ] `bin/qa_check.sh` is green after extra-quality evidence passes.
- [ ] Commit title/body follow the roadmap004 rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 6 criteria/evidence pass, commit:

`roadmap004 - epic 6 - add common multi-format conversion facade`

The body must summarize detection/options/pipeline behavior, the complete matrix evidence,
robustness/resource/scheduler/no-process results, compatibility, and QA.

# EPIC004 Plan: MP3 Decode, Encode, and Re-encode

## Progress

- [ ] Phase 4.1: Implement in-memory MPEG-1/2/2.5 Layer III decode with bounded ID3/sync handling and PCM metadata.
- [ ] Phase 4.2: Implement validated mono/stereo MP3 encode with numeric bits/s bitrate, CBR/VBR, drain, delay, and reservoir completion.
- [ ] Phase 4.3: Add `RustyOpus.MP3.decode/1`, `encode/2`, and `reencode/2` with only qualified dedicated options.
- [ ] Phase 4.4: Compose optional rate/channel transforms and complete metadata-dropping MP3 re-encoding.
- [ ] Phase 4.5: Harden layer/rate/bitrate/tag/frame/reservoir/truncation/garbage/allocation error boundaries.
- [ ] Phase 4.6: Pass the frozen MP3 interoperability, fidelity, bitrate, duration, fuzz, target, memory, scheduler, and lifecycle gate.
- [ ] Phase 4.7: Run complete MP3 suites and `bin/qa_check.sh`, verify Epic 4, and prepare the focused commit.

## Implementation Steps

1. Adapt the Epic 1 pinned backend for whole-binary input; bound leading ID3 and sync
   searches; decode all qualified versions/modes; concatenate interleaved f32le output;
   return actual rate/channels; reject unsupported changes deterministically.
2. Validate output sample rate/channels and CBR tables before backend calls; configure
   numeric CBR/VBR; push all PCM; flush/pad/drain reservoir and metadata frames; concatenate
   a complete deterministic MP3 binary with checked sizes.
3. Add Elixir module/native stubs/settings; require bits/s bitrate; default to VBR; add a
   dedicated VBR-quality option only if the qualification contract approved it; reject
   unknown/conflicting settings consistently.
4. Build re-encode as decode → optional shared transform → encode; document/remove input
   metadata; bound delay/padding and test repeated re-encode duration.
5. Add option/table/parser unit tests and integration coverage for tags, garbage, malformed
   headers/reservoirs, truncation, unsupported layers/rates, invalid bitrates, empty/large
   input, overflow, and backend failures.
6. Run the frozen independent corpus and all quality/conformance measurements; execute
   bounded child-BEAM fuzzing, target builds, memory/scheduler/counter checks; record and
   fix all failures without changing thresholds.
7. Run MP3, PCM-transform, compatibility, source-boundary, license, and regression checks
   through `bin/qa_check.sh`; review scope/diff and prepare the Epic 4 commit.

## Test Isolation Checklist

- [ ] Every encode/decode/reencode case owns its complete codec state and binaries.
- [ ] Quality comparisons use identical source/alignment/metric/settings manifests.
- [ ] Independent results come from committed artifacts or developer conformance tooling,
      never an external executable invoked by runtime/default tests.
- [ ] Corrupt/fuzz cases are bounded and fatal paths stay in disposable child BEAMs.
- [ ] Scheduler tests use heartbeats/barriers; lifecycle tests capture counter baselines.
- [ ] No test depends on ID3 metadata being preserved.
- [ ] Target builds use locked dependencies and clean build directories.

## Extra Quality Evidence

- Independent decode/encode compatibility matrix across MPEG versions, modes, and tags.
- Per-content-class objective fidelity and aligned duration/delay report.
- Target-vs-actual bitrate and output-size ordering table for CBR/VBR ladders.
- Frame/header/reservoir/drain and deterministic output validation.
- Corrupt-input fuzz, target-build, peak-memory, scheduler, and counter-baseline results.

## Quality Gate

- [ ] Decode metadata/reference alignment passes for every qualified fixture.
- [ ] CBR/VBR output is independently consumable and structurally valid.
- [ ] Frozen quality, bitrate, size, and duration thresholds pass without waiver.
- [ ] Invalid standard bitrates error before backend snapping can occur.
- [ ] Pure-Rust/no-process/no-file/no-FFI and target/provenance audits pass.
- [ ] `bin/qa_check.sh` is green after extra-quality evidence passes.
- [ ] Commit title/body follow the roadmap004 rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 4 criteria/evidence pass, commit:

`roadmap004 - epic 4 - add qualified pure Rust MP3 support`

The body must name the pinned backend/version, summarize format/settings behavior,
independent quality/interoperability evidence, robustness/target/lifecycle results, and QA.

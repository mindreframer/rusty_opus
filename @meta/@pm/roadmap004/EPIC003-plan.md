# EPIC003 Plan: WAV Decode, Encode, and Re-encode

## Progress

- [x] Phase 3.1: Implement checked in-memory RIFF/WAVE parsing, legal chunk traversal/padding, and deferred-format rejection.
- [x] Phase 3.2: Decode supported 8/16/24/32-bit integer and f32 mono/stereo WAV to `%RustyOpus.PCM{}`.
- [x] Phase 3.3: Encode PCM to finalized deterministic `:s16`, `:s24`, `:s32`, and `:f32` WAV binaries.
- [x] Phase 3.4: Add `RustyOpus.WAV.decode/1`, `encode/2`, and `reencode/2` with stable validation/errors/transforms.
- [x] Phase 3.5: Add unit/integration coverage for formats, transforms, chunks, empty/truncated/overflow input, and options.
- [x] Phase 3.6: Pass independent WAV conformance, quantization, fuzz, memory, scheduler, determinism, and lifecycle checks.
- [x] Phase 3.7: Run complete WAV suites and `bin/qa_check.sh`, verify Epic 3, and prepare the focused commit.

## Implementation Steps

1. Wire the pinned WAV dependency or the least required glue over an in-memory cursor;
   validate RIFF/WAVE signatures, `fmt `/`data`, extensible supported subtypes, chunk
   bounds/order/padding, and checked arithmetic before allocation.
2. Convert accepted unsigned/signed integer and float samples into validated f32le PCM;
   report actual rate/channels and cover empty/ancillary/reordered legal chunks.
3. Convert validated PCM to requested integer/float samples; implement documented
   saturation/rounding; write/finalize a minimal canonical WAV in an in-memory seekable
   buffer; verify exact header/data/pad sizes.
4. Add the Elixir module and native stubs/settings maps; require `:sample_format`, allow
   only shared rate/channel transforms, reject unknown options, and map errors consistently.
5. Add parsing/conversion unit tests, committed-fixture integration tests, all output
   format re-read tests, transform combinations, empty input, and targeted malformed cases.
6. Run independent readers/fixtures, exact/quantized signal checks, bounded chunk fuzz in
   child BEAMs, deterministic output hashes, memory/scheduler measurements, and counter
   baselines; fix every failure and record evidence.
7. Run all WAV and regression checks through `bin/qa_check.sh`, audit forbidden paths and
   scope, review the diff, and prepare the Epic 3 commit.

## Test Isolation Checklist

- [x] Tests use binary fixtures or unique temporary directories only for developer tooling.
- [x] Runtime/QA tests never call ffmpeg, a system reader, or a filesystem codec path.
- [x] Each fuzz case is bounded and unrecoverable cases stay in disposable child BEAMs.
- [x] Exact and quantized comparisons use the matching sample-depth tolerance.
- [x] Scheduler checks use barriers/heartbeats rather than arbitrary sleeps.
- [x] Repeated calls compare counters to a captured baseline.
- [x] Independent reference outputs have manifest hashes/provenance.

## Extra Quality Evidence

- Independent-reader/header/chunk acceptance matrix for all output sample formats.
- Exact f32 output hashes and s16/s24/s32 max/RMS quantization-error table.
- Transform duration/rate/channel results and canonical output determinism hashes.
- Odd/unknown/extensible chunk and corrupt-layout fuzz report.
- Peak memory, scheduler heartbeat, and repeated-call counter baseline results.

## Quality Gate

- [x] Supported WAV inputs decode with correct metadata and sample behavior.
- [x] All four output sample formats are canonical and independently consumable.
- [x] Exact/quantized thresholds and rate/channel/duration invariants pass.
- [x] Unsupported/malformed/oversized variants return stable errors without panic.
- [x] No metadata-preservation, path, streaming, extra-codec, or unrelated DSP scope leaked in.
- [x] `bin/qa_check.sh` is green after extra-quality evidence passes.
- [x] Commit title/body follow the roadmap004 rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 3 criteria/evidence pass, commit:

`roadmap004 - epic 3 - add in-memory WAV decode encode and reencode`

The body must summarize supported WAV forms, transform/error behavior, independent
conformance and quantization evidence, memory/scheduler/lifecycle results, and QA.

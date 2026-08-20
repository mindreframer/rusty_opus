# EPIC002 Spec: PCM Descriptor and Deterministic Audio Transform Core

## Purpose

Add the single metadata-carrying PCM representation used by file formats and implement
only the deterministic channel/rate transforms required for cross-format conversion.
Preserve the existing f32le binary contract and avoid growing a public DSP framework.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epic 1: frozen API/option contract, exact dependency pins, target matrix, and fixtures
- Existing `RustyOpus.PCM` binary helpers and `RustyOpus.TestHelpers` lossy comparison
- Existing raw Opus encode/decode APIs that continue accepting/returning bare PCM binaries
- Selected fixed-ratio offline resampler and native-safety rules

## Scope

In scope:

- `%RustyOpus.PCM{data: binary, sample_rate: pos_integer, channels: 1 | 2}` with
  enforced construction/validation and a public type
- retention of existing `sample_count/1`, `from_samples/1`, `to_samples/1`,
  `interleave/2`, and `deinterleave/1` behavior for bare binaries
- centralized f32le byte alignment, frame/sample count, finite-value, channel, rate,
  checked-arithmetic, and allocation-bound validation for the new file pipeline
- deterministic mono-to-stereo duplication and stereo-to-mono `(left + right) / 2`
  conversion, with explicit clipping/finite behavior
- fixed-ratio offline sample-rate conversion, including input/output frame accounting,
  tail flush, delay compensation where required, and bounded output estimation
- one internal transform operation that applies requested `:channels` and `:sample_rate`
  without exposing the selected resampler or tuning knobs publicly
- unit, integration, lifecycle/counter, scheduler, signal-integrity, and conformance tests

Out of scope:

- file format detection or MP3/WAV/Ogg encode/decode
- arbitrary channel matrices, surround layouts, more than two channels, or panning
- normalization, gain, dither, filters, time stretch, pitch shift, trim, or effects
- real-time clock-drift resampling or adjustable resampler quality in the public API
- changing the bare-binary contract of existing raw Opus functions

## PCM Contract

```elixir
@enforce_keys [:data, :sample_rate, :channels]
defstruct [:data, :sample_rate, :channels]
```

- `data` is f32le interleaved PCM and its byte size is divisible by
  `4 * channels`.
- `sample_rate` is the actual logical rate and must pass a documented positive upper bound.
- `channels` is exactly `1` or `2`.
- Samples passed into native transforms are finite; NaN/infinity returns a stable
  `:invalid_pcm` error rather than leaking undefined codec behavior.
- Empty PCM may be represented and transformed deterministically; individual encoders
  decide whether empty audio is a valid file input.
- The struct is additive. Existing helpers continue to accept and return binaries unless
  a new explicitly named struct helper is used.

## Transform Contract

- No requested rate/channel change returns the same validated PCM data without lossy work.
- Mono-to-stereo duplicates each sample to left/right.
- Stereo-to-mono averages left/right with deterministic f32 behavior.
- Channel conversion order relative to resampling is fixed and documented; tests prove
  the chosen order does not change duration or channel semantics.
- Resampling uses a fixed rational ratio for offline files, flushes the tail, and reports
  a frame count within the documented rounding bound of
  `input_frames * output_rate / input_rate`.
- Output allocation is computed with checked integer arithmetic and a documented maximum.
- Longer transforms run on a dirty scheduler and never block normal BEAM schedulers.

## Acceptance Criteria

- `%RustyOpus.PCM{}` represents every supported file decoder result without another
  sample contract.
- Invalid data/rate/channel/size/finite-value inputs return stable tagged errors.
- Existing raw packet/PCM functions and helpers remain source- and behavior-compatible.
- Mono/stereo conversion is sample-correct and deterministic.
- Required rate pairs, especially 44.1↔48 kHz and speech-rate↔48 kHz, preserve duration
  and signal quality within frozen thresholds.
- Tail samples are not dropped, intermediate/output memory is bounded, and repeated calls
  return counters to baseline.
- No unrelated DSP or public resampler abstraction is introduced.

## Test Strategy

- Struct/validation unit tests cover alignment, frame counts, empty input, invalid rate/
  channels, non-finite samples, overflows, and bounded maximums.
- Exact channel tests cover mono duplication, stereo identity, balanced/canceling stereo,
  clipping edges, and channel separation.
- Resampler tests cover identity, upsample, downsample, non-integer ratios, short/tail
  input, mono/stereo, and deterministic repeated output.
- Signal fixtures cover impulse, silence, DC, sine sweeps, speech, and stereo-separated tones.
- Lifecycle and scheduler tests use counters/barriers and bounded heartbeats, never sleeps.
- Existing raw Opus regression tests remain unchanged in intent and green.

## Extra Quality Gate

Phase 6 records per-rate-pair input/output frame counts, duration drift, passband/alias
measurements, impulse/tail behavior, stereo crosstalk, deterministic output hashes, peak
intermediate memory, dirty-scheduler responsiveness, and repeated-call counter baselines.
Every frozen threshold from Epic 1 must pass.

## Quality Bar

- The representation is small and explicit, not a generic audio graph.
- Transform results are measured with signal-aware assertions, not only byte sizes.
- Checked sizes and finite samples prevent hostile PCM from reaching unsafe backend paths.
- No panic crosses the NIF boundary and no normal scheduler is blocked.
- `bin/qa_check.sh` passes before the epic commit.

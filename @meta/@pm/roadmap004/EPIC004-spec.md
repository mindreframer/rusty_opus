# EPIC004 Spec: MP3 Decode, Encode, and Re-encode

## Purpose

Ship a qualified pure-Rust `RustyOpus.MP3` module for in-memory MPEG Layer III audio,
with explicit numeric bitrate control, stable CBR/VBR semantics, shared PCM transforms,
and evidence that output is interoperable and meets the fidelity floors frozen in Epic 1.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epic 1: selected exact MP3 dependency/features, frozen quality thresholds, corpus,
  provenance, and no-FFI boundary
- Epic 2: `%RustyOpus.PCM{}`, validation, rate/channel transforms, and signal helpers
- Committed MPEG-1/2/2.5, mono/stereo, CBR/VBR, leading-ID3, corrupt, and reference PCM fixtures
- Existing `RustyOpus.Error`, native panic containment, dirty scheduling, and counters

## Scope

In scope:

- whole-binary MPEG-1/2/2.5 Audio Layer III frame synchronization and decode
- safe skipping of supported leading ID3v2 data and bounded garbage/resynchronization
  behavior defined by the qualified backend
- mono/stereo decode to `%RustyOpus.PCM{}` with actual sample rate and channel count
- mono/stereo encode from validated PCM using required `:bitrate` in bits per second and
  `:bitrate_mode` `:vbr | :cbr` (default `:vbr`)
- strict CBR bitrate/rate/version validation without silent snapping; VBR target behavior
  documented from measured aggregate output
- correct encoder flush, final frame padding, reservoir drain, and Xing/Info or equivalent
  duration/gapless metadata supported by the selected backend
- `RustyOpus.MP3.decode/1`, `encode/2`, and `reencode/2`; optional dedicated VBR-quality
  setting only if Epic 1 approved its reliability and semantics
- rate/channel transforms through Epic 2, with no metadata copy on newly encoded output
- stable tagged errors, checked allocations, dirty scheduling, panic containment, bounded
  corrupt-input fuzzing, lifecycle/counter, scheduler, quality, and conformance tests

Out of scope:

- MPEG Layer I/II, AAC, MP4, arbitrary MPEG systems streams, or embedded album artwork
- ID3/APE metadata editing or preservation
- arbitrary stereo-mode forcing unless specifically approved by Epic 1 qualification
- LAME, libmp3lame, ffmpeg, C/FFI, system codecs, subprocesses, Ports, or temporary files
- real-time streaming/resource APIs; the public surface is one-shot blob/PCM operations
- universal cross-codec quality presets

## Public Contract

```elixir
@spec decode(binary()) ::
        {:ok, RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}

@spec encode(RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}

@spec reencode(binary(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}
```

- `encode/2` and `reencode/2` require a positive integer `:bitrate` expressed in bits/s.
- `:bitrate_mode` is `:vbr` or `:cbr` and defaults to `:vbr`.
- `:sample_rate` and `:channels` use the shared transform core; unsupported target MP3
  rates/channels return errors.
- A dedicated `:vbr_quality` may be added only when the Epic 1 report froze its range,
  bitrate interpretation, conflict rules, and quality evidence. It is never common API.
- Unknown/conflicting options, including simultaneous bitrate/quality controls when
  disallowed, return `:invalid_settings`.
- `reencode/2` outputs audio only; input metadata is not preserved.

## Codec Contract

- Decode rejects non-Layer-III streams and reports the first accepted stream's actual
  rate/channels; unsupported midstream configuration changes fail deterministically.
- CBR accepts only the documented standard bitrate table for the MPEG version selected by
  output sample rate. The wrapper validates before calling a backend that might snap.
- VBR uses numeric bitrate as a documented aggregate target with a measured tolerance;
  individual frames use legal Layer III bitrates.
- Output contains complete parseable frames and any required first-frame metadata; no
  partial reservoir/back-pointer state escapes.
- Decode and encode account for documented delay/padding so output duration remains inside
  the frozen tolerance and repeated re-encode does not grow unbounded silence.
- Lower target bitrate yields no larger aggregate corpus size than a higher target within
  the frozen VBR/container-overhead rules, while every point retains its fidelity floor.

## Acceptance Criteria

- Every qualified fixture decodes with correct MPEG version/rate/channels, bounded duration,
  and reference-aligned PCM quality.
- CBR and VBR outputs are accepted by an independent decoder/reference validation path.
- Required bitrate ladder points meet aggregate bitrate tolerance, size ordering, and the
  per-content-class objective fidelity thresholds frozen in Epic 1.
- Mono/stereo and supported rate/channel transforms work without hidden snapping.
- Delay, tail padding, reservoir, leading-ID3, truncation, corruption, and unsupported
  layer/rate/bitrate cases behave as documented.
- Hostile input cannot panic, allocate without bound, block normal schedulers, or leak counters.
- Dependency/source audits prove pure-Rust in-process operation on every supported target.

## Test Strategy

- Unit tests cover option/rate/bitrate tables, ID3 bounds, error mapping, drain semantics,
  size arithmetic, and backend adapter behavior.
- Decoder integration tests use independently encoded MPEG version/channel/mode fixtures
  and delay-aligned reference PCM.
- Encoder tests parse every emitted frame, verify legal headers/reservoir relationships,
  decode via the qualified independent path/artifacts, and compare signal/duration.
- Re-encode tests cover CBR/VBR ladders, transform combinations, metadata removal, and
  repeated re-encode tail behavior.
- Corrupt/adversarial cases run bounded in disposable child BEAMs when failure may be fatal.
- Lifecycle/counter/scheduler tests use baselines and barriers/heartbeats, not sleeps.

## Extra Quality Gate

Phase 6 reruns the frozen corpus and records independent compatibility, decoded alignment,
per-class objective fidelity, target-vs-actual bitrate, size ordering, duration/delay,
frame/reservoir validation, deterministic hashes, malformed-input fuzz outcomes, target
builds, peak memory, dirty-scheduler heartbeat, and repeated-call counter baselines. The
thresholds may not be weakened to make the selected backend pass.

## Quality Bar

- Numeric bitrate is primary and always expressed in bits/s at the Elixir boundary.
- Independent compatibility and content-diverse quality evidence are mandatory.
- Known backend limitations are documented and bounded, not hidden behind a preset.
- No runtime/test-under-test external codec or self-round-trip-only proof is accepted.
- `bin/qa_check.sh` passes before the epic commit.

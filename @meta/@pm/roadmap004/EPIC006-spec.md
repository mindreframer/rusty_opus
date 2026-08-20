# EPIC006 Spec: Common `convert/2` Facade and Cross-Format Matrix

## Purpose

Add one small common conversion API that detects only the three supported file formats,
owns their true shared options, and composes already-proven dedicated modules through the
shared PCM representation. Keep specialized controls and implementation details out of
the facade.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epic 1: frozen `convert/2` option/result/error contract and detection fixtures
- Epic 2: `%RustyOpus.PCM{}` and internal rate/channel transforms
- Epics 3–5: `RustyOpus.WAV`, `RustyOpus.MP3`, and `RustyOpus.OggOpus`
- Existing raw Opus APIs that must remain distinct and compatible

## Scope

In scope:

- `RustyOpus.convert(binary | PCM.t(), opts)` with required `:to`
- byte-based detection of RIFF/WAVE, Ogg Opus family 0, and MP3 with/without bounded
  leading ID3; detection validates enough structure to avoid accepting a single magic collision
- optional `:from` defaulting to `:auto` for binary input, with exact format-mismatch errors
- common options: `:bitrate`, `:bitrate_mode`, `:sample_rate`, `:channels`, and
  `:sample_format`, validated for applicability to the selected target
- PCM input and `to: :pcm` output without accepting ambiguous bare raw-PCM binaries
- all nine file-to-file source/target pairs plus file↔PCM endpoints
- same-format file conversion routed through the corresponding dedicated `reencode/2`
- one decode, at most one composed rate/channel transform, and one encode per conversion
- stable stage-aware errors using `RustyOpus.Error`, checked allocation/intermediate limits,
  panic containment, dirty scheduling, counters, concurrency, and scheduler responsiveness
- documented common examples and an exhaustive deterministic conversion matrix

Out of scope:

- extension/MIME/path-based detection or arbitrary media probing
- adding other formats, metadata preservation, file paths, streaming, callbacks, progress,
  cancellation APIs, or generalized conversion graphs
- accepting codec-specific options such as Opus application/complexity/frame duration or
  MP3 VBR quality through `convert/2`
- universal quality presets or backend selection
- changing raw `RustyOpus.encode/decode/transcode` meanings

## Public Contract

```elixir
@spec convert(binary() | RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary() | RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}
```

Target rules:

- `to: :ogg_opus` — require `:bitrate`; allow `:bitrate_mode`, `:channels`; reject
  `:sample_format`; output uses the documented 48 kHz Ogg Opus clock.
- `to: :mp3` — require `:bitrate`; allow `:bitrate_mode`, supported `:sample_rate`, and
  `:channels`; reject `:sample_format`.
- `to: :wav` — require `:sample_format`; allow `:sample_rate` and `:channels`; reject
  bitrate options.
- `to: :pcm` — allow `:sample_rate` and `:channels`; reject bitrate/sample-format options;
  return `%RustyOpus.PCM{}`.

Input rules:

- binary plus omitted/`:auto` `:from` uses content detection
- binary plus explicit `:from` must pass that dedicated format's validation; a mismatch
  returns `:format_mismatch`, not a later unrelated decoder error
- `%RustyOpus.PCM{}` rejects `:from`, is validated by Epic 2, and never enters detection
- bare f32le binary is never inferred as PCM

All unknown, duplicate/conflicting, and target-inapplicable options fail before native
codec work. The facade may translate shared mode/rate/channel options into dedicated
settings but may not expose their complete option union.

## Detection Contract

- WAV requires `RIFF`, a bounded declared size policy, and `WAVE` plus a parseable
  supported `fmt ` path; the four-byte `RIFF` prefix alone is insufficient.
- Ogg Opus requires valid initial Ogg page structure and an `OpusHead` identification
  packet for a supported family; generic Ogg is not accepted.
- MP3 with ID3 validates synchsafe tag size before searching; tagless MP3 requires a
  bounded sequence of mutually consistent valid Layer III frames, not one sync word.
- Detection order and error precedence are fixed, deterministic, and tested on prefix
  collisions, truncation, garbage, and polyglot-like adversarial fixtures.

## Pipeline and Error Contract

- Detection/explicit validation → dedicated decode → shared transform → dedicated encode.
- No format module calls another; the facade is the only cross-format composer.
- If source and target are the same file format, the facade delegates to that module's
  `reencode/2` while preserving the same common transform semantics.
- Stable reason atoms distinguish invalid settings, unsupported format, format mismatch,
  decode failure, transform failure, encode failure, allocation bound, and contained panic.
- Error messages identify the failed stage/format without exposing unstable Rust strings
  as reason atoms.
- Input, PCM intermediate, resampler output, and encoded output sizes use checked limits;
  all long work remains dirty-scheduled.

## Acceptance Criteria

- All documented examples succeed with one call and expected result type/format.
- Detection correctly identifies every supported fixture and rejects unsupported/generic/
  ambiguous/truncated inputs deterministically.
- Every 3×3 file pair and PCM endpoint obeys output format, rate, channels, duration,
  bitrate/sample-format, fidelity, and size constraints.
- Option ownership/applicability is exact; no dedicated-only control leaks into the facade.
- Cross-format operations use one PCM intermediate and no external process/file/temp path.
- Concurrent/hostile/bounded-large conversions cannot panic, leak, or block normal schedulers.
- Existing raw and dedicated APIs remain behavior-compatible.

## Test Strategy

- Detection unit tests cover signatures, structured validation, ID3 bounds, consistent
  MP3 frames, generic Ogg, prefix collisions, explicit mismatch, and corrupt/truncated input.
- Option-table unit tests cover every target, missing required keys, inapplicable keys,
  unknown keys, conflicts, PCM/from rules, and validation-before-native-work.
- Matrix integration tests exercise all nine file pairs at representative mono/stereo
  rates, plus each file→PCM and PCM→file path.
- Result validation uses independent format parsers/reference fixtures and delay-aware
  signal/duration assertions rather than only successful self-decode.
- Lifecycle/concurrency/scheduler tests use unique inputs, captured counters, barriers,
  and heartbeats; fatal fuzz stays in disposable child BEAMs.
- Source tracing/audits prove no process, Port, ffmpeg, temp file, or path API is used.

## Extra Quality Gate

Phase 6 records a complete source×target matrix with detected/explicit format, output
signature/conformance, rate/channels/frames/duration, target-vs-actual bitrate or WAV sample
format, size/fidelity tolerance, stable error cases, deterministic behavior, peak memory,
concurrent isolation, scheduler heartbeat, counter baselines, and forbidden-activity audit.

## Quality Bar

- One keyword-list facade is sufficient; no public graph/protocol/config struct appears.
- Detection is structural and conservative rather than extension- or prefix-based.
- Invalid options fail early and explain the target contract.
- Dedicated modules remain the only advanced surface.
- `bin/qa_check.sh` passes before the epic commit.

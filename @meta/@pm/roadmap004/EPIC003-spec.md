# EPIC003 Spec: WAV Decode, Encode, and Re-encode

## Purpose

Ship a focused `RustyOpus.WAV` module for in-memory uncompressed RIFF/WAVE audio,
normalizing supported input to the shared PCM descriptor and emitting explicit integer
or float output without introducing file-path APIs or a general container layer.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epic 1: selected/pinned WAV dependency, fixture manifest, native boundary, and audits
- Epic 2: `%RustyOpus.PCM{}`, transform composition, validation, and signal helpers
- Microsoft RIFF/WAVE PCM, IEEE-float, chunk padding, and extensible-subformat rules
- Committed independent WAV/reference PCM fixtures

## Scope

In scope:

- in-memory RIFF/WAVE parsing with checked RIFF/chunk sizes and correct odd-byte padding
- classic PCM and IEEE-float format tags; WAVE_FORMAT_EXTENSIBLE only when its subformat
  resolves to supported PCM/float and its channel count is mono/stereo
- decoding unsigned 8-bit and signed 16/24/32-bit integer PCM plus 32-bit IEEE float
  to f32le `%RustyOpus.PCM{}`
- safe skipping of well-formed unknown/ancillary chunks before or after `fmt `/`data`
- encoding `%RustyOpus.PCM{}` to `:s16`, `:s24`, `:s32`, or `:f32` RIFF/WAVE in memory
- explicit saturating quantization and rounding for integer output; no dither
- valid empty WAV output/input, complete header finalization, exact chunk/file lengths,
  padding, and stable deterministic bytes
- `RustyOpus.WAV.decode/1`, `encode/2`, and `reencode/2`, with optional rate/channel
  transforms and required output `:sample_format`
- stable errors, dirty scheduling, checked allocations, panic containment, conformance,
  lifecycle/counter, fuzz, and scheduler tests

Out of scope:

- RF64/WAVE64, RIFX/big-endian, ADPCM, A-law, mu-law, MP3-in-WAV, or arbitrary codecs
- more than two channels or surround speaker-mask conversion
- preservation of LIST/INFO, cue, broadcast, XML, artwork, or other ancillary metadata
- dithering/noise shaping, normalization, or other DSP
- file paths, append/edit-in-place, streaming output, or temporary files

## Public Contract

```elixir
@spec decode(binary()) ::
        {:ok, RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}

@spec encode(RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}

@spec reencode(binary(), keyword()) ::
        {:ok, binary()} | {:error, RustyOpus.Error.t()}
```

- `encode/2` and `reencode/2` require `:sample_format` in
  `[:s16, :s24, :s32, :f32]`.
- `:sample_rate` and `:channels` use Epic 2 transforms; other options are rejected.
- `decode/1` returns the rate/channels declared by the accepted audio stream.
- Metadata/unknown chunks are not copied by `reencode/2`; output is a minimal canonical WAV.
- Results use the shared `RustyOpus.Error` taxonomy with WAV-specific context in messages,
  not a second error struct.

## Quantization and Container Contract

- Float input outside `[-1.0, 1.0]` saturates for integer WAV output according to one
  documented mapping; non-finite PCM was already rejected by Epic 2 validation.
- Integer decode scales each supported bit depth consistently into the f32 domain;
  re-encoding at the same depth remains within one least-significant step.
- `:f32` encode/decode preserves the validated f32 bit patterns exactly.
- RIFF size, `fmt ` size/content, `data` size, block alignment, byte rate, channel count,
  sample rate, sample format, and pad bytes are internally consistent.
- Declared chunk sizes are checked against remaining input and maximum allocations before
  reads/copies. Duplicate/contradictory required chunks return a stable error.

## Acceptance Criteria

- All required PCM/float fixtures decode in memory with correct rate, channels, frames,
  and sample values/tolerances.
- Encoded files are accepted by independent reference readers and their headers/chunks
  match the emitted samples exactly.
- `:f32` round-trips exactly; integer output meets per-depth quantization bounds.
- Re-encode applies requested rate/channel/sample-format changes and drops metadata as documented.
- Odd padding, unknown chunks, empty audio, reordered legal chunks, and extensible supported
  subtypes behave deterministically.
- Compressed, multichannel, big-endian, RF64, truncated, overflowing, or malformed input
  returns stable errors without panic, excessive allocation, or scheduler blockage.

## Test Strategy

- Unit tests cover header/tag/subformat parsing, chunk iteration, padding, arithmetic,
  sample conversions, quantization edges, and error mapping.
- Integration tests decode every committed WAV fixture and encode/re-read every output format.
- Re-encode tests cover sample-format-only, rate-only, channel-only, and combined transforms.
- Independent fixture/readers validate output rather than relying solely on self-round-trip.
- Targeted corrupt fixtures and bounded generated chunk layouts run in disposable child BEAMs.
- Lifecycle/counter and scheduler tests compare to captured baselines with barriers/heartbeats.

## Extra Quality Gate

Phase 6 records independent header/chunk interoperability, exact f32 hashes, per-depth
maximum/RMS quantization error, rate/channel/duration results, odd/unknown/extensible chunk
coverage, corrupt-layout fuzz outcomes, peak memory, scheduler heartbeat, determinism, and
repeated-call counter baselines.

## Quality Bar

- The WAV surface is three direct functions and one settings list.
- Output is canonical, minimal, deterministic, and standards-conformant.
- Unsupported codecs/container variants fail explicitly rather than being guessed.
- Runtime/tests use no paths, process spawn, system codec, or ffmpeg.
- `bin/qa_check.sh` passes before the epic commit.

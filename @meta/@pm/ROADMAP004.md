# ROADMAP004 — Cohesive Ogg Opus, MP3, and WAV Blob Conversion

**Status:** In progress

- **Scope:** Add pure-Rust, in-process MP3 and WAV handling; organize Ogg Opus file
  operations in a dedicated module; and add one small common conversion API.
- **Target release:** `0.4.0`
- **Primary interface:** Elixir binaries and `%RustyOpus.PCM{}`
- **Native implementation:** Rust via Rustler; no Port, executable, ffmpeg, or spawned
  process in runtime or test code under test
- **Formats:** Ogg Opus family 0, MPEG Layer III (MP3), and uncompressed PCM/IEEE-float WAV

## 1. Goal

Turn RustyOpus into a focused in-process audio-blob converter without turning it into a
general media framework. A caller should be able to reduce the storage size of an Ogg
Opus or MP3 blob, convert WAV/MP3/Ogg Opus between the supported formats, or decode a
file-like blob to the existing `f32le` PCM contract with one predictable API.

The common path is deliberately small:

```elixir
{:ok, opus} =
  RustyOpus.convert(mp3_blob,
    to: :ogg_opus,
    bitrate: 20_000
  )

{:ok, mp3} =
  RustyOpus.convert(wav_blob,
    to: :mp3,
    bitrate: 64_000,
    bitrate_mode: :vbr,
    channels: 1
  )

{:ok, wav} =
  RustyOpus.convert(opus_blob,
    to: :wav,
    sample_format: :s16,
    sample_rate: 16_000
  )

{:ok, %RustyOpus.PCM{} = pcm} = RustyOpus.convert(mp3_blob, to: :pcm)
```

Callers needing format-specific controls use `RustyOpus.OggOpus`, `RustyOpus.MP3`, or
`RustyOpus.WAV`. Existing raw Opus packet APIs remain unchanged.

## 2. Public Contract

### Common conversion

```elixir
@spec convert(binary() | RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary() | RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}
```

The common options are:

- `:to` — required; `:ogg_opus`, `:mp3`, `:wav`, or `:pcm`
- `:from` — optional for binary input; defaults to `:auto`, or may explicitly be
  `:ogg_opus`, `:mp3`, or `:wav`
- `:bitrate` — bits per second; required for MP3 and Ogg Opus output
- `:bitrate_mode` — `:vbr` or `:cbr`; defaults to `:vbr`
- `:sample_rate` — optional output sample rate; otherwise preserve when legal, with
  the documented Ogg Opus 48 kHz PCM clock behavior
- `:channels` — optional target `1` or `2`; otherwise preserve the source channel count
- `:sample_format` — required for WAV output; `:s16`, `:s24`, `:s32`, or `:f32`

Unknown, conflicting, or target-inapplicable options return a stable tagged error. The
common API does not accept codec-specific controls such as Opus application/complexity or
MP3 VBR quality indexes.

### Dedicated format modules

Each format module exposes the same three verbs:

```elixir
RustyOpus.OggOpus.decode(blob)
RustyOpus.OggOpus.encode(pcm, opts)
RustyOpus.OggOpus.reencode(blob, opts)

RustyOpus.MP3.decode(blob)
RustyOpus.MP3.encode(pcm, opts)
RustyOpus.MP3.reencode(blob, opts)

RustyOpus.WAV.decode(blob)
RustyOpus.WAV.encode(pcm, opts)
RustyOpus.WAV.reencode(blob, opts)
```

All return `{:ok, value}` or `{:error, %RustyOpus.Error{}}`. Decoders return
`%RustyOpus.PCM{}`. Encoders and re-encoders return a binary in their module's format.

`RustyOpus.reencode/2` remains backward-compatible and delegates only to
`RustyOpus.OggOpus.reencode/2`; it does not gain format auto-detection. Existing
`RustyOpus.encode/4`, `decode/4`, `transcode/5`, `Encoder`, and `Decoder` continue to mean
raw Opus packets and PCM, never file containers.

### PCM descriptor

The existing PCM helper module gains a minimal metadata-carrying struct without changing
the stable sample representation:

```elixir
%RustyOpus.PCM{
  data: <<...>>,
  sample_rate: 44_100,
  channels: 2
}
```

`data` is always little-endian IEEE-754 `f32`, interleaved by channel. File sample formats
such as WAV `:s16` are converted at the native boundary; they never create a second PCM
contract inside Elixir.

## 3. In Scope

- In-memory binary input and output; no temporary file is required for codec work.
- Content-based detection of Ogg Opus, MP3 (including leading ID3), and RIFF/WAVE, with
  an explicit `:from` override.
- Ogg Opus family 0 mono/stereo decode, encode, and re-encode.
- MP3 MPEG-1/2/2.5 Layer III mono/stereo decode, encode, and re-encode, including CBR and
  VBR modes supported by the selected pure-Rust implementation.
- WAV RIFF/WAVE decode, encode, and re-encode for integer PCM up to 32-bit and IEEE `f32`.
- Mono/stereo channel preservation or explicit conversion to `1` or `2` channels.
- Fixed-ratio offline sample-rate conversion required by cross-format conversion.
- Stable tagged errors, panic containment, checked allocation arithmetic, dirty scheduling,
  resource/counter baselines, and scheduler-responsiveness tests.
- Auditable exact dependency pins, licenses, provenance, supported-target checks, and
  precompiled-NIF verification.
- Committed deterministic reference fixtures. ffmpeg may appear only in developer-side
  fixture-import/conformance tooling and never in runtime or the tests under test.

## 4. Explicitly Out of Scope

- WebM, MP4/M4A, AAC, FLAC, Vorbis, AIFF, RF64, ADPCM WAV, or arbitrary media probing.
- More than two channels, Ogg Opus mapping families other than family 0, or surround
  channel-layout policy.
- File-path overloading, directory conversion, streaming file I/O, Enumerable protocols,
  real-time device audio, RTP, or network transport.
- Metadata editing or preservation: ID3 tags, Ogg comments/artwork, and non-audio WAV
  chunks may be read/skipped as necessary but are not copied to new output.
- Normalization, loudness targeting, trimming, silence detection, filters, effects, or
  other DSP beyond required resampling and mono/stereo conversion.
- A public codec behaviour, plugin system, backend selection, or generalized media graph.
- A universal `quality: :low | :medium | :high` abstraction across formats. Numeric
  bitrate remains the shared lossy-codec control.
- A C/FFI or system-library MP3 fallback. If no pure-Rust candidate passes the Epic 1
  conformance and quality gate, the roadmap stops for an explicit scope decision.

## 5. Architecture and Compatibility Principles

1. **One internal PCM:** every file decoder normalizes to `%RustyOpus.PCM{}` carrying
   `f32le` interleaved samples, rate, and channel count.
2. **Decode, transform, encode:** common conversion is a direct pipeline over the shared
   PCM representation; formats do not call one another or shell out.
3. **Thin facade:** `RustyOpus.convert/2` validates the shared options and dispatches to
   dedicated modules. It does not expose the union of every codec setting.
4. **Dedicated depth:** codec-specific settings live only in their format module and are
   translated into a small native settings map.
5. **Honest container naming:** `:ogg_opus` and `RustyOpus.OggOpus` mean an Ogg Opus
   file-like blob; raw `:opus` packets retain the existing packet APIs.
6. **Additive compatibility:** no existing public function changes arity, input type,
   output type, defaults, or error meaning in this roadmap.
7. **No hidden rounding:** unsupported MP3 CBR bitrates, sample rates, sample formats,
   and channel counts error instead of silently snapping to a nearby value.
8. **Bounded in-process work:** checked sizes, bounded intermediate buffers, dirty
   scheduling, and panic containment apply to every whole-blob path.
9. **Dependency restraint:** select the least dependency set that passes conformance,
   quality, license, security, toolchain, and precompiled-target gates.

## 6. Cross-Format Invariants

- Auto-detection is based on bytes, not filenames or extensions, and never treats an
  arbitrary raw PCM binary as a file format.
- Explicit `:from` must agree with the input; a mismatch returns a tagged format error.
- Decode reports the actual sample rate and channel count in `%RustyOpus.PCM{}`.
- Encode/re-encode preserve duration within a documented codec-delay/resampler tolerance.
- Channel conversion is deterministic and uses one documented stereo-to-mono policy.
- Fixed-rate resampling neither drops the tail nor invents an unbounded duration drift.
- Lower target bitrate produces no larger aggregate output than a higher target bitrate
  on the committed speech/music conformance fixtures, subject to documented container
  overhead and VBR tolerance.
- WAV `:f32` round-trips the PCM contract exactly; integer WAV formats compare within
  their quantization tolerance. Lossy formats compare within codec-specific tolerances.
- Empty, truncated, corrupt, adversarial, or oversized input returns a stable tagged
  error and never crashes or wedges the BEAM.
- Every runtime and test-under-test path remains free of process spawn, Port, ffmpeg,
  temporary codec files, and system codec libraries.

## 7. Quality Policy and Epic Gate

Every epic has exactly seven phases. Phase 6 is an **extra quality phase** specific to
the epic's risk; it must produce recorded evidence rather than merely rerun the ordinary
test suite. Phase 7 is the normal epic close.

An epic is complete only when:

1. Its implementation, unit, integration, lifecycle, and conformance tests pass.
2. Public documentation and acceptance criteria match the actual behavior.
3. The Phase 6 extra-quality evidence passes with no waived failure.
4. `bin/qa_check.sh` passes after the extra-quality work.
5. The diff contains no unrelated edits, build caches, secrets, absolute paths, or
   unreviewed generated artifacts.
6. All seven phases are checked only in the future epic plan after the work is verified.
7. One focused green commit is created as `roadmap004 - epic N - <outcome>`, with a body
   stating the result, extra-quality evidence, and QA verification.

Epics and phases execute in dependency order. Each epic has its own spec and seven-phase
checkbox plan in `@meta/@pm/roadmap004/`; those files govern implementation details.

---

## Epic 1 — Public Contract, Dependency Qualification, and Fixture Foundation

**Objective:** Freeze the additive Elixir contract, qualify the native building blocks,
and establish independent fixtures and QA checks before new codec behavior enters the NIF.

### Phases

1. **Freeze the public API:** specify `convert/2`, `%RustyOpus.PCM{}`, the three format
   modules, common/dedicated option ownership, result types, and compatibility rules.
2. **Revise the native boundary:** add ADR and project-instruction updates that permit
   only MP3 and WAV beside Ogg Opus while retaining the no-process/no-system-codec rules.
3. **Qualify MP3 candidates:** test pure-Rust MP3 candidates for decode/encode coverage,
   CBR/VBR correctness, objective quality, error behavior, license, and maintenance risk;
   pin one only if every mandatory threshold passes.
4. **Qualify WAV and resampling dependencies:** select and exactly pin the smallest WAV
   and fixed-rate resampling stack that works on in-memory readers/writers and all targets.
5. **Build the fixture foundation:** commit compact WAV, MP3, Ogg Opus, and reference PCM
   fixtures covering mono/stereo, rates, sample formats, CBR/VBR, leading ID3, and corruption.
6. **Extra quality — independent qualification:** record a dependency/target/license
   matrix, external-reference interoperability results, objective MP3 quality measurements,
   and fixture provenance; a failed MP3 threshold blocks the roadmap rather than being waived.
7. **Pass the epic gate:** extend QA with dependency/provenance/fixture audits, run
   `bin/qa_check.sh`, verify scope and acceptance criteria, and commit the green foundation.

### Acceptance Criteria

- The API and compatibility contract is unambiguous before implementation.
- Exact candidate versions and licenses are auditable and build on the supported matrix.
- MP3 encode/decode quality and interoperability meet documented minimum thresholds.
- Fixtures are deterministic, compact, provenance-recorded, and tests need no ffmpeg.
- The roadmap introduces no codec implementation before the qualification gate passes.

---

## Epic 2 — PCM Descriptor and Deterministic Audio Transform Core

**Objective:** Add the one shared PCM descriptor plus the resampling and mono/stereo
conversion needed by every cross-format path, without creating a general DSP framework.

### Phases

1. **Add `%RustyOpus.PCM{}`:** introduce validated `data`, `sample_rate`, and `channels`
   fields while keeping existing binary PCM helpers and call sites compatible.
2. **Harden PCM validation:** centralize f32le alignment, finite-sample, frame-count,
   channel-count, checked-size, and native marshalling validation.
3. **Implement channel conversion:** preserve channels by default and add deterministic
   mono-to-stereo and documented stereo-to-mono conversion for `1`/`2` channels only.
4. **Implement fixed-rate resampling:** add an offline resampler with explicit tail flush,
   frame accounting, checked allocation bounds, and no public algorithm abstraction.
5. **Expose internal transform composition:** validate common `:sample_rate`/`:channels`
   options and compose channel conversion plus resampling in one internal operation.
6. **Extra quality — signal integrity:** verify impulse, silence, DC, sine, speech, and
   stereo-separation cases; measure duration drift, alias rejection, determinism, memory
   bounds, and repeated-call counter baselines across required rate pairs.
7. **Pass the epic gate:** run all PCM/transform unit, integration, lifecycle, scheduler,
   and conformance tests plus `bin/qa_check.sh`, then commit the green transform core.

### Acceptance Criteria

- `%RustyOpus.PCM{}` carries enough metadata for any supported file decoder.
- Existing raw packet/PCM APIs retain their current binary contract and behavior.
- Required conversions such as 44.1 kHz to 48 kHz are deterministic and bounded.
- Channel conversion and resampling preserve duration and signal within documented limits.
- No unrelated DSP or public transform framework is introduced.

---

## Epic 3 — WAV Decode, Encode, and Re-encode

**Objective:** Ship `RustyOpus.WAV` for in-memory RIFF/WAVE PCM handling over the shared
PCM descriptor, including the output sample formats relevant to storage and interchange.

### Phases

1. **Implement in-memory WAV parsing:** accept RIFF/WAVE binaries, validate headers and
   checked chunk sizes, skip supported unknown chunks safely, and reject deferred encodings.
2. **Decode WAV to PCM:** normalize 8/16/24/32-bit integer PCM and IEEE `f32` mono/stereo
   samples to `%RustyOpus.PCM{}` with correct rate/channel metadata.
3. **Encode PCM to WAV:** write valid seek-finalized in-memory RIFF/WAVE output for
   `:s16`, `:s24`, `:s32`, and `:f32`, with explicit quantization and clipping policy.
4. **Add `RustyOpus.WAV`:** expose validated `decode/1`, `encode/2`, and `reencode/2`
   with stable errors and transform options shared through the internal PCM core.
5. **Add WAV integration coverage:** test format/sample-rate/channel conversion, odd
   chunk padding, ancillary chunks, empty audio, truncation, overflow, and option errors.
6. **Extra quality — WAV conformance:** validate emitted headers/chunks with independent
   reference fixtures/readers, prove exact `:f32` round-trip and integer quantization
   bounds, fuzz chunk layouts in disposable child BEAMs, and measure memory/scheduler behavior.
7. **Pass the epic gate:** run WAV unit, integration, lifecycle, fuzz, and conformance
   suites plus `bin/qa_check.sh`, then commit the green WAV module.

### Acceptance Criteria

- Supported WAV binaries decode without a filesystem path or temporary file.
- WAV output is accepted by independent reference readers and contains correct sizes.
- `:f32` is exact and integer sample formats meet documented quantization tolerance.
- Unsupported compressed/multichannel/RF64 inputs fail with stable errors.
- Repeated and adversarial WAV work leaves the BEAM responsive and counters at baseline.

---

## Epic 4 — MP3 Decode, Encode, and Re-encode

**Objective:** Ship `RustyOpus.MP3` with qualified pure-Rust MPEG Layer III support and
numeric bitrate control suitable for storage optimization.

### Phases

1. **Implement MP3 decode:** accept in-memory MPEG-1/2/2.5 Layer III streams, skip leading
   ID3 safely, decode mono/stereo to `%RustyOpus.PCM{}`, and report actual rate/channels.
2. **Implement MP3 encode:** encode shared PCM to valid mono/stereo MP3 with required
   numeric bits-per-second bitrate and validated `:cbr`/`:vbr` behavior.
3. **Add `RustyOpus.MP3`:** expose `decode/1`, `encode/2`, and `reencode/2`, including
   dedicated VBR-quality controls only when the qualified backend supports them reliably.
4. **Compose re-encoding and transforms:** decode, optionally resample/downmix, encode,
   flush delay/padding correctly, and return one complete binary with no metadata copy.
5. **Harden MP3 errors and boundaries:** cover unsupported layers, illegal CBR rates,
   malformed frames/reservoirs, truncated tags, garbage, empty input, and allocation limits.
6. **Extra quality — MP3 fidelity and interoperability:** run the independent mono/stereo,
   MPEG version, CBR/VBR, ID3, tonal, speech, music, and transient corpus; verify external
   decode compatibility, duration/delay bounds, bitrate-size behavior, objective fidelity
   thresholds, malformed-input fuzzing, supported targets, and counter baselines.
7. **Pass the epic gate:** run MP3 unit, integration, lifecycle, fuzz, quality, and
   conformance suites plus `bin/qa_check.sh`, then commit the green MP3 module.

### Acceptance Criteria

- Qualified MP3 fixtures decode with correct sample rate, channels, and bounded duration.
- Encoded CBR/VBR streams are independently consumable and meet documented quality floors.
- Lower bitrate reduces aggregate fixture size without violating fidelity thresholds.
- Invalid standard bitrates error; the wrapper never silently snaps them.
- No C library, system codec, external process, temporary file, panic, or resource leak exists.

---

## Epic 5 — Dedicated Ogg Opus Module and Backward Compatibility

**Objective:** Give file-like Ogg Opus the same dedicated three-verb surface as MP3 and
WAV while preserving every existing raw Opus and top-level re-encode call site.

### Phases

1. **Introduce `RustyOpus.OggOpus`:** add the module boundary and delegate the existing
   top-level Ogg re-encode behavior without changing results or errors.
2. **Decode Ogg Opus to PCM:** expose family-0 mono/stereo decode returning the shared
   PCM descriptor with documented 48 kHz clock, pre-skip, and end-trim behavior.
3. **Encode PCM to Ogg Opus:** resample when required and write valid family-0 Ogg pages,
   headers, granule positions, checksums, end-of-stream state, and channel metadata.
4. **Complete dedicated re-encode:** compose decode/transform/encode; add preferred
   `:bitrate_mode` while retaining current `:cbr` compatibility and rejecting conflicts.
5. **Prove compatibility:** keep `RustyOpus.reencode/2`, raw packet facade functions,
   encoder/decoder resources, defaults, fixtures, errors, and documentation call sites green.
6. **Extra quality — Ogg/RFC conformance:** verify family, headers, serial/page sequence,
   granule math, checksum, pre-skip, exact channel count, duration bounds, bitrate-size
   ordering, corrupt-page handling, scheduler responsiveness, and lifecycle baselines.
7. **Pass the epic gate:** run Ogg Opus and complete backward-compatibility suites plus
   `bin/qa_check.sh`, then commit the green dedicated module.

### Acceptance Criteria

- The dedicated module provides decode, encode, and re-encode over file-like blobs.
- `RustyOpus.reencode/2` behaves as before and delegates only to Ogg Opus.
- Raw Opus packet APIs never parse or emit Ogg and remain source-compatible.
- Produced files satisfy family-0 header/page/granule/duration conformance checks.
- No existing public test, documented call, or clean consumer regresses.

---

## Epic 6 — Common `convert/2` Facade and Cross-Format Matrix

**Objective:** Add the small common API that detects supported blobs, owns the shared
options, and composes the already-proven dedicated modules.

### Phases

1. **Implement content detection:** identify Ogg Opus, MP3 with/without ID3, and
   RIFF/WAVE from bytes; support explicit `:from` and reject mismatches/ambiguity.
2. **Implement common option validation:** require `:to`, own the shared bitrate/mode,
   rate/channel/sample-format options, and reject unknown or target-inapplicable settings.
3. **Implement PCM endpoints:** accept `%RustyOpus.PCM{}` as input and support `to: :pcm`
   without allowing ambiguous raw PCM binaries.
4. **Compose format conversion:** dispatch decode → optional transform → encode for all
   supported source/target pairs, including same-format conversion through dedicated modules.
5. **Stabilize facade errors and scheduling:** unify detection/decode/transform/encode
   error contexts, checked size limits, panic containment, counters, and normal-scheduler responsiveness.
6. **Extra quality — full conversion matrix:** exercise every supported 3×3 file pair
   plus PCM endpoints over mono/stereo and representative rates; verify format detection,
   duration, channel/rate output, size/fidelity tolerances, deterministic errors, bounded
   memory, concurrency isolation, and absence of external-process/file-system activity.
7. **Pass the epic gate:** run facade, matrix, compatibility, lifecycle, scheduler, and
   conformance suites plus `bin/qa_check.sh`, then commit the green common API.

### Acceptance Criteria

- Each documented common example succeeds with one function call.
- Auto-detection and explicit `:from` are deterministic and never depend on extensions.
- All nine file-to-file pairs and PCM endpoints obey rate/channel/format contracts.
- Codec-specific options remain in dedicated modules rather than leaking into the facade.
- Existing raw and Ogg-specific APIs remain unchanged.

---

## Epic 7 — Hardening, Documentation, Packaging, and `0.4.0` Readiness

**Objective:** Harden the complete multi-format surface, synchronize all public and legal
material, and prove source/precompiled consumers before preparing the release for the maintainer.

### Phases

1. **System hardening:** run bounded corrupt-input fuzzing in disposable child BEAMs,
   concurrent mixed-format workloads, repeated conversion/counter baselines, panic tests,
   allocation-bound checks, and dirty-scheduler responsiveness across all formats.
2. **Documentation and examples:** update README, moduledocs, codec/quality/troubleshooting
   guides, examples, compatibility notes, MIME/format terminology, and explicit limitations.
3. **License, provenance, and security:** synchronize Cargo pins/locks, NOTICE, third-party
   inventory, provenance, security guidance, source audits, and dependency vulnerability checks.
4. **Package and clean consumers:** inspect the unpacked Hex package and test clean source
   and no-Rust precompiled consumers using `convert/2` plus every dedicated format module.
5. **Release pipeline and version:** update precompiled artifact smoke coverage for the
   larger NIF, validate the exact target matrix, bump Mix/Cargo/locks/changelog to `0.4.0`,
   and prepare—not manually publish—the release pipeline.
6. **Extra quality — release conformance rehearsal:** from a clean checkout run full QA,
   docs, package, license, security, source consumer, no-Rust consumer, backward-compatibility,
   artifact-matrix, per-format smoke, checksum-source, and binary-size regression checks;
   if any remote pipeline is dispatched, monitor every target to completion.
7. **Pass the final epic gate:** run `bin/qa_check.sh` once more after all release changes,
   verify every roadmap acceptance criterion and deferred boundary, mark ROADMAP004 complete,
   and commit the green `0.4.0` readiness result. Leave final Hex/release publish to the maintainer.

### Acceptance Criteria

- Mixed-format hostile/concurrent workloads cannot crash, leak, or block the BEAM.
- README, HexDocs, changelog, examples, MIME names, and limitations match the real API.
- Exact dependency licenses and provenance are auditable; security checks are green.
- Clean source and no-Rust consumers exercise all formats without sibling paths or caches.
- The supported precompiled matrix passes format smoke tests and the maintainer receives a
  release-ready `0.4.0`; the agent does not perform the final manual publish.

---

## 8. Epic Dependency Order

```text
Epic 1: contract, dependency qualification, and fixtures
   ↓
Epic 2: shared PCM descriptor and transform core
   ↓
Epic 3: WAV format module
   ↓
Epic 4: MP3 format module
   ↓
Epic 5: dedicated Ogg Opus module and compatibility
   ↓
Epic 6: common convert facade and cross-format matrix
   ↓
Epic 7: hardening, docs, packaging, and 0.4.0 readiness
```

## 9. Initial Technical Direction

- Keep `opus-rs` and the existing thin Ogg glue as the authoritative Opus path.
- Treat `rusty_mp3` as a candidate, not a foregone conclusion: its pure-Rust CBR/VBR
  surface is attractive, but it must earn an exact pin through Epic 1's independent
  compatibility, objective-fidelity, error, target, and maintenance-risk gates.
- Treat `hound` as the leading WAV candidate because it supports generic in-memory
  readers/writers and the required PCM/IEEE-float surface; confirm edge-case coverage first.
- Treat `rubato` as the leading fixed-ratio offline resampling candidate; expose no
  resampler type or tuning surface in the public API.
- Disable unrelated default features and avoid a broad universal decoder dependency when
  the three dedicated paths are smaller and easier to audit.
- Keep all public binaries and `%RustyOpus.PCM{}` in BEAM-owned terms; process whole blobs
  on dirty schedulers with checked sizes and bounded intermediate storage.

Exact versions are selected and pinned only in Epic 1 after conformance and license review.

## 10. Definition of Success

ROADMAP004 is complete when an ordinary Elixir caller can, entirely inside one BEAM OS
process:

- convert any supported Ogg Opus, MP3, or WAV blob to either of the other two formats;
- reduce Ogg Opus or MP3 size with an explicit numeric bitrate;
- decode any supported file blob to one metadata-carrying `f32le` PCM representation;
- use dedicated modules for relevant format-specific controls without learning a media graph;
- rely on stable errors, deterministic rate/channel behavior, bounded duration drift,
  objective fidelity floors, and independent format-conformance evidence;
- retain every existing raw Opus and `RustyOpus.reencode/2` call site unchanged;
- install from source or the supported precompiled NIF matrix with complete license,
  provenance, package, checksum, and clean-consumer verification.

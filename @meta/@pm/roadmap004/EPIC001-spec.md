# EPIC001 Spec: Public Contract, Dependency Qualification, and Fixture Foundation

## Purpose

Freeze the additive multi-format API, revise the native boundary deliberately, qualify
the smallest pure-Rust dependency set, and establish independent fixtures and audits
before MP3, WAV, resampling, or new Ogg behavior enters the production NIF.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Current public API: `RustyOpus`, `RustyOpus.PCM`, `RustyOpus.Encoder`, and
  `RustyOpus.Decoder`
- Current Ogg Opus contract and ADR003; raw Opus packet/PCM boundaries remain authoritative
- Candidate research: pure-Rust MP3 encode/decode, generic in-memory WAV read/write, and
  fixed-ratio offline resampling crates
- Existing fixture, provenance, license, source-audit, clean-consumer, and precompiled-target
  conventions

## Scope

In scope:

- exact public signatures and semantics for `%RustyOpus.PCM{}`, `RustyOpus.convert/2`,
  and `RustyOpus.OggOpus`, `RustyOpus.MP3`, and `RustyOpus.WAV`
- a common-option ownership table and dedicated-option boundaries
- additive compatibility rules for every existing raw packet, PCM, and Ogg re-encode API
- ADR/project-instruction updates permitting only MP3 and PCM/float WAV beside Ogg Opus,
  while retaining the no-Port/no-process/no-system-codec runtime boundary
- predeclared MP3 qualification criteria covering interoperability, supported MPEG
  versions, CBR/VBR, objective fidelity, failure behavior, maintenance risk, and targets
- exact qualification of WAV and resampling candidates for in-memory operation and edge cases
- exact dependency pins, feature flags, Rust/toolchain compatibility, licenses, provenance,
  vulnerability audit, and supported precompiled targets
- compact committed WAV, MP3, Ogg Opus, corrupt-input, and reference PCM fixtures with
  machine-readable provenance and expected properties
- QA checks that reject unpinned dependencies, forbidden native/process paths, fixture
  drift, and incomplete third-party inventory

Out of scope:

- production MP3/WAV/resampling/Ogg module implementation
- accepting a C/FFI/system MP3 fallback
- weakening qualification thresholds after observing candidate results
- runtime or test-under-test invocation of ffmpeg or another executable
- file paths, streaming, metadata preservation, extra formats, multichannel, or generic
  codec behaviours

## Qualification Contract

The candidate report must define all numerical thresholds before final comparative runs.
At minimum it records:

- decode compatibility and alignment against independently produced MPEG-1/2/2.5,
  mono/stereo, CBR/VBR, and leading-ID3 fixtures
- encode compatibility through an independent decoder/reference tool, not only the
  candidate's own decoder
- per-class objective fidelity for speech, tonal audio, music, and transients at the
  intended bitrate ladder, including the maximum permitted regression from a documented
  reference encoder and a catastrophic-failure floor
- output duration/delay, bitrate error, size ordering, malformed-input behavior, and
  deterministic repeatability
- all supported Rust/precompiled targets, Rust version, `unsafe` usage, dependency tree,
  licenses, release cadence, open correctness risks, and maintenance contingency

The report names a single selected MP3 crate only if every mandatory threshold passes.
If none pass, ROADMAP004 is blocked for an explicit scope decision; implementation must
not silently substitute LAME, ffmpeg, another process, or an FFI library.

WAV and resampling qualification must demonstrate generic in-memory reader/writer support,
required sample formats/rate pairs, checked failure behavior, target compilation, and a
license/dependency cost acceptable to the package.

## Fixture Contract

- Runtime tests consume committed files only and require no network, database, ffmpeg,
  system codec, or sibling checkout.
- Each fixture has a stable identifier, SHA-256, format, encoder/source provenance,
  expected sample rate/channels/duration, and the feature or failure it covers.
- Reference PCM uses the stable f32le interleaved contract and records any alignment or
  codec-delay treatment.
- Generated fixture-import/conformance tooling writes only to a caller-selected output
  directory and never runs from the library/test path.
- Corrupt fixtures are minimal and targeted: truncated headers/tags/chunks, illegal sizes,
  bad sync/checksum, unsupported subtype, and bounded random/adversarial cases.

## Acceptance Criteria

- The public contract is complete enough for later epics to implement without inventing
  new common abstractions.
- Existing function arities, defaults, input/output meanings, and error semantics are
  explicitly protected.
- One pure-Rust MP3 candidate passes the predeclared qualification gate, or the roadmap
  stops without codec implementation.
- WAV and resampling candidates pass in-memory, feature, target, and license gates.
- Exact dependency pins/features and all third-party licenses/provenance are auditable.
- Fixtures cover the required matrix, verify against recorded hashes/properties, and
  default tests need no external tool.
- Source and dependency audits enforce the new narrow native boundary.

## Test Strategy

- Contract tests/typespec checks verify accepted option shapes and backward-compatibility
  examples without enabling production codec behavior.
- Candidate harnesses run independently generated fixtures and capture structured results.
- Build each candidate with locked dependencies and only intended features on the target matrix.
- Fixture audits verify hashes, metadata manifests, and offline availability.
- Source scans reject process spawn, Port, ffmpeg, temporary codec files, system-library
  links, unpinned codec dependencies, and absolute/sibling paths.

## Extra Quality Gate

Phase 6 produces a reviewable qualification dossier containing the dependency/feature/
license/target matrix, frozen MP3 thresholds, raw and summarized interoperability/quality
results, selected-candidate rationale, known limitations, fixture manifest/provenance, and
security/maintenance-risk review. No mandatory failure may be waived.

## Quality Bar

- Selection is evidence-driven rather than popularity-driven.
- A candidate is not accepted solely because it round-trips through itself.
- The roadmap remains pure Rust and in-process or stops for user direction.
- No production codec behavior lands before the foundation gate is green.
- `bin/qa_check.sh` passes before the epic commit.

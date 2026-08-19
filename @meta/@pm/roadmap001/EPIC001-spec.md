# EPIC001 Spec: Native Foundation, Data Contract, Provenance, and Reproducible Quality Gate

## Purpose

Establish RustyOpus's standalone Elixir/Rust package boundary, the stable PCM/Opus
binary contract, pinned `opus-rs` provenance, native-safety rules, isolated test
foundations, and one reproducible quality gate before implementing any codec behavior.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP001.md`
- Existing generated Mix scaffold (`mix new` hello-world)
- `opus-rs` crate at pinned version `0.1.29` (BSD-3-Clause), default `std` + `heap` features
- Rustler resource, dirty-scheduler, panic-containment, and precompiled-NIF conventions
- Existing maintained-library conventions: `bin/qa_check.sh`, `@meta/@pm`, AGENTS.md,
  badges, and release patterns from the user's other Elixir/Rust libraries

## Scope

In scope:

- initial `RustyOpus`, `Encoder`, `Decoder`, facade, settings, error, and native module
  boundaries; the explicit no-Ogg, no-Port, one-process, and no-BEAM-scheduler-blocking
  contracts
- a native Rust crate with pinned toolchain-compatible dependencies
  (`native/rusty_opus_native`) and a minimal loadable Rustler NIF
- deterministic native success and translated-error smoke calls
- exact `opus-rs` provenance (version, license, features) and a third-party license policy
- owner-thread/resource, dirty-scheduling, frame/buffer-bounds, panic, cancellation,
  process-safety, and shutdown rules
- executable `bin/qa_check.sh` for deterministic Elixir/Rust format/compile/lint/test
  checks and source audits
- isolated f32le-PCM helpers, a lossy-compare helper, native resource counters,
  disposable child-BEAM helpers, and concise ADRs for the data contract and no-Ogg boundary

Out of scope:

- importing or compiling any encoder/decoder codec behavior
- Ogg/container parsing or media handling
- ffmpeg or any Port/executable backend in the runtime path
- production encode/decode, quality presets, transcode, telemetry, or packaging

## Foundation Contract

The public package presents Elixir-owned validation and stable tagged results over a
narrow Rustler seam. PCM is a binary of little-endian IEEE-754 `f32` samples,
interleaved for stereo; Opus packets are raw binaries. This contract is fixed now and
reused by every later epic. The NIF is a shared library loaded into the BEAM; it is not
a service executable. No normal BEAM scheduler may perform long-running native work, and
no panic may unwind across a callable NIF boundary.

`bin/qa_check.sh` is authoritative. Later epics extend it rather than adding competing
release gates. No committed build may depend on an absolute path, the fixture SQLite DB,
or a sibling checkout.

## Acceptance Criteria

- Initial public modules and deferred/no-Ogg boundaries are documented.
- The native crate and Rust toolchain are pinned and load through Rustler.
- One deterministic success call and one translated native error pass through the public
  Elixir API.
- Panic containment, dirty scheduling, resource lifetime, and shutdown rules are explicit.
- `opus-rs` revision, license, feature set, and target support are recorded.
- Test helpers provide f32le-PCM conversions and a lossy-compare primitive.
- `bin/qa_check.sh` is executable and passes from the project root.
- Source audits reject committed absolute/sibling paths and process-control use.
- No encoder, decoder, or production codec behavior is introduced.

## Test Strategy

- Exercise NIF loading, a stable success term, a normal translated Rust error, and a
  contained test panic in a disposable child BEAM if required.
- Build from a copied clean source tree to detect absolute path and undeclared sibling
  dependencies.
- Verify the f32le-PCM helper round-trips and the lossy-comparison helper behaves.
- Record third-party licenses and provenance mechanically.
- Run all Elixir and Rust checks through `bin/qa_check.sh` without network services.

## Quality Bar

- The generated hello-world API no longer defines project direction.
- Public documentation does not overstate codec, fidelity, or platform guarantees.
- Native smoke code performs no long-lived work and leaks no resource.
- No panic crosses the NIF boundary, no normal scheduler is blocked, and no
  process-global behavior is installed.
- Provenance is reproducible and auditable before upstream codec code enters the package.
- `bin/qa_check.sh` is green before the epic commit.

# EPIC007 Spec: Hardening, Documentation, Packaging, and 0.4.0 Readiness

## Purpose

Harden the complete multi-format surface under hostile/concurrent/lifecycle stress,
synchronize documentation/legal/package metadata, and verify source plus every precompiled
consumer/artifact before closing ROADMAP004 and handing the explicit final publish to the
maintainer.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP004.md`
- Epics 1–6: qualified dependencies, fixtures, PCM/transforms, all format modules,
  common facade, extra-quality reports, and compatibility suites
- Existing `bin/qa_check.sh`, package checker, clean consumer, CI, precompiled workflow,
  checksum generation, release conventions, and supported artifact matrix
- Current Mix/Cargo/package version `0.3.3`; target `0.4.0`
- AGENTS release rules: source first, monitor dispatched targets, published-binary-only
  checksums, no manual final Hex/release publish by the agent

## Scope

In scope:

- bounded fuzzing/corrupt corpora for detection, WAV, MP3, Ogg, PCM, transforms, and facade
- disposable child-BEAM containment for unrecoverable native failures
- concurrent mixed-format operations, repeated conversions, owner/process death where
  resources exist, counter/allocation baselines, checked limits, and scheduler responsiveness
- README, top-level/module docs, codec/quality/troubleshooting/provenance/security guides,
  examples, MIME/container terminology, option tables, compatibility, and limitations
- exact dependency pins/features/locks, NOTICE, third-party license inventory, provenance,
  security policy, source-boundary audits, and vulnerability/advisory checks
- unpacked Hex package verification, source-build consumer, no-Rust precompiled consumer,
  dedicated-module/common-facade smoke, and absence of caches/absolute paths
- CI and precompiled target workflow updates for WAV/MP3/Ogg/convert smoke and the larger NIF
- version synchronization to `0.4.0` across Mix, Cargo, locks, changelog, README, docs,
  package metadata, examples, and compatibility statements
- exact artifact matrix, target smoke, archive naming/content, published-binary checksums,
  no-Rust consumers, binary-size regression, and remote pipeline monitoring when dispatched
- final ROADMAP004 close and focused release-readiness commit

Out of scope:

- new audio formats/features/options or refactors unrelated to roadmap conformance
- publishing the Hex package or performing the final manual release action
- generating/checking in checksums from locally rebuilt or unpublished binaries
- declaring success while a dispatched target, artifact, checksum, consumer, docs, or CI
  verification remains incomplete

## Hardening Contract

- Fuzzing is deterministic/reproducible, bounded by bytes/cases/time, preserves failing
  seeds, and runs fatal cases outside the main test BEAM.
- Mixed-format concurrency uses unique binaries/state and explicit barriers; no arbitrary
  sleeps or shared mutable codec handles.
- Repeated success/error/panic/owner-death paths return native resources, allocations,
  threads, and counters to captured baselines.
- Maximum input/intermediate/output limits fail before overflow or impractical allocation.
- Dirty whole-blob work leaves normal scheduler heartbeats within the frozen bound.
- Source audits prove runtime/default tests cannot spawn, open a Port, invoke ffmpeg/system
  codecs, or create temporary codec files.

## Documentation and Package Contract

- Quick starts lead with numeric-bitrate Ogg shrink and common MP3/WAV/Ogg conversion.
- `:ogg_opus` is consistently distinguished from raw Opus packets; MIME/container/codec
  terminology and supported/deferred variants are accurate.
- Dedicated option tables and common option applicability match actual validation.
- Metadata non-preservation, mono/stereo limit, rate behavior, lossy quality/delay,
  memory limits, security boundary, and pure-Rust dependency caveats are explicit.
- The unpacked package contains all required source, checksums, licenses, notices, docs,
  fixtures needed by consumers, and no `_build`, `target`, cache, secret, absolute/sibling path.

## Release and Artifact Contract

- Source-build full QA must be green before any precompiled release pipeline runs.
- Every supported target builds the exact locked source and smokes WAV, MP3, Ogg Opus,
  `convert/2`, and an old raw Opus API through the archived artifact.
- Archive names, NIF version, internal files, hashes, asset count, and target set match the
  exact expected matrix; no stale/extra/missing asset is accepted.
- Checksums are generated only from the published binaries they describe.
- A clean no-Rust consumer loads each applicable published artifact and performs per-format
  smoke without Cargo/Rust or cached native state.
- If the release/precompiled pipeline is dispatched, every target is monitored until
  success/failure and all failures are fixed/re-run before completion.
- Final Hex/final-release publish remains a maintainer action after the verified handoff.

## Acceptance Criteria

- Hostile, corrupt, oversized, concurrent, repeated, panic, and lifecycle workloads cannot
  crash, leak, wedge, or block the BEAM.
- Every existing and new public API has synchronized docs, examples, typespecs, limitations,
  and backward-compatibility coverage.
- Licenses, provenance, locks, security/advisory checks, and source-boundary audits are green.
- Package and clean source/no-Rust consumers exercise all format/common paths successfully.
- Mix/Cargo/locks/changelog/docs report `0.4.0` consistently.
- Exact precompiled artifacts are target-smoked, published-binary checksums validate, and
  CI/pipeline jobs are green before success is reported.
- ROADMAP004 is marked Complete only after all seven epics and their extra-quality evidence pass.
- The agent does not perform the final manual Hex/release publish.

## Test Strategy

- Aggregate existing format/facade suites plus deterministic fuzz seeds and mixed-format
  concurrency/lifecycle tests into the authoritative QA path.
- Build docs and run executable examples/doctests where deterministic.
- Audit dependencies/licenses/provenance/advisories and unpacked package contents mechanically.
- Create clean source and no-Rust consumers in unique temporary directories with native
  caches/toolchains explicitly excluded as appropriate.
- Smoke the exact archives produced/published by each target rather than the build tree.
- Compare precompiled NIF/archive sizes to `0.3.3` and require review for the documented threshold.
- Run all checks from a clean checkout before the close commit.

## Extra Quality Gate

Phase 6 produces a release-conformance dossier containing clean-checkout QA/docs/package/
license/security results, fuzz/concurrency/lifecycle/scheduler evidence, backward-compatibility
matrix, source/no-Rust consumer logs, exact artifact/target/archive/hash/checksum validation,
per-format archive smoke, binary-size regression analysis, and completed CI/pipeline status.
No local rebuild may stand in for a published binary when generating checksums.

## Quality Bar

- Release claims are based on exact consumer artifacts, not source-only success.
- Documentation is honest about quality and deferred variants.
- Security and legal inventories cover every newly shipped native dependency.
- The final diff contains only roadmap-related source/docs/generated release material.
- `bin/qa_check.sh` is green from a clean checkout before the epic commit.

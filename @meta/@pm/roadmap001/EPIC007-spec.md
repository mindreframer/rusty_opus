# EPIC007 Spec: CI, Precompiled Matrix, and Release Readiness

## Purpose

Wire CI, the precompiled-NIF release matrix with checksums and loadability smoke tests,
clean consumers, and a clean `0.1.0` release commit — while leaving the final publish to
the maintainer.

## Reference Inputs

- Roadmap Epics 1–6 (QA gate, codec, docs, package content)
- Existing maintained-library CI and release workflows (source QA on push/PR; tag-triggered
  precompiled matrix attaching `lib<name>-vX-nif-2.15-<target>` archives; `rustler_precompiled`
  checksum + no-Rust consumer smoke)
- `bin/qa_check.sh` as the authoritative gate

## Scope

In scope:

- `.github/workflows/ci.yml` running `bin/qa_check.sh` on push/PR with pinned OTP/Elixir
  and Rust toolchains and proper caching
- `.github/workflows/release.yml` building the pinned `rusty_opus_native` release NIF for
  the supported targets and attaching archives on tag `v*`
- loadability smoke of the exact archived NIF through the public `RustyOpus` API, and a
  no-Rust `rustler_precompiled.download` consumer job
- `checksum-Elixir.RustyOpus.Native.exs` generated only from published binaries, and exact
  artifact-set/digest validation before any publish
- `scripts/clean_consumer.sh` for source-build and no-Rust precompiled consumers from clean
  temporary Mix projects
- final release conformance: full QA, package, license, clean-consumer, artifact
  verification; version bump to `0.1.0`; changelog/docs/readme/checksum sync

Explicitly out of scope: actually publishing to Hex or creating the final release. The
agent prepares, tests, and monitors the pipeline and leaves the publish step to the
maintainer.

## Acceptance Criteria

- CI runs the authoritative QA gate and is green on `main`.
- Every supported precompiled artifact is smoke-tested and loadable through the public API,
  and all digests/checksums validate.
- Clean source and no-Rust consumers compile and run without sibling paths or cached
  native artifacts.
- The release pipeline is ready to tag, but the final publish step remains explicitly for
  the maintainer.

## Test Strategy

- CI job runs `bin/qa_check.sh` end to end on a clean checkout.
- Matrix job builds the release NIF, archives it, smokes the exact artifact, and a
  no-Rust consumer loads each published artifact through `rustler_precompiled`.
- `clean_consumer.sh` validates source-build and precompiled paths in disposable projects.

## Quality Bar

- No artifact, checksum, or consumer expectation is asserted optimistically.
- The release is staged and verified, never published by the agent.
- `bin/qa_check.sh` is green from a clean checkout before the release commit.

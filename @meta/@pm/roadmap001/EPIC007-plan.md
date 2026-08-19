# EPIC007 Plan: CI, Precompiled Matrix, and Release Readiness

## Progress

- [x] Phase 7.1: Add `.github/workflows/ci.yml` running `bin/qa_check.sh` on push/PR; make it green from a clean run.
- [x] Phase 7.2: Add `.github/workflows/release.yml` building the pinned release NIF for the supported targets and attaching archives on tag `v*`.
- [x] Phase 7.3: Smoke the exact archived NIF through the public `RustyOpus` API and add a no-Rust `rustler_precompiled.download` consumer job.
- [x] Phase 7.4: Generate `checksum-Elixir.RustyOpus.Native.exs` only from published binaries and validate the exact artifact set/digests.
- [x] Phase 7.5: Add `scripts/clean_consumer.sh` for source-build and no-Rust precompiled consumers.
- [x] Phase 7.6: Run full release conformance; bump to `0.1.0`; sync changelog/docs/readme/checksums.
- [x] Phase 7.7: Pass the final epic gate from a clean checkout and prepare the `0.1.0` release commit (do not run the final publish).

## Implementation Steps

1. Write `ci.yml` with `erlef/setup-beam` (OTP 27.3 / Elixir 1.20.1), `dtolnay/rust-toolchain`
   (1.89.0, rustfmt+clippy), Mix/Cargo caching, `mix deps.get`, and `bin/qa_check.sh`.
2. Write `release.yml` with a matrix for the supported targets (e.g.
   aarch64-apple-darwin, x86_64-apple-darwin, aarch64-unknown-linux-gnu,
   x86_64-unknown-linux-gnu) building `cargo build --release --locked --target` and
   packaging `rusty_opus_native-vX-nif-2.15-<target>` tar.gz archives; attach on tag `v*`
   via `softprops/action-gh-release`.
3. In the matrix job, extract the exact archived NIF, smoke it through the public
   `RustyOpus` API, and add an upload/download consumer job that loads the artifact via
   `rustler_precompiled` without a Rust toolchain.
4. Add an aggregate job that downloads all artifacts, validates the exact asset set and
   digests, and (only for the maintainer's explicit step) prepares the checksums from
   published binaries; commit the generated `checksum-*.exs`.
5. Write `clean_consumer.sh` creating a clean temporary Mix project (source-build and
   no-Rust precompiled modes), compiling and running a smoke without sibling paths or
   cached native artifacts; wire into `bin/qa_check.sh`.
6. Bump `mix.exs`/`native/rusty_opus_native/Cargo.toml` to `0.1.0` (verified by
   `scripts/project_version.sh`), sync `CHANGELOG.md`, README, docs, and checksum, and run
   the full QA and consumer checks.
7. Run `bin/qa_check.sh` from a clean checkout, confirm CI and matrix are green, review the
   final diff, and prepare the `0.1.0` release commit. Do not run the final Hex/GitHub
   publish; leave it explicitly for the maintainer.

## Test Isolation Checklist

- [x] Clean consumers run in disposable directories with no shared native caches.
- [x] Artifact-set validation compares exact expected filenames and digests.
- [x] No-Rust jobs place stub `cargo`/`rustc` on PATH to prove precompiled loading.

## Quality Gate

- [x] CI runs `bin/qa_check.sh` and is green on `main`.
- [x] Each precompiled artifact is smoke-tested and loadable; digests/checksums validate.
- [x] Clean source and no-Rust consumers compile and run.
- [x] Release commit is staged and verified but not published by the agent.
- [x] `bin/qa_check.sh` is green from a clean checkout; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 7 criteria pass, commit
`roadmap001 - epic 7 - wire CI, precompiled matrix, and release readiness`. Do not include
the final publish in this commit; it remains for the maintainer.

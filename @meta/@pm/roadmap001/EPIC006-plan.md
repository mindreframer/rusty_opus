# EPIC006 Plan: Documentation, License, and Package Content

## Progress

- [x] Phase 6.1: Write README with badges, quality-change quickstart, PCM/Opus contract, supported targets, release section.
- [x] Phase 6.2: Add `docs/installation.md`, `docs/codec.md`, `docs/quality.md`, `docs/troubleshooting.md`, `docs/provenance.md`.
- [x] Phase 6.3: Add Apache-2.0 `LICENSE`, `NOTICE` (BSD-3-Clause opus-rs), `CHANGELOG.md`, `SECURITY.md`.
- [x] Phase 6.4: Configure `mix.exs` `description`, `source_url`, `docs`, `package` files, maintainers, licenses, links.
- [x] Phase 6.5: Add `scripts/package_check.sh` and make the unpacked-package checks pass; add `checksum-*.exs` scaffold.
- [x] Phase 6.6: Add light telemetry/native counters for encode/decode durations and error counts.
- [x] Phase 6.7: Pass the epic gate, verify every Epic 6 criterion, and prepare the focused commit.

## Implementation Steps

1. Write the README mirroring the user's library style, with the badge set and a
   `RustyOpus.change_quality` quickstart that exists in the API.
2. Write the five docs pages and reference them from `mix.exs` `docs.extras`; set
   `main: "readme"`.
3. Add the Apache-2.0 `LICENSE`, `NOTICE` naming `opus-rs 0.1.29` (BSD-3-Clause), a
   `CHANGELOG.md`, and a short `SECURITY.md` describing the NIF trust boundary.
4. Configure the `package` block with `files` including `lib`, `native/rusty_opus_native`
   source (`src`, `Cargo*`, `rust-toolchain.toml`, `build.rs`), docs, `LICENSE`,
   `NOTICE`, `CHANGELOG.md`, `SECURITY.md`, and `checksum-*.exs`.
5. Write `scripts/package_check.sh` to `mix hex.build --unpack` and assert the presence of
   docs, licenses, and `checksum-*.exs` and the absence of `target/`, `_build/`,
   absolute paths; wire it into `bin/qa_check.sh`.
6. Add minimal `:telemetry`/counter instrumentation for encode/decode durations and error
   counts guarded to be cheap, or document `native_counters` only if instrumentation adds
   package risk.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion, review the diff, and
   only then prepare the epic commit.

## Test Isolation Checklist

- [x] Package checks build/unpack only in a clean temporary directory.
- [x] Docs/doctests are deterministic and need no network or DB.
- [x] Provenance strings are asserted exactly.

## Quality Gate

- [x] README/docs match the implemented API; `mix docs` builds.
- [x] Legal material records `opus-rs` BSD-3-Clause and pinned revision.
- [x] Unpacked package has docs, `checksum-*.exs`, and no build/absolute-path artifacts.
- [x] `bin/qa_check.sh` is green; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 6 criteria pass, commit
`roadmap001 - epic 6 - document, license, and package the library`. Never commit partial,
optimistic, or out-of-scope work.

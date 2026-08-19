# EPIC003 Spec: 0.2.0 and Roadmap Close

## Purpose

Ship a documented `0.2.0` that includes the whole-stream API, keep 0.1.0 call sites
working, and close ROADMAP002. Precompiled artifacts and Hex publish stay with the
maintainer.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP002.md`
- Epics 1–2 (bulk NIFs and facade)
- Version sources: `mix.exs`, `native/rusty_opus_native/Cargo.toml`, lockfiles
- `CHANGELOG.md`, `README.md`, HexDocs

## Scope

In scope:

- Version bump `0.1.0` → `0.2.0` in Mix, Cargo, and lockfiles.
- Changelog entry for bulk API and `encode/4`, `decode/4`, `transcode/5`.
- README and docs synchronized; note that 0.1.0 call sites are unchanged.
- `bin/qa_check.sh` green.
- Mark ROADMAP002 complete.

Out of scope:

- Running the precompiled-NIF release workflow
- Publishing the Hex package or GitHub release
- Polish of `close/1` docs, `:invalid_setting` spelling, or moving `rustle/2`

## Acceptance Criteria

- `mix.exs` and `Cargo.toml` both report `0.2.0`.
- Changelog and README describe the shipped whole-stream API and do not claim
  container/file support.
- Existing 0.1.0 public functions still compile and pass their tests.
- ROADMAP002 status is Complete, with a short summary of what shipped.
- `bin/qa_check.sh` is green.

## Test Strategy

- No new codec tests in this epic unless docs/examples fail the existing doctest/QA stages.
- Rely on Epics 1–2 tests plus the full QA gate (format, compile, lint, tests, package,
  license, clean-consumer as already wired).

## Quality Bar

- Version strings are consistent across Mix, Cargo, lockfiles, changelog, and README.
- The agent does not publish. Maintainer publishes after this commit.
- `bin/qa_check.sh` is green before the epic commit.

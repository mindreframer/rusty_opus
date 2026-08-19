# EPIC006 Spec: Documentation, License, and Package Content

## Purpose

Produce professional, consistent library metadata, documentation, legal material, and
Hex package content matching the user's other maintained libraries (badges, ExDoc pages,
`mix.exs` packaging, `NOTICE`, `CHANGELOG`, `SECURITY`).

## Reference Inputs

- Roadmap Epics 1–5 (implemented API, data contract, provenance)
- Existing maintained-library conventions: `README.md` badges, `docs/` pages,
  `mix.exs` `docs`/`package` blocks, `NOTICE` for third-party licenses
- Apache-2.0 license and BSD-3-Clause `opus-rs` third-party license

## Scope

In scope:

- README with badges (Hex, HexDocs, CI, precompiled, license), a quality-change
  quickstart, the PCM/Opus contract, supported targets, and a release section
- `docs/installation.md`, `docs/codec.md`, `docs/quality.md`, `docs/troubleshooting.md`,
  and `docs/provenance.md` wired into ExDoc extras
- Apache-2.0 `LICENSE`, a `NOTICE` recording BSD-3-Clause `opus-rs` and its pinned
  revision, `CHANGELOG.md`, and `SECURITY.md`
- `mix.exs` packaging: `description`, `source_url`, docs extras, `package` files,
  maintainers, licenses, links
- `scripts/package_check.sh` building/unpacking the Hex package and checking
  `checksum-*.exs`, docs, licenses, and exclusion of build artifacts
- light telemetry/counters for encode/decode durations and error counts when trivially
  cheap; otherwise documented native counters only

Out of scope: CI workflows and the precompiled matrix (Epic 7), behavior changes to the
codec, and further quality/facade feature work.

## Acceptance Criteria

- README and docs match the implemented API and are internally consistent with `mix docs`.
- License and provenance material record `opus-rs` BSD-3-Clause and pinned revision.
- The unpacked Hex package contains docs, `checksum-*.exs`, and no build caches or
  absolute sibling paths.
- `bin/qa_check.sh` passes with the package-content stage.

## Test Strategy

- `package_check.sh` inspects the unpacked package deterministically.
- Docs examples that are testable run in automated tests (doctests where feasible).
- Provenance/license strings are mechanically asserted, guarding against regression.

## Quality Bar

- Documentation never overstates fidelity, target, or platform guarantees.
- Legal material correctly attributes the third-party codec.
- `bin/qa_check.sh` is green before the epic commit.

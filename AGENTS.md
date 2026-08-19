# AGENTS.md

## Roadmaps

- Work is roadmap-driven. Treat a roadmap as an execution contract.
- Layout: one `@meta/@pm/ROADMAP00X.md`; each roadmap has seven epics and each epic has seven phases.
- Each epic has a spec and a plan in `@meta/@pm/roadmap00x/`. The plan contains the phase checkboxes.
- Read the roadmap overview and every epic file completely before coding.
- Execute epics and phases in dependency order.
- Implement the matching unit, integration, lifecycle, and conformance tests for every phase and epic.
- Check a phase only when its implementation, tests, documentation, and acceptance criteria pass. Never check work optimistically.
- After every epic, run `bin/qa_check.sh`. Fix all failures.
- Commit each green epic as `roadmap001 - epic x - <outcome>` with a concise body stating the result and verification.
- Given a roadmap, finish it end to end. Do not stop between phases or ask routine questions; inspect, make the smallest reasonable assumption, and continue.

## Native Boundary

- RustyOpus exposes the pure-Rust `opus-rs` codec through a Rustler NIF. It must not shell out to ffmpeg, launch a Port, or spawn a process for codec work in the library path. ffmpeg appears only in fixture-import tooling, never in runtime or test code under test.
- RustyOpus wraps the raw Opus CODEC (RFC 6716). It encodes PCM to Opus packets and decodes Opus packets to PCM. It must not parse, demux, or mux the Ogg container; the Ogg/Opus `.ogg` files in the fixture DB are pre-decoded to PCM by the import script before becoming test fixtures.
- Codec state (encoder/decoder) lives in Rustler resources owned by Elixir processes. Resource cleanup on owner death and explicit close must be idempotent and leak-free.
- PCM is passed as a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved for stereo. Opus packets are passed as raw binaries. Keep this one stable binary contract everywhere.
- Longer encodes/decodes run on Rustler dirty I/O schedulers so a large frame never blocks a normal BEAM scheduler.
- Native code must translate Opus `&'static str` errors into stable tagged Elixir errors and must never let a Rust panic unwind across a callable NIF boundary.

## Code

- Use the least abstraction that solves the current roadmap phase.
- Prefer direct, readable, maintainable code. Avoid speculative frameworks and abstractions without a second implementation.
- Minimize dependencies. Each dependency adds build, security, upgrade, and release cost.
- Keep the Elixir API independent of any consuming application.
- Keep the pinned `opus-rs` revision, its BSD-3-Clause license, and the vendored/third-party license inventory auditable.
- Keep roadmap commits focused. Do not mix unrelated cleanup into an epic.

## Tests

- Default tests must be isolated, deterministic, bounded, and independent of execution order.
- Use unique resource handles and dynamically allocated temporary paths. Never share mutable codec state or fixed temp paths between concurrent tests.
- Audio assertions compare PCM within a lossy-tolerance (`RustyOpus.TestHelpers`) rather than exact equality, because Opus is lossy.
- Resource tests prove repeated open/close and process-owner death return codec memory, thread, and native counters to baseline.
- Prefer explicit counters, barriers, and reference fixtures over arbitrary sleeps.
- Tests that intentionally crash a NIF or exercise unrecoverable native failure run in disposable child BEAMs.

## Release

- A finished roadmap normally bumps the version. Synchronize Mix, Cargo, lockfiles, changelog, README, docs, metadata, examples, and compatibility statements.
- Run full QA, documentation, package, license, security, and clean-consumer checks before release.
- Run the precompiled-NIF pipeline only after source-build QA is green.
- Monitor every target until completion. Never dispatch release work and walk away.
- Verify the exact native artifact matrix, smoke tests, checksums, release tag, package contents, and no-Rust consumer tests.
- Generate checksums only from published binaries. Report success only after source tests, artifacts, checksums, consumers, package documentation, and CI are all verified.
- The agent never publishes the Hex package or the final release manually; it prepares, tests, and monitors the release pipeline and leaves the explicit publish step to the maintainer.

# EPIC001 Plan: Native Foundation, Data Contract, Provenance, and Reproducible Quality Gate

## Progress

- [x] Phase 1.1: Define public encoder/decoder/facade/settings/error/native boundaries and the no-Ogg/no-Port contract.
- [x] Phase 1.2: Bootstrap the pinned Rustler crate with success, translated-error, and panic-containment smoke tests.
- [x] Phase 1.3: Pin opus-rs provenance, license, features, and third-party policy.
- [x] Phase 1.4: Establish dirty-scheduling, bounds, panic, resource, process-safety, and shutdown rules.
- [x] Phase 1.5: Create executable `bin/qa_check.sh` with deterministic Elixir, Rust, source-audit, and clean-path stages.
- [x] Phase 1.6: Add f32le-PCM/lossy-compare/resource/child-BEAM test foundations and the required ADRs.
- [x] Phase 1.7: Pass the epic gate, verify every Epic 1 criterion, and prepare the focused commit.

## Implementation Steps

1. Replace generated hello-world concepts with documented public module boundaries and
   explicit no-Ogg, one-process, no-Port, and no-BEAM-scheduler-blocking constraints.
2. Create `native/rusty_opus_native` with pinned toolchain, `opus-rs =0.1.29` and
   `rustler =0.36.2`, load it with Rustler, and expose only deterministic smoke functions
   that prove stable term/error translation plus panic containment.
3. Record exact `opus-rs` provenance (version `0.1.29`, BSD-3-Clause), the `std` + `heap`
   features, target matrix, and restrictions on the codec boundary.
4. Write the native contract covering resource lifetime, dirty scheduling, frame/buffer
   bounds, timeouts, owner death, destructor fallback, process-control prohibitions, and
   unrecoverable shutdown.
5. Add one fail-fast non-interactive QA script for Mix and Cargo format,
   warnings-as-errors compilation, Clippy, tests, source safety, and absolute-path audits.
6. Add f32le-PCM conversion helpers, the lossy-compare helper, native resource counters,
   disposable child-BEAM helpers, and ADRs for the data contract and no-Ogg boundary.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion and scope boundary,
   review the final diff, and only then prepare the epic commit.

## Test Isolation Checklist

- [ ] Every filesystem fixture owns a unique temporary directory with deterministic cleanup.
- [ ] f32le-PCM helpers round-trip and reject mis-sized binary input.
- [ ] Native smoke tests retain no runtime thread, allocation, or resource after completion.
- [ ] Panic-containment checks cannot terminate the main test BEAM.
- [ ] Clean-copy checks ignore build caches and require no sibling checkout or network service.
- [ ] Default tests use no credentials, external services, or execution-order assumptions.
- [ ] Resource/data helpers use deterministic values rather than arbitrary sleeps.

## Quality Gate

- [x] Public and native-safety contracts are documented and internally consistent.
- [x] Native success, translated-error, and panic-containment smoke tests pass.
- [x] Provenance, license, target matrix, and third-party policy are complete.
- [x] `bin/qa_check.sh` is executable, authoritative, and green from the root.
- [x] Source/path audits find no process-control violation, secret, or absolute sibling dependency.
- [x] No encoder, decoder, container, or production codec API exists yet.
- [x] Commit title and informative body follow the commit rule.

## Commit Rule

After implementation, run only the repository gate from the repository root:

```sh
bin/qa_check.sh
```

Only if it passes and all Epic 1 criteria are complete, create one focused commit. Use
`roadmap001 - epic 1 - establish native foundation, data contract, and provenance`. The
body must summarize the public/native boundaries, data contract, provenance decision,
safety invariants, and tests executed by the QA gate. Do not commit failing, partial,
optimistic, or out-of-scope work.

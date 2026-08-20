# EPIC007 Plan: Hardening, Documentation, Packaging, and 0.4.0 Readiness

## Progress

- [x] Phase 7.1: Harden all formats/facade with bounded fuzz, mixed concurrency, panic, limits, scheduler, lifecycle, and counter tests.
- [x] Phase 7.2: Synchronize README, moduledocs, guides, examples, terminology, option tables, compatibility, and limitations.
- [x] Phase 7.3: Synchronize exact pins/locks, NOTICE/licenses/provenance/security, source audits, and advisory checks.
- [x] Phase 7.4: Verify unpacked package plus clean source and no-Rust consumers across common/dedicated/legacy APIs.
- [x] Phase 7.5: Update CI/precompiled format smoke, validate the target matrix, and synchronize version/changelog/docs to `0.4.0`.
- [x] Phase 7.6: Pass clean release conformance including artifacts, published-binary checksums, consumers, compatibility, size, CI, and monitored targets.
- [x] Phase 7.7: Run final `bin/qa_check.sh`, verify all roadmap criteria, mark ROADMAP004 Complete, and prepare the focused readiness commit.

## Implementation Steps

1. Add deterministic bounded fuzz seeds/corpora, mixed-format concurrent workloads,
   panic/child-BEAM cases, max-size arithmetic, repeated success/error/owner-death counter
   baselines, and dirty-scheduler heartbeat tests; preserve/fix every discovered failure.
2. Rewrite README and all relevant ExDoc/guides/examples around the implemented common and
   dedicated APIs; document formats/options/quality/delay/limits/metadata/deferred scope and
   prove example names/arities/results.
3. Refresh Cargo locks/features, NOTICE, third-party inventory, provenance, security and
   native-boundary docs; run license/source/advisory audits and resolve every finding.
4. Extend package inspection and clean consumers; test source build and no-Rust precompiled
   load of WAV, MP3, Ogg Opus, `convert/2`, PCM, and a legacy raw Opus call from clean
   disposable projects with no sibling/cached state.
5. Update CI/release workflows and exact expected assets for the larger NIF; add archived
   per-format/legacy smoke; set `0.4.0` everywhere; synchronize changelog/docs/metadata;
   source QA must be green before any precompiled dispatch.
6. From a clean checkout run the complete release rehearsal; when maintainer-authorized
   artifacts are published, monitor every target, validate exact archives/hashes/smokes,
   generate checksums only from those binaries, run no-Rust consumers, and record size/
   compatibility/CI evidence. Do not close on partial pipeline state.
7. Run `bin/qa_check.sh` again after all generated/remote verification material is final;
   audit diff/scope/version/deferred boundaries, mark roadmap/plan phases complete only
   then, and prepare the Epic 7 readiness commit without final manual publish.

## Test Isolation Checklist

- [x] Fuzz inputs/seeds/bounds are deterministic; fatal cases use disposable child BEAMs.
- [x] Mixed workloads own unique state and coordinate with barriers, not sleeps.
- [x] Clean consumers use unique temporary projects and explicitly excluded caches/toolchains.
- [x] Artifact smoke extracts and loads the exact archive, never the build-tree library.
- [x] Checksums derive only from published assets and exact expected filenames.
- [x] Docs/examples/package/advisory checks need no credentials or mutable external service.
- [x] Existing `.cursor/` and unrelated user changes remain untouched.

## Extra Quality Evidence

- Deterministic fuzz, mixed-concurrency, panic, limits, scheduler, and counter-baseline report.
- Full old/new public API backward-compatibility and documentation/example matrix.
- Exact pins/features/license/provenance/security/advisory/source-audit report.
- Unpacked package, clean source consumer, and per-target no-Rust consumer logs.
- Exact artifact/archive/hash/published-checksum/per-format-smoke/target-status matrix.
- `0.3.3`→`0.4.0` native/archive size regression analysis and approval.
- Clean-checkout QA, docs, package, consumer, CI, and monitored-pipeline completion record.

## Quality Gate

- [x] Hostile/concurrent/repeated/lifecycle/scheduler checks pass without leak/crash/wedge.
- [x] Docs, examples, terminology, limitations, and compatibility match actual behavior.
- [x] License/provenance/security/advisory/source and package audits are green.
- [x] Clean source and every applicable no-Rust consumer pass all format smokes.
- [x] `0.4.0`, exact artifacts, published-binary checksums, target smokes, and CI all verify.
- [x] Final `bin/qa_check.sh` is green from a clean checkout and ROADMAP004 criteria pass.
- [x] Commit follows the roadmap004 rule; final manual publish remains with maintainer.

## Commit Rule

Only after every extra-quality artifact and the final clean-checkout QA pass, create:

`roadmap004 - epic 7 - prepare verified multi-format 0.4.0 release`

The body must summarize hardening, docs/legal/package work, version synchronization,
exact artifact/checksum/consumer/size/CI evidence, final QA, and the unperformed maintainer
publish step.

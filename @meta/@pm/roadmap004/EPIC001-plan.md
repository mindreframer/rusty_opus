# EPIC001 Plan: Public Contract, Dependency Qualification, and Fixture Foundation

## Progress

- [x] Phase 1.1: Freeze `convert/2`, `%RustyOpus.PCM{}`, format-module, option, result, and compatibility contracts.
- [x] Phase 1.2: Revise ADRs and project instructions for the narrow MP3/WAV/Ogg native boundary.
- [x] Phase 1.3: Predeclare thresholds, qualify pure-Rust MP3 candidates, and pin one only if all mandatory gates pass.
- [x] Phase 1.4: Qualify and exactly pin the smallest in-memory WAV and fixed-rate resampling dependencies.
- [x] Phase 1.5: Commit the cross-format/reference/corrupt fixture corpus and machine-readable provenance manifest.
- [x] Phase 1.6: Produce and pass the independent dependency, target, license, interoperability, and objective-quality dossier.
- [x] Phase 1.7: Extend QA audits, run `bin/qa_check.sh`, verify Epic 1, and prepare the focused commit.

## Implementation Steps

1. Write public contract documentation/typespec fixtures for the shared PCM struct,
   common facade, dedicated modules, option ownership, stable errors, and old API guarantees.
2. Add or revise the native-boundary ADR, AGENTS instructions, source-audit patterns, and
   deferred-scope text without changing existing codec behavior.
3. Freeze numerical/interoperability thresholds first; build locked candidate harnesses;
   run the required corpus; record raw results; select and exactly pin a pure-Rust MP3
   implementation only if every mandatory criterion passes.
4. Exercise leading WAV/resampler candidates over in-memory cursors, required sample
   formats/rate pairs, corrupt input, target compilation, dependency features, and licenses;
   record the selected exact versions and disabled defaults.
5. Add compact fixtures and a manifest with hashes, provenance, expected format/rate/
   channels/duration, delay/alignment policy, and feature ownership. Keep generation tools
   explicitly developer-side.
6. Produce the Phase 6 dossier, independently verify encoder outputs and decoder reference
   results, audit maintenance/security/unsafe/target risk, and fail rather than waive any
   mandatory threshold.
7. Wire deterministic dependency, license, source-boundary, and fixture-manifest checks
   into `bin/qa_check.sh`; run it, review the diff/scope, and prepare the Epic 1 commit.

## Test Isolation Checklist

- [x] Candidate builds use exact versions and locked dependency graphs.
- [x] Comparative runs use identical source PCM, settings, alignment, and metric versions.
- [x] Runtime tests read committed fixtures and invoke no external executable or service.
- [x] Fixture generation uses a caller-selected temporary/output directory and is not in QA.
- [x] Corrupt/adversarial qualification is bounded and cannot crash the main BEAM.
- [x] Target checks use clean build directories and no sibling checkout.
- [x] Existing `.cursor/` and unrelated worktree changes remain untouched.

## Extra Quality Evidence

- Frozen mandatory MP3 thresholds and raw result artifacts.
- Independent decode/encode interoperability matrix for the required corpus.
- Objective quality, bitrate accuracy, duration/delay, size-order, and determinism report.
- Exact dependency/features/license/security/maintenance/target matrix.
- Fixture manifest with hashes and provenance, plus a successful offline audit.

## Quality Gate

- [x] API, option, error, compatibility, and deferred boundaries are unambiguous.
- [x] A pure-Rust MP3 candidate passed every mandatory threshold; no fallback was inferred.
- [x] WAV and resampling selections passed in-memory, target, edge, and license checks.
- [x] Dependency pins, features, provenance, licenses, and fixture hashes are audited.
- [x] No production MP3/WAV/resampling/Ogg-module behavior was introduced.
- [x] `bin/qa_check.sh` is green after the extra-quality dossier is complete.
- [x] Commit title/body follow the roadmap004 rule.

## Commit Rule

After all evidence and acceptance criteria pass, run:

```sh
bin/qa_check.sh
```

Only if green, create one focused commit:

`roadmap004 - epic 1 - qualify dependencies and freeze the multi-format contract`

The body must name the selected exact dependencies, summarize the extra-quality evidence,
record fixture/provenance work, and state that no production codec behavior was added.

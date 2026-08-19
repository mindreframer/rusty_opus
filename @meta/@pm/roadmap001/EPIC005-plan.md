# EPIC005 Plan: Robustness, Lifecycle, and Concurrency

## Progress

- [x] Phase 5.1: Tie each resource to one Elixir owner; prove owner-death cleanup and idempotent close.
- [x] Phase 5.2: Run many encoders/decoders concurrently across processes; assert isolation and baseline-returning counters.
- [x] Phase 5.3: Prove large-frame encode/decode leaves normal schedulers responsive (timed heartbeat).
- [x] Phase 5.4: Cover error paths: invalid rates/channels, empty PCM, oversized frames, truncated/corrupt packets, non-binary.
- [x] Phase 5.5: Fuzz random/corrupt input in a disposable child BEAM; assert clean survivability and panic containment.
- [x] Phase 5.6: Add resource-baseline and encode/decode throughput smoke checks.
- [x] Phase 5.7: Pass the epic gate, verify every Epic 5 criterion, and prepare the focused commit.

## Implementation Steps

1. Confirm resources are released when their owning process dies (drop the resource in
   `process_exit`/owner callback or rely on resource GC) and that calls after close return
   `{:error, :closed}`.
2. Add a concurrency test opening N encoders/decoders across spawned processes, running
   mixed workloads, then asserting native counters return to the pre-exercise baseline.
3. Add a scheduler-responsiveness test running a large-frame encode/decode while a
   `Process.send_after` timer on a normal scheduler fires within a documented bound.
4. Enumerate and test every error path through the public API with stable tagged errors.
5. Add a child-BEAM fuzz test feeding random bytes as PCM and packets; assert the child
   exits a defined way (not an unclean crash) and the parent VM is unaffected.
6. Add a lightweight throughput/`native_counters` smoke consumed by docs and QA; keep it
   deterministic enough not to be flaky in CI.
7. Run and fix `bin/qa_check.sh`, confirm every acceptance criterion, review the diff, and
   only then prepare the epic commit.

## Test Isolation Checklist

- [ ] Concurrency/lifecycle tests use unique handles and counter/barrier primitives, no sleeps.
- [ ] Fuzz and panic tests run only in disposable child BEAMs.
- [ ] Throughput smoke uses a bounded input size and a generous assertion.

## Quality Gate

- [x] No leaked resource or growing counter after concurrent/repeated lifecycle.
- [x] Large-frame codec work never blocks a normal scheduler.
- [x] All hostile/invalid inputs map to stable tagged errors; child BEAM survives fuzz.
- [x] Close and owner death are deterministic and idempotent.
- [x] `bin/qa_check.sh` is green; commit follows the rule.

## Commit Rule

Run `bin/qa_check.sh`; only if green and all Epic 5 criteria pass, commit
`roadmap001 - epic 5 - harden robustness, lifecycle, and concurrency`. Never commit
partial, optimistic, or out-of-scope work.

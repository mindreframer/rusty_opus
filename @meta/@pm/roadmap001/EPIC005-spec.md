# EPIC005 Spec: Robustness, Lifecycle, and Concurrency

## Purpose

Prove the codec resources are safe under concurrency, error, and lifecycle stress, never
block normal BEAM schedulers, and survive hostile input without crashing the VM.

## Reference Inputs

- Roadmap Epics 1–4 (encoder, decoder, facade, data contract)
- `RustyOpus.Encoder`/`RustyOpus.Decoder` resources from Epics 2–3
- Rustler dirty scheduling and panic-containment conventions
- Disposable child-BEAM and resource-counter test foundations from Epic 1

## Scope

In scope:

- resource ownership and cleanup tied to one Elixir owner, owner-death cleanup, idempotent
  close with `{:error, :closed}` after close
- concurrent and multi-process codec isolation, with counters returning to baseline
- dirty-scheduler proof: large-frame encode/decode while a concurrent timer stays on time
- error-path coverage: invalid rates/channels, empty PCM, oversized frames,
  truncated/corrupt packets, non-binary input — all stable tagged errors
- panic containment and fuzz robustness on random/corrupt `f32`-binary and packet input in
  a disposable child BEAM
- resource baselines and an encode/decode throughput smoke for docs

Out of scope: container handling, presets/transcode additions, telemetry (Epic 6),
and packaging/CI (Epics 6–7).

## Acceptance Criteria

- Concurrent and repeated lifecycle leave no leaked resource or growing counter.
- No large-frame encode/decode blocks a normal BEAM scheduler.
- All corrupt/invalid inputs return stable tagged errors; a child BEAM survives fuzz.
- Resource close and owner death are deterministic and idempotent.

## Test Strategy

- Spawn many processes owning encoders/decoders, run interleaved workloads, then require
  resource counters return to baseline.
- Run a large-frame encode/decode while asserting a bounded timer fires on schedule.
- Feed random bytes as `f32`-binary PCM and as Opus packets from a disposable child BEAM,
  asserting the child exits cleanly rather than crashing the main VM.
- Throughput smoke gives a documented number without becoming a flaky benchmark gate.

## Quality Bar

- No normal scheduler is blocked; no panic crosses the NIF boundary.
- Stability is proven under hostile and concurrent input, not assumed.
- `bin/qa_check.sh` is green before the epic commit.

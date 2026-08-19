# EPIC003 Spec: Decoder NIF Resource and API

## Purpose

Own a Rust `OpusDecoder` behind a Rustler resource and expose a documented
`RustyOpus.Decoder` that decodes Opus packets to the PCM-binary contract with
packet-loss concealment, completing the codec core needed for the quality-change feature.

## Reference Inputs

- Roadmap Epics 1 (foundation/data contract), 2 (encoder), and 3 (decoder)
- `opus-rs` `OpusDecoder`: `new(rate, channels)` and
  `decode(&[u8], frame_size, &mut [f32]) -> Result<usize, &'static str>`, including
  implicit PLC for 1-byte ToC-only (lost/DTX) frames
- `RustyOpus.Encoder` output as the primary decode input

## Scope

In scope:

- decoder Rustler resource with `decoder_new/2` and rate/channel validation
- `decoder_decode/3` with capacity-safe PCM output and dirty scheduling
- packet-loss concealment for ToC-only lost/DTX packets
- `RustyOpus.Decoder` (`new/2`, `decode/3`), the PCM output contract, and stable error mapping
- decoder tests: decode our encoder's output, golden packets, channel-mismatch rejection,
  PLC, and resource cleanup

Out of scope: container handling, presets/facade/transcode (Epic 4), robustness fuzzing (Epic 5).

## Acceptance Criteria

- `RustyOpus.Decoder.new/2` accepts documented rates/channels and rejects others.
- `decode/3` returns the PCM-binary contract and never blocks a normal scheduler.
- A packet encoded by `RustyOpus.Encoder` round-trips through the decoder within lossy
  tolerance.
- Lost/DTX packets conceal instead of erroring; channel mismatches error cleanly with a
  stable tagged error.

## Test Strategy

- Round-trip tests encode then decode and compare within `RustyOpus` lossy tolerance.
- Golden/reference packet fixtures (imported in Epic 4 or minimal local goldens) decode to
  a known PCM length/content.
- Channel-mismatch tests craft/expect a stable error.
- Resource tests prove close is idempotent and owner death reclaims the decoder.

## Quality Bar

- Every Opus `&'static str` is translated to a stable tagged `RustyOpus.Error`.
- No panic crosses the NIF boundary; larger decodes run on dirty schedulers.
- `bin/qa_check.sh` is green before the epic commit.

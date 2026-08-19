# EPIC002 Spec: Encoder NIF Resource and API

## Purpose

Own a Rust `OpusEncoder` behind a Rustler resource and expose the full quality-control
surface through a documented `RustyOpus.Encoder` module, proving the bitrate/quality
knobs actually affect the produced packets.

## Reference Inputs

- Roadmap Epics 1 (foundation, data contract, `bin/qa_check.sh`) and 2 (encoder)
- `opus-rs` `OpusEncoder`: `new(rate, channels, Application)`, public fields
  `bitrate_bps`, `complexity`, `use_cbr`, `use_inband_fec`, `packet_loss_perc`,
  and `encode(&[f32], frame_size, &mut [u8]) -> Result<usize, &'static str>`
- Rustler resource registration and dirty-I/O scheduling conventions

## Scope

In scope:

- encoder Rustler resource with `encoder_new/4` and validation of rate/channels/app/options
- f32le-PCM-binary → `&[f32]` marshalling and return contracts
- `encoder_encode/3` with frame-size validation, capacity-safe output, and dirty scheduling
- bitrate_bps, complexity, CBR/VBR (`use_cbr`), in-band FEC, and packet-loss settings,
  including runtime setters where stable
- `RustyOpus.Encoder` (`new/3|4`, `encode/3`), a `RustyOpus.Settings` validation layer,
  and stable `RustyOpus.Error` mapping
- encoder tests: construction validation, round-trip decode sanity, bitrate effect, CBR
  bounded size, and resource cleanup

Out of scope: decoder, container handling, presets/facade/transcode (Epics 3–4).

## Acceptance Criteria

- `RustyOpus.Encoder.new/4` accepts documented settings and rejects invalid
  rates/channels/options with stable tagged errors.
- `encode/3` returns an Opus packet binary and never blocks a normal scheduler.
- Raising bitrate increases (or never shrinks) produced packet size for the same content,
  proving the quality control is real.
- `use_cbr` bounds packet size; VBR is allowed to vary.
- Closing the encoder is idempotent and frees the native resource.

## Test Strategy

- Unit tests on the settings validation layer and error mapping.
- Round-trip sanity: encode PCM, then decode with the encoder-under-Epic-3 to confirm a
  bounded, lossy-tolerance relation (or use a stub/golden decoder until Epic 3 provides it).
- Bitrate-order tests assert `size(high) >= size(medium) >= size(low)`.
- Resource tests prove repeated open/close and owner death return counters to baseline.

## Quality Bar

- Every Opus `&'static str` is translated to a stable tagged `RustyOpus.Error`.
- No panic crosses the NIF boundary; large frames run on dirty schedulers.
- `bin/qa_check.sh` is green before the epic commit.

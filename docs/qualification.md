# ROADMAP004 qualification and frozen conversion contract

**Status:** qualification in progress  
**Threshold freeze:** 2026-08-20, before the first comparative ROADMAP004 corpus run

This document freezes the additive multi-format contract and the mandatory dependency
qualification gates. A candidate that misses a mandatory gate is rejected; the gate is not
relaxed after results are known. Developer-side qualification may use independent tools, but
the library and tests under test never invoke them.

## Public contract

```elixir
@spec RustyOpus.convert(binary() | RustyOpus.PCM.t(), keyword()) ::
        {:ok, binary() | RustyOpus.PCM.t()} | {:error, RustyOpus.Error.t()}

%RustyOpus.PCM{data: f32le_interleaved, sample_rate: rate, channels: 1_or_2}
```

`data` is always little-endian IEEE-754 `f32`, interleaved by channel. File sample
formats are converted at the native boundary and never create another Elixir PCM type.
Decoders return the actual source rate and channel count, except Ogg Opus uses its
specified 48 kHz output clock.

The three dedicated modules expose the same verbs:

```elixir
RustyOpus.OggOpus.decode(blob)
RustyOpus.OggOpus.encode(pcm, opts)
RustyOpus.OggOpus.reencode(blob, opts)

RustyOpus.MP3.decode(blob)
RustyOpus.MP3.encode(pcm, opts)
RustyOpus.MP3.reencode(blob, opts)

RustyOpus.WAV.decode(blob)
RustyOpus.WAV.encode(pcm, opts)
RustyOpus.WAV.reencode(blob, opts)
```

All return `{:ok, value}` or `{:error, %RustyOpus.Error{}}`. Dedicated decoders return
`%RustyOpus.PCM{}`; encoders and re-encoders return a binary in their module's format.

### Common option ownership

| Target | Required | Optional | Rejected as target-inapplicable |
|---|---|---|---|
| `:ogg_opus` | `:to`, `:bitrate` | `:from`, `:bitrate_mode`, `:channels` | `:sample_rate`, `:sample_format` |
| `:mp3` | `:to`, `:bitrate` | `:from`, `:bitrate_mode`, `:sample_rate`, `:channels` | `:sample_format` |
| `:wav` | `:to`, `:sample_format` | `:from`, `:sample_rate`, `:channels` | `:bitrate`, `:bitrate_mode` |
| `:pcm` | `:to` | `:from` for binary input, `:sample_rate`, `:channels` | `:bitrate`, `:bitrate_mode`, `:sample_format` |

`from:` is `:auto`, `:ogg_opus`, `:mp3`, or `:wav`. It is forbidden for PCM-struct
input. Binary auto-detection is structural and never infers arbitrary raw PCM. Unknown,
duplicate, conflicting, or inapplicable options fail before codec work. The common API
does not accept Opus application/complexity/frame duration or an MP3 quality index.

`bitrate` is a positive integer in bits per second. `bitrate_mode` is `:vbr` or `:cbr`
and defaults to `:vbr`. `channels` is `1` or `2`. WAV `sample_format` is `:s16`, `:s24`,
`:s32`, or `:f32`.

### Dedicated option ownership

- Ogg Opus owns `:application`, `:complexity`, `:frame_duration_ms`, and legacy `:cbr`.
  `:cbr` and `:bitrate_mode` conflict when both are supplied.
- MP3 owns a quality index only if independent qualification freezes a reliable range and
  conflict rule. No such option is approved by this contract.
- WAV owns no codec-specific controls beyond its required output `:sample_format`.
- Rate and channel conversion are shared internal transforms, not a public DSP API.

### Compatibility freeze

- `RustyOpus.reencode/2` remains Ogg-Opus-only and retains its existing defaults,
  validation order, accepted options, result shape, and error meanings.
- `RustyOpus.encode/4`, `decode/4`, `transcode/5`, `RustyOpus.Encoder`, and
  `RustyOpus.Decoder` continue to operate on raw Opus packets and bare f32le PCM binaries.
- No existing public function changes arity, defaults, input/output meaning, or error
  reason. Dedicated modules and `%RustyOpus.PCM{}` are additive.
- Stable reason atoms include invalid input/settings/PCM/rate, unsupported format,
  format mismatch, decode/transform/encode failure, allocation bound, and contained panic.
  Backend strings may appear only in the human-readable message.

## Frozen mandatory MP3 gates

The corpus has four content classes: speech, tonal, music-like/dense harmonic, and
transient. Measurements align candidate and reference decodes by normalized
cross-correlation before comparing the common-duration region.

| Area | Mandatory threshold |
|---|---|
| Decode coverage | 100% of committed MPEG-1/2/2.5 Layer III mono/stereo, CBR/VBR, tagless and leading-ID3 fixtures decode without crash and report exact rate/channels. |
| Decode agreement | After delay alignment, correlation with the independent FFmpeg decode is at least `0.9999` and RMS difference is at most `1e-4` for every fixture. |
| Encode interoperability | Every emitted CBR/VBR stream is accepted by FFmpeg 9 and has only legal, mutually consistent Layer III frames. |
| Catastrophic fidelity floor | Delay-aligned correlation is at least `0.90` and segmental SNR is at least `6 dB` for every content/bitrate point. |
| Speech and tonal floor | At 64 kbps mono or 128 kbps stereo and above, correlation is at least `0.97` and segmental SNR is at least `12 dB`. |
| Reference regression | Candidate segmental SNR may trail matched-rate LAME by at most `8 dB` on speech/tonal/music and `12 dB` on transients; the candidate's documented PEAQ gap may not exceed `2.0 ODG` at 128 kbps or above. |
| Duration/delay | Decoded audible duration differs from source by at most one MPEG audio frame plus `20 ms`; no truncated real tail is permitted. |
| CBR accuracy | Aggregate audio-frame bitrate is within `5%` of the requested standard bitrate. |
| VBR accuracy | Aggregate audio-frame bitrate is within `20%` of the numeric target over the complete corpus. |
| Size ordering | Aggregate output at each lower target bitrate is strictly smaller than at the next higher target for both CBR and VBR ladders. |
| Determinism | Three identical runs produce byte-identical encoded output and sample-identical decode output. |
| Failure safety | Empty, truncated ID3, malformed/truncated frame, non-Layer-III, and bounded random input return an error without panic, hang, unbounded scan, or allocation. |
| Boundary | Pure Rust; no C/FFI, build script, system library, process, Port, temporary codec file, runtime dependency, or non-permissive selected license. |
| Toolchain/targets | MSRV is no newer than the project Rust 1.89 pin and locked builds pass for the six supported Apple/Linux gnu/musl targets. |

The selected backend must satisfy all rows. Upstream claims are supporting context, not a
substitute for the project corpus or an independent decoder.

## Candidate shortlist

| Candidate | Version | Decode | Encode | CBR/VBR | License | Initial disposition |
|---|---:|---|---|---|---|---|
| `rusty_mp3` | `0.7.0` | MPEG-1/2/2.5 Layer III | MPEG-1/2/2.5 | both | Apache-2.0 | Advance to full corpus; zero runtime dependencies, Rust 1.85 MSRV. |
| `shine-rs` | `0.1.3` | no | MPEG Layer III | CBR only | LGPL-2.0 | Reject: cannot satisfy decode, VBR, dependency-restraint, or permissive-license gates. |
| `minimp3` family | current published crates | decode only and/or C-backed | no qualified pure-Rust encoder | no | mixed | Reject: cannot satisfy the required pure-Rust encode/decode surface. |
| LAME bindings | current published crates | varies | yes | both | C/FFI, LGPL | Reference only; forbidden as a selected runtime dependency. |

The selected crate remains provisional until the recorded corpus, malformed-input, target,
license, and maintenance gates pass.

## WAV and resampler candidates

| Candidate | Version | Exact role | Gate result |
|---|---:|---|---|
| `hound` | `3.5.1` | Generic `Read`/`Write+Seek` RIFF/WAVE PCM/float | Candidate: Apache-2.0, no runtime dependencies, supports required sample depths and extensible input. Must still pass checked malformed-chunk behavior. |
| Thin in-crate RIFF glue | project source | Same narrow WAV surface | Candidate: smallest dependency count and permits project-specific checked limits; must pass independent reader and chunk-fuzz evidence. |
| `rubato` | `5.0.0` | Fixed-ratio offline resampling | Candidate: Rust 1.87 MSRV, MIT/Apache-2.0, `Fft::process_all` has explicit delay/tail handling; pin only `fft_resampler`, with logging disabled. |
| Linear interpolation | project-local | Fixed-ratio resampling | Reject for production selection: no anti-alias filter, so it cannot meet the downsampling alias-rejection gate. |

The WAV selection is whichever passing option has the smaller audited dependency and
error surface. The resampler must preserve the final partial chunk and keep frame-count
error to at most one output frame for all required rate pairs.

## Supported target and legal matrix

The project matrix is `aarch64-apple-darwin`, `x86_64-apple-darwin`,
`aarch64-unknown-linux-gnu`, `aarch64-unknown-linux-musl`,
`x86_64-unknown-linux-gnu`, and `x86_64-unknown-linux-musl`. The exact Rust toolchain is
1.89.0. Selected dependencies must build from the lockfile on every target.

`rusty_mp3 0.7.0` is Apache-2.0, declares Rust 1.85, has no normal dependencies or build
script, and uses isolated runtime-detected x86 SIMD `unsafe`; non-x86 targets use safe
scalar paths. Any selection must be reflected in `Cargo.toml`, `Cargo.lock`, `NOTICE`, and
`docs/provenance.md`.

## Fixture and result provenance

`test/fixtures/manifest.json` is authoritative for committed fixture hashes and expected
properties. Existing speech PCM originates from the developer-only fixture importer.
ROADMAP004 reference WAV/MP3/Ogg files are independently encoded by the recorded FFmpeg
version through `scripts/import_multiformat_fixtures.sh` into an explicit caller-selected
output directory. Runtime/default tests consume only committed bytes.

## Foundation evidence recorded so far

The first fixture/contract run used FFmpeg 9.0.1, Elixir 1.20.1, Rust/Cargo 1.89.0,
and the exact `rusty_mp3 =0.7.0` lock entry with default features disabled.

```text
mix test test/rusty_opus/roadmap004_contract_test.exs \
  test/rusty_opus/roadmap004_fixture_test.exs \
  test/rusty_opus/multiformat_test.exs
14 tests, 0 failures

scripts/audit_fixtures.sh
fixture audit passed (21 fixtures)
```

The independent decode smoke produced the following metadata and raw decoded frame counts:

| Fixture | Reported rate/channels | Decoded frames |
|---|---:|---:|
| MPEG-1 CBR stereo | 44,100 / 2 | 38,016 |
| MPEG-1 VBR + ID3v2 stereo | 44,100 / 2 | 38,016 |
| MPEG-2 CBR mono | 22,050 / 1 | 28,224 |
| MPEG-2.5 CBR mono | 11,025 / 1 | 14,976 |
| WAV s16 mono | 16,000 / 1 | 19,200 |
| WAV s24 stereo | 48,000 / 2 | 38,400 |
| WAV f32 stereo | 44,100 / 2 | 35,280 |
| Ogg Opus family-0 stereo | 48,000 / 2 | 38,400 |

Two independent fixture imports produced byte-identical files after the importer
canonicalized FFmpeg's random Ogg stream serial and recomputed every page CRC. The manifest
audit rejects missing/unlisted files, duplicate IDs/paths, invalid hashes, incomplete
provenance/metadata, and hash drift.

These are foundation checks, not the completed Phase 6 dossier. Objective MP3 fidelity,
matched LAME regression, CBR/VBR ladders, malformed-input fuzz, WAV/resampler comparative
results, and all six target builds remain required. Until every mandatory result is present
and green, Epic 1 and the MP3/WAV/resampler selections are not complete.

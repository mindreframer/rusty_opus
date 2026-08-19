# RustyOpus

[![Hex.pm](https://img.shields.io/hexpm/v/rusty_opus.svg)](https://hex.pm/packages/rusty_opus)
[![HexDocs](https://img.shields.io/badge/HexDocs-API%20reference-6e4a7e.svg)](https://hexdocs.pm/rusty_opus)
[![CI](https://github.com/mindreframer/rusty_opus/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mindreframer/rusty_opus/actions/workflows/ci.yml)
[![Precompiled NIFs](https://github.com/mindreframer/rusty_opus/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/mindreframer/rusty_opus/actions/workflows/release.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/mindreframer/rusty_opus/blob/main/LICENSE)

Pure-Rust [Opus](https://opus-codec.org/) (RFC 6716) for Elixir, wrapped from the
[`opus-rs`](https://github.com/restsend/opus-rs) codec through Rustler. No C `libopus`,
no external process, no Ogg container handling — just PCM ⇄ Opus packets in one BEAM
process.

**The headline feature: change the encoding quality of audio.** Decode a packet to PCM
and re-encode it at a different bitrate or a `:low`/`:medium`/`:high` preset to trade
size against fidelity.

## Quick start

```elixir
{:ok, encoder} = RustyOpus.Encoder.new(16_000, 1, :voip, bitrate: 24_000)
{:ok, packet} = RustyOpus.Encoder.encode(encoder, pcm, 320)
:ok = RustyOpus.Encoder.close(encoder)

{:ok, decoder} = RustyOpus.Decoder.new(16_000, 1)
{:ok, pcm} = RustyOpus.Decoder.decode(decoder, packet, 320)
:ok = RustyOpus.Decoder.close(decoder)

# Change the encoding quality of a packet:
{:ok, smaller} = RustyOpus.change_quality(packet, 16_000, 1, :low)
{:ok, larger}  = RustyOpus.change_quality(packet, 16_000, 1, :high, target_bitrate: 96_000)
```

## Data contract

- **PCM** — binary of little-endian IEEE-754 `f32` samples, interleaved for stereo.
- **Opus packets** — raw binaries.

RustyOpus targets the raw Opus CODEC. It does not parse, demux, or mux containers
(Ogg/WebM); it never launches an external process. See the [codec guide](docs/codec.md).

## Features

- `RustyOpus.Encoder` — bitrate, complexity, CBR/VBR, in-band FEC, packet-loss controls,
  runtime `set/2`
- `RustyOpus.Decoder` — packet-loss concealment for lost/DTX frames
- `RustyOpus.change_quality/4,5` — decode → re-encode at a new quality
- `RustyOpus.Quality` presets and `:target_bitrate` overrides
- `RustyOpus.PCM` — sample-count, interleave/deinterleave helpers
- Dirty-scheduled codec work that never blocks normal BEAM schedulers
- Panic containment: hostile packets become tagged errors, not crashes
- Checksum-verified precompiled NIFs with source-build fallback

## Supported OS

Precompiled NIFs are published for:

- Apple Silicon macOS (`aarch64-apple-darwin`)
- ARM64 Linux with glibc (`aarch64-unknown-linux-gnu`)
- x86-64 Linux with glibc (`x86_64-unknown-linux-gnu`)

Other targets (e.g. Intel macOS) build from source with `RUSTY_OPUS_BUILD=1` and Rust 1.89.0.

## Technology

| Elixir module | Native crate | Rust package |
| --- | --- | --- |
| `RustyOpus` | `native/rusty_opus_native` | `opus-rs 0.1.29` |

## Development

The authoritative gate:

```sh
bin/qa_check.sh
```

Rust 1.89.0 is pinned. Fixtures come from real speech imported from the audio database
via `scripts/import_fixtures.sh` (committed fixtures are stable; tests need neither the
DB nor ffmpeg).

## Release

1. Bump the version in `mix.exs` and `native/rusty_opus_native/Cargo.toml`.
2. Run `bin/qa_check.sh` and push the green version commit.
3. Tag `v0.1.0`; the release workflow builds and smoke-tests every precompiled NIF,
   verifies the artifact set and digests, generates the checksum manifest, and runs
   no-Rust consumer tests.
4. Publish the Hex package and GitHub release (maintainer step).

## License

RustyOpus is licensed under the [Apache License 2.0](LICENSE). The bundled `opus-rs`
codec is BSD-3-Clause (see [NOTICE](NOTICE) and [provenance](docs/provenance.md)).

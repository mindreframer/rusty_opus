# RustyOpus

[![Hex.pm](https://img.shields.io/hexpm/v/rusty_opus.svg)](https://hex.pm/packages/rusty_opus)
[![HexDocs](https://img.shields.io/badge/HexDocs-API%20reference-6e4a7e.svg)](https://hexdocs.pm/rusty_opus)
[![CI](https://github.com/mindreframer/rusty_opus/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mindreframer/rusty_opus/actions/workflows/ci.yml)
[![Precompiled NIFs](https://github.com/mindreframer/rusty_opus/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/mindreframer/rusty_opus/actions/workflows/release.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/mindreframer/rusty_opus/blob/main/LICENSE)

Pure-Rust in-process audio conversion for Elixir. WAV, MP3, and Ogg Opus blobs are
handled without C codecs, ffmpeg, Ports, or external processes; raw Opus packets remain
available through the compatible packet API.

**Headline:** convert supported file blobs or metadata-carrying PCM with one small API:

```elixir
{:ok, opus} = RustyOpus.convert(mp3_blob, to: :ogg_opus, bitrate: 20_000)
{:ok, wav} = RustyOpus.convert(opus, to: :wav, sample_format: :s16)
{:ok, pcm} = RustyOpus.convert(wav, to: :pcm)
```

That is the whole call. Useful bitrate ladder values:
`8_000`, `12_000`, `16_000`, `20_000`, `24_000`, `32_000`.

## Quick start

```elixir
# Dedicated Ogg Opus re-encode retains its compatibility surface
{:ok, smaller} = RustyOpus.reencode(ogg_blob, bitrate: 20_000)

# WAV/MP3/Ogg Opus conversion uses content detection
{:ok, mp3} = RustyOpus.convert(wav_blob, to: :mp3, bitrate: 64_000, bitrate_mode: :vbr)
{:ok, pcm} = RustyOpus.convert(mp3, to: :pcm)

# Raw packets / PCM (no container)
{:ok, packets} = RustyOpus.encode(pcm, 16_000, 1, bitrate: 24_000)
{:ok, pcm}     = RustyOpus.decode(packets, 16_000, 1)
```

## Data contract

- **Ogg Opus** — RFC 7845 family-0 binaries (`audio/ogg` / `.ogg`) for the dedicated module.
- **MP3** — MPEG Layer III mono/stereo (`audio/mpeg` / `.mp3`), including bounded leading ID3.
- **WAV** — RIFF/WAVE uncompressed integer PCM or IEEE float (`audio/wav` / `.wav`).
- **PCM** — `%RustyOpus.PCM{}` carrying little-endian IEEE-754 `f32`, interleaved for stereo.
- **Opus packets** — raw binaries (no container), unchanged from earlier releases.

Metadata is not preserved, file paths and streaming are not supported, and only mono/stereo
is accepted. WebM, MP4, AAC, FLAC, compressed WAV, and other Ogg mapping families remain out
of scope. Never launches an external process. See the [codec guide](docs/codec.md).

## Features

- `RustyOpus.convert/2` — common WAV/MP3/Ogg Opus/PCM conversion facade
- `RustyOpus.WAV`, `RustyOpus.MP3`, `RustyOpus.OggOpus` — dedicated three-verb file APIs
- `RustyOpus.reencode/2` — backward-compatible Ogg Opus blob → lower bitrate Ogg Opus blob
- `RustyOpus.encode/4`, `decode/4`, `transcode/5` — whole-stream raw packet/PCM path
- `RustyOpus.Encoder` / `Decoder` — per-frame control
- Dirty-scheduled codec work; panic containment at the NIF boundary
- Checksum-verified precompiled NIFs with source-build fallback

## Supported OS

Precompiled NIFs are published for:

- Apple Silicon macOS (`aarch64-apple-darwin`)
- Intel macOS (`x86_64-apple-darwin`)
- ARM64 Linux glibc (`aarch64-unknown-linux-gnu`)
- ARM64 Linux musl / Alpine (`aarch64-unknown-linux-musl`)
- x86-64 Linux glibc (`x86_64-unknown-linux-gnu`)
- x86-64 Linux musl / Alpine (`x86_64-unknown-linux-musl`)

Other targets can build from source with `RUSTY_OPUS_BUILD=1` and Rust 1.89.0.

## Technology

| Elixir module | Native crate | Rust packages |
| --- | --- | --- |
| `RustyOpus` | `native/rusty_opus_native` | `opus-rs 0.1.29`, `rusty_mp3 0.7.0` |

## Development

```sh
bin/qa_check.sh
```

Committed fixtures include an Ogg Opus speech blob for `reencode/2` tests.
Tests need neither a live database nor ffmpeg.

## Release

1. Bump the version in `mix.exs` and `native/rusty_opus_native/Cargo.toml`.
2. Run `bin/qa_check.sh` and push the green version commit.
3. Tag `v0.4.0`; the release workflow builds and smoke-tests every precompiled NIF.
4. Publish the Hex package and GitHub release (maintainer step).

## License

RustyOpus is licensed under the [Apache License 2.0](LICENSE). Bundled codecs:
`opus-rs` (BSD-3-Clause) and `rusty_mp3` (Apache-2.0) — see [NOTICE](NOTICE) and
[provenance](docs/provenance.md).

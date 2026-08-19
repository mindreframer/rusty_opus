# Installation

Add `rusty_opus` to your dependencies:

```elixir
def deps do
  [
    {:rusty_opus, "~> 0.3.1"}
  ]
end
```

## Precompiled NIFs

Precompiled NIFs are published for:

- Apple Silicon macOS (`aarch64-apple-darwin`)
- ARM64 Linux with glibc (`aarch64-unknown-linux-gnu`)
- x86-64 Linux with glibc (`x86_64-unknown-linux-gnu`)

Downloads are checksum-verified through `rustler_precompiled`.

## Source build

Set `RUSTY_OPUS_BUILD=1` (or omit it when no checksum manifest is present) to build the
NIF from source. Requirements:

- Rust 1.89.0 (pinned in `native/rusty_opus_native/rust-toolchain.toml`)
- a C toolchain for `libclang`-based builds is not required; `opus-rs` is pure Rust

## Usage

```elixir
{:ok, encoder} = RustyOpus.Encoder.new(16_000, 1, :voip, bitrate: 24_000)
{:ok, packet} = RustyOpus.Encoder.encode(encoder, pcm, 320)
:ok = RustyOpus.Encoder.close(encoder)

{:ok, decoder} = RustyOpus.Decoder.new(16_000, 1)
{:ok, pcm} = RustyOpus.Decoder.decode(decoder, packet, 320)
:ok = RustyOpus.Decoder.close(decoder)
```

See [codec.md](codec.md) for the data contract and [quality.md](quality.md) for changing
the encoding quality.

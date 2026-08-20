# Codec and conversion API

RustyOpus provides three small in-memory file modules over one PCM contract. No module
uses a path, Port, process, system codec, or temporary codec file.

## Common conversion

```elixir
{:ok, opus} = RustyOpus.convert(mp3_blob, to: :ogg_opus, bitrate: 20_000)
{:ok, mp3} = RustyOpus.convert(wav_blob, to: :mp3, bitrate: 64_000, bitrate_mode: :vbr)
{:ok, wav} = RustyOpus.convert(opus_blob, to: :wav, sample_format: :s16)
{:ok, pcm} = RustyOpus.convert(mp3_blob, to: :pcm)
```

`convert/2` detects RIFF/WAVE, Ogg Opus family 0, and MPEG Layer III bytes. `:from` may
be `:auto` (the default), `:wav`, `:mp3`, or `:ogg_opus`. Detection is structural and
never uses a filename. A `%RustyOpus.PCM{}` input is already typed and cannot supply `:from`.
Bare f32le binaries are never guessed to be PCM.

Target options:

| Target | Required | Allowed shared options |
| --- | --- | --- |
| `:ogg_opus` | `:bitrate` | `:bitrate_mode`, `:channels` |
| `:mp3` | `:bitrate` | `:bitrate_mode`, `:sample_rate`, `:channels` |
| `:wav` | `:sample_format` | `:sample_rate`, `:channels` |
| `:pcm` | none | `:sample_rate`, `:channels` |

Unknown, duplicate, or target-inapplicable options return `%RustyOpus.Error{reason: :invalid_settings}`.
Dedicated settings such as Opus application/complexity and MP3 VBR quality are not accepted
by the common facade.

## Shared PCM

```elixir
%RustyOpus.PCM{data: f32le, sample_rate: 44_100, channels: 2}
```

`data` is interleaved little-endian IEEE-754 `f32`. Only one or two channels are supported;
finite samples, aligned frame bytes, positive rates up to 192 kHz, and a bounded 256 MiB
intermediate are required. Mono-to-stereo duplicates samples. Stereo-to-mono uses
`(left + right) / 2`. A deterministic linear offline resampler is used for requested rate
changes; its output frame count is rounded to the nearest rational duration.

The existing raw APIs still accept bare PCM binaries and raw Opus packet lists. They do not
parse or emit containers.

## Dedicated modules

Each format has `decode/1`, `encode/2`, and `reencode/2` returning `{:ok, value}` or a
stable tagged error. Decoders return `%RustyOpus.PCM{}`.

### WAV

`RustyOpus.WAV` reads RIFF/WAVE PCM and IEEE float mono/stereo, including 8/16/24/32-bit
integer and 32-bit float samples. Unknown chunks and odd chunk padding are skipped. Output
requires `sample_format: :s16 | :s24 | :s32 | :f32`; integer output saturates and rounds
without dither. `:f32` preserves sample bits. Compressed WAV, RF64, RIFX, ADPCM, and
multichannel input are rejected. Output is minimal and does not preserve metadata.

### MP3

`RustyOpus.MP3` supports MPEG-1/2/2.5 Layer III mono/stereo. Leading ID3v2 tags are
validated and skipped. Output requires numeric `:bitrate` in bits/s and accepts standard
Layer III values for the selected sample-rate family. `:bitrate_mode` is `:vbr` by default
or `:cbr`; invalid values are rejected rather than snapped. Output metadata is not copied.
The implementation is pure Rust through the pinned `rusty_mp3 0.7.0` crate.

### Ogg Opus

`RustyOpus.OggOpus` is the file-like RFC 7845 family-0 surface. Decode reports the logical
PCM clock as 48 kHz after pre-skip and final-granule trimming. Encode resamples to 48 kHz,
accepts numeric `:bitrate`, `:bitrate_mode`, and the existing Opus-specific settings. The
legacy `RustyOpus.reencode/2` delegates to this module; raw packet functions remain separate.
`:bitrate_mode` and legacy `:cbr` cannot be supplied together.

## Boundaries and errors

All file work is in memory and dirty-scheduled. Errors use `RustyOpus.Error` with stable
reason atoms including `:invalid_settings`, `:invalid_pcm`, `:format_mismatch`,
`:unsupported_format`, `:decode_failed`, `:encode_failed`, `:allocation_bound`, and
`:codec_panicked`. Metadata, paths, streaming, WebM, MP4, AAC, FLAC, compressed WAV, and
non-family-0 Ogg Opus are intentionally out of scope.

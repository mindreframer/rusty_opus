# Spec: Speech-oriented `reencode/2` profile

## Purpose

Match the MemoMoo FFmpeg speech ladder as closely as `opus-rs` allows, so
`RustyOpus.reencode/2` produces comparable quality and size to:

```text
ffmpeg -c:a libopus -b:a <bitrate> -vbr on -compression_level 10
       -application voip -frame_duration 60 -ac 1 -f ogg
```

## Success criteria

1. `reencode/2` accepts FFmpeg-analogue options and documents defaults.
2. Defaults are speech-oriented: VoIP, complexity 10, VBR (`cbr: false`), 20 ms frames.
3. On a real mono Ogg speech blob at 20 kb/s, output is smaller than the previous
   Audio/default path and within a reasonable band of FFmpeg voip@20ms size
   (not the old ~1.7× overshoot).
4. Invalid options return stable `%RustyOpus.Error{}` reasons.
5. Focused reencode tests pass; package builds from source.

## Scope

- Extend `RustyOpus.reencode/2` options and the `ogg_reencode` NIF.
- Keep demux/mux on the existing thin Ogg path (ADR003).
- Do not add ffmpeg, C libopus, or Ports to the library path.
- Do not publish to Hex in this Spec.

## Options (FFmpeg mapping)

| Option | FFmpeg | Default | Notes |
|--------|--------|---------|-------|
| `:bitrate` | `-b:a` | required | bits/s |
| `:application` | `-application` | `:voip` | `:voip` \| `:audio` \| `:restricted_low_delay` |
| `:complexity` | `-compression_level` | `10` | `0..10` |
| `:cbr` | inverse of `-vbr on` | `false` | `false` = VBR |
| `:frame_duration_ms` | `-frame_duration` | `20` | Opus ms; see limitation |

## Limitation

`opus-rs` rejects 40 ms and 60 ms frames at 48 kHz for this encode path
(60 ms: invalid frame size; 40 ms: unsupported in Hybrid/CELT mode). Closest
supported speech-friendly duration is **20 ms**. Callers requesting unsupported
durations get `{:error, %RustyOpus.Error{reason: :invalid_settings}}`.

Ogg remux packs multiple complete packets per page (≤255 lacing values), like
typical ffmpeg/libopus output, so container overhead stays small.

## Out of scope

- Hex publish / precompiled NIF release pipeline
- Switching the codec crate to `rusty-opus` or libopus
- WebM/MP4 containers
- Consuming-app (moo_courses) worker wiring beyond a local path dependency + listen preview

## Verification

- Unit tests for option validation and speech defaults.
- Local A/B: same source Ogg → RustyOpus vs FFmpeg voip@20ms and voip@60ms;
  report byte sizes and write preview files for listening.

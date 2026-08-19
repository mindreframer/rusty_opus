# Troubleshooting

## The NIF does not load

- Confirm a precompiled artifact exists for your target (`aarch64-apple-darwin`,
  `x86_64-apple-darwin`, `aarch64-unknown-linux-gnu`, `aarch64-unknown-linux-musl`,
  `x86_64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`).
- Or build from source with `RUSTY_OPUS_BUILD=1 mix compile` and Rust 1.89.0 installed.
- A `:bad_lib`/`Function not found` error means the loaded `.so` does not match the
  compiled module — recompile after code changes (`mix clean && mix compile`).

## Errors

| `reason` | Meaning |
| --- | --- |
| `:invalid_rate` | sampling rate not in 8000/12000/16000/24000/48000 |
| `:invalid_settings` | channel count or application invalid |
| `:invalid_setting` | an option value is out of its documented range |
| `:invalid_input` | frame_size/PCM length mismatch or non-binary input |
| `:invalid_pcm` | PCM byte length is not a multiple of 4 |
| `:encode_failed` / `:decode_failed` | the codec rejected the input |
| `:codec_panicked` | the codec panicked on hostile input; the resource is now unusable |
| `:closed` | the codec resource was closed |

## Common issues

- **"expected N f32 samples ... got M"** — the PCM passed to `encode/3` must contain
  exactly `frame_size * channels` samples. Split your buffer into frames first.
- **Decoded audio sounds delayed/short** — `opus-rs` decodes with codec lookahead;
  compare by energy (RMS) rather than per-sample, and buffer a few frames before use.
- **Tiny packets for a quiet clip** — silent frames encode to a few bytes at every
  bitrate; use a loud region to compare bitrate effects.
- **Windows targets** — not yet published; use a source build or a supported target.

## QA

The authoritative quality gate is:

```sh
bin/qa_check.sh
```

It runs Elixir formatting/compile/tests, Rust format/check/clippy/tests, and source,
path, provenance, and package audits.

# EPIC001 Plan: Wire `ruopus` and Ship `reencode/2`

## Progress

- [x] Phase 1.1: Add pinned `ruopus` dependency; update license/provenance notes.
- [x] Phase 1.2: Implement `ogg_reencode` NIF (DirtyCpu, panic-contained, tagged errors).
- [x] Phase 1.3: Stub Native + `RustyOpus.reencode/2` with required `:bitrate`.
- [x] Phase 1.4: Fixture + size/error tests.
- [x] Phase 1.5: `bin/qa_check.sh` green; focused epic commit.

## Implementation Steps

1. Add `ruopus` to `native/rusty_opus_native/Cargo.toml` (exact version pin). Confirm MIT
   and update NOTICE / provenance if the audit scripts require it.
2. In Rust, add `ogg_reencode(env, blob, bitrate) -> Result<Binary, (String, String)>`:
   decode with `ruopus::decode_ogg_opus`, encode with `ruopus::encode_ogg_opus` using
   decoded channel count and `bitrate` as `u32`. Catch panics. Map failures to stable tags.
3. Register DirtyCpu NIF in `lib.rs`; stub on `RustyOpus.Native`.
4. Elixir: `def reencode(blob, opts \\ [])` — require `:bitrate`, call NIF, `rustle` errors.
5. Add `test/fixtures/*.ogg` (small speech Ogg Opus) and `test/rusty_opus/reencode_test.exs`.
6. Run `bin/qa_check.sh`, commit.

## Test Isolation Checklist

- [x] Tests use unique blobs; no shared mutable native state beyond the one-shot NIF.
- [x] Size comparisons use a speech fixture, not silence.
- [x] No ffmpeg / Port in tests.

## Quality Gate

- [x] `RustyOpus.reencode(blob, bitrate: n)` works end-to-end.
- [x] Packet APIs unchanged.
- [x] `bin/qa_check.sh` is green.
- [x] Commit title/body follow the commit rule.

## Commit Rule

```sh
bin/qa_check.sh
```

Only if green and Epic 1 criteria complete:

`roadmap003 - epic 1 - reencode ogg opus blobs at a numeric bitrate`

Body: one call shrinks an Ogg Opus blob via `ruopus`; no ffmpeg; packet APIs unchanged.
Do not bump the version in this commit.

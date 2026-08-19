# Provenance

RustyOpus vendors no third-party source code; it depends on published crates from
crates.io and published Hex packages. This page records the exact upstream revisions
and licenses so a build is reproducible and the third-party surface is auditable.

## Codec: opus-rs

- **Crate:** `opus-rs`
- **Version:** `0.1.29` (pinned exactly with `=0.1.29` in `native/rusty_opus_native/Cargo.toml` and `Cargo.lock`)
- **Repository:** <https://github.com/restsend/opus-rs>
- **License:** BSD-3-Clause (see `NOTICE`)
- **Features:** default `std` + `heap`. The `std` feature enables OS-backed runtime x86
  SIMD detection; the `heap` feature keeps `OpusEncoder`/`OpusDecoder` on the heap so the
  public structs are small and fit ordinary stacks.
- **Edition:** 2024 (requires Rust 1.85+; RustyOpus pins `1.89.0`).

RustyOpus does **not** modify `opus-rs`. It wraps the public `OpusEncoder`/`OpusDecoder`
API through Rustler for packet/PCM work, and uses the same codec behind thin in-crate
Ogg Opus family-0 demux/mux for `RustyOpus.reencode/2` (ADR003). The pinned revision is
exactly what `Cargo.lock` records.

## NIF layer: rustler

- **Crate:** `rustler`
- **Version:** `0.36.2` (pinned exactly)
- **License:** MIT / Apache-2.0
- **NIF version:** 2.15

## Elixir tooling

- `rustler_precompiled` (~> 0.9), Apache/MIT — checksum-verified precompiled NIFs with a
  source-build fallback.
- `ex_doc` (~> 0.40, dev only), Apache-2.0 — documentation.

## License policy

- The RustyOpus package itself is Apache-2.0 (`LICENSE`).
- Third-party licenses are recorded in `NOTICE`. No vendored source is committed; all
  dependencies are pinned in `Cargo.lock` and `mix.lock`.

## Fixtures

- PCM / raw-packet fixtures are imported by `scripts/import_fixtures.sh` (developer-side;
  ffmpeg only there).
- `test/fixtures/moo_audio_versions_1.ogg` is a real MemoMoo `audio_versions` Ogg Opus
  speech blob used by `reencode/2` tests. Tests never open the live SQLite DB.
  The native NIF is always built in **release** mode so multi-second Opus work stays
  in the millisecond–low-second range under `mix test`.

# ADR002: No Container Parsing and No External Process in the Runtime Path

- **Status:** Accepted (narrowed by [ADR003](ADR003-reencode-opus-rs-ogg.md) for `reencode/2`)
- **Date:** ROADMAP001 Epic 1

## Context

The motivating feature is changing the encoding quality of Opus audio. The files in the
source data are Ogg/Opus containers, but the `opus-rs` crate implements only the raw Opus
codec, not the Ogg container. Foreign process use (ffmpeg) would be a deployment and
safety burden.

## Decision

- Packet/PCM APIs target the raw Opus CODEC only. They implement no container parsing,
  demuxing, or muxing (Ogg/WebM, tags, metadata).
- **Exception (ADR003):** `RustyOpus.reencode/2` may demux/mux **Ogg Opus family 0** in
  process via thin in-crate glue and `opus-rs`. No other containers.
- No embedded path shells out to ffmpeg or launches any process, Port, or executable for
  codec or container work.
- ffmpeg is used only by the developer-side fixture-import script
  (`scripts/import_fixtures.sh`) that pre-decodes Ogg/Opus to PCM before files are
  committed as fixtures; runtime and test code never invoke it.

## Consequences

- Small, safe, embeddable surface; no process-lifecycle or foreign container code.
- Callers who need WebM/MP4 (or Ogg outside `reencode/2`) demux/mux in their own layer.
- Fixtures remain usable without the foreign DB or ffmpeg at runtime.

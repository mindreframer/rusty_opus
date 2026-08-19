# ADR002: No Container Parsing and No External Process in the Runtime Path

- **Status:** Accepted
- **Date:** ROADMAP001 Epic 1

## Context

The motivating feature is changing the encoding quality of Opus audio. The files in the
source data are Ogg/Opus containers, but the `opus-rs` crate implements only the raw Opus
codec, not the Ogg container. Foreign process use (ffmpeg) would be a deployment and
safety burden.

## Decision

- RustyOpus targets the raw Opus CODEC only. It implements no container parsing, demuxing,
  or muxing (Ogg/WebM, tags, metadata).
- No embedded path shells out to ffmpeg or launches any process, Port, or executable for
  codec work.
- ffmpeg is used only by the developer-side fixture-import script
  (`scripts/import_fixtures.sh`) that pre-decodes Ogg/Opus to PCM before files are
  committed as fixtures; runtime and test code never invoke it.

## Consequences

- Small, safe, embeddable surface; no process-lifecycle or container code to maintain.
- Callers who need Ogg/WebM must demux/mux in their own layer; RustyOpus stays a codec.
- Fixtures are committed as PCM (and a golden Opus packet) so tests need neither the
  foreign DB nor ffmpeg at runtime.

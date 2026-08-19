# EPIC002 Spec: Whole-Stream Facade

## Purpose

Give callers one-shot functions that open a codec, run the bulk path, and close it,
so encoding a PCM buffer or transcoding a packet list is a single call.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP002.md`
- Epic 1: `Encoder.encode_many/2`, `Decoder.decode_many/2`
- Existing one-shots: `encode_pcm/4`, `decode_packet/4`, `change_quality/5`
- `RustyOpus.Quality.to_settings/2` and `RustyOpus.Settings`

## Scope

In scope:

- `RustyOpus.encode(pcm, rate, channels, opts \\ [])` → `{:ok, [packet]}`.
  Opens an encoder, calls `encode_many`, closes it. `opts` accept encoder settings,
  optional `:frame_size`, optional `:quality` (preset atom or `Settings`), and
  `:application` (default `:audio`).
- `RustyOpus.decode(packets, rate, channels, opts \\ [])` → `{:ok, pcm}`.
  Opens a decoder, calls `decode_many`, closes it. Optional `:frame_size`.
- `RustyOpus.transcode(packets, rate, channels, quality, opts \\ [])` → `{:ok, [packet]}`.
  Bulk-decode then bulk-encode at `quality`. Same quality resolution as
  `change_quality/5` (`:target_bitrate` and Settings keys). One output packet per
  input packet, in order.
- Tests for single-packet equivalence with `change_quality/5`, multi-packet order,
  preset size ordering, and tagged errors.
- README quick start and `RustyOpus` moduledoc lead with these three calls.
  Keep `encode_pcm/4`, `decode_packet/4`, and `change_quality/5` as single-frame helpers.

Out of scope:

- Version bump (Epic 3)
- Changing 0.1.0 function signatures
- File I/O or container handling

## Contract

- `encode/4` of one exact frame equals `[packet]` from `encode_pcm/4` on that frame
  (same rate, channels, settings).
- `transcode/5` of a one-packet list equals `[packet]` from `change_quality/5` on
  that packet (same rate, channels, quality, opts). Because encode pads a short last
  frame, a bulk encode of multi-frame PCM with a remainder will have one extra packet
  versus a strict per-frame loop that dropped the remainder — that is intended.
- Codecs created by the facade are closed on both success and error paths.
- Default `frame_size` is `div(rate, 50)` when omitted.

## Acceptance Criteria

- Converting a whole stream to a lower quality is one call: `transcode/5`.
- Single-packet `transcode/5` matches `change_quality/5`.
- Multi-packet transcode preserves count and order.
- `:low` total encoded size ≤ `:high` for the same input.
- Bad rate/quality/input return tagged `RustyOpus.Error` values.
- README and moduledoc examples do not require a per-frame loop.

## Test Strategy

- Single-packet equivalence: `transcode` vs `change_quality`.
- Multi-packet: count, order, and round-trip through `decode/4` within lossy tolerance.
- Preset ordering on total size (`:low` ≤ `:medium` ≤ `:high`).
- Error cases: invalid rate, unknown quality atom, non-list packets, non-binary PCM.
- Facade close: encoder/decoder counters return to baseline after `encode`/`decode`/`transcode`.

## Quality Bar

- No new modules. Facade functions live on `RustyOpus`.
- One-shots stay documented as single-frame; they are not removed.
- `bin/qa_check.sh` is green before the epic commit.

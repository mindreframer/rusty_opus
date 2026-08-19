# ROADMAP002 — Encode and Transcode a Whole Stream

**Status:** Not started
- **Scope:** Let callers encode a full PCM buffer and transcode a full packet list without a per-frame loop. Version `0.2.0`.
- **Why this is short:** Roadmap 001 already shipped a working per-frame codec. This only adds the missing whole-stream path.

## Current gap

`Encoder.encode/3`, `Decoder.decode/3`, `encode_pcm/4`, `decode_packet/4`, and `change_quality/5` all operate on **one 20 ms frame**. Encoding a file today means slicing PCM in Elixir, calling the NIF once per frame, and concatenating packets. There is no bulk API and no stream-level transcode.

## Goal

A caller can:

```elixir
{:ok, packets} = RustyOpus.encode(pcm, 16_000, 1, quality: :medium)
{:ok, pcm}     = RustyOpus.decode(packets, 16_000, 1)
{:ok, smaller} = RustyOpus.transcode(packets, 16_000, 1, :low)
```

Frame size defaults to 20 ms (`div(rate, 50)`). The last incomplete frame is padded with silence, never truncated. Existing 0.1.0 functions stay unchanged.

## Out of scope

- Ogg/WebM containers and file I/O
- New quality presets or settings keys
- Polish of `close/1` docs, `:invalid_setting` spelling, or moving `rustle/2`
- Release publish (maintainer step)

## How to execute

Three epics, in order. Each epic has a spec and a plan in `@meta/@pm/roadmap002/`. After each epic: `bin/qa_check.sh`, then commit `roadmap002 - epic N - <outcome>`. Check a box only after the work and tests pass.

---

## Epic 1 — Bulk encode and decode

Chunking and the encode/decode loop move into Rust so a whole stream is one NIF call.

- [x] `encoder_encode_many(resource, pcm, frame_size)` — chunk PCM into `frame_size * channels` frames, pad a short last frame with zeros, encode each, return the packet list. Dirty CPU scheduler.
- [x] `decoder_decode_many(resource, packets, frame_size)` — decode each packet with shared decoder state, return one concatenated PCM binary. Dirty CPU scheduler. 1-byte DTX packets still conceal.
- [x] `Encoder.encode_many/2` and `Decoder.decode_many/2`. Optional `:frame_size` (default `div(rate, 50)`).
- [x] Tests: bulk output matches a per-frame loop on the same handle; stereo; remainder is padded not dropped; empty packet list → empty PCM; closed handle → `:closed`; counters return to baseline after open/close.

**Done when:** a multi-second PCM buffer encodes, and a list of packets decodes, in one call each, equivalent to the 0.1.0 per-frame loop.

---

## Epic 2 — Whole-stream facade

One-shot helpers that open a codec, run the bulk path, and close it.

- [ ] `RustyOpus.encode(pcm, rate, channels, opts \\ [])` → `{:ok, [packet]}`. `opts` are encoder settings plus optional `:frame_size` and `:quality`.
- [ ] `RustyOpus.decode(packets, rate, channels, opts \\ [])` → `{:ok, pcm}`. Optional `:frame_size`.
- [ ] `RustyOpus.transcode(packets, rate, channels, quality, opts \\ [])` → `{:ok, [packet]}`. Same quality resolution as `change_quality/5`. One input packet produces one output packet, in order.
- [ ] Tests: `transcode` on a single packet equals `change_quality/5`; multi-packet count and order; `:low` total size ≤ `:high`; bad rate/quality return tagged errors.
- [ ] README quick start and `RustyOpus` moduledoc lead with these three calls. Keep `encode_pcm/4`, `decode_packet/4`, and `change_quality/5` as single-frame helpers.

**Done when:** converting a whole stream to a lower quality is one function call, documented as the default path.

---

## Epic 3 — `0.2.0` and close

- [ ] Bump Mix, Cargo, and lockfiles to `0.2.0`.
- [ ] Changelog and README match the shipped API. Note that 0.1.0 call sites are unchanged.
- [ ] `bin/qa_check.sh` green.
- [ ] Mark this roadmap complete.

**Done when:** `0.2.0` is documented and QA is green. Precompiled artifacts and Hex publish stay with the maintainer.

---

## Success

- `RustyOpus.encode/4`, `decode/4`, and `transcode/5` handle a full stream.
- No common-path caller slices frames or passes `frame_size`.
- 0.1.0 functions still work.
- `bin/qa_check.sh` is green.

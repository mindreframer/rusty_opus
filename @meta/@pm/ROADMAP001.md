# ROADMAP001 — RustyOpus: Pure-Rust Opus Codec for Elixir

- **Status:** In progress
- **Scope:** Initial in-process wrapper around `opus-rs` and `0.1.0` release
- **Primary interface:** Elixir
- **Native implementation:** Rust via Rustler
- **Codec:** pinned pure-Rust `opus-rs` crate (RFC 6716)

## 1. Goal

Build RustyOpus as a standalone Elixir package that exposes the pure-Rust
[`opus-rs`](https://github.com/restsend/opus-rs) Opus codec through Rustler.
An Elixir application must be able to encode PCM audio to Opus packets and decode
Opus packets to PCM with full control over encoding quality and bitrate, without
linking C `libopus`, shelling out to ffmpeg, or starting any external process.

The primary motivating use case is **changing the encoding quality** of audio:
decode an Opus stream to PCM and re-encode it at a different bitrate / complexity /
VBR setting to trade file size against fidelity. RustyOpus must expose the codec
knobs that make that control possible in a small, stable Elixir API.

RustyOpus targets the raw Opus CODEC. It does not implement the Ogg container
or high-level media demuxing; those are out of scope for 0.1.0. Test fixtures are
imported from pre-existing Ogg/Opus audio by decoding them to PCM during fixture
generation, so all runtime tests use raw PCM ↔ Opus packets.

## 2. In Scope

- A normal Mix package named `:rusty_opus` with public `RustyOpus`, `RustyOpus.Encoder`,
  `RustyOpus.Decoder`, and `RustyOpus.Native` modules.
- Rustler NIF loading from the application `priv` directory with a
  `rustler_precompiled` source-build fallback.
- Encoder resource: sampling rate, channels, `Application` (Voip/Audio/RestrictedLowDelay),
  and quality controls (bitrate_bps, complexity, CBR/VBR, in-band FEC, packet-loss).
- Decoder resource: sampling rate and channels, with packet-loss concealment for
  lost/DTX (1-byte ToC) frames.
- A stable PCM contract: binary of little-endian `f32` samples, interleaved for stereo.
- High-level `RustyOpus` facade for encode/decode and for re-encoding ("changing
  the quality") a decoded buffer at a new bitrate/quality profile.
- Quality presets that map readable profiles (e.g. `:low`, `:medium`, `:high`) to
  concrete bitrate/complexity/VBR settings and a `:target_bitrate` override.
- Deterministic, isolated tests using compact real-world PCM fixtures with a lossy
  compare helper.
- Telemetry/diagnostics (light) for encode/decode timings and counters.
- Source builds and a verified precompiled-NIF release matrix for supported targets,
  with a smoke test that the published native artifacts load through the public API.

## 3. Explicitly Deferred

- Ogg/WebM container demuxing or muxing, and any media-container parsing.
- A Port / executable / ffmpeg backend for codec work. ffmpeg is used only by the
  fixture-import script during development, never by runtime or test code.
- File format auto-detection, metadata inspection, or media tags.
- Full libopus option surface not exposed by `opus-rs` (e.g. DTX, variable-duration
  API details) unless trivially free.
- Real-time streaming transport, RTP, jitter buffers, or network codecs.
- Speech-detection, VAD callbacks, or application-level semantic transcoding.
- Windows and musl targets for 0.1.0 (deferred until a verified artifact matrix exists).

## 4. Architecture Principles

1. **Correctness by inheritance:** use `opus-rs`'s encoder/decoder and its quality
   controls directly. Do not reimplement Opus in Elixir.
2. **One process, honest native artifact:** ship a NIF inside the Mix package; no
   child process, Port, or daemon.
3. **Codec state is a resource:** `OpusEncoder`/`OpusDecoder` are owned by Rustler
   resources tied to an Elixir owner, with explicit close and destructor fallback.
4. **Quality change is decode-then-encode:** re-encoding uses the decoder to reach PCM
   and the encoder at the new settings; no raw-packet bitrate surgery.
5. **Stable binary contract:** PCM is little-endian `f32` binary (interleaved),
   Opus packets are raw binaries. No compressed Erlang term marshalling for sample data.
6. **Bounded and dirty:** frame sizes and buffers are validated; large frames run on
   dirty I/O schedulers so normal schedulers are never blocked.
7. **Stable Elixir contract:** Opus `&'static str` errors become documented tagged
   Elixir errors. Panics are contained at the NIF boundary.
8. **Application-neutral package:** no module or test depends on a consuming app.
9. **Minimal dependencies:** Rust side depends only on `opus-rs` and `rustler`;
   Elixir side only on `rustler` and `rustler_precompiled`.

## 5. Required Codec and Quality Invariants

- A valid round-trip (encode → decode, ignoring Opus lossy imprecision) reconstructs
  the source PCM within a documented tolerance for the given bitrate.
- Raising the target bitrate must not shrink the encoded packet size for equivalent
  content, and the quality preset ordering is monotonic in produced size (low < med < high).
- CBR mode produces a bounded packet size; VBR mode is allowed to vary.
- A decoder created for rate `r`/channels `c` rejects packets whose ToC declares a
  different channel count with a stable tagged error.
- Empty input and invalid sampling rates/channels are rejected at construction or call
  time with stable tagged errors, never a crash.
- A 1-byte (ToC-only) packet is treated as a lost/DTX frame and conceals (PLC) rather
  than erroring.
- Encoder/decoder construction validates against the supported rates
  (8000/12000/16000/24000/48000) and channels (1/2).

## 6. Required Native and Lifecycle Invariants

- No embedded path calls `exit`, `abort`, `fork`, installs signal handlers, or installs
  a process-global allocator.
- Rust panics never unwind across a callable NIF boundary; they are caught and reported.
- Resource close is idempotent and rejects further calls with `{:error, :closed}`.
- Elixir owner death releases/nils the native resource so codec memory is reclaimed.
- Repeated open/close in tests returns codec, allocation, and native counters to baseline.
- Loading RustyOpus beside another native library is tested for symbol isolation.

## 7. Quality Policy and Epic Gate

`bin/qa_check.sh` is the single project quality entry point. It must eventually cover:

- Elixir formatting, warnings-as-errors compilation, static analysis, tests, and package checks.
- Rust formatting, pinned-toolchain build/check, Clippy with warnings denied, and Rust tests.
- NIF codec functional tests: round-trip, quality-order, error mapping, lifecycle/
  resource, and scheduler-responsiveness tests.
- License and third-party provenance checks (BSD-3-Clause `opus-rs`, Apache-2.0 rustler).
- Clean source-build and clean precompiled-binary consumer tests.

An epic is complete only when all seven phases, deliverables, and acceptance criteria
are complete. At the end of every epic:

1. Run `bin/qa_check.sh` from the repository root.
2. Fix every failure; do not waive checks to close the epic.
3. Confirm the epic's acceptance criteria and deferred boundaries.
4. Review the diff for generated artifacts, credentials, absolute sibling paths, and unrelated changes.
5. Check phase boxes only after implementation and verification.
6. Commit one focused green epic using `roadmap001 - epic N - <outcome>` and an informative body.

Epics execute in dependency order. Exploration may occur ahead of the current epic,
but later work must not be declared complete before its dependencies.

---

## Epic 1 — Native Foundation, Data Contract, Provenance, and Quality Gate

**Objective:** Establish the standalone Elixir/Rust package, the stable PCM/Opus binary
contract, pinned `opus-rs` provenance, native-safety rules, and the quality gate before
implementing any codec behavior.

### Phases

1. **Define the public boundary:** replace generated hello-world code with documented
   `Encoder`, `Decoder`, facade, settings, error, and native boundaries; state the PCM
   (little-endian `f32` binary, interleaved) and Opus (raw binary) contracts and the
   no-Ogg/no-Port rules.
2. **Bootstrap Rustler:** create `native/rusty_opus_native`, pin the Rust toolchain and
   dependencies, load a minimal NIF, and verify success and translated-error calls.
3. **Pin opus-rs provenance:** record the exact crate version `0.1.29`, BSD-3-Clause
   license, supported features (`std` + `heap`), and third-party license policy.
4. **Establish native-safety rules:** document dirty scheduling, frame/buffer bounds,
   panic containment, resource lifetime, no-process-control, and no-BEAM-scheduler-blocking.
5. **Create the QA command:** add executable `bin/qa_check.sh` with deterministic Elixir
   and Rust format, compile/check, lint, test, and source-audit stages.
6. **Add test foundations and ADRs:** add f32le PCM helpers, a lossy-compare helper,
   native resource counters, a disposable child-BEAM fixture, and ADRs for the data
   contract and the no-Ogg boundary.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 1 criterion, review
   the focused diff, and prepare the green epic commit.

### Deliverables

- Loadable Rustler skeleton with pinned toolchain and `opus-rs` dependency.
- Auditable provenance and data-contract documentation.
- Public/lifecycle contracts and one authoritative QA command.

### Acceptance Criteria

- A test crosses the Elixir/Rust boundary and a translated error cannot crash the VM.
- The package builds without depending on an absolute path or sibling application.
- PCM and Opus binary contracts and the no-Ogg/no-Port boundary are explicit.
- The QA command passes from a clean scaffold.
- No encoder, decoder, or production codec behavior is implemented yet.

---

## Epic 2 — Encoder NIF Resource and API

**Objective:** Own a Rust `OpusEncoder` behind a Rustler resource and expose the full
quality-control surface through a documented Elixir module.

### Phases

1. **Native encoder resource:** register the encoder resource and implement
   `encoder_new(rate, channels, application, settings)` with full validation.
2. **f32le PCM marshalling:** convert the PCM binary contract to `&[f32]` and back
   without copying when possible; reject non-binary and mis-sized input.
3. **Encode NIF:** implement `encoder_encode(resource, pcm, frame_size)` with validated
   frame sizes, capacity-safe output buffers, and dirty-I/O scheduling.
4. **Quality controls:** wire bitrate_bps, complexity, CBR/VBR, in-band FEC, and
   packet-loss settings into the encoder, plus runtime setters where stable.
5. **Elixir Encoder module:** add `RustyOpus.Encoder` with `new/3|4`, `encode/3`, a
   `Settings`/options validation layer, and stable error mapping.
6. **Encoder tests:** construction validation, round-trip decode sanity, bitrate effect
   (higher bitrate → larger/better output), CBR bounded size, and resource cleanup.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 2 criterion, review
   the native diff, and prepare the green epic commit.

### Deliverables

- Encoder Rustler resource with full quality knobs.
- `RustyOpus.Encoder` and validated settings.
- Encoder unit/integration tests.

### Acceptance Criteria

- `RustyOpus.Encoder.new/4` accepts documented settings and rejects invalid
  rates/channels/options with stable tagged errors.
- `encode/3` returns an Opus packet binary and never blocks a normal scheduler.
- Raising bitrate provably increases (or never shrinks) produced packet size for the
  same content, confirming the quality control is real.
- Closing the encoder is idempotent and frees the native resource.

---

## Epic 3 — Decoder NIF Resource and API

**Objective:** Own a Rust `OpusDecoder` behind a Rustler resource and expose a
documented Elixir decoder with packet-loss concealment.

### Phases

1. **Native decoder resource:** register the decoder resource and implement
   `decoder_new(rate, channels)` with validation.
2. **Decode NIF:** implement `decoder_decode(resource, packet, frame_size)` with
   capacity-safe PCM output and dirty-I/O scheduling.
3. **Packet-loss concealment:** handle 1-byte ToC-only packets as lost/DTX frames via
   PLC rather than erroring.
4. **Elixir Decoder module:** add `RustyOpus.Decoder` with `new/2`, `decode/3`, a PCM
   output contract, and stable error mapping.
5. **Decoder tests:** decode our encoder's output, decode golden/reference packets,
   channel-mismatch rejection, PLC for lost frames, and resource cleanup.
6. **Error mapping and lifecycle:** map every surfaced Opus error to a stable tagged
   `RustyOpus.Error`; prove close-on-owner-death and idempotent close.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 3 criterion, review
   the native diff, and prepare the green epic commit.

### Deliverables

- Decoder Rustler resource with PLC.
- `RustyOpus.Decoder` and stable error mapping.
- Decoder unit/integration tests.

### Acceptance Criteria

- `RustyOpus.Decoder.new/2` accepts documented rates/channels and rejects others.
- `decode/3` returns the PCM binary contract and never blocks a normal scheduler.
- Our encoder's output round-trips through the decoder within lossy tolerance.
- Lost/DTX frames conceal instead of erroring, and channel mismatches error cleanly.

---

## Epic 4 — Quality-Change Facade, Presets, and Fixtures

**Objective:** Deliver the motivating feature — changing encoding quality — plus real
audio fixtures imported from the Opus audio database.

### Phases

1. **Facade API:** add `RustyOpus` top-level helpers `encode_pcm/3|4` and
   `decode_packet/3` that construct and own short-lived codec resources.
2. **PCM helpers:** add interleave/deinterleave and sample-count helpers operating on
   the `f32`-binary contract.
3. **Quality presets:** add `:low`/`:medium`/`:high` presets and a `:target_bitrate`
   override that tune bitrate, complexity, and VBR/CBR.
4. **Transcode helper:** add `RustyOpus.change_quality/4` that decodes an Opus-buffer
   stream to PCM and re-encodes at a new quality, returning the re-encoded packets.
5. **Fixture import:** add `scripts/import_fixtures.sh` that reads the Ogg/Opus files
   from the SQLite audio DB, decodes a few short clips to f32le PCM via ffmpeg, and
   writes compact `test/fixtures/` files plus one golden Opus packet fixture.
6. **Quality-change tests:** assert numeric byte-size ordering across presets, that
   re-encoding at lower bitrate shrinks output, and that decode→re-encode stays lossy-
   tolerant vs the source PCM.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 4 criterion, review
   the facade/fixture diff, and prepare the green epic commit.

### Deliverables

- `RustyOpus` facade, presets, and `change_quality/4` transcode helper.
- Real-world PCM and golden-Opus fixtures from the audio DB.
- Quality-change acceptance tests.

### Acceptance Criteria

- `change_quality/4` re-encodes a decoded buffer at a new quality and the output
  ordering matches the preset monotonicity (low < med < high in size).
- Reading quality/lower bitrate observably reduces encoded size for the same content.
- Fixtures import is reproducible offline from the DB and yields stable test files.

---

## Epic 5 — Robustness, Lifecycle, and Concurrency

**Objective:** Prove the codec resources are safe under concurrency, error, and
lifecycle stress, and never block normal BEAM schedulers.

### Phases

1. **Resource ownership and cleanup:** tie each resource to one Elixir owner, prove
   owner-death cleanup, and idempotent close with `{:error, :closed}` after close.
2. **Concurrent codecs:** run many encoders/decoders concurrently and across processes,
   asserting isolation and baseline-returning resource counts.
3. **Dirty-scheduler proof:** execute large-frame encodes/decodes and assert normal
   schedulers remain responsive (e.g. a concurrent timer/heartbeat fires on time).
4. **Error-path coverage:** invalid rates/channels, empty PCM, oversized frames,
   truncated/corrupt packets, non-binary input — all stable tagged errors.
5. **Panic containment and fuzz robustness:** feed random/corrupt `f32`-binary and
   packet input, and verify a disposable child BEAM survives any reactor/internal panic.
6. **Resource baselines and smoke:** repeated open/close and large batches return
   native counters to baseline; add an encode/decode throughput smoke for docs.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 5 criterion, review
   the robustness diff, and prepare the green epic commit.

### Deliverables

- Concurrency, error, panic, and resource-baseline test suites.
- Scheduler-responsiveness proof and throughput smoke.
- Documented bounds for frame sizes and resource counts.

### Acceptance Criteria

- Concurrent and repeated lifecycle leave no leaked resource or growing counter.
- No large-frame encode/decode blocks a normal BEAM scheduler.
- All corrupt/invalid inputs return stable tagged errors; a child BEAM survives fuzz.
- Resource close and owner death are deterministic and idempotent.

---

## Epic 6 — Documentation, License, and Package Content

**Objective:** Produce professional, consistent library metadata, documentation, and
package content matching the other maintained libraries.

### Phases

1. **README:** add badges (Hex, HexDocs, CI, precompiled, license), a quality-change
   quickstart, the PCM/Opus contract, supported targets, and a release section.
2. **Docs pages:** add `docs/installation.md`, `docs/codec.md`, `docs/quality.md`,
   `docs/troubleshooting.md`, and `docs/provenance.md` under ExDoc extras.
3. **Legal material:** add Apache-2.0 `LICENSE`, a `NOTICE` recording the BSD-3-Clause
   `opus-rs` third-party license and revision, `CHANGELOG.md`, and `SECURITY.md`.
4. **Mix packaging:** set `description`, `source_url`, `docs`, `package` files,
   maintainers, licenses, and links in `mix.exs`.
5. **Package inspect:** add a `scripts/package_check.sh` that builds/unpacks the Hex
   package and checks `checksum-*.exs`, docs, licenses, and excludes build artifacts.
6. **Telemetry (light):** add minimal `:telemetry`/counter events for encode/decode
   durations and error counts when cheap, otherwise document counters only.
7. **Pass the epic gate:** run `bin/qa_check.sh`, verify every Epic 6 criterion, review
   the docs/content diff, and prepare the green epic commit.

### Deliverables

- Versioned README with badges and quality-change quickstart.
- ExDoc documentation set and legal/security material.
- Hex-ready `mix.exs` and a package-content check.

### Acceptance Criteria

- README and docs match the implemented API and are internally consistent.
- License and provenance material record `opus-rs` BSD-3-Clause and pinned revision.
- The unpacked Hex package contains docs, `checksum-*.exs`, and no build caches or
  absolute sibling paths.

---

## Epic 7 — CI, Precompiled Matrix, and Release Readiness

**Objective:** Wire CI, the precompiled-NIF release matrix with checksums and
loadability smoke tests, and a clean release commit — while leaving the final publish
to the maintainer.

### Phases

1. **Source QA CI:** add `.github/workflows/ci.yml` running `bin/qa_check.sh` on push/PR
   with pinned OTP/Elixir and Rust, and make it green from a clean run.
2. **Precompiled matrix workflow:** add `.github/workflows/release.yml` building the
   pinned `rusty_opus_native` release NIF for the supported targets and attaching
   `librusty_opus_native-vX-nif-2.15-<target>` archives on tag `v*`.
3. **Loadability smoke:** in the matrix job, smoke the exact archived NIF through the
   public `RustyOpus` API, and add a no-Rust `rustler_precompiled.download` consumer job.
4. **Checksums and artifact set:** generate `checksum-Elixir.RustyOpus.Native.exs` only
   from published binaries and validate the exact artifact set/digests before any publish.
5. **Clean consumers:** add `scripts/clean_consumer.sh` for source-build and no-Rust
   precompiled consumers from clean temporary Mix projects.
6. **Release conformance:** run full QA, package, license, clean-consumer, and artifact
   verification; bump to `0.1.0`; sync changelog/docs/readme/checksums.
7. **Pass the final epic gate:** run `bin/qa_check.sh` from a clean checkout, ensure CI
   and matrix are green, and prepare the `0.1.0` release commit. Do not run the final
   publish; leave it for the maintainer.

### Deliverables

- Green source-QA CI workflow.
- Precompiled-NIF release matrix with checksums, smoke, and loadability consumers.
- Release-ready Hex package contents and a final `0.1.0` commit.

### Acceptance Criteria

- CI runs the authoritative QA gate and is green on `main`.
- Every supported precompiled artifact is smoke-tested and loadable through the public
  API, and all digests/checksums validate.
- Clean source and no-Rust consumers compile and run without sibling paths or cached
  native artifacts.
- Release pipeline is ready to tag, but the final publish step remains explicitly for
  the maintainer.

---

## 8. Epic Dependency Order

```text
Epic 1: foundation, data contract, provenance, and QA
   ↓
Epic 2: encoder NIF resource and API
   ↓
Epic 3: decoder NIF resource and API
   ↓
Epic 4: quality-change facade, presets, and fixtures
   ↓
Epic 5: robustness, lifecycle, and concurrency
   ↓
Epic 6: documentation, license, and package content
   ↓
Epic 7: CI, precompiled matrix, and release readiness
```

## 9. Initial Technical Direction

Exact versions are pinned during implementation and must be validated together. The
intended stack is:

- Rustler `=0.36.2` for NIF loading, resources, term encoding, and dirty scheduling.
- `rustler_precompiled ~> 0.9` for checksum-verified precompiled artifacts with a
  source-build fallback (`FORCE_BUILD`/no-checksum), NIF version 2.15.
- `opus-rs =0.1.29` (BSD-3-Clause) for the codec, using default `std` + `heap` features.
- Rust toolchain pinned to `1.89.0` (supports the edition-2024 `opus-rs` crate), in
  `native/rusty_opus_native/rust-toolchain.toml` and the QA/CI commands.
- OTP 27.3 / Elixir 1.20.1 in CI (local dev may be newer).
- f32 little-endian binary PCM across the Elixir/Rust boundary; raw-binary Opus packets.
- `:telemetry` only if trivially free; otherwise documented native counters.
- Disposable child BEAMs and a classic `bin/qa_check.sh` for the quality gate.

No committed build, QA path, or release may depend on `/Users/...`, the fixture SQLite
DB path, `../opus` sources, or another machine-specific checkout. The fixture DB is
referenced only by the developer-side import script.

## 10. Definition of Initial Success

RustyOpus is initially successful when an ordinary Elixir application can install one
dependency and, inside one BEAM OS process:

- create an encoder and decoder at common rates/channels;
- encode `f32`-binary PCM to Opus packets and decode them back within lossy tolerance;
- change the encoding quality of decoded audio (decode → re-encode at a new bitrate or
  preset) with observably monotonic size behavior;
- control bitrate, complexity, and CBR/VBR for a given encoding;
- survive invalid/corrupt input, concurrent usage, owner death, and repeated lifecycle
  with stable tagged errors and no leaked resources;
- never block a normal BEAM scheduler during large-frame codec work;
- load verified precompiled NIFs on the supported target matrix and build from source
  when no artifact is available.

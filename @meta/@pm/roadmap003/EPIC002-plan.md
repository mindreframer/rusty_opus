# EPIC002 Plan: Docs, Fixtures, and `0.3.0`

## Progress

- [x] Phase 2.1: README + moduledoc lead with `reencode/2` and numeric bitrates.
- [x] Phase 2.2: Changelog + fixture note; bump Mix/Cargo/lockfiles to `0.3.0`.
- [x] Phase 2.3: `bin/qa_check.sh`, mark ROADMAP003 Complete, focused commit.

## Implementation Steps

1. Rewrite README quick start to show `RustyOpus.reencode(ogg, bitrate: 20_000)` first;
   demote packet APIs to “raw Opus packets / PCM”.
2. Add `0.3.0` changelog: Ogg Opus reencode via `ruopus`, numeric bitrate only, no ffmpeg.
3. Set version `0.3.0` in Mix and Cargo; refresh lockfiles; confirm Native `base_url` uses version.
4. Set ROADMAP003 status to Complete with a short close summary. Run `bin/qa_check.sh`.
5. Commit. Do not tag/publish unless the maintainer asks (release monitoring is separate).

## Test Isolation Checklist

- [x] Docs examples match real function names/arities.
- [x] No new shared temp paths.

## Quality Gate

- [x] Version is `0.3.0` everywhere declared.
- [x] README leads with blob reencode.
- [x] ROADMAP003 Complete.
- [x] `bin/qa_check.sh` green.
- [x] Commit rule followed; no Hex publish.

## Commit Rule

```sh
bin/qa_check.sh
```

Only if green and Epic 2 complete:

`roadmap003 - epic 2 - bump to 0.3.0 and document ogg reencode`

Body: version bump; Ogg blob reencode documented as the default file-like path;
publish remains the maintainer’s step.

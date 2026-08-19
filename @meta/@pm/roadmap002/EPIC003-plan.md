# EPIC003 Plan: 0.2.0 and Roadmap Close

## Progress

- [x] Phase 3.1: Bump Mix, Cargo, and lockfiles to `0.2.0`.
- [x] Phase 3.2: Changelog and README match the shipped API; 0.1.0 call sites noted as unchanged.
- [x] Phase 3.3: Run `bin/qa_check.sh`, mark ROADMAP002 complete, and prepare the focused commit.

## Implementation Steps

1. Set version `0.2.0` in `mix.exs` and `native/rusty_opus_native/Cargo.toml`. Refresh
   lockfiles if the version field is recorded there. Confirm `RustyOpus.Native`
   precompiled `base_url` still interpolates `v#{version}`.
2. Add a `0.2.0` changelog section: bulk `encode_many`/`decode_many`, facade
   `encode/4` `decode/4` `transcode/5`, default 20 ms frames, last-frame silence padding,
   0.1.0 API unchanged. Align README feature list and quick start with Epic 2.
3. Set ROADMAP002 status to Complete and add a one-paragraph close summary. Run
   `bin/qa_check.sh` from the repository root, fix every failure, then commit.

## Test Isolation Checklist

- [x] No new shared temp paths or codec handles.
- [x] Changelog/README examples match actual function names and arities.

## Quality Gate

- [x] Version is `0.2.0` everywhere it is declared.
- [x] Changelog and README match the shipped API.
- [x] ROADMAP002 is marked complete.
- [x] `bin/qa_check.sh` is green.
- [x] Commit title and body follow the commit rule. No publish step.

## Commit Rule

After implementation, run only the repository gate from the repository root:

```sh
bin/qa_check.sh
```

Only if it passes and all Epic 3 criteria are complete, create one focused commit:

`roadmap002 - epic 3 - bump to 0.2.0 and close the roadmap`

The body must state the version bump, that the whole-stream API is documented, and that
publish remains the maintainer's step. Do not tag, upload artifacts, or run `mix hex.publish`.

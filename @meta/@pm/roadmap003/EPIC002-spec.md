# EPIC002 Spec: Docs, Fixtures, and `0.3.0`

## Purpose

Make `reencode/2` the documented default for Ogg Opus size reduction, ship a real
fixture, bump to `0.3.0`, and close ROADMAP003. Publish stays with the maintainer.

## Reference Inputs

- Roadmap: `@meta/@pm/ROADMAP003.md`
- Epic 1: `RustyOpus.reencode/2` + `ruopus`
- Version sources: `mix.exs`, `Cargo.toml`, lockfiles, `CHANGELOG.md`, `README.md`

## Scope

In scope:

- README quick start and `RustyOpus` moduledoc: Ogg blob reencode with numeric bitrate first.
- Docs note MemoMoo-style ladder (`8_000`, `12_000`, `16_000`, `20_000`, `24_000`, `32_000`).
- Ensure fixture used in tests is committed and documented.
- Version `0.3.0` across Mix, Cargo, lockfiles, changelog.
- Mark ROADMAP003 Complete after green QA.

Out of scope:

- Precompiled release publish / Hex publish (maintainer)
- Extra container formats
- Removing `:low` presets from the old Quality module (leave; just don’t lead with them)

## Acceptance Criteria

- A new user reading README can shrink an Ogg Opus blob with one shown call and a number.
- `mix.exs` and `Cargo.toml` report `0.3.0`.
- ROADMAP003 status Complete with a one-paragraph close summary.
- `bin/qa_check.sh` green.

## Test Strategy

- No new codec surface unless docs/examples break doctests/QA.
- Rely on Epic 1 tests + full QA gate.

## Quality Bar

- Version strings consistent.
- Agent does not publish Hex.
- `bin/qa_check.sh` green before commit.

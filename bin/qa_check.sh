#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
export MIX_ENV=test
export RUST_BACKTRACE=1
export RUSTY_OPUS_BUILD=1

stage() { printf '\n==> %s\n' "$1"; }

stage "Version parity"
scripts/project_version.sh

stage "Elixir dependencies"
mix deps.get --check-locked
mix deps.unlock --check-unused

stage "Elixir format"
mix format

stage "Elixir compile"
mix compile --warnings-as-errors

stage "Elixir tests"
mix test

stage "Rust format"
cargo +1.89.0 fmt --manifest-path native/rusty_opus_native/Cargo.toml --

stage "Rust check and Clippy"
cargo +1.89.0 check --locked --manifest-path native/rusty_opus_native/Cargo.toml
cargo +1.89.0 clippy --locked --manifest-path native/rusty_opus_native/Cargo.toml --all-targets -- -D warnings

stage "Rust tests"
cargo +1.89.0 test --locked --manifest-path native/rusty_opus_native/Cargo.toml

stage "Source, path, and provenance audits"
scripts/audit_source.sh

if [ -f scripts/package_check.sh ]; then
  stage "Documentation and package contents"
  scripts/package_check.sh
fi

if [ -f scripts/clean_consumer.sh ]; then
  stage "Clean source consumer"
  scripts/clean_consumer.sh
fi

printf '\nAll RustyOpus QA checks passed.\n'

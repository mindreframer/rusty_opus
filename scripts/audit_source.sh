#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if git grep -nIE '(/Users/[^ ]+|/home/[^ ]+|\.\./rusty_opus|\.\./opus)' -- . \
  ':(exclude)@meta/**' ':(exclude)AGENTS.md' ':(exclude)scripts/audit_source.sh' \
  ':(exclude)scripts/import_fixtures.sh' ':(exclude)scripts/package_check.sh' ':(exclude)bin/qa_check.sh' ':(exclude)*.md'; then
  echo "machine-specific or sibling path found" >&2
  exit 1
fi

if grep -RInE '(std::process::(exit|abort|Command)|libc::(fork|daemon|_exit)|Command::new)' \
  native/rusty_opus_native/src native/rusty_opus_native/build.rs; then
  echo "forbidden process-control use in embedded native source" >&2
  exit 1
fi

if grep -RInE '(System\.cmd|Port\.open|:os\.cmd|System\.shell)' lib; then
  echo "forbidden process/Port use in the Elixir library path" >&2
  exit 1
fi

if grep -RInE --include='*.ex' --include='*.exs' \
  '(System\.cmd|Port\.open|:os\.cmd)[^\n]*(ffmpeg|ffprobe|lame|sox)' test; then
  echo "external codec invocation found in tests under test" >&2
  exit 1
fi

if grep -RInE '(#\[link|pkg[_-]?config|vcpkg|libmp3lame|lame_sys)' \
  native/rusty_opus_native/src native/rusty_opus_native/Cargo.toml; then
  echo "system codec/FFI linkage found in the native runtime" >&2
  exit 1
fi

grep -Fq 'rusty_mp3 = { version = "=0.7.0", default-features = false }' \
  native/rusty_opus_native/Cargo.toml
grep -Fq 'name = "rusty_mp3"' native/rusty_opus_native/Cargo.lock
grep -Fq 'version = "0.7.0"' native/rusty_opus_native/Cargo.lock
grep -Fq 'checksum = "3fd89ed8a368cceb87ffcc9f3f128fff535ff1cd3ad27e4e64406c29d307a956"' \
  native/rusty_opus_native/Cargo.lock

if git grep -nIE '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16})' -- . \
  ':(exclude)scripts/audit_source.sh'; then
  echo "possible committed credential" >&2
  exit 1
fi

[ -f docs/provenance.md ]
[ -f docs/qualification.md ]
grep -q '0.1.29' docs/provenance.md
grep -q '0.7.0' docs/provenance.md
grep -q 'BSD-3-Clause' docs/provenance.md
grep -q 'Apache-2.0' docs/provenance.md

echo "source audit passed"

#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

package_dir=.ci/package
rm -rf "$package_dir"
mkdir -p .ci

mix hex.build --unpack --output "$package_dir"

# Required package contents
for file in README.md LICENSE NOTICE CHANGELOG.md SECURITY.md mix.exs .formatter.exs; do
  test -f "$package_dir/$file" || { echo "package is missing $file" >&2; exit 1; }
done

# A checksum manifest becomes mandatory once one exists at the root (generated
# from published binaries in the release workflow).
if ls checksum-*.exs >/dev/null 2>&1; then
  test -f "$package_dir/checksum-Elixir.RustyOpus.Native.exs" || {
    echo "package is missing checksum-Elixir.RustyOpus.Native.exs" >&2
    exit 1
  }
fi

for doc in docs/installation.md docs/codec.md docs/quality.md docs/provenance.md docs/qualification.md docs/troubleshooting.md; do
  test -f "$package_dir/$doc" || { echo "package is missing $doc" >&2; exit 1; }
done

test -f "$package_dir/test/fixtures/manifest.json" || { echo "package is missing fixture manifest" >&2; exit 1; }

# Native source must be packaged for source builds
for src in native/rusty_opus_native/Cargo.toml native/rusty_opus_native/Cargo.lock \
           native/rusty_opus_native/build.rs native/rusty_opus_native/rust-toolchain.toml \
           native/rusty_opus_native/src/lib.rs native/rusty_opus_native/src/encoder.rs \
           native/rusty_opus_native/src/decoder.rs native/rusty_opus_native/src/ogg.rs \
           native/rusty_opus_native/src/mp3.rs native/rusty_opus_native/src/wav.rs; do
  test -f "$package_dir/$src" || { echo "package is missing $src" >&2; exit 1; }
done

# Forbidden contents
if find "$package_dir" -path '*/target/*' -o -name '*.o' -o -name '*.rlib' | grep -q .; then
  echo "package contains native build artifacts" >&2
  exit 1
fi

if grep -rnE '/Users/|/home/' "$package_dir" >/dev/null 2>&1; then
  echo "package contains machine-specific absolute paths" >&2
  exit 1
fi

if grep -rnE '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16})' "$package_dir" >/dev/null 2>&1; then
  echo "package contains a possible credential" >&2
  exit 1
fi

rm -rf "$package_dir"

echo "package check passed"

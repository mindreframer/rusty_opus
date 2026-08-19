#!/usr/bin/env bash
# Package a built rusty_opus_native library into a rustler_precompiled archive.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <project-version> <nif-version> <target>" >&2
  exit 64
fi

project_version=$1
nif_version=$2
target=$3
crate=rusty_opus_native
crate_dir=native/rusty_opus_native

lib_prefix=lib
source_suffix=.so
case "$target" in
  *-apple-*) source_suffix=.dylib ;;
  *-pc-windows-*) lib_prefix=; source_suffix=.dll ;;
esac

# RustlerPrecompiled uses .so in macOS archive names even though Cargo emits a dylib.
archive_suffix=$source_suffix
case "$target" in
  *-apple-*) archive_suffix=.so ;;
esac

# Container builds may set CARGO_TARGET_DIR to .../target/<triple>
if [[ -n "${CARGO_TARGET_DIR:-}" ]]; then
  source_dir="${CARGO_TARGET_DIR}/release"
else
  source_dir="$crate_dir/target/$target/release"
fi

source_file="$source_dir/${lib_prefix}${crate}${source_suffix}"
final_name="${lib_prefix}${crate}-v${project_version}-nif-${nif_version}-${target}${archive_suffix}"
archive_name="${final_name}.tar.gz"

if [[ ! -f "$source_file" ]]; then
  echo "error: missing compiled NIF: $source_file" >&2
  exit 1
fi

cp "$source_file" "$source_dir/$final_name"
tar -C "$source_dir" -czf "$PWD/$archive_name" "$final_name"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "file-name=$archive_name"
    echo "file-path=$GITHUB_WORKSPACE/$archive_name"
  } >> "$GITHUB_OUTPUT"
fi

printf 'Packaged %s\n' "$archive_name"

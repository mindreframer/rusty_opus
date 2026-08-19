#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

mode=${1:-source}
case "$mode" in
  source | --source) mode=source ;;
  precompiled | --precompiled) mode=precompiled ;;
  *) echo "usage: $0 [--source|--precompiled]" >&2; exit 2 ;;
esac

if [ "$mode" = "precompiled" ] && [ ! -f checksum-Elixir.RustyOpus.Native.exs ]; then
  echo "no checksum manifest; precompiled consumer skipped (generate it from published artifacts)"
  exit 0
fi

consumer_root=$(mktemp -d /tmp/rusty_opus-consumer.XXXXXX)
trap 'rm -rf "$consumer_root"' EXIT

mkdir -p "$consumer_root/lib"

cat > "$consumer_root/mix.exs" <<EOF
defmodule RustyOpusConsumer.MixProject do
  use Mix.Project
  def project do
    [
      app: :rusty_opus_consumer,
      version: "0.0.1",
      elixir: "~> 1.15",
      deps: deps()
    ]
  end
  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:rusty_opus, path: "$root"}]
end
EOF

export MIX_ENV=prod
unset FORCE_BUILD

if [ "$mode" = "precompiled" ]; then
  # Prove the NIF loads from the precompiled artifact without a Rust toolchain.
  no_rust="$consumer_root/no-rust"
  mkdir -p "$no_rust"
  for command in cargo rustc; do
    cat > "$no_rust/$command" <<'STUB'
#!/usr/bin/env sh
echo "error: precompiled consumer attempted to invoke Rust" >&2
exit 97
STUB
    chmod +x "$no_rust/$command"
  done
  export PATH="$no_rust:$PATH"
  unset RUSTLER_PRECOMPILED_FORCE_BUILD_ALL FORCE_BUILD
else
  export RUSTY_OPUS_BUILD=1
fi

cd "$consumer_root"
mix local.hex --force >/dev/null 2>&1 || true
mix deps.get >/dev/null
mix compile --warnings-as-errors
mix run --no-start "$root/scripts/smoke_consumer.exs"

echo "clean $mode consumer passed"
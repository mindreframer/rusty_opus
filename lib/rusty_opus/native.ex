defmodule RustyOpus.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]
  checksum = Path.expand("../../checksum-Elixir.RustyOpus.Native.exs", __DIR__)

  force_build =
    System.get_env("RUSTY_OPUS_BUILD") in ["1", "true"] or not File.regular?(checksum)

  use RustlerPrecompiled,
    otp_app: :rusty_opus,
    crate: "rusty_opus_native",
    base_url: "https://github.com/mindreframer/rusty_opus/releases/download/v#{version}",
    force_build: force_build,
    version: version,
    targets: [
      "aarch64-apple-darwin",
      "x86_64-apple-darwin",
      "aarch64-unknown-linux-gnu",
      "x86_64-unknown-linux-gnu"
    ],
    nif_versions: ["2.15"],
    cargo: {:rustup, "1.89.0"},
    mode: if(Mix.env() == :prod, do: :release, else: :debug)

  def smoke, do: :erlang.nif_error(:nif_not_loaded)
  def translated_error, do: :erlang.nif_error(:nif_not_loaded)
  def contained_panic, do: :erlang.nif_error(:nif_not_loaded)
end

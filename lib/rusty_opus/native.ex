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
      "aarch64-unknown-linux-musl",
      "x86_64-unknown-linux-gnu",
      "x86_64-unknown-linux-musl"
    ],
    nif_versions: ["2.15"],
    cargo: {:rustup, "1.89.0"},
    # Always release: debug Opus encode is orders of magnitude too slow for CI.
    mode: :release

  def smoke, do: :erlang.nif_error(:nif_not_loaded)
  def translated_error, do: :erlang.nif_error(:nif_not_loaded)
  def contained_panic, do: :erlang.nif_error(:nif_not_loaded)

  def encoder_new(_rate, _channels, _application, _settings),
    do: :erlang.nif_error(:nif_not_loaded)

  def encoder_encode(_resource, _pcm, _frame_size), do: :erlang.nif_error(:nif_not_loaded)

  def encoder_encode_many(_resource, _pcm, _frame_size),
    do: :erlang.nif_error(:nif_not_loaded)

  def encoder_set(_resource, _settings), do: :erlang.nif_error(:nif_not_loaded)
  def encoder_close(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def encoder_count, do: :erlang.nif_error(:nif_not_loaded)

  def decoder_new(_rate, _channels), do: :erlang.nif_error(:nif_not_loaded)
  def decoder_decode(_resource, _packet, _frame_size), do: :erlang.nif_error(:nif_not_loaded)

  def decoder_decode_many(_resource, _packets, _frame_size),
    do: :erlang.nif_error(:nif_not_loaded)

  def decoder_close(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def decoder_count, do: :erlang.nif_error(:nif_not_loaded)

  def wav_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
  def wav_encode(_pcm, _rate, _channels, _sample_format), do: :erlang.nif_error(:nif_not_loaded)
  def mp3_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
  def mp3_encode(_pcm, _rate, _channels, _settings), do: :erlang.nif_error(:nif_not_loaded)
  def ogg_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
  def ogg_encode(_pcm, _channels, _settings), do: :erlang.nif_error(:nif_not_loaded)
  def ogg_reencode(_blob, _settings), do: :erlang.nif_error(:nif_not_loaded)
end

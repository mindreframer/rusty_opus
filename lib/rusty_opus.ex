defmodule RustyOpus do
  @moduledoc """
  Pure-Rust [Opus](https://opus-codec.org/) (RFC 6716) for Elixir, wrapped from the
  `opus-rs` codec through Rustler.

  RustyOpus encodes PCM audio to Opus packets and decodes Opus packets to PCM, with
  full control over encoding bitrate and quality so you can **change the quality of an
  encoding**: decode audio to PCM and re-encode it at a different bitrate or a
  `:low`/`:medium`/`:high` preset.

  ## Data contract

  - **PCM** is a binary of 32-bit little-endian IEEE-754 `f32` samples, interleaved
    for stereo. This is the stable PCM contract used by `RustyOpus.Encoder` and
    `RustyOpus.Decoder`.
  - **Opus packets** are raw binaries.

  ## Boundary

  RustyOpus targets the raw Opus CODEC. It does not parse, demux, or mux media
  containers (such as Ogg/Opus `.ogg` files). It never launches an external process,
  a Port, or an executable for codec work. See `RustyOpus.Encoder` and
  `RustyOpus.Decoder` for the codec API and `RustyOpus.change_quality/4` for
  re-encoding at a new quality.
  """

  @doc """
  Returns the loaded native library version as `{:ok, version}`.

  This proves the Elixir/Rust boundary is live. It fails with `{:error, ...}` if the
  NIF is not loaded.
  """
  @spec native_smoke() :: {:ok, String.t()} | {:error, term()}
  def native_smoke do
    case RustyOpus.Native.smoke() do
      {:ok, version} -> {:ok, version}
      other -> {:error, other}
    end
  end

  @doc """
  Translates a deterministic native error into a stable `RustyOpus.Error`.
  """
  @spec translated_error() :: {:error, RustyOpus.Error.t()}
  def translated_error do
    {:error, rustle(:native, "deterministic native error")}
  end

  @doc """
  Runs a contained native panic and reports `{:error, :contained_panic}`.

  The panic never unwinds across the NIF boundary, so the caller BEAM is untouched.
  """
  @spec contained_panic() :: {:error, :contained_panic} | {:ok, term()}
  def contained_panic do
    case RustyOpus.Native.contained_panic() do
      {:error, :contained_panic, _} -> {:error, :contained_panic}
      other -> {:ok, other}
    end
  end

  @doc false
  def rustle(reason, message) do
    %RustyOpus.Error{reason: normalize_reason(reason), message: message}
  end

  @reasons %{
    "native" => :native,
    "closed" => :closed,
    "poisoned" => :poisoned,
    "invalid_pcm" => :invalid_pcm,
    "invalid_input" => :invalid_input,
    "invalid_settings" => :invalid_settings,
    "invalid_application" => :invalid_application,
    "invalid_rate" => :invalid_rate,
    "encode_failed" => :encode_failed,
    "decode_failed" => :decode_failed
  }

  defp normalize_reason(reason) when is_binary(reason), do: Map.get(@reasons, reason, reason)
  defp normalize_reason(reason), do: reason
end

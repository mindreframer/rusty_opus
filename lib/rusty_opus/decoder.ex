defmodule RustyOpus.Decoder do
  @moduledoc """
  Opus decoder backed by the `opus-rs` codec through Rustler.

  Decodes raw Opus packets into PCM (the little-endian `f32` binary contract,
  interleaved for stereo). A 1-byte (ToC-only) packet is treated as a lost/DTX frame
  and concealed (packet-loss concealment) rather than rejected.

  ## Example

      {:ok, decoder} = RustyOpus.Decoder.new(16_000, 1)
      {:ok, pcm} = RustyOpus.Decoder.decode(decoder, packet, 320)
      :ok = RustyOpus.Decoder.close(decoder)

  `frame_size` is the number of **samples per channel** in the decoded frame (for
  example 320 samples at 16 kHz is a 20 ms frame) and must match the frame duration of
  the encoded packets.
  """

  alias RustyOpus.{Error, Native}

  @enforce_keys [:resource, :rate, :channels]
  defstruct [:resource, :rate, :channels]

  @type t :: %__MODULE__{
          resource: reference(),
          rate: 8000 | 12_000 | 16_000 | 24_000 | 48_000,
          channels: 1 | 2
        }

  @valid_rates [8000, 12_000, 16_000, 24_000, 48_000]

  @doc """
  Creates a new decoder for a supported sampling rate and channel count.
  """
  @spec new(pos_integer(), 1 | 2) :: {:ok, t()} | {:error, Error.t()}
  def new(rate, channels)

  def new(rate, channels) when is_integer(rate) and channels in [1, 2] do
    if rate in @valid_rates do
      case Native.decoder_new(rate, channels) do
        {:ok, resource} -> {:ok, %__MODULE__{resource: resource, rate: rate, channels: channels}}
        {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
      end
    else
      {:error,
       RustyOpus.rustle(
         :invalid_rate,
         "invalid sampling rate #{inspect(rate)} (allowed: #{inspect(@valid_rates)})"
       )}
    end
  end

  def new(rate, channels) do
    {:error,
     RustyOpus.rustle(
       :invalid_settings,
       "invalid decoder parameters: rate=#{inspect(rate)} channels=#{inspect(channels)} " <>
         "(allowed rates: #{inspect(@valid_rates)}, channels: 1|2)"
     )}
  end

  @doc """
  Decodes one Opus `packet` into PCM using `frame_size` samples per channel.

  Returns `{:ok, pcm}` where `pcm` is the little-endian `f32` binary with
  `written_samples * channels` samples.
  """
  @spec decode(t(), binary(), pos_integer()) :: {:ok, binary()} | {:error, Error.t()}
  def decode(%__MODULE__{resource: resource}, packet, frame_size)
      when is_binary(packet) and is_integer(frame_size) do
    case Native.decoder_decode(resource, packet, frame_size) do
      {:ok, pcm} ->
        {:ok, pcm}

      {:error, {reason, message}} ->
        {:error, RustyOpus.rustle(reason, message)}
    end
  end

  def decode(_, _, _), do: {:error, RustyOpus.rustle(:invalid_input, "packet must be a binary")}

  @doc """
  Closes the decoder idempotently. Further calls return `{:error, %Error{reason: :closed}}`.
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{resource: resource}) do
    case Native.decoder_close(resource) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end
end

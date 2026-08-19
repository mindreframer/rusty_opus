defmodule RustyOpus.Encoder do
  @moduledoc """
  Opus encoder backed by the `opus-rs` codec through Rustler.

  Encodes PCM audio (the little-endian `f32` binary contract, interleaved for stereo)
  into raw Opus packets with full control over bitrate and quality.

  ## Example

      {:ok, encoder} = RustyOpus.Encoder.new(16_000, 1, :voip, bitrate: 24_000)
      pcm = RustyOpus.TestHelpers.PCM.sine(16_000, 1, 1)
      {:ok, packet} = RustyOpus.Encoder.encode(encoder, pcm, 320)
      :ok = RustyOpus.Encoder.close(encoder)

  `frame_size` is the number of **samples per channel** in one frame (for example 320
  samples at 16 kHz is a 20 ms frame). The PCM binary must contain exactly
  `frame_size * channels` `f32` samples.

  ## Quality control

  Pass `:bitrate`, `:complexity`, `:cbr`, `:fec`, and `:packet_loss` to `new/4` or update
  them at runtime with `set/2`. Higher bitrate produces larger packets with better
  fidelity; lower bitrate shrinks them. See `RustyOpus.Settings`.
  """

  alias RustyOpus.{Error, Native, Settings}

  @enforce_keys [:resource, :rate, :channels]
  defstruct [:resource, :rate, :channels]

  @type t :: %__MODULE__{
          resource: reference(),
          rate: 8000 | 12_000 | 16_000 | 24_000 | 48_000,
          channels: 1 | 2
        }

  @valid_rates [8000, 12_000, 16_000, 24_000, 48_000]
  @applications [:voip, :audio, :restricted_low_delay]

  @doc """
  Creates a new encoder.

  ## Options

  See `RustyOpus.Settings` for `:bitrate`, `:complexity`, `:cbr`, `:fec`, and
  `:packet_loss`. `application` is one of `:voip`, `:audio`, or `:restricted_low_delay`.
  """
  @spec new(pos_integer(), 1 | 2, atom(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(rate, channels, application \\ :audio, opts \\ [])

  def new(rate, channels, application, opts)
      when is_integer(rate) and channels in [1, 2] and application in @applications and
             is_list(opts) do
    if rate in @valid_rates do
      case Settings.new(opts) do
        {:ok, settings} ->
          case Native.encoder_new(
                 rate,
                 channels,
                 Atom.to_string(application),
                 Settings.to_native(settings)
               ) do
            {:ok, resource} ->
              {:ok, %__MODULE__{resource: resource, rate: rate, channels: channels}}

            {:error, {reason, message}} ->
              {:error, RustyOpus.rustle(reason, message)}
          end

        {:error, %Error{} = error} ->
          {:error, error}
      end
    else
      {:error,
       RustyOpus.rustle(
         :invalid_rate,
         "invalid sampling rate #{inspect(rate)} (allowed: #{inspect(@valid_rates)})"
       )}
    end
  end

  def new(rate, channels, application, _opts) do
    {:error,
     RustyOpus.rustle(
       :invalid_settings,
       "invalid encoder parameters: rate=#{inspect(rate)} channels=#{inspect(channels)} " <>
         "application=#{inspect(application)} (allowed rates: #{inspect(@valid_rates)}, " <>
         "channels: 1|2, applications: #{inspect(@applications)})"
     )}
  end

  @doc """
  Encodes one PCM frame into an Opus packet.

  `frame_size` is samples per channel; `pcm` must hold `frame_size * channels` samples.
  Returns `{:ok, packet}` where `packet` is a raw Opus binary.
  """
  @spec encode(t(), binary(), pos_integer()) :: {:ok, binary()} | {:error, Error.t()}
  def encode(%__MODULE__{resource: resource}, pcm, frame_size)
      when is_binary(pcm) and is_integer(frame_size) do
    case Native.encoder_encode(resource, pcm, frame_size) do
      {:ok, packet} -> {:ok, packet}
      {:error, {reason, message}} -> {:error, RustyOpus.rustle(reason, message)}
    end
  end

  def encode(_, _, _), do: {:error, RustyOpus.rustle(:invalid_input, "pcm must be a binary")}

  @doc """
  Updates quality settings on a live encoder. See `RustyOpus.Settings`.
  """
  @spec set(t(), keyword()) :: :ok | {:error, Error.t()}
  def set(%__MODULE__{resource: resource}, opts) when is_list(opts) do
    with {:ok, settings} <- Settings.new(opts) do
      case Native.encoder_set(resource, Settings.to_native(settings)) do
        {:ok, _} ->
          :ok

        {:error, {reason, message}} ->
          {:error, RustyOpus.rustle(reason, message)}
      end
    end
  end

  @doc """
  Closes the encoder idempotently. Further calls return `{:error, %Error{reason: :closed}}`.
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{resource: resource}) do
    case Native.encoder_close(resource) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end
end

defmodule RustyOpus.PCM do
  import Bitwise

  @moduledoc """
  The common, metadata-carrying PCM representation used by file APIs.

  `data` is always interleaved little-endian IEEE-754 `f32`. The legacy helper
  functions in this module continue to operate on bare PCM binaries so raw
  Opus packet APIs remain source compatible.
  """

  @enforce_keys [:data, :sample_rate, :channels]
  defstruct [:data, :sample_rate, :channels]

  @type t :: %__MODULE__{
          data: binary(),
          sample_rate: pos_integer(),
          channels: 1 | 2
        }

  # This is intentionally a package-level bound. It prevents hostile metadata
  # from turning a checked multiplication into an impractical BEAM allocation.
  @max_bytes 256 * 1024 * 1024
  @max_sample_rate 192_000

  @doc "Constructs and validates a metadata-carrying PCM value."
  @spec new(binary(), pos_integer(), 1 | 2) :: {:ok, t()} | {:error, RustyOpus.Error.t()}
  def new(data, sample_rate, channels) when is_binary(data) do
    with :ok <- validate_rate(sample_rate),
         :ok <- validate_channels(channels),
         :ok <- validate_size(data, channels),
         :ok <- validate_samples(data) do
      {:ok, %__MODULE__{data: data, sample_rate: sample_rate, channels: channels}}
    end
  end

  def new(_, _, _), do: error(:invalid_pcm, "PCM data must be a binary")

  @doc "Validates a `%RustyOpus.PCM{}` supplied by a caller or another decoder."
  @spec validate(t()) :: :ok | {:error, RustyOpus.Error.t()}
  def validate(%__MODULE__{data: data, sample_rate: rate, channels: channels}) do
    cond do
      not is_binary(data) ->
        error(:invalid_pcm, "PCM data must be a binary")

      true ->
        with :ok <- validate_rate(rate),
             :ok <- validate_channels(channels),
             :ok <- validate_size(data, channels),
             :ok <- validate_samples(data) do
          :ok
        end
    end
  end

  def validate(_), do: error(:invalid_pcm, "expected a RustyOpus.PCM struct")

  @doc "Number of `f32` samples in a bare PCM binary."
  @spec sample_count(binary()) :: non_neg_integer()
  def sample_count(pcm) when is_binary(pcm), do: div(byte_size(pcm), 4)

  @doc "Number of interleaved frames in a metadata-carrying PCM value."
  @spec frame_count(t()) :: non_neg_integer()
  def frame_count(%__MODULE__{data: data, channels: channels}),
    do: div(byte_size(data), 4 * channels)

  @doc "Builds a PCM binary from a list of float samples."
  @spec from_samples([float()]) :: binary()
  def from_samples(samples) do
    for s <- samples, into: <<>>, do: <<s::float-little-32>>
  end

  @doc "Decodes a PCM binary into a list of float samples."
  @spec to_samples(binary()) :: [float()]
  def to_samples(pcm) when is_binary(pcm) do
    for <<s::float-little-32 <- pcm>>, do: s
  end

  @doc "Interleaves two mono PCM binaries into one stereo PCM binary."
  @spec interleave(binary(), binary()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def interleave(left, right) when is_binary(left) and is_binary(right) do
    ls = sample_count(left)
    rs = sample_count(right)

    if ls == rs do
      pairs = Enum.zip(to_samples(left), to_samples(right))
      {:ok, from_samples(List.flatten(for {l, r} <- pairs, do: [l, r]))}
    else
      error(
        :invalid_input,
        "left and right PCM must have the same sample count (got #{ls} and #{rs})"
      )
    end
  end

  @doc "Deinterleaves a stereo PCM binary into `{left, right}` mono binaries."
  @spec deinterleave(binary()) :: {:ok, {binary(), binary()}} | {:error, RustyOpus.Error.t()}
  def deinterleave(pcm) when is_binary(pcm) do
    if rem(sample_count(pcm), 2) == 0 do
      left =
        for <<l::float-little-32, _r::float-little-32 <- pcm>>,
          into: <<>>,
          do: <<l::float-little-32>>

      right =
        for <<_l::float-little-32, r::float-little-32 <- pcm>>,
          into: <<>>,
          do: <<r::float-little-32>>

      {:ok, {left, right}}
    else
      error(:invalid_input, "stereo PCM must contain an even number of samples")
    end
  end

  @doc false
  @spec transform(t(), keyword()) :: {:ok, t()} | {:error, RustyOpus.Error.t()}
  def transform(%__MODULE__{} = pcm, opts) when is_list(opts) do
    if not Keyword.keyword?(opts) do
      error(:invalid_settings, "PCM transform options must be a keyword list")
    else
      transform_valid(pcm, opts)
    end
  end

  def transform(_, _),
    do: error(:invalid_pcm, "expected a RustyOpus.PCM struct and keyword options")

  defp transform_valid(%__MODULE__{} = pcm, opts) do
    with :ok <- validate(pcm),
         {:ok, channels} <- target_channels(pcm.channels, opts),
         {:ok, rate} <- target_rate(pcm.sample_rate, opts),
         {:ok, transformed} <- convert_channels(pcm, channels),
         {:ok, transformed} <- resample(transformed, rate),
         :ok <- validate(transformed) do
      {:ok, transformed}
    end
  end

  @doc false
  def max_bytes, do: @max_bytes

  defp target_channels(current, opts) do
    case Keyword.fetch(opts, :channels) do
      :error -> {:ok, current}
      {:ok, channels} when channels in [1, 2] -> {:ok, channels}
      {:ok, _} -> error(:invalid_settings, "channels must be 1 or 2")
    end
  end

  defp target_rate(current, opts) do
    case Keyword.fetch(opts, :sample_rate) do
      :error -> {:ok, current}
      {:ok, rate} when is_integer(rate) and rate > 0 and rate <= @max_sample_rate -> {:ok, rate}
      {:ok, _} -> error(:invalid_settings, "sample_rate must be an integer between 1 and 192000")
    end
  end

  defp convert_channels(%__MODULE__{channels: channels} = pcm, channels), do: {:ok, pcm}

  defp convert_channels(%__MODULE__{data: data, channels: 1} = pcm, 2) do
    out =
      for <<sample::float-little-32 <- data>>, into: <<>> do
        <<sample::float-little-32, sample::float-little-32>>
      end

    {:ok, %__MODULE__{pcm | data: out, channels: 2}}
  end

  defp convert_channels(%__MODULE__{data: data, channels: 2} = pcm, 1) do
    out =
      for <<left::float-little-32, right::float-little-32 <- data>>, into: <<>> do
        <<(left + right) / 2::float-little-32>>
      end

    {:ok, %__MODULE__{pcm | data: out, channels: 1}}
  end

  defp resample(%__MODULE__{sample_rate: rate} = pcm, rate), do: {:ok, pcm}

  defp resample(%__MODULE__{data: data, sample_rate: in_rate, channels: channels} = pcm, out_rate) do
    frames = div(byte_size(data), 4 * channels)

    if frames == 0 do
      {:ok, %__MODULE__{pcm | sample_rate: out_rate}}
    else
      out_frames = max(1, div(frames * out_rate + div(in_rate, 2), in_rate))

      if out_frames * channels * 4 > @max_bytes do
        error(:allocation_bound, "resampled PCM exceeds the maximum supported size")
      else
        values = data |> to_samples() |> List.to_tuple()

        out =
          for index <- 0..(out_frames - 1), channel <- 0..(channels - 1), into: <<>> do
            sample = interpolate(values, frames, channels, index, out_frames, channel)
            <<sample::float-little-32>>
          end

        {:ok, %__MODULE__{pcm | data: out, sample_rate: out_rate}}
      end
    end
  end

  defp interpolate(values, frames, channels, index, out_frames, channel) do
    if out_frames == 1 or frames == 1 do
      elem(values, channel)
    else
      position = index * (frames - 1) / (out_frames - 1)
      before = trunc(position)
      after_index = min(before + 1, frames - 1)
      fraction = position - before
      left = elem(values, before * channels + channel)
      right = elem(values, after_index * channels + channel)
      left + (right - left) * fraction
    end
  end

  defp validate_rate(rate) when is_integer(rate) and rate > 0 and rate <= @max_sample_rate,
    do: :ok

  defp validate_rate(_),
    do: error(:invalid_rate, "sample_rate must be an integer between 1 and 192000")

  defp validate_channels(channels) when channels in [1, 2], do: :ok
  defp validate_channels(_), do: error(:invalid_pcm, "channels must be 1 or 2")

  defp validate_size(data, channels) do
    alignment = 4 * channels

    cond do
      byte_size(data) > @max_bytes ->
        error(:allocation_bound, "PCM exceeds the maximum supported size")

      rem(byte_size(data), alignment) != 0 ->
        error(:invalid_pcm, "PCM byte length is not aligned to channel frames")

      true ->
        :ok
    end
  end

  defp validate_samples(data) do
    bits = for <<value::little-unsigned-32 <- data>>, do: value

    if Enum.all?(bits, &(band(&1, 0x7F800000) != 0x7F800000)) do
      :ok
    else
      error(:invalid_pcm, "PCM samples must be finite IEEE-754 values")
    end
  end

  defp error(reason, message), do: {:error, RustyOpus.rustle(reason, message)}
end

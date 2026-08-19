defmodule RustyOpus.PCM do
  @moduledoc """
  Helpers over the stable PCM contract: a binary of little-endian IEEE-754 `f32`
  samples, interleaved for stereo.

  Sample count for a PCM binary is `byte_size(pcm) / 4`. For stereo, samples are
  interleaved as `[left, right, left, right, ...]`.
  """

  @doc """
  Number of `f32` samples in a PCM binary.
  """
  @spec sample_count(binary()) :: non_neg_integer()
  def sample_count(pcm) when is_binary(pcm), do: div(byte_size(pcm), 4)

  @doc """
  Builds a PCM binary from a list of float samples.
  """
  @spec from_samples([float()]) :: binary()
  def from_samples(samples) do
    for s <- samples, into: <<>>, do: <<s::float-little-32>>
  end

  @doc """
  Decodes a PCM binary into a list of float samples.
  """
  @spec to_samples(binary()) :: [float()]
  def to_samples(pcm) when is_binary(pcm) do
    for <<s::float-little-32 <- pcm>>, do: s
  end

  @doc """
  Interleaves two mono PCM binaries into one stereo PCM binary.

  Both inputs must have the same sample count.
  """
  @spec interleave(binary(), binary()) :: {:ok, binary()} | {:error, RustyOpus.Error.t()}
  def interleave(left, right) when is_binary(left) and is_binary(right) do
    ls = sample_count(left)
    rs = sample_count(right)

    if ls == rs do
      pairs = Enum.zip(to_samples(left), to_samples(right))
      {:ok, from_samples(List.flatten(for {l, r} <- pairs, do: [l, r]))}
    else
      {:error,
       RustyOpus.rustle(
         :invalid_input,
         "left and right PCM must have the same sample count (got #{ls} and #{rs})"
       )}
    end
  end

  @doc """
  Deinterleaves a stereo PCM binary into `{left, right}` mono binaries.
  """
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
      {:error,
       RustyOpus.rustle(:invalid_input, "stereo PCM must contain an even number of samples")}
    end
  end
end

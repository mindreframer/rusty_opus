defmodule RustyOpus.TestHelpers.PCM do
  @moduledoc """
  Helpers for the stable PCM contract: a binary of little-endian `f32` samples,
  interleaved for stereo.
  """

  @doc """
  Build a PCM binary from a list of float samples.
  """
  @spec from_samples([float()]) :: binary()
  def from_samples(samples) do
    for s <- samples, into: <<>>, do: <<s::float-little-32>>
  end

  @doc """
  Decode a PCM binary into a list of float samples.
  """
  @spec to_samples(binary()) :: [float()]
  def to_samples(pcm) do
    for <<s::float-little-32 <- pcm>>, do: s
  end

  @doc """
  Number of `f32` samples in a PCM binary.
  """
  @spec sample_count(binary()) :: non_neg_integer()
  def sample_count(pcm) when is_binary(pcm), do: div(byte_size(pcm), 4)

  @doc """
  Generate `n` seconds of a deterministic sine wave at the given rate/channels.
  """
  @spec sine(non_neg_integer(), pos_integer(), non_neg_integer(), float()) :: binary()
  def sine(rate, channels, seconds, frequency \\ 440.0) do
    total = rate * channels * seconds

    samples =
      for i <- 0..(total - 1)//1 do
        Math.sin(2.0 * :math.pi() * frequency * i / rate)
      end

    from_samples(samples)
  end
end

defmodule Math do
  @moduledoc false
  def sin(x), do: :math.sin(x)
end

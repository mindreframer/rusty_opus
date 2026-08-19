defmodule RustyOpus.TestHelpers.LossyCompare do
  @moduledoc """
  Deterministic lossy PCM comparison.

  Opus is a lossy codec, so round-trip comparisons are checked with a bounded
  mean-absolute-error and peak-error tolerance rather than exact equality.
  """

  @doc """
  Returns `true` when `a` and `b` (PCM binaries) are within the given tolerance.

  Tolerances are exact byte-length-equal plus bounded per-sample error.
  """
  @spec similar?(binary(), binary(), float(), float()) :: boolean()
  def similar?(a, b, max_mean_abs \\ 0.02, max_peak \\ 0.5)
      when is_binary(a) and is_binary(b) do
    if byte_size(a) != byte_size(b) do
      false
    else
      sa = RustyOpus.TestHelpers.PCM.to_samples(a)
      sb = RustyOpus.TestHelpers.PCM.to_samples(b)

      case diffs(sa, sb) do
        {:ok, mean_abs, peak} -> mean_abs <= max_mean_abs and peak <= max_peak
        :error -> false
      end
    end
  end

  defp diffs(a, b) when length(a) != length(b), do: :error

  defp diffs(a, b) do
    {sum, peak} =
      Enum.zip(a, b)
      |> Enum.reduce({0.0, 0.0}, fn {x, y}, {sum, peak} ->
        d = abs(x - y)
        {sum + d, max(peak, d)}
      end)

    {:ok, sum / max(length(a), 1), peak}
  end

  @doc """
  Compares two PCM binaries by energy (RMS), which is shift-invariant and tolerates
  the codec lookahead/delay. Returns true when the RMS ratio is within `1.0 / factor`
  and `factor` (pass `factor` as 1.0 to allow a 2x range). Also asserts the signal is
  not silent: at least one sample exceeds `min_peak`.
  """
  @spec energy_close?(binary(), binary(), float(), float()) :: boolean()
  def energy_close?(a, b, factor \\ 1.0, min_peak \\ 0.5)
      when is_binary(a) and is_binary(b) do
    if byte_size(a) != byte_size(b) do
      false
    else
      pkm = peak(b)
      ra = rms(a)
      rb = rms(b)

      within_ratio =
        if ra == 0.0 or rb == 0.0 do
          abs(ra - rb) <= 0.01
        else
          max(ra, rb) / min(ra, rb) <= 1.0 + factor
        end

      within_ratio and pkm >= min_peak
    end
  end

  defp rms(pcm) do
    samples = RustyOpus.TestHelpers.PCM.to_samples(pcm)
    :math.sqrt(Enum.sum(for x <- samples, do: x * x) / max(length(samples), 1))
  end

  defp peak(pcm), do: pcm |> RustyOpus.TestHelpers.PCM.to_samples() |> Enum.max()
end

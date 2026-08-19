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
end

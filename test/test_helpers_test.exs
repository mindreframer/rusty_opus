defmodule RustyOpus.TestHelpers.PCMTest do
  use ExUnit.Case, async: true

  alias RustyOpus.TestHelpers.PCM

  test "from_samples/to_samples round-trips" do
    samples = [0.0, 0.5, -0.5, 1.0, -1.0]
    assert PCM.to_samples(PCM.from_samples(samples)) == samples
  end

  test "sample_count reflects f32 little-endian layout" do
    assert PCM.sample_count(PCM.from_samples([1.0, 2.0, 3.0])) == 3
  end

  test "sine produces the expected number of samples" do
    pcm = PCM.sine(16_000, 1, 1)
    assert byte_size(pcm) == 16_000 * 4
  end
end

defmodule RustyOpus.TestHelpers.LossyCompareTest do
  use ExUnit.Case, async: true

  alias RustyOpus.TestHelpers.{LossyCompare, PCM}

  test "identical PCM is similar" do
    pcm = PCM.sine(16_000, 1, 1)
    assert LossyCompare.similar?(pcm, pcm)
  end

  test "small differences stay within tolerance" do
    a = PCM.from_samples([0.0, 0.1, 0.2])
    b = PCM.from_samples([0.001, 0.102, 0.2])
    assert LossyCompare.similar?(a, b, 0.02, 0.5)
  end

  test "byte-length mismatch is not similar" do
    refute LossyCompare.similar?(PCM.from_samples([0.0]), PCM.from_samples([0.0, 1.0]))
  end
end

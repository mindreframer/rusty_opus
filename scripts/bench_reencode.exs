# Benchmark RustyOpus.reencode/2 on a real MemoMoo Ogg Opus fixture.
#
#   RUSTY_OPUS_BUILD=1 mix run scripts/bench_reencode.exs
#   RUSTY_OPUS_BUILD=1 mix run scripts/bench_reencode.exs path/to/file.ogg
#   BENCH_DURATION_S=7.37 RUSTY_OPUS_BUILD=1 mix run scripts/bench_reencode.exs
#
# Historical baseline (ruopus on Apple M3 Ultra, release NIF, ~7.37s fixture):
#   median ~965 ms at 20_000 bit/s ≈ 7.6× realtime (ADR003).

path =
  case System.argv() do
    [p | _] -> p
    [] -> Path.expand("../test/fixtures/moo_audio_versions_1.ogg", __DIR__)
  end

unless File.regular?(path) do
  IO.puts(:stderr, "fixture not found: #{path}")
  System.halt(1)
end

source = File.read!(path)
source_bytes = byte_size(source)

unless String.starts_with?(source, "OggS") do
  IO.puts(:stderr, "not an Ogg blob (missing OggS magic): #{path}")
  System.halt(1)
end

{:ok, version} = RustyOpus.native_smoke()

# Prior ruopus median on this fixture / machine class (ms). Used for speedup proof.
baseline_ms = 965.0
# Fail the script if 20 kb/s median is not dramatically faster than baseline.
min_speedup = 10.0

bitrates = [8_000, 12_000, 16_000, 20_000, 24_000, 32_000, 48_000, 64_000]
warmup = 2
iters = 7

duration_s =
  case System.get_env("BENCH_DURATION_S") do
    nil -> 7.37
    s -> String.to_float(s)
  end

IO.puts("""
RustyOpus reencode bench (ADR003: opus-rs + thin Ogg)
  native:     #{version}
  fixture:    #{path}
  source:     #{source_bytes} bytes
  audio:      ~#{duration_s}s (set BENCH_DURATION_S to override)
  baseline:   #{baseline_ms} ms median @ 20 kb/s (ruopus, pre-ADR003)
  require:    ≥#{min_speedup}× faster than baseline at 20 kb/s
  warmup:     #{warmup}   iters/bitrate: #{iters}
""")

Enum.each(1..warmup, fn _ ->
  {:ok, _} = RustyOpus.reencode(source, bitrate: 20_000)
end)

IO.puts(
  String.pad_trailing("bitrate", 10) <>
    String.pad_trailing("out", 10) <>
    String.pad_trailing("shrink", 10) <>
    String.pad_trailing("median", 12) <>
    String.pad_trailing("mean", 12) <>
    String.pad_trailing("x realtime", 12) <>
    "vs baseline"
)

IO.puts(String.duplicate("-", 78))

results =
  Enum.map(bitrates, fn bitrate ->
    us_list =
      Enum.map(1..iters, fn _ ->
        {us, {:ok, out}} = :timer.tc(fn -> RustyOpus.reencode(source, bitrate: bitrate) end)
        {us, byte_size(out)}
      end)

    times = Enum.map(us_list, &elem(&1, 0))
    out_bytes = us_list |> List.last() |> elem(1)
    us_sorted = Enum.sort(times)
    median = Enum.at(us_sorted, div(length(us_sorted), 2))
    mean = Enum.sum(times) / length(times)
    ms_median = median / 1000.0
    ms_mean = mean / 1000.0
    shrink = 100.0 * (1.0 - out_bytes / source_bytes)
    xrt = duration_s / (ms_median / 1000.0)
    vs_base = baseline_ms / ms_median

    IO.puts(
      String.pad_trailing("#{bitrate}", 10) <>
        String.pad_trailing("#{out_bytes}", 10) <>
        String.pad_trailing("#{Float.round(shrink, 1)}%", 10) <>
        String.pad_trailing("#{Float.round(ms_median, 2)}ms", 12) <>
        String.pad_trailing("#{Float.round(ms_mean, 2)}ms", 12) <>
        String.pad_trailing("#{Float.round(xrt, 0)}x", 12) <>
        "#{Float.round(vs_base, 1)}x faster"
    )

    %{bitrate: bitrate, ms_median: ms_median, vs_base: vs_base}
  end)

ref = Enum.find(results, &(&1.bitrate == 20_000))
fastest = Enum.min_by(results, & &1.ms_median)

IO.puts("""

proof @ 20_000 bit/s: median #{Float.round(ref.ms_median, 2)} ms \
(#{Float.round(duration_s / (ref.ms_median / 1000.0), 0)}x realtime) — \
#{Float.round(ref.vs_base, 1)}× faster than ruopus baseline #{baseline_ms} ms

fastest median: #{fastest.bitrate} bit/s in #{Float.round(fastest.ms_median, 2)} ms \
(#{Float.round(duration_s / (fastest.ms_median / 1000.0), 0)}x realtime)
""")

if ref.vs_base < min_speedup do
  IO.puts(:stderr, """
  FAIL: expected ≥#{min_speedup}× speedup at 20 kb/s vs #{baseline_ms} ms baseline, \
  got #{Float.round(ref.vs_base, 2)}× (median #{Float.round(ref.ms_median, 2)} ms)
  """)
  System.halt(1)
end

IO.puts("PASS: ADR003 speedup proven (≥#{min_speedup}× vs ruopus baseline).")

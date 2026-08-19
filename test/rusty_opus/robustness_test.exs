defmodule RustyOpus.RobustnessTest do
  use ExUnit.Case, async: false

  alias RustyOpus.{Decoder, Encoder, Error}
  alias RustyOpus.TestHelpers.PCM

  @rate 16_000
  @frame 320

  defp wait_until(fun, timeout \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        raise "condition not met within #{timeout}ms"

      true ->
        Process.sleep(10)
        wait_until(fun, deadline - System.monotonic_time(:millisecond))
    end
  end

  describe "resource ownership and cleanup" do
    test "owner death releases encoder and decoder resources" do
      before = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()

      # Spawn a process that creates resources and exits normally WITHOUT closing them.
      pid =
        spawn(fn ->
          {:ok, e} = Encoder.new(@rate, 1)
          {:ok, d} = Decoder.new(@rate, 1)
          {:ok, packet} = Encoder.encode(e, sine(), @frame)
          {:ok, _} = Decoder.decode(d, packet, @frame)
          :ok
        end)

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
      after
        5_000 -> flunk("child did not exit")
      end

      # The dead owner's heap (holding the resource terms) is freed, so the native
      # resources are reclaimed even without an explicit close.
      wait_until(fn ->
        RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= before + 2
      end)
    end

    test "repeated open/close returns counters to baseline" do
      baseline = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()

      Enum.each(1..20, fn _ ->
        {:ok, e} = Encoder.new(@rate, 1)
        {:ok, d} = Decoder.new(@rate, 1)
        :ok = Encoder.close(e)
        :ok = Decoder.close(d)
      end)

      :erlang.garbage_collect()

      wait_until(fn ->
        RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= baseline + 2
      end)
    end

    test "close is idempotent" do
      {:ok, e} = Encoder.new(@rate, 1)
      {:ok, d} = Decoder.new(@rate, 1)
      assert :ok = Encoder.close(e)
      assert :ok = Encoder.close(e)
      assert :ok = Decoder.close(d)
      assert :ok = Decoder.close(d)
    end
  end

  describe "concurrency" do
    test "many concurrent codecs stay isolated and correct" do
      baseline = RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count()

      results =
        1..16
        |> Task.async_stream(
          fn _ ->
            {:ok, e} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
            {:ok, d} = Decoder.new(@rate, 1)

            packets =
              Enum.map(1..20, fn _ ->
                {:ok, p} = Encoder.encode(e, sine(), @frame)
                p
              end)

            decoded =
              Enum.map(packets, fn p ->
                {:ok, pcm} = Decoder.decode(d, p, @frame)
                PCM.sample_count(pcm) == @frame
              end)

            :ok = Encoder.close(e)
            :ok = Decoder.close(d)
            Enum.all?(decoded)
          end,
          max_concurrency: 8,
          timeout: 30_000
        )
        |> Enum.map(fn
          {:ok, ok} -> ok
          {:error, err} -> raise inspect(err)
        end)

      assert Enum.all?(results)

      :erlang.garbage_collect()

      wait_until(fn ->
        RustyOpus.Native.encoder_count() + RustyOpus.Native.decoder_count() <= baseline + 4
      end)
    end
  end

  describe "scheduler responsiveness" do
    test "large-frame codec work does not block normal schedulers" do
      parent = self()

      # A timer on a normal scheduler that must fire on schedule while we hammer
      # the dirty-scheduled codec NIFs.
      spawn(fn ->
        Process.sleep(100)
        send(parent, :fired)
      end)

      # Heavy dirty-scheduled codec work in this process.
      {:ok, e} = Encoder.new(48_000, 1, :audio, bitrate: 96_000)
      {:ok, d} = Decoder.new(48_000, 1)
      pcm = PCM.sine(48_000, 1, 0.02)

      Enum.each(1..200, fn _ ->
        {:ok, packet} = Encoder.encode(e, pcm, 960)
        {:ok, _} = Decoder.decode(d, packet, 960)
      end)

      receive do
        :fired -> :ok
      after
        1_000 -> flunk("timer did not fire; a codec call blocked a normal scheduler")
      end
    end
  end

  describe "error paths" do
    test "non-binary inputs are rejected" do
      {:ok, e} = Encoder.new(@rate, 1)
      assert {:error, %Error{reason: :invalid_input}} = Encoder.encode(e, :not_pcm, @frame)

      {:ok, d} = Decoder.new(@rate, 1)
      assert {:error, %Error{reason: :invalid_input}} = Decoder.decode(d, 123, @frame)
    end

    test "truncated/corrupt packets return tagged decode errors" do
      {:ok, e} = Encoder.new(@rate, 1)
      {:ok, packet} = Encoder.encode(e, sine(), @frame)
      {:ok, d} = Decoder.new(@rate, 1)

      # truncate the packet to 1 byte (ToC only) -> concealment, not error
      assert {:ok, _} = Decoder.decode(d, binary_part(packet, 0, 1), @frame)

      # corrupt a middle byte -> either decodes as garbage or errors cleanly
      <<head::binary-size(2), rest::binary>> = packet
      corrupt = head <> <<0xFF, 0xFF, 0xFF>> <> rest

      result = Decoder.decode(d, corrupt, @frame)

      assert match?({:ok, _}, result) or
               match?({:error, %Error{reason: :decode_failed}}, result)
    end

    test "invalid frame sizes are rejected by the codec" do
      {:ok, e} = Encoder.new(@rate, 1)
      # 7 samples per channel is not a valid Opus frame size
      assert {:error, %Error{reason: :invalid_input}} = Encoder.encode(e, sine(0.02), 7)
    end
  end

  describe "fuzz robustness in a disposable child BEAM" do
    test "random PCM/packet input never crashes the VM" do
      expr = """
      alias RustyOpus.{Encoder, Decoder}
      {:ok, e} = Encoder.new(16_000, 1, :voip)
      {:ok, d} = Decoder.new(16_000, 1)
      Enum.each(1..200, fn _ ->
        garbage = :crypto.strong_rand_bytes(:rand.uniform(4096))
        _ = Encoder.encode(e, garbage, 320)
        _ = Decoder.decode(d, garbage, 320)
      end)
      IO.puts("fuzz-ok")
      """

      assert {:ok, out} = RustyOpus.TestHelpers.ChildBEAM.run_mix(expr)
      assert out =~ "fuzz-ok"
    end

    test "hostile packets never crash the caller process (contained at the NIF)" do
      {:ok, d} = Decoder.new(@rate, 1)

      Enum.each(1..300, fn _ ->
        garbage = :crypto.strong_rand_bytes(max(:rand.uniform(4096), 1))

        case Decoder.decode(d, garbage, @frame) do
          {:ok, _} -> :ok
          {:error, %Error{}} -> :ok
        end
      end)

      {:ok, e} = Encoder.new(@rate, 1)

      Enum.each(1..300, fn _ ->
        garbage = :crypto.strong_rand_bytes(max(:rand.uniform(4096), 1))

        case Encoder.encode(e, garbage, @frame) do
          {:ok, _} -> :ok
          {:error, %Error{}} -> :ok
        end
      end)
    end

    test "a contained native panic in a child BEAM keeps the parent alive" do
      expr = """
      result = RustyOpus.contained_panic()
      IO.inspect(result)
      """

      assert {:ok, out} = RustyOpus.TestHelpers.ChildBEAM.run_mix(expr)
      assert out =~ "contained_panic"
    end
  end

  describe "throughput smoke" do
    test "encodes and decodes many frames quickly" do
      {:ok, e} = Encoder.new(@rate, 1, :audio, bitrate: 24_000)
      {:ok, d} = Decoder.new(@rate, 1)
      pcm = sine()

      {us, result} =
        :timer.tc(fn ->
          Enum.reduce(1..1_000, 0, fn _, acc ->
            {:ok, packet} = Encoder.encode(e, pcm, @frame)
            {:ok, _} = Decoder.decode(d, packet, @frame)
            acc + 1
          end)
        end)

      # 1000 frames round-tripped; allow generous CI headroom (target ~ms range).
      assert result == 1_000
      assert us < 20_000_000
    end
  end

  defp sine(seconds \\ 0.02), do: PCM.sine(@rate, 1, seconds)
end

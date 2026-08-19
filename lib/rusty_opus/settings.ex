defmodule RustyOpus.Settings do
  @moduledoc """
  Validated encoder quality settings.

  These settings tune the encoding quality and size:

    * `:bitrate` — target bitrate in bits/second (a positive integer), or `nil` to keep
      the codec default (64_000).
    * `:complexity` — encoding complexity from `0` (fast) to `10` (best), or `nil`.
    * `:cbr` — `true` to force constant bitrate, `false` for variable, or `nil` for default.
    * `:fec` — `true` to enable in-band forward error correction.
    * `:packet_loss` — expected packet-loss percentage `0..100` used for rate estimation.

  Raise `:bitrate` to increase output size/fidelity, or lower it to shrink it — this is
  the knob behind "changing the quality" of an encoding.
  """

  defstruct bitrate: nil, complexity: nil, cbr: nil, fec: false, packet_loss: 0

  @type t :: %__MODULE__{
          bitrate: non_neg_integer() | nil,
          complexity: 0..10 | nil,
          cbr: boolean() | nil,
          fec: boolean(),
          packet_loss: 0..100
        }

  @doc """
  Builds validated settings from a keyword list.

  Returns `{:ok, settings}` or `{:error, %RustyOpus.Error{}}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, RustyOpus.Error.t()}
  def new(opts) when is_list(opts) do
    with {:ok, bitrate} <- int_opt(opts, :bitrate, nil, &(is_integer(&1) and &1 >= 0)),
         {:ok, complexity} <-
           int_opt(opts, :complexity, nil, &(is_integer(&1) and &1 in 0..10)),
         {:ok, cbr} <- bool_opt(opts, :cbr, nil),
         {:ok, fec} <- bool_opt(opts, :fec, false),
         {:ok, packet_loss} <-
           int_opt(opts, :packet_loss, 0, &(is_integer(&1) and &1 in 0..100)) do
      {:ok,
       %__MODULE__{
         bitrate: bitrate,
         complexity: complexity,
         cbr: cbr,
         fec: fec,
         packet_loss: packet_loss
       }}
    end
  end

  @doc """
  Returns the native NifMap shape consumed by the encoder NIF.
  """
  @spec to_native(t()) :: map()
  def to_native(%__MODULE__{} = s) do
    %{
      bitrate: s.bitrate,
      complexity: s.complexity,
      cbr: s.cbr,
      fec: s.fec,
      packet_loss: s.packet_loss
    }
  end

  defp int_opt(opts, key, default, valid?) do
    case Keyword.fetch(opts, key) do
      :error ->
        {:ok, default}

      {:ok, nil} ->
        {:ok, default}

      {:ok, value} ->
        if valid?.(value), do: {:ok, value}, else: {:error, error(key, value)}
    end
  end

  defp bool_opt(opts, key, default) do
    case Keyword.fetch(opts, key) do
      :error -> {:ok, default}
      {:ok, nil} -> {:ok, default}
      {:ok, value} when is_boolean(value) -> {:ok, value}
      {:ok, value} -> {:error, error(key, value)}
    end
  end

  defp error(key, value) do
    %RustyOpus.Error{
      reason: :invalid_setting,
      message: "invalid value for #{inspect(key)}: #{inspect(value)}"
    }
  end
end

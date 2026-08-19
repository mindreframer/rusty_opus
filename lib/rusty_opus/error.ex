defmodule RustyOpus.Error do
  @moduledoc """
  A stable, tagged Opus/encode-decode error.

  Every error surfaced across the Rust boundary is represented as a
  `RustyOpus.Error` with a documented `:reason` and a human-readable `:message`.
  """

  defexception [:message, :reason]

  @type t :: %__MODULE__{message: String.t(), reason: atom() | String.t()}
end

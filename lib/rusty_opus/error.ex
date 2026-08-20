defmodule RustyOpus.Error do
  @moduledoc """
  A stable, tagged Opus/encode-decode error.

  Every error surfaced across the Rust boundary is represented as a
  `RustyOpus.Error` with a documented `:reason` and a human-readable `:message`.
  """

  defexception [:message, :reason]

  @type reason ::
          :native
          | :closed
          | :poisoned
          | :invalid_pcm
          | :invalid_input
          | :invalid_settings
          | :invalid_application
          | :invalid_rate
          | :encode_failed
          | :decode_failed
          | :allocation_bound
          | :format_mismatch
          | :unsupported_format
          | :codec_panicked
          | atom()

  @type t :: %__MODULE__{message: String.t(), reason: reason()}
end

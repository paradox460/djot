defmodule Djot.DjotError do
  @moduledoc """
  Raised (or returned) when rendering, sanitizing, or highlighting a Djot document fails.

  `reason` holds the underlying cause, e.g. the native error message or `{:highlight, error}`.
  """

  defexception [:reason, message: "An error occurred transforming the Djot document"]

  @type t :: %__MODULE__{reason: term(), message: String.t()}
end

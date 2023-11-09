defmodule Djot.DjotError do
  @moduledoc """
    The djot parser/transformer does not expose many errors, it either parses and transforms a document, or fails to do so.
  """

  defexception message: "An error occured transforming the Djot document"
end

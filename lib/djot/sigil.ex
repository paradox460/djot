defmodule Djot.Sigil do
  @moduledoc """
  Implements a sigil for quickly writing Djot content in an elixir document.
  """

  @doc """
  Sigil for writing Djot markup inline in Elixir source.
  """

  def sigil_d(string, []), do: Djot.to_html!(string)
end

defmodule Djot do
  @moduledoc """
    Transform a Djot string input to HTML output.

    No sanitization is performed, the document comes directly from the Djot transformer.
  """

  alias Djot.Native

  @spec to_html(String.t()) :: {:ok, String.t()} | {:error, :djot_transform}
  def to_html(dj) do
    Native.to_html(dj)
  end

  @spec to_html!(String.t()) :: String.t()
  def to_html!(dj) do
    case Native.to_html(dj) do
      {:ok, html} -> html
      {:error, :djot_transform} -> raise Djot.DjotError
    end
  end
end

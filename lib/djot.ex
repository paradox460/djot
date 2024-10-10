defmodule Djot do
  @moduledoc """
  Transform a Djot string input to HTML output.

  No sanitization is performed, the document comes directly from the Djot transformer.


  Various options are accepted to control the Djot renderer output. See `Djot.Options` for details
  """

  alias Djot.Native

  @doc ~S"""
  Converts a Djot document into HTML

  Returns a tuple

  ## Examples
  ```
  iex> Djot.to_html("Hello World!")
  {:ok, "<p>Hello World!</p>\n"}
  ```
  """
  @spec to_html(String.t(), Djot.Options.t() | Enumerable.t()) ::
          {:ok, String.t()} | {:error, :djot_transform}
  def to_html(dj, options \\ %Djot.Options{})

  def to_html(dj, %Djot.Options{} = options) do
    Native.to_html(dj, options)
  end

  def to_html(dj, options) do
    options = struct(Djot.Options, options)
    to_html(dj, options)
  end

  @doc ~S"""
  Converts a Djot document into HTML

  Returns the document or throws an error

  ## Examples
  ```
  iex> Djot.to_html!("Hello World!")
  "<p>Hello World!</p>\n"
  ```
  """
  @spec to_html!(String.t(), Djot.Options.t() | Enumerable.t()) :: String.t()
  def to_html!(dj, options \\ %Djot.Options{}) do
    case to_html(dj, options) do
      {:ok, html} -> html
      {:error, :djot_transform} -> raise Djot.DjotError
    end
  end
end

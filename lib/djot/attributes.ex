defmodule Djot.Attributes do
  @moduledoc """
  Helpers for node attribute lists.

  Attributes are an ordered list of `{key, value}` string pairs. Order and
  duplicates are preserved; multiple `"class"` entries are joined when rendered.
  """

  @type t :: [{String.t(), String.t()}]

  @doc """
  Returns the value for `key`.

  For `"class"`, all class values joined with a space. For other keys, the last value.
  Returns `nil` when the key is absent.

      iex> Djot.Attributes.get([{"class", "a"}, {"id", "x"}, {"class", "b"}], "class")
      "a b"
      iex> Djot.Attributes.get([{"id", "x"}, {"id", "y"}], "id")
      "y"
  """
  @spec get(t(), String.t()) :: String.t() | nil
  def get(attrs, "class") do
    case for({"class", v} <- attrs, do: v) do
      [] -> nil
      classes -> Enum.join(classes, " ")
    end
  end

  def get(attrs, key) do
    Enum.reduce(attrs, nil, fn
      {^key, v}, _ -> v
      _, acc -> acc
    end)
  end

  @doc "Replaces every entry for `key` with a single `{key, value}` at the end."
  @spec put(t(), String.t(), String.t()) :: t()
  def put(attrs, key, value), do: delete(attrs, key) ++ [{key, value}]

  @doc "Removes every entry for `key`."
  @spec delete(t(), String.t()) :: t()
  def delete(attrs, key), do: Enum.reject(attrs, &match?({^key, _}, &1))

  @doc "Appends a class."
  @spec add_class(t(), String.t()) :: t()
  def add_class(attrs, class), do: attrs ++ [{"class", class}]
end

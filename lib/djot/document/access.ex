defmodule Djot.Document.Access do
  @moduledoc false
  # Ported from MDEx.Document.Access (MIT, https://github.com/leandrocp/mdex).
  #
  # Selectors: a node module (`Djot.Strong`), a bare atom (`:strong`), a struct
  # pattern (`%Djot.Heading{level: 2}`), a 1-arity predicate, or an integer index
  # into the pre-order walk.

  alias Djot.Document.Traversal

  defmacro __using__(_opts) do
    quote do
      @behaviour Access

      @impl Access
      defdelegate fetch(document, selector), to: Djot.Document.Access

      @impl Access
      defdelegate get_and_update(document, selector, fun), to: Djot.Document.Access

      @impl Access
      defdelegate pop(document, selector), to: Djot.Document.Access
    end
  end

  def fetch(document, selector) when is_integer(selector) do
    case Enum.at(document, selector) do
      nil -> :error
      node -> {:ok, node}
    end
  end

  def fetch(document, selector) do
    match? = matcher(selector)

    case Enum.filter(document, match?) do
      [] -> :error
      nodes -> {:ok, nodes}
    end
  end

  def get_and_update(document, selector, fun) when is_integer(selector) do
    case Enum.at(document, selector) do
      nil ->
        {nil, document}

      node ->
        case fun.(node) do
          {old, _new} -> {old, document}
          :pop -> {node, document}
        end
    end
  end

  def get_and_update(document, selector, fun) do
    match? = matcher(selector)

    {document, {_, old}} =
      Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, _} = acc ->
          {node, acc}

        node, {:cont, _} = acc ->
          if match?.(node) do
            case fun.(node) do
              {old, new} -> {new, {:halted, old}}
              :pop -> {:pop, {:halted, node}}
            end
          else
            {node, acc}
          end
      end)

    {old, document}
  end

  def pop(document, selector, default \\ nil)

  def pop(document, selector, default) when is_integer(selector) do
    {Enum.at(document, selector) || default, document}
  end

  def pop(document, selector, default) do
    match? = matcher(selector)

    {new, {_, old}} =
      Traversal.traverse_and_update(document, {:cont, nil}, fn
        node, {:halted, _} = acc ->
          {node, acc}

        node, {:cont, _} = acc ->
          if match?.(node), do: {:pop, {:halted, node}}, else: {node, acc}
      end)

    {old || default, new}
  end

  @doc false
  def matcher(selector) when is_function(selector, 1), do: selector
  def matcher(selector) when is_struct(selector), do: &struct_match?(&1, selector)

  def matcher(selector) when is_atom(selector) do
    module = modulefy!(selector)
    &match?(%{__struct__: ^module}, &1)
  end

  def matcher(selector), do: modulefy!(selector)

  @doc false
  def struct_match?(%mod{} = node, %mod{} = selector) do
    defaults = struct(mod)

    selector
    |> Map.from_struct()
    |> Map.delete(:nodes)
    |> Enum.all?(fn {field, value} ->
      value == Map.get(defaults, field) or value == Map.get(node, field)
    end)
  end

  def struct_match?(_, _), do: false

  @doc false
  def modulefy!(selector) when is_atom(selector) and not is_nil(selector) do
    case Atom.to_string(selector) do
      "Elixir." <> _ -> selector
      name -> Module.concat(["Djot", Macro.camelize(name)])
    end
  end

  def modulefy!(selector), do: raise(ArgumentError, "invalid selector: #{inspect(selector)}")
end

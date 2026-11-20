defmodule Djot.Stream do
  @moduledoc false
  # Each chunk re-parses the whole buffer: reference links and footnotes
  # resolve document-wide, so a later chunk can change an earlier block.

  alias Djot.Document

  def stream(enumerable, opts \\ []) do
    if Keyword.has_key?(opts, :source) do
      raise ArgumentError, "Djot.stream/2 does not accept :source"
    end

    Stream.transform(
      enumerable,
      fn -> %{base: Djot.new(opts), buffer: "", pending: "", emitted: %{}} end,
      &reduce/2,
      &last/1,
      fn _ -> :ok end
    )
  end

  defp reduce(chunk, st) do
    {valid, pending} =
      case :unicode.characters_to_binary(st.pending <> chunk) do
        valid when is_binary(valid) -> {valid, ""}
        {:incomplete, valid, rest} -> {valid, rest}
        {:error, _, _} -> raise ArgumentError, "invalid UTF-8 in djot stream"
      end

    buffer = st.buffer <> valid
    blocks = buffer |> Djot.Native.parse() |> flatten_sections()
    count = length(blocks)

    {changed, emitted} =
      blocks
      |> Enum.with_index()
      |> Enum.reduce({[], st.emitted}, fn {node, i}, {out, emitted} ->
        if Map.get(emitted, i) == node do
          {out, emitted}
        else
          {[{i, run(st.base, i, [node])} | out], Map.put(emitted, i, node)}
        end
      end)

    {removed, emitted} =
      emitted
      |> Enum.filter(fn {i, value} -> i >= count and value != :removed end)
      |> Enum.sort()
      |> Enum.reduce({[], emitted}, fn {i, _}, {out, emitted} ->
        {[{i, run(st.base, i, [])} | out], Map.put(emitted, i, :removed)}
      end)

    {Enum.reverse(changed) ++ Enum.reverse(removed),
     %{st | buffer: buffer, pending: pending, emitted: emitted}}
  end

  defp last(%{pending: ""} = st), do: {[], st}
  defp last(_st), do: raise(ArgumentError, "incomplete UTF-8 at end of djot stream")

  defp run(base, id, nodes) do
    case Document.run(Document.put_private(%{base | nodes: nodes}, :stream, %{id: id})) do
      {_doc, exception} -> raise exception
      doc -> doc
    end
  end

  @doc false
  def flatten_sections(nodes) do
    Enum.flat_map(nodes, fn
      %Djot.Section{} = section ->
        {children, _} =
          Enum.map_reduce(section.nodes, false, fn
            %Djot.Heading{has_section: true} = h, false ->
              {%{h | has_section: false, attributes: section.attributes ++ h.attributes}, true}

            node, done? ->
              {node, done?}
          end)

        flatten_sections(children)

      node ->
        [node]
    end)
  end
end

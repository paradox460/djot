# Enumerable walks a document or node in pre-order, root included.
defimpl Enumerable,
  for: [
    Djot.Document,
    Djot.Section,
    Djot.Heading,
    Djot.Paragraph,
    Djot.Blockquote,
    Djot.Div,
    Djot.List,
    Djot.ListItem,
    Djot.TaskListItem,
    Djot.DescriptionList,
    Djot.DescriptionTerm,
    Djot.DescriptionDetails,
    Djot.Table,
    Djot.TableRow,
    Djot.TableCell,
    Djot.Caption,
    Djot.Footnote,
    Djot.LinkDefinition,
    Djot.CodeBlock,
    Djot.RawBlock,
    Djot.ThematicBreak,
    Djot.Text,
    Djot.Span,
    Djot.Emphasis,
    Djot.Strong,
    Djot.Mark,
    Djot.Insert,
    Djot.Delete,
    Djot.Superscript,
    Djot.Subscript,
    Djot.Link,
    Djot.Image,
    Djot.Verbatim,
    Djot.Math,
    Djot.RawInline,
    Djot.FootnoteReference,
    Djot.Symbol,
    Djot.SmartPunctuation,
    Djot.NonBreakingSpace,
    Djot.SoftBreak,
    Djot.HardBreak,
    Djot.Raw
  ] do
  def count(_), do: {:error, __MODULE__}
  def member?(_, _), do: {:error, __MODULE__}
  def slice(_), do: {:error, __MODULE__}

  def reduce(node, acc, fun), do: do_reduce([node], acc, fun)

  defp do_reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  defp do_reduce(stack, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(stack, &1, fun)}
  defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}

  defp do_reduce([node | rest], {:cont, acc}, fun) do
    do_reduce(Map.get(node, :nodes, []) ++ rest, fun.(node, acc), fun)
  end
end

defimpl Collectable, for: Djot.Document do
  def into(doc) do
    collector = fn
      acc, {:cont, node} -> [node | acc]
      acc, :done -> %{doc | nodes: doc.nodes ++ Enum.reverse(acc)}
      _acc, :halt -> :ok
    end

    {[], collector}
  end
end

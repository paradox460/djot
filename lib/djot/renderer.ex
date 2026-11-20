defmodule Djot.Renderer do
  @moduledoc false

  alias Djot.{Document, Native}

  @spec render(Document.t(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def render(%Document{} = doc, opts) do
    heex? = Keyword.fetch!(opts, :heex)

    if fast_path?(doc) do
      native(Native.source_to_html(doc.source, native_options(doc, heex?)))
    else
      with %Document{} = doc <- run(Document.put_private(doc, :heex, heex?)),
           {:ok, doc} <- Djot.Highlight.apply(doc, heex?) do
        native(Native.nodes_to_html(doc.nodes, native_options(doc, heex?)))
      end
    end
  end

  defp fast_path?(doc) do
    doc.nodes == [] and is_binary(doc.source) and doc.current_steps == [] and
      Document.get_option(doc, :syntax_highlight) == nil
  end

  defp run(doc) do
    case Document.run(doc) do
      {_doc, exception} -> {:error, exception}
      doc -> doc
    end
  end

  defp native({:ok, html}), do: {:ok, html}

  defp native({:error, reason}),
    do:
      {:error, %Djot.DjotError{reason: reason, message: "djot render failed: #{inspect(reason)}"}}

  defp native_options(doc, heex?) do
    render = Document.get_option(doc, :render, [])

    sanitize =
      case Document.get_option(doc, :sanitize) do
        nil -> nil
        kw -> Map.new(NimbleOptions.validate!(kw, Document.sanitize_options_schema()))
      end

    %{
      renderer: Keyword.get(render, :renderer, :default),
      indent_string: Keyword.get(render, :indent_string, "\t"),
      indent_initial_level: Keyword.get(render, :indent_initial_level, 0),
      heex: heex?,
      sanitize: sanitize
    }
  end
end

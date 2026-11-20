defmodule Djot.Sigil do
  @moduledoc """
  The `~DJ` sigil, evaluated at compile time.

    * `~DJ"..."` - a `%Djot.Document{}` with the parsed nodes
    * `~DJ"..."HTML` - the rendered HTML string
    * `~DJ"..."HEEX` - a `Phoenix.LiveView.Rendered`; requires `assigns` in scope
      and `{:phoenix_live_view, "~> 1.2"}`

  Options come from `use Djot, opts`.

      iex> import Djot.Sigil
      iex> ~DJ"*a*"HTML
      "<p><strong>a</strong></p>\\n"
  """

  @doc "Djot sigil; see the module docs."
  defmacro sigil_DJ({:<<>>, _meta, [source]}, modifiers) when is_binary(source) do
    opts = (__CALLER__.module && Module.get_attribute(__CALLER__.module, :djot_options)) || []

    case modifiers do
      [] ->
        doc = Djot.parse_document!(source, opts)
        Macro.escape(%Djot.Document{nodes: doc.nodes})

      ~c"HTML" ->
        Djot.to_html!(source, opts)

      ~c"HEEX" ->
        html =
          case Djot.HEEx.render_template(source, opts) do
            {:ok, html} -> html
            {:error, exception} -> raise exception
          end

        Djot.HEEx.compile(html, %{__CALLER__ | line: __CALLER__.line + 1})

      other ->
        raise ArgumentError, "unsupported ~DJ modifier: #{other}"
    end
  end
end

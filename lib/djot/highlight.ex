defmodule Djot.Highlight do
  @moduledoc false
  # Replaces highlighted code blocks with `Djot.Raw` nodes before rendering.

  @compile {:no_warn_undefined, [Lumis]}

  alias Djot.{Attributes, Document}

  @decorators ~w(theme pre_class highlight_lines highlight_lines_style highlight_lines_class include_highlights)

  @syntect_schema [
    theme: [type: {:or, [:string, nil]}, default: nil],
    pre_class: [type: {:or, [:string, nil]}, default: nil]
  ]

  @lumis_schema [formatter: [type: :any, default: {:html_inline, theme: "onedark"}]]

  @html_formatters [:html_inline, :html_linked, :html_multi_themes]

  @spec apply(Document.t(), boolean()) :: {:ok, Document.t()} | {:error, Djot.DjotError.t()}
  def apply(%Document{} = doc, heex?) do
    case Document.get_option(doc, :syntax_highlight) do
      nil -> {:ok, doc}
      config -> highlight(doc, config, heex?)
    end
  end

  defp highlight(doc, config, heex?) do
    with {:ok, highlighter} <- highlighter(config[:engine], config[:opts]) do
      {doc, error} =
        Djot.traverse_and_update(doc, nil, fn
          %Djot.CodeBlock{language: language} = block, nil when language != "" ->
            case highlighter.(block) do
              {:ok, html} -> {%Djot.Raw{literal: escape_braces(html, heex?)}, nil}
              {:error, reason} -> {block, reason}
            end

          node, acc ->
            {node, acc}
        end)

      case error do
        nil -> {:ok, doc}
        reason -> {:error, error(reason)}
      end
    end
  end

  defp error(:lumis_not_available) do
    %Djot.DjotError{
      reason: {:highlight, :lumis_not_available},
      message:
        ~s(syntax_highlight engine :lumis requires {:lumis, "~> 0.10"} and lumis_wasm_* parser packages in your deps)
    }
  end

  defp error(reason) do
    %Djot.DjotError{
      reason: {:highlight, reason},
      message: "syntax highlighting failed: #{inspect(reason)}"
    }
  end

  defp escape_braces(html, false), do: html
  defp escape_braces(html, true), do: Djot.HEEx.escape_braces(html)

  # -- syntect ---------------------------------------------------------------

  defp highlighter(:syntect, opts) do
    opts = NimbleOptions.validate!(opts, @syntect_schema)

    {:ok,
     fn %Djot.CodeBlock{language: language, literal: literal, attributes: attrs} ->
       options = %{
         theme: Attributes.get(attrs, "theme") || opts[:theme],
         pre_class:
           join_classes([
             opts[:pre_class],
             Attributes.get(attrs, "pre_class"),
             Attributes.get(attrs, "class")
           ]),
         pre_attrs: for({k, v} <- attrs, k not in @decorators and k != "class", do: {k, v}),
         highlight_lines: attrs |> Attributes.get("highlight_lines") |> parse_lines(),
         highlight_lines_style: Attributes.get(attrs, "highlight_lines_style"),
         highlight_lines_class: Attributes.get(attrs, "highlight_lines_class")
       }

       Djot.Native.syntect_highlight(literal, language, options)
     end}
  end

  # -- lumis -----------------------------------------------------------------

  defp highlighter(:lumis, opts) do
    if Code.ensure_loaded?(Lumis) do
      opts = NimbleOptions.validate!(opts, @lumis_schema)

      {name, base} =
        case opts[:formatter] do
          name when is_atom(name) -> {name, []}
          {name, fopts} when is_atom(name) and is_list(fopts) -> {name, fopts}
        end

      {:ok,
       fn %Djot.CodeBlock{language: language, literal: literal, attributes: attrs} ->
         fopts = lumis_options(name, Keyword.put(base, :language, language), attrs)

         case Lumis.highlight(literal, formatter: {name, fopts}) do
           {:ok, html} -> {:ok, html}
           {:error, error} -> {:error, error}
         end
       end}
    else
      {:error, error(:lumis_not_available)}
    end
  end

  defp lumis_options(name, fopts, attrs) do
    html? = name in @html_formatters

    fopts
    |> put_if(html?, :pre_class, fn ->
      join_classes([
        fopts[:pre_class],
        Attributes.get(attrs, "pre_class"),
        Attributes.get(attrs, "class")
      ])
    end)
    |> put_if(html?, :pre_attrs, fn ->
      case Attributes.get(attrs, "id") do
        nil -> fopts[:pre_attrs]
        id -> Keyword.put(fopts[:pre_attrs] || [], :id, id)
      end
    end)
    |> put_if(name in [:html_inline, :terminal], :theme, fn ->
      Attributes.get(attrs, "theme") || fopts[:theme]
    end)
    |> put_if(
      name in [:html_inline, :html_multi_themes] and
        Attributes.get(attrs, "include_highlights") == "true",
      :include_highlights,
      fn -> true end
    )
    |> put_if(true, :highlight_lines, fn -> lumis_lines(name, attrs, fopts[:highlight_lines]) end)
  end

  defp lumis_lines(name, attrs, default) do
    case attrs |> Attributes.get("highlight_lines") |> parse_lines() do
      [] ->
        default

      ranges ->
        lines =
          Enum.map(ranges, fn
            {n, n} -> n
            {n, m} -> n..m
          end)

        style = Attributes.get(attrs, "highlight_lines_style")
        class = Attributes.get(attrs, "highlight_lines_class")

        extra =
          case name do
            n when n in [:html_inline, :html_multi_themes] -> [style: style, class: class]
            :html_linked -> [class: class]
            _ -> []
          end

        extra
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
        |> Map.put(:lines, lines)
    end
  end

  # Puts `key` only when `cond?` and the computed value is non-nil.
  defp put_if(opts, false, _key, _fun), do: opts

  defp put_if(opts, true, key, fun) do
    case fun.() do
      nil -> opts
      value -> Keyword.put(opts, key, value)
    end
  end

  defp join_classes(parts) do
    case parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> nil
      classes -> classes
    end
  end

  @doc false
  # "1,3-5" -> [{1, 1}, {3, 5}]; invalid tokens are skipped.
  def parse_lines(nil), do: []

  def parse_lines(spec) do
    spec
    |> String.split(",")
    |> Enum.flat_map(fn token ->
      case token |> String.trim() |> String.split("-") |> Enum.map(&String.trim/1) do
        [n] -> range(n, n)
        [n, m] -> range(n, m)
        _ -> []
      end
    end)
  end

  defp range(a, b) do
    with {n, ""} <- Integer.parse(a),
         {m, ""} <- Integer.parse(b),
         true <- n >= 1 and n <= m do
      [{n, m}]
    else
      _ -> []
    end
  end
end

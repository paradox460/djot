defmodule Djot do
  @moduledoc """
  Djot ([djot.net](https://djot.net)) parsing and rendering, backed by the Rust
  [jotdown](https://github.com/hellux/jotdown) crate.

  The API follows [MDEx](https://github.com/leandrocp/mdex):

    * `to_html/2` renders source or a `Djot.Document`
    * `parse_document/2` returns a `Djot.Document` tree you can query and edit
    * plugins and pipeline steps (`Djot.Document`)
    * syntax highlighting with syntect or Lumis, with code block decorators
    * HTML sanitization (ammonia)
    * HEEx components and expressions (`to_heex/2`, `~DJ"..."HEEX`)
    * streaming of chunked input (`stream/2`)

  ## Examples

      iex> Djot.to_html("Hello *world*!")
      {:ok, "<p>Hello <strong>world</strong>!</p>\\n"}

      iex> Djot.to_html!("Hello", render: [renderer: :minified])
      "<p>Hello</p>"

  ## Code block decorators

  Block attributes on a code block control highlighting and are never rendered:

      {theme=github_dark pre_class="a b" highlight_lines="1,3-5" highlight_lines_style="background: #ff0" highlight_lines_class=hl include_highlights=true}
      ``` elixir
      IO.puts("hi")
      ```

  Without `syntax_highlight:`, `pre_class` becomes a class on `<pre>` and the
  other decorators are ignored.

  ## `use Djot`

  `use Djot` requires `Djot`, imports `Djot.Sigil`, and stores its options in
  `@djot_options`, which `~DJ` uses at compile time.
  """

  alias Djot.Document

  @typedoc "Djot source or a document."
  @type source :: String.t() | Document.t()

  @doc """
  Builds a document from options. `:source` is parsed when the pipeline runs.

  ## Options

  #{NimbleOptions.docs(Djot.Document.options_schema())}
  """
  @spec new(keyword()) :: Document.t()
  def new(opts \\ []) do
    {source, rest} = Keyword.pop(opts, :source)

    %Document{}
    |> Document.put_options(rest)
    |> Document.put_source(source)
  end

  @doc """
  Parses source into a `Djot.Document` and runs the pipeline.

      iex> {:ok, doc} = Djot.parse_document("Hello *world*")
      iex> doc.nodes
      [%Djot.Paragraph{nodes: [%Djot.Text{literal: "Hello "}, %Djot.Strong{nodes: [%Djot.Text{literal: "world"}]}]}]
  """
  @spec parse_document(String.t(), keyword()) :: {:ok, Document.t()} | {:error, Exception.t()}
  def parse_document(source, opts \\ []) when is_binary(source) do
    case Document.run(new([source: source] ++ opts)) do
      {_doc, exception} -> {:error, exception}
      doc -> {:ok, doc}
    end
  end

  @doc "Like `parse_document/2` but raises on error."
  @spec parse_document!(String.t(), keyword()) :: Document.t()
  def parse_document!(source, opts \\ []) do
    case parse_document(source, opts) do
      {:ok, doc} -> doc
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Renders source or a document to HTML. `opts` are merged into the document
  options (see `new/1`).

      iex> Djot.to_html("_hi_")
      {:ok, "<p><em>hi</em></p>\\n"}
  """
  @spec to_html(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_html(source_or_doc, opts \\ []) do
    source_or_doc |> document(opts) |> Djot.Renderer.render(heex: false)
  end

  @doc "Like `to_html/2` but raises on error."
  @spec to_html!(source(), keyword()) :: String.t()
  def to_html!(source_or_doc, opts \\ []) do
    case to_html(source_or_doc, opts) do
      {:ok, html} -> html
      {:error, exception} -> raise exception
    end
  end

  @doc false
  def document(source, opts) when is_binary(source), do: new([source: source] ++ opts)
  def document(%Document{} = doc, opts), do: Document.put_options(doc, opts)

  @doc """
  Sanitizes and/or escapes an HTML string. Plugins use this to build safe
  `Djot.Raw` nodes.

  ## Options

    * `:sanitize` - ammonia options merged over `Djot.Document.default_sanitize_options/0`,
      or `nil` to skip sanitizing. Defaults to the default sanitize options.
    * `:escape` - HTML-escape `& < > " '` after sanitizing. Defaults to `false`.
    * `:heex` - replace `{` and `}` with `&lbrace;` / `&rbrace;` last, so the
      HTML is not read as HEEx expressions by `to_heex/2`. Pass
      `Djot.Document.get_private(doc, :heex, false)` from a step. Defaults to `false`.

  ## Examples

      iex> Djot.safe_html("<script>x</script><b onclick=\\"y\\">hi</b>")
      "<b>hi</b>"

      iex> Djot.safe_html("<a>&</a>", sanitize: nil, escape: true)
      "&lt;a&gt;&amp;&lt;/a&gt;"

      iex> Djot.safe_html("<pre>A{b}</pre>", sanitize: nil, heex: true)
      "<pre>A&lbrace;b&rbrace;</pre>"
  """
  @spec safe_html(String.t(), keyword()) :: String.t()
  def safe_html(html, opts \\ []) when is_binary(html) do
    opts =
      NimbleOptions.validate!(opts,
        sanitize: [type: {:or, [nil, :keyword_list]}, default: []],
        escape: [type: :boolean, default: false],
        heex: [type: :boolean, default: false]
      )

    sanitize =
      case opts[:sanitize] do
        nil ->
          nil

        kw ->
          Document.default_sanitize_options()
          |> Keyword.merge(kw)
          |> NimbleOptions.validate!(Document.sanitize_options_schema())
          |> Map.new()
      end

    case Djot.Native.safe_html(html, sanitize, opts[:escape]) do
      {:ok, html} ->
        if opts[:heex], do: Djot.HEEx.escape_braces(html), else: html

      {:error, reason} ->
        raise Djot.DjotError, reason: reason, message: "safe_html failed: #{reason}"
    end
  end

  @doc """
  Streams chunks of Djot source, emitting `{id, %Djot.Document{}}` for each
  top-level block that is new or changed. A later emission with the same id
  replaces the earlier one; an empty document means the block was removed.

  Sections are flattened so each heading streams as its own block. `opts`
  are as in `new/1` (plugins attach once); `:source` is not accepted.

      iex> ["# Hel", "lo\\n\\nPara"]
      ...> |> Djot.stream()
      ...> |> Enum.map(fn {id, doc} -> {id, Djot.to_html!(doc)} end)
      [{0, "<h1 id=\\"Hel\\">Hel</h1>\\n"}, {0, "<h1 id=\\"Hello\\">Hello</h1>\\n"}, {1, "<p>Para</p>\\n"}]
  """
  @spec stream(Enumerable.t(), keyword()) :: Enumerable.t()
  defdelegate stream(enumerable, opts \\ []), to: Djot.Stream

  @doc "Traverses and updates the tree post-order; returning `nil` or `:pop` removes a node."
  defdelegate traverse_and_update(doc, fun), to: Djot.Document.Traversal

  @doc "Like `traverse_and_update/2` with an accumulator; the function returns `{node, acc}`."
  defdelegate traverse_and_update(doc, acc, fun), to: Djot.Document.Traversal

  @doc false
  defmacro __using__(opts) do
    quote do
      require Djot
      import Djot.Sigil
      @djot_options unquote(opts)
    end
  end

  @doc """
  Renders Djot with HEEx components and expressions into a `Phoenix.LiveView.Rendered`.

  Requires `{:phoenix_live_view, "~> 1.2"}`. HEEx tags (`<.link>`, `<Mod.fun>`,
  `<:slot>`), `{@expr}` expressions and `<%= %>` blocks are recognized outside
  code; djot attribute syntax like `{.class}` is left alone. Explicit
  `` `...`{=heex} `` and ```` ```=heex ```` raw blocks also work.

  Assigns come from the `:assigns` option. The template is compiled at runtime
  with the caller's environment, so imports (e.g. `Phoenix.Component`) apply.
  `sanitize:` is not supported.
  """
  defmacro to_heex(source, opts \\ []) do
    ensure_live_view!()

    quote do
      Djot.HEEx.__to_heex__(unquote(source), unquote(opts), unquote(Macro.escape(__CALLER__)))
    end
  end

  @doc "Like `to_heex/2` but raises on error."
  defmacro to_heex!(source, opts \\ []) do
    ensure_live_view!()

    quote do
      Djot.HEEx.__to_heex__!(unquote(source), unquote(opts), unquote(Macro.escape(__CALLER__)))
    end
  end

  defp ensure_live_view! do
    unless Djot.HEEx.live_view_available?() do
      raise ArgumentError, ~s(Djot.to_heex/2 requires {:phoenix_live_view, "~> 1.2"})
    end
  end
end

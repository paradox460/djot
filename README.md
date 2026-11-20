# Djot

<div align=center>

[![Hex.pm](https://img.shields.io/hexpm/v/djot?style=for-the-badge&color=%23714a94)](https://hex.pm/packages/djot)

</div>

A fast [Djot](https://djot.net) parser and formatter for Elixir.

Djot parsing and transformations powered by the [jotdown](https://crates.io/crates/jotdown) rust crate.
The API is heavily "inspired" by [MDEx](https://hex.pm/packages/mdex): a document AST, a plugin pipeline,
syntax highlighting, sanitization, HEEx, and streaming.

## Usage

```elixir
Djot.to_html("hello *world*!")
# => {:ok, "<p>hello <strong>world</strong>!</p>\n"}

Djot.to_html!("hello *world*!", render: [renderer: :minified])
# => "<p>hello <strong>world</strong>!</p>"
```

Render options: `renderer` (`:default`, `:minified`, `:indented`), `indent_string`
(default `"\t"`), and `indent_initial_level` (default `0`).

### Document AST

`Djot.parse_document/2` returns a `%Djot.Document{}` whose nodes (`Djot.Section`,
`Djot.Paragraph`, `Djot.Strong`, …) support `Access` and `Enumerable`, Floki-style:

```elixir
doc = Djot.parse_document!("# Hi\n\nSome *bold* text")
doc[Djot.Strong]
# => [%Djot.Strong{nodes: [%Djot.Text{literal: "bold"}], attributes: []}]

doc
|> Djot.Document.update_nodes(Djot.Strong, &%Djot.Emphasis{nodes: &1.nodes})
|> Djot.to_html!()
# => "<section id=\"Hi\">\n<h1>Hi</h1>\n<p>Some <em>bold</em> text</p>\n</section>\n"
```

### Plugins and pipeline

Plugins expose `attach/2` and use the same functions as MDEx plugins
(`register_options/2`, `put_options/2`, `append_steps/2`, `halt/1`, …).
See `Djot.Document` for more. Use `Djot.Raw` nodes with `Djot.safe_html/2`
to inject HTML from a plugin.

```elixir
Djot.to_html!("hi", plugins: [{MyPlugin, my_option: true}])
```

Djot sets two private keys that steps can read with `Djot.Document.get_private/3`:

- `:heex` is `true` while rendering for `to_heex/2` or `~DJ"..."HEEX`. `Djot.Raw`
  is written verbatim, so pass `heex: true` to `Djot.safe_html/2` to turn `{`/`}`
  into entities, or HEEx will read them as expressions.
- `:stream` is `%{id: id}` on each per-block document from `Djot.stream/2`. Skip
  page-level injections (scripts, styles) there and put the id in element ids
  so they stay unique across blocks.

```elixir
defmodule DiagramPlugin do
  alias Djot.Document

  def attach(doc, _opts) do
    Document.append_steps(doc, diagrams: &diagrams/1)
  end

  defp diagrams(doc) do
    heex? = Document.get_private(doc, :heex, false)

    prefix =
      case Document.get_private(doc, :stream) do
        %{id: id} -> "diagram-#{id}"
        nil -> "diagram"
      end

    {doc, _} =
      Djot.traverse_and_update(doc, 1, fn
        %Djot.CodeBlock{language: "diagram"} = block, n ->
          body = Djot.safe_html(block.literal, sanitize: nil, escape: true, heex: heex?)
          {%Djot.Raw{literal: ~s(<pre id="#{prefix}-#{n}" class="diagram">#{body}</pre>)}, n + 1}

        node, n ->
          {node, n}
      end)

    doc
  end
end
```

### Syntax highlighting

Djot supports syntax highlighting via [syntect](https://github.com/syntect/syntect) and [Lumis](https://hex.pm/packages/lumis).
Configure it with `syntax_highlight:`. The `:syntect` engine is 
built in, [Lumis](https://hex.pm/packages/lumis) needs `{:lumis, "~> 0.10"}` plus a
parser package such as `{:lumis_wasm_elixir, "~> 0.26"}` in your deps, and you select
it with `engine: :lumis`.

```elixir
Djot.to_html!(source, syntax_highlight: [engine: :syntect, opts: [theme: "Dracula"]])
Djot.to_html!(source, syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "onedark"}]])
```

Code blocks take decorators as djot block attributes:

````djot
{theme=Dracula pre_class="a b" highlight_lines="1,3-5" highlight_lines_class=hl}
``` elixir
IO.puts("hi")
```
````

| Decorator | Effect |
| --- | --- |
| `theme` | Overrides the configured theme (syntect, Lumis `:html_inline` / `:terminal`) |
| `pre_class` | Extra classes on `<pre>` |
| `highlight_lines` | Lines to highlight: comma-separated `N` or `N-M`; invalid entries are skipped |
| `highlight_lines_style` | Inline style for highlighted lines |
| `highlight_lines_class` | Extra class for highlighted lines |
| `include_highlights` | `true` adds a `data-highlight` attribute with the scope name (Lumis `:html_inline` / `:html_multi_themes` only) |

Decorators never appear in the output. Without `syntax_highlight:`, `pre_class` still
becomes a class on `<pre>` and the rest are ignored.

Due to the way Djot works, client side syntax highlighting is fairly easy to implement.

### Sanitization

```elixir
Djot.to_html!(source, sanitize: Djot.Document.default_sanitize_options())
Djot.safe_html("<script>x</script><b>ok</b>")
# => "<b>ok</b>"
```

Sanitizing runs on the final HTML, including `Djot.Raw` nodes from plugins. Scripts
and attributes outside the allowlist (such as `phx-update` or `data-*`) are removed
unless you allow them, e.g. with `add_tag_attributes:` or `add_generic_attribute_prefixes:`.
You can't combine `sanitize:` with HEEx rendering; `to_heex/2` returns a
`Djot.DjotError` with reason `:sanitize_unsupported_in_heex`.

### HEEx

With `{:phoenix_live_view, "~> 1.2"}`, Djot can contain components and expressions:

```elixir
use Djot
import Phoenix.Component

def render(assigns) do
  ~DJ"""
  Hello {@name}

  <.link href="/x">go</.link>
  """HEEX
end

Djot.to_heex!("Hi {@name}", assigns: %{name: "Ann"})
```

`to_heex/2` and `to_heex!/2` are macros, available after `use Djot` or `require Djot`.
They compile the template at runtime in the caller's environment, so imports such as
`Phoenix.Component` apply. The compiler can't see that, though, and warns that an
import only the template uses is unused. `~DJ"..."HEEX` compiles the template at
compile time and doesn't trigger the warning.

### Sigil

`use Djot` (or `import Djot.Sigil`) provides `~DJ`, evaluated at compile time:
`~DJ"..."` returns a `%Djot.Document{}`, `~DJ"..."HTML` the HTML string, and
`~DJ"..."HEEX` compiles a HEEx template whose code needs an `assigns` variable in
scope where the sigil is used (as in `render(assigns)` above). Options given to
`use Djot, opts` apply to every `~DJ` in the module.

```elixir
use Djot

~DJ"""
This is a Djot document. \
It will be compiled to HTML automatically, at compile time!
"""HTML
# => "<p>This is a Djot document. <br>\nIt will be compiled to HTML automatically, at compile time!</p>\n"
```

### Streaming

```elixir
chunks
|> Djot.stream()
|> Enum.each(fn {id, doc} -> send(self(), {:block, id, Djot.to_html!(doc)}) end)
```

Each emission replaces the block with the same `id`. Plugins attach once and their
steps run on every emitted block document (see the `:stream` private key above).

## Installation

```elixir
def deps do
  [
    {:djot, "~> 0.1.0"}
  ]
end
```

## See also

If you want something that runs on _pure BEAM_ code, checkout [jot](https://hex.pm/packages/jot), written in Gleam.

This package is inspired by the excellent [mdex](https://hex.pm/packages/mdex) package.

# Djot

<div align=center>

[![Hex.pm](https://img.shields.io/hexpm/v/djot?style=for-the-badge&color=%23714a94)](https://hex.pm/packages/djot)

</div>

A fast [Djot](https://djot.net) parser and formatter for Elixir.

Djot parsing and transformations powered by the [jotdown](https://crates.io/crates/jotdown) rust crate.
The API follows [MDEx](https://hex.pm/packages/mdex): a document AST, a plugin pipeline,
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
See `Djot.Document` for an example. Use `Djot.Raw` nodes with `Djot.safe_html/2`
to inject HTML from a plugin.

```elixir
Djot.to_html!("hi", plugins: [{MyPlugin, my_option: true}])
```

### Syntax highlighting

syntect is built in; [Lumis](https://hex.pm/packages/lumis) is used when you add
`{:lumis, "~> 0.10"}` and a parser package such as `{:lumis_wasm_elixir, "~> 0.26"}`.

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

### Sanitization

```elixir
Djot.to_html!(source, sanitize: Djot.Document.default_sanitize_options())
Djot.safe_html("<script>x</script><b>ok</b>")
# => "<b>ok</b>"
```

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

### Sigil

`use Djot` (or `import Djot.Sigil`) provides `~DJ`, evaluated at compile time:
`~DJ"..."` returns a `%Djot.Document{}`, `~DJ"..."HTML` the HTML string, and
`~DJ"..."HEEX` a rendered HEEx template.

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

Each emission replaces the block with the same `id`.

## Installation

```elixir
def deps do
  [
    {:djot, "~> 0.1.0"}
  ]
end
```

## See Also

If you want something that runs on _pure BEAM_ code, checkout [jot](https://hex.pm/packages/jot), written in Gleam.

This package is inspired by the excellent [mdex](https://hex.pm/packages/mdex) package.

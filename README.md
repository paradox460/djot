# Djot

<div align=center>

[![Hex.pm](https://img.shields.io/hexpm/v/djot?style=for-the-badge&color=%23714a94)](https://hex.pm/packages/djot)

</div>

A fast [Djot](https://djot.net) parser and formatter for Elixir.

Djot parsing and transformations powered by the [jotdown](https://crates.io/crates/jotdown) rust crate.

## Usage

Simply call `to_html` on a string that contains Djot data, and you'll get back a html fragment.

```elixir
Djot.to_html("hello *world*!")
# => {:ok, "<p>hello <strong>world</strong>!</p>\n"}
```

### Sigil

If you want to write Djot contents inline in an Elixir program, you can use the provided sigil

```elixir
import Djot.Sigil

~d"""
This is a Djot document. \
It will be compiled to HTML automatically, at compile time!

Here's some display math, thank you djot!

$$`
\frac{-b \pm \sqrt{b^2 - 4 a c}}{2 a}
`
"""
# => "<p>This is a Djot document. <br>\nIt will be compiled to HTML automatically, at compile time!</p>\n<p><span class=\"math display\">\\[\n\\frac{-b \\pm \\sqrt{b^2 - 4 a c}}{2 a}\n\\]</span></p>\n"
```

This can be useful when paired with tools such as the [Tableau SSG](https://github.com/elixir-tools/tableau)

### Options

The Djot renderer accepts a few options:

| Option                 | Values                               | Description                                                              |
| ---------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| `renderer`             | `:default`, `:minified`, `:indented` | Which particular output renderer to use                                  |
| `indent_string`        | String                               | String which is used to indent lines when using the `:indented` renderer |
| `indent_initial_level` | Integer                              | How deep the initial indent starts at                                    |

These are passed to the `Djot.to_html` calls as follows:

```elixir
Djot.to_html(document, renderer: :indented, indent_string: "    ", initial_indent_level: 1)
```

If you are using the bang variant of `to_html/2`, substitute it where appropriate

## Installation

Add `:djot` as a dependency:

```elixir
def deps do
[
  {:djot, "~> 0.1.0"}
]
```

## See Also

If you want something that runs on _pure BEAM_ code, checkout [jot](https://hex.pm/packages/jot), written in Gleam.

This package is inspired by the excellent [mdex](https://hex.pm/packages/mdex) package.

There is no syntax highlighting out of the box with this package. If you want server-side highlighting, I recommend [autumn](https://hex.pm/packages/autumn).

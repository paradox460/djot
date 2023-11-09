# Djot
<div align=center>

[![Hex.pm](https://img.shields.io/hexpm/v/djot?style=for-the-badge&color=%23714a94)](https://hex.pm/packages/djot)

</div>

A fast [Djot](https://djot.net) parser and formatter for Elixir.

Djot parsing and transformations powered by the [jotdown](https://crates.io/crates/jotdown) rust crate.

## Goals
- [x] Fast Djot to HTML transforms
- [ ] Precompiled binary
- [ ] Optional sanitization
- [ ] Syntax highlighting via autumn or inkjet

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

## Installation

Add `:djot` as a dependency:

```elixir
def deps do
[
  {:djot, "~> 0.1.0"}
]
```

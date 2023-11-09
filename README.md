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

## Installation

Add `:djot` as a dependency:

```elixir
def deps do
[
  {:djot, "~> 0.1.0"}
]
```

# Node structs for the Djot document tree. Field names mirror
# native/djot_nif/src/ast.rs exactly; change both together.

block = [
  {Djot.Section, "A section wrapping a heading and the blocks under it.",
   [id: "", nodes: [], attributes: []]},
  {Djot.Heading,
   "A heading. `has_section` is true when wrapped by a `Djot.Section` that owns the id.",
   [level: 1, id: "", has_section: false, nodes: [], attributes: []]},
  {Djot.Paragraph, "A paragraph.", [nodes: [], attributes: []]},
  {Djot.Blockquote, "A block quote.", [nodes: [], attributes: []]},
  {Djot.Div, "A `:::` div. `class` is the class given after the fence.",
   [class: "", nodes: [], attributes: []]},
  {Djot.List,
   """
   A list.

   * `kind` - `:bullet`, `:ordered`, or `:task`
   * `bullet` - `:dash`, `:star`, `:plus` (bullet and task lists), otherwise `nil`
   * `numbering` - `:decimal`, `:alpha_lower`, `:alpha_upper`, `:roman_lower`, `:roman_upper` (ordered only)
   * `style` - `:period`, `:paren`, `:paren_paren` (ordered only)
   * `start` - first number (ordered only)
   """,
   [
     kind: :bullet,
     bullet: :dash,
     numbering: nil,
     style: nil,
     start: nil,
     tight: true,
     nodes: [],
     attributes: []
   ]},
  {Djot.ListItem, "An item of a bullet or ordered list.", [nodes: [], attributes: []]},
  {Djot.TaskListItem, "An item of a task list.", [checked: false, nodes: [], attributes: []]},
  {Djot.DescriptionList, "A definition list.", [nodes: [], attributes: []]},
  {Djot.DescriptionTerm, "A term in a definition list.", [nodes: [], attributes: []]},
  {Djot.DescriptionDetails, "The details of a definition list term.",
   [nodes: [], attributes: []]},
  {Djot.Table, "A table.", [nodes: [], attributes: []]},
  {Djot.TableRow, "A table row.", [head: false, nodes: [], attributes: []]},
  {Djot.TableCell,
   "A table cell. `alignment` is `:unspecified`, `:left`, `:center`, or `:right`.",
   [alignment: :unspecified, head: false, nodes: [], attributes: []]},
  {Djot.Caption, "A table caption.", [nodes: [], attributes: []]},
  {Djot.Footnote, "A footnote definition.", [label: "", nodes: [], attributes: []]},
  {Djot.LinkDefinition, "A reference link definition. Not rendered.",
   [label: "", url: "", attributes: []]},
  {Djot.CodeBlock, "A fenced code block.", [language: "", literal: "", attributes: []]},
  {Djot.RawBlock, "A raw block (```` ```=format ````). Only `html` is rendered.",
   [format: "", literal: "", attributes: []]},
  {Djot.ThematicBreak, "A thematic break (`<hr>`).", [attributes: []]}
]

inline = [
  {Djot.Text, "Plain text.", [literal: ""]},
  {Djot.Span, "A `[text]{attrs}` span.", [nodes: [], attributes: []]},
  {Djot.Emphasis, "Emphasis (`_x_`).", [nodes: [], attributes: []]},
  {Djot.Strong, "Strong emphasis (`*x*`).", [nodes: [], attributes: []]},
  {Djot.Mark, "Highlighted text (`{=x=}`).", [nodes: [], attributes: []]},
  {Djot.Insert, "Inserted text (`{+x+}`).", [nodes: [], attributes: []]},
  {Djot.Delete, "Deleted text (`{-x-}`).", [nodes: [], attributes: []]},
  {Djot.Superscript, "Superscript (`^x^`).", [nodes: [], attributes: []]},
  {Djot.Subscript, "Subscript (`~x~`).", [nodes: [], attributes: []]},
  {Djot.Link,
   "A link. `link_type` is `:inline`, `:reference`, `:unresolved`, `:autolink`, or `:email`.",
   [url: "", link_type: :inline, nodes: [], attributes: []]},
  {Djot.Image, "An image; `nodes` are the alt text. `link_type` as in `Djot.Link`.",
   [url: "", link_type: :inline, nodes: [], attributes: []]},
  {Djot.Verbatim, "Inline code.", [literal: "", attributes: []]},
  {Djot.Math, "Inline (`$`x``) or display (`$$`x``) math.",
   [display: false, literal: "", attributes: []]},
  {Djot.RawInline, "Raw inline content (`` `x`{=format} ``). Only `html` is rendered.",
   [format: "", literal: "", attributes: []]},
  {Djot.FootnoteReference, "A footnote reference (`[^label]`).", [label: ""]},
  {Djot.Symbol, "A symbol (`:name:`), rendered as `:name:`.", [name: ""]},
  {Djot.SmartPunctuation,
   "Smart punctuation. `kind` is `:left_single_quote`, `:right_single_quote`, `:left_double_quote`, `:right_double_quote`, `:ellipsis`, `:en_dash`, or `:em_dash`.",
   [kind: :ellipsis]},
  {Djot.NonBreakingSpace, "A non-breaking space (`\\ `).", []},
  {Djot.SoftBreak, "A soft line break.", []},
  {Djot.HardBreak, "A hard line break.", []},
  {Djot.Raw,
   "Raw HTML written verbatim. Never produced by the parser; for plugins (see `Djot.safe_html/2`).",
   [literal: ""]}
]

for {module, doc, fields} <- block ++ inline do
  defmodule module do
    @moduledoc doc <> "\n\nFields: `#{inspect(Keyword.keys(fields))}`."
    use Djot.Document.Access
    defstruct fields
    @type t :: %__MODULE__{}
  end
end

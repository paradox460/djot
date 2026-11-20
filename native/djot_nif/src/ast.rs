//! Rust mirrors of the `Djot.*` node structs defined in `lib/djot/nodes.ex`.
//!
//! Field names must match the Elixir struct fields exactly.

use rustler::{Atom, Decoder, Encoder, Env, Error, NifResult, Term};

pub type Attrs = Vec<(String, String)>;

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum ListKindEx {
    Bullet,
    Ordered,
    Task,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum BulletEx {
    Dash,
    Star,
    Plus,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum NumberingEx {
    Decimal,
    AlphaLower,
    AlphaUpper,
    RomanLower,
    RomanUpper,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum ListStyleEx {
    Period,
    Paren,
    ParenParen,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum AlignmentEx {
    Unspecified,
    Left,
    Center,
    Right,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum LinkTypeEx {
    Inline,
    Reference,
    Unresolved,
    Autolink,
    Email,
}

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum PunctuationEx {
    LeftSingleQuote,
    RightSingleQuote,
    LeftDoubleQuote,
    RightDoubleQuote,
    Ellipsis,
    EnDash,
    EmDash,
}

/// Defines one `NifStruct` per node plus the `Node` enum. The decoder dispatches
/// on `__struct__` instead of trying every variant in turn.
macro_rules! nodes {
    ($( $variant:ident => $ex:ident, $module:literal { $($field:ident : $ty:ty),* $(,)? } )*) => {
        $(
            #[derive(Debug, Clone, NifStruct)]
            #[module = $module]
            pub struct $ex { $(pub $field: $ty),* }
        )*

        #[derive(Debug, Clone)]
        pub enum Node { $($variant($ex)),* }

        impl Encoder for Node {
            fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
                match self { $(Node::$variant(inner) => inner.encode(env)),* }
            }
        }

        impl<'a> Decoder<'a> for Node {
            fn decode(term: Term<'a>) -> NifResult<Self> {
                let module: Atom = term.map_get(rustler::types::atom::__struct__())?.decode()?;
                let name = module.to_term(term.get_env()).atom_to_string()?;
                match name.as_str() {
                    $(concat!("Elixir.", $module) => Ok(Node::$variant(term.decode()?)),)*
                    _ => Err(Error::BadArg),
                }
            }
        }
    };
}

nodes! {
    Section => ExSection, "Djot.Section" { id: String, nodes: Vec<Node>, attributes: Attrs }
    Heading => ExHeading, "Djot.Heading" { level: u16, id: String, has_section: bool, nodes: Vec<Node>, attributes: Attrs }
    Paragraph => ExParagraph, "Djot.Paragraph" { nodes: Vec<Node>, attributes: Attrs }
    Blockquote => ExBlockquote, "Djot.Blockquote" { nodes: Vec<Node>, attributes: Attrs }
    Div => ExDiv, "Djot.Div" { class: String, nodes: Vec<Node>, attributes: Attrs }
    List => ExList, "Djot.List" {
        kind: ListKindEx,
        bullet: Option<BulletEx>,
        numbering: Option<NumberingEx>,
        style: Option<ListStyleEx>,
        start: Option<u64>,
        tight: bool,
        nodes: Vec<Node>,
        attributes: Attrs,
    }
    ListItem => ExListItem, "Djot.ListItem" { nodes: Vec<Node>, attributes: Attrs }
    TaskListItem => ExTaskListItem, "Djot.TaskListItem" { checked: bool, nodes: Vec<Node>, attributes: Attrs }
    DescriptionList => ExDescriptionList, "Djot.DescriptionList" { nodes: Vec<Node>, attributes: Attrs }
    DescriptionTerm => ExDescriptionTerm, "Djot.DescriptionTerm" { nodes: Vec<Node>, attributes: Attrs }
    DescriptionDetails => ExDescriptionDetails, "Djot.DescriptionDetails" { nodes: Vec<Node>, attributes: Attrs }
    Table => ExTable, "Djot.Table" { nodes: Vec<Node>, attributes: Attrs }
    TableRow => ExTableRow, "Djot.TableRow" { head: bool, nodes: Vec<Node>, attributes: Attrs }
    TableCell => ExTableCell, "Djot.TableCell" { alignment: AlignmentEx, head: bool, nodes: Vec<Node>, attributes: Attrs }
    Caption => ExCaption, "Djot.Caption" { nodes: Vec<Node>, attributes: Attrs }
    Footnote => ExFootnote, "Djot.Footnote" { label: String, nodes: Vec<Node>, attributes: Attrs }
    LinkDefinition => ExLinkDefinition, "Djot.LinkDefinition" { label: String, url: String, attributes: Attrs }
    CodeBlock => ExCodeBlock, "Djot.CodeBlock" { language: String, literal: String, attributes: Attrs }
    RawBlock => ExRawBlock, "Djot.RawBlock" { format: String, literal: String, attributes: Attrs }
    ThematicBreak => ExThematicBreak, "Djot.ThematicBreak" { attributes: Attrs }
    Text => ExText, "Djot.Text" { literal: String }
    Span => ExSpan, "Djot.Span" { nodes: Vec<Node>, attributes: Attrs }
    Emphasis => ExEmphasis, "Djot.Emphasis" { nodes: Vec<Node>, attributes: Attrs }
    Strong => ExStrong, "Djot.Strong" { nodes: Vec<Node>, attributes: Attrs }
    Mark => ExMark, "Djot.Mark" { nodes: Vec<Node>, attributes: Attrs }
    Insert => ExInsert, "Djot.Insert" { nodes: Vec<Node>, attributes: Attrs }
    Delete => ExDelete, "Djot.Delete" { nodes: Vec<Node>, attributes: Attrs }
    Superscript => ExSuperscript, "Djot.Superscript" { nodes: Vec<Node>, attributes: Attrs }
    Subscript => ExSubscript, "Djot.Subscript" { nodes: Vec<Node>, attributes: Attrs }
    Link => ExLink, "Djot.Link" { url: String, link_type: LinkTypeEx, nodes: Vec<Node>, attributes: Attrs }
    Image => ExImage, "Djot.Image" { url: String, link_type: LinkTypeEx, nodes: Vec<Node>, attributes: Attrs }
    Verbatim => ExVerbatim, "Djot.Verbatim" { literal: String, attributes: Attrs }
    Math => ExMath, "Djot.Math" { display: bool, literal: String, attributes: Attrs }
    RawInline => ExRawInline, "Djot.RawInline" { format: String, literal: String, attributes: Attrs }
    FootnoteReference => ExFootnoteReference, "Djot.FootnoteReference" { label: String }
    Symbol => ExSymbol, "Djot.Symbol" { name: String }
    SmartPunctuation => ExSmartPunctuation, "Djot.SmartPunctuation" { kind: PunctuationEx }
    NonBreakingSpace => ExNonBreakingSpace, "Djot.NonBreakingSpace" {}
    SoftBreak => ExSoftBreak, "Djot.SoftBreak" {}
    HardBreak => ExHardBreak, "Djot.HardBreak" {}
    Raw => ExRaw, "Djot.Raw" { literal: String }
}

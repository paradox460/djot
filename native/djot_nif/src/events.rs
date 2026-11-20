//! Conversion between jotdown events and the `Node` tree.

use std::borrow::Cow;

use jotdown::{
    Alignment, AttributeKind, AttributeValue, Attributes, Container, Event, LinkType,
    ListBulletType, ListKind, OrderedListNumbering, OrderedListStyle, SpanLinkType,
};

use crate::ast::*;

struct Frame<'s> {
    container: Container<'s>,
    attributes: Attrs,
    children: Vec<Node>,
    literal: String,
}

fn is_literal(c: &Container) -> bool {
    matches!(
        c,
        Container::CodeBlock { .. }
            | Container::RawBlock { .. }
            | Container::Verbatim
            | Container::Math { .. }
            | Container::RawInline { .. }
            | Container::LinkDefinition { .. }
    )
}

fn attrs_to_ex(attrs: &Attributes) -> Attrs {
    attrs
        .iter()
        .filter_map(|(kind, value)| {
            let key = match kind {
                AttributeKind::Class => "class".to_string(),
                AttributeKind::Id => "id".to_string(),
                AttributeKind::Pair { key } => key.to_string(),
                AttributeKind::Comment => return None,
            };
            Some((key, value.parts().collect::<String>()))
        })
        .collect()
}

fn push_child(children: &mut Vec<Node>, node: Node) {
    if let Node::Text(ExText { literal }) = &node
        && let Some(Node::Text(prev)) = children.last_mut()
    {
        prev.literal.push_str(literal);
        return;
    }
    children.push(node);
}

/// Builds the children of `Document` from a balanced event stream.
pub fn nodes_from_events<'s>(events: impl Iterator<Item = Event<'s>>) -> Vec<Node> {
    let mut stack: Vec<Frame<'s>> = vec![Frame {
        container: Container::Document,
        attributes: Vec::new(),
        children: Vec::new(),
        literal: String::new(),
    }];

    for event in events {
        match event {
            Event::Start(Container::Document, _) | Event::End(Container::Document) => {}
            Event::Start(container, attrs) => stack.push(Frame {
                container,
                attributes: attrs_to_ex(&attrs),
                children: Vec::new(),
                literal: String::new(),
            }),
            Event::End(_) => {
                if stack.len() > 1 {
                    let frame = stack.pop().expect("frame");
                    let node = build(frame);
                    let parent = stack.last_mut().expect("parent");
                    push_child(&mut parent.children, node);
                }
            }
            other => {
                let top = stack.last_mut().expect("frame");
                if is_literal(&top.container) {
                    match other {
                        Event::Str(s) => top.literal.push_str(&s),
                        Event::Softbreak | Event::Hardbreak => top.literal.push('\n'),
                        _ => {}
                    }
                    continue;
                }
                let node = match other {
                    Event::Str(s) => Node::Text(ExText {
                        literal: s.into_owned(),
                    }),
                    Event::FootnoteReference(label) => {
                        Node::FootnoteReference(ExFootnoteReference {
                            label: label.into_owned(),
                        })
                    }
                    Event::Symbol(name) => Node::Symbol(ExSymbol {
                        name: name.into_owned(),
                    }),
                    Event::LeftSingleQuote => punct(PunctuationEx::LeftSingleQuote),
                    Event::RightSingleQuote => punct(PunctuationEx::RightSingleQuote),
                    Event::LeftDoubleQuote => punct(PunctuationEx::LeftDoubleQuote),
                    Event::RightDoubleQuote => punct(PunctuationEx::RightDoubleQuote),
                    Event::Ellipsis => punct(PunctuationEx::Ellipsis),
                    Event::EnDash => punct(PunctuationEx::EnDash),
                    Event::EmDash => punct(PunctuationEx::EmDash),
                    Event::NonBreakingSpace => Node::NonBreakingSpace(ExNonBreakingSpace {}),
                    Event::Softbreak => Node::SoftBreak(ExSoftBreak {}),
                    Event::Hardbreak => Node::HardBreak(ExHardBreak {}),
                    Event::ThematicBreak(attrs) => Node::ThematicBreak(ExThematicBreak {
                        attributes: attrs_to_ex(&attrs),
                    }),
                    Event::Escape | Event::Blankline | Event::Attributes(_) => continue,
                    Event::Start(..) | Event::End(_) => unreachable!(),
                };
                push_child(&mut top.children, node);
            }
        }
    }

    // The parser always balances events; fold anything left open just in case.
    while stack.len() > 1 {
        let frame = stack.pop().expect("frame");
        let node = build(frame);
        let parent = stack.last_mut().expect("parent");
        push_child(&mut parent.children, node);
    }
    stack.pop().map(|f| f.children).unwrap_or_default()
}

fn punct(kind: PunctuationEx) -> Node {
    Node::SmartPunctuation(ExSmartPunctuation { kind })
}

fn bullet_ex(b: ListBulletType) -> BulletEx {
    match b {
        ListBulletType::Dash => BulletEx::Dash,
        ListBulletType::Star => BulletEx::Star,
        ListBulletType::Plus => BulletEx::Plus,
    }
}

fn span_link_ex(t: SpanLinkType) -> LinkTypeEx {
    match t {
        SpanLinkType::Inline => LinkTypeEx::Inline,
        SpanLinkType::Reference => LinkTypeEx::Reference,
        SpanLinkType::Unresolved => LinkTypeEx::Unresolved,
    }
}

fn build(frame: Frame) -> Node {
    let Frame {
        container,
        attributes,
        children: nodes,
        literal,
    } = frame;

    match container {
        Container::Document => unreachable!("Document frames are never pushed"),
        Container::Blockquote => Node::Blockquote(ExBlockquote { nodes, attributes }),
        Container::List { kind, tight } => {
            let (kind, bullet, numbering, style, start) = match kind {
                ListKind::Unordered(b) => {
                    (ListKindEx::Bullet, Some(bullet_ex(b)), None, None, None)
                }
                ListKind::Task(b) => (ListKindEx::Task, Some(bullet_ex(b)), None, None, None),
                ListKind::Ordered {
                    numbering,
                    style,
                    start,
                } => (
                    ListKindEx::Ordered,
                    None,
                    Some(match numbering {
                        OrderedListNumbering::Decimal => NumberingEx::Decimal,
                        OrderedListNumbering::AlphaLower => NumberingEx::AlphaLower,
                        OrderedListNumbering::AlphaUpper => NumberingEx::AlphaUpper,
                        OrderedListNumbering::RomanLower => NumberingEx::RomanLower,
                        OrderedListNumbering::RomanUpper => NumberingEx::RomanUpper,
                    }),
                    Some(match style {
                        OrderedListStyle::Period => ListStyleEx::Period,
                        OrderedListStyle::Paren => ListStyleEx::Paren,
                        OrderedListStyle::ParenParen => ListStyleEx::ParenParen,
                    }),
                    Some(start),
                ),
            };
            Node::List(ExList {
                kind,
                bullet,
                numbering,
                style,
                start,
                tight,
                nodes,
                attributes,
            })
        }
        Container::ListItem => Node::ListItem(ExListItem { nodes, attributes }),
        Container::TaskListItem { checked } => Node::TaskListItem(ExTaskListItem {
            checked,
            nodes,
            attributes,
        }),
        Container::DescriptionList => {
            Node::DescriptionList(ExDescriptionList { nodes, attributes })
        }
        Container::DescriptionDetails => {
            Node::DescriptionDetails(ExDescriptionDetails { nodes, attributes })
        }
        Container::Footnote { label } => Node::Footnote(ExFootnote {
            label: label.into_owned(),
            nodes,
            attributes,
        }),
        Container::Table => Node::Table(ExTable { nodes, attributes }),
        Container::TableRow { head } => Node::TableRow(ExTableRow {
            head,
            nodes,
            attributes,
        }),
        Container::Section { id } => Node::Section(ExSection {
            id: id.into_owned(),
            nodes,
            attributes,
        }),
        Container::Div { class } => Node::Div(ExDiv {
            class: class.into_owned(),
            nodes,
            attributes,
        }),
        Container::Paragraph => Node::Paragraph(ExParagraph { nodes, attributes }),
        Container::Heading {
            level,
            has_section,
            id,
        } => Node::Heading(ExHeading {
            level,
            id: id.into_owned(),
            has_section,
            nodes,
            attributes,
        }),
        Container::TableCell { alignment, head } => Node::TableCell(ExTableCell {
            alignment: match alignment {
                Alignment::Unspecified => AlignmentEx::Unspecified,
                Alignment::Left => AlignmentEx::Left,
                Alignment::Center => AlignmentEx::Center,
                Alignment::Right => AlignmentEx::Right,
            },
            head,
            nodes,
            attributes,
        }),
        Container::Caption => Node::Caption(ExCaption { nodes, attributes }),
        Container::DescriptionTerm => {
            Node::DescriptionTerm(ExDescriptionTerm { nodes, attributes })
        }
        Container::LinkDefinition { label } => Node::LinkDefinition(ExLinkDefinition {
            label: label.into_owned(),
            url: literal,
            attributes,
        }),
        Container::RawBlock { format } => Node::RawBlock(ExRawBlock {
            format: format.into_owned(),
            literal,
            attributes,
        }),
        Container::CodeBlock { language } => Node::CodeBlock(ExCodeBlock {
            language: language.into_owned(),
            literal,
            attributes,
        }),
        Container::Span => Node::Span(ExSpan { nodes, attributes }),
        Container::Link(url, link_type) => Node::Link(ExLink {
            url: url.into_owned(),
            link_type: match link_type {
                LinkType::Span(t) => span_link_ex(t),
                LinkType::AutoLink => LinkTypeEx::Autolink,
                LinkType::Email => LinkTypeEx::Email,
            },
            nodes,
            attributes,
        }),
        Container::Image(url, link_type) => Node::Image(ExImage {
            url: url.into_owned(),
            link_type: span_link_ex(link_type),
            nodes,
            attributes,
        }),
        Container::Verbatim => Node::Verbatim(ExVerbatim {
            literal,
            attributes,
        }),
        Container::Math { display } => Node::Math(ExMath {
            display,
            literal,
            attributes,
        }),
        Container::RawInline { format } => Node::RawInline(ExRawInline {
            format: format.into_owned(),
            literal,
            attributes,
        }),
        Container::Subscript => Node::Subscript(ExSubscript { nodes, attributes }),
        Container::Superscript => Node::Superscript(ExSuperscript { nodes, attributes }),
        Container::Insert => Node::Insert(ExInsert { nodes, attributes }),
        Container::Delete => Node::Delete(ExDelete { nodes, attributes }),
        Container::Strong => Node::Strong(ExStrong { nodes, attributes }),
        Container::Emphasis => Node::Emphasis(ExEmphasis { nodes, attributes }),
        Container::Mark => Node::Mark(ExMark { nodes, attributes }),
    }
}

fn attrs_from_ex(attrs: &Attrs) -> Attributes<'static> {
    attrs
        .iter()
        .map(|(key, value)| {
            let kind = match key.as_str() {
                "class" => AttributeKind::Class,
                "id" => AttributeKind::Id,
                _ => AttributeKind::Pair {
                    key: Cow::Owned(key.clone()),
                },
            };
            (kind, AttributeValue::from(value.replace('\\', "\\\\")))
        })
        .collect()
}

fn owned(s: &str) -> Cow<'static, str> {
    Cow::Owned(s.to_string())
}

fn span_link(t: LinkTypeEx) -> SpanLinkType {
    match t {
        LinkTypeEx::Reference => SpanLinkType::Reference,
        LinkTypeEx::Unresolved => SpanLinkType::Unresolved,
        LinkTypeEx::Inline | LinkTypeEx::Autolink | LinkTypeEx::Email => SpanLinkType::Inline,
    }
}

fn bullet(b: Option<BulletEx>) -> ListBulletType {
    match b {
        Some(BulletEx::Star) => ListBulletType::Star,
        Some(BulletEx::Plus) => ListBulletType::Plus,
        Some(BulletEx::Dash) | None => ListBulletType::Dash,
    }
}

/// Inverse of [`nodes_from_events`]: a balanced event stream wrapped in `Document`.
pub fn events_from_nodes(nodes: &[Node]) -> Vec<Event<'static>> {
    let mut out = Vec::new();
    out.push(Event::Start(Container::Document, Attributes::new()));
    for node in nodes {
        emit(node, true, &mut out);
    }
    out.push(Event::End(Container::Document));
    out
}

fn container(
    out: &mut Vec<Event<'static>>,
    c: Container<'static>,
    attrs: &Attrs,
    children: &[Node],
    block_children: bool,
) {
    out.push(Event::Start(c.clone(), attrs_from_ex(attrs)));
    for child in children {
        emit(child, block_children, out);
    }
    out.push(Event::End(c));
}

fn literal(out: &mut Vec<Event<'static>>, c: Container<'static>, attrs: &Attrs, text: &str) {
    out.push(Event::Start(c.clone(), attrs_from_ex(attrs)));
    if !text.is_empty() {
        out.push(Event::Str(owned(text)));
    }
    out.push(Event::End(c));
}

fn emit(node: &Node, block_parent: bool, out: &mut Vec<Event<'static>>) {
    match node {
        Node::Section(n) => container(
            out,
            Container::Section { id: owned(&n.id) },
            &n.attributes,
            &n.nodes,
            true,
        ),
        Node::Heading(n) => container(
            out,
            Container::Heading {
                level: n.level,
                has_section: n.has_section,
                id: owned(&n.id),
            },
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::Paragraph(n) => container(out, Container::Paragraph, &n.attributes, &n.nodes, false),
        Node::Blockquote(n) => container(out, Container::Blockquote, &n.attributes, &n.nodes, true),
        Node::Div(n) => container(
            out,
            Container::Div {
                class: owned(&n.class),
            },
            &n.attributes,
            &n.nodes,
            true,
        ),
        Node::List(n) => {
            let kind = match n.kind {
                ListKindEx::Bullet => ListKind::Unordered(bullet(n.bullet)),
                ListKindEx::Task => ListKind::Task(bullet(n.bullet)),
                ListKindEx::Ordered => ListKind::Ordered {
                    numbering: match n.numbering {
                        Some(NumberingEx::AlphaLower) => OrderedListNumbering::AlphaLower,
                        Some(NumberingEx::AlphaUpper) => OrderedListNumbering::AlphaUpper,
                        Some(NumberingEx::RomanLower) => OrderedListNumbering::RomanLower,
                        Some(NumberingEx::RomanUpper) => OrderedListNumbering::RomanUpper,
                        Some(NumberingEx::Decimal) | None => OrderedListNumbering::Decimal,
                    },
                    style: match n.style {
                        Some(ListStyleEx::Paren) => OrderedListStyle::Paren,
                        Some(ListStyleEx::ParenParen) => OrderedListStyle::ParenParen,
                        Some(ListStyleEx::Period) | None => OrderedListStyle::Period,
                    },
                    start: n.start.unwrap_or(1),
                },
            };
            container(
                out,
                Container::List {
                    kind,
                    tight: n.tight,
                },
                &n.attributes,
                &n.nodes,
                false,
            )
        }
        Node::ListItem(n) => container(out, Container::ListItem, &n.attributes, &n.nodes, true),
        Node::TaskListItem(n) => container(
            out,
            Container::TaskListItem { checked: n.checked },
            &n.attributes,
            &n.nodes,
            true,
        ),
        Node::DescriptionList(n) => container(
            out,
            Container::DescriptionList,
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::DescriptionTerm(n) => container(
            out,
            Container::DescriptionTerm,
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::DescriptionDetails(n) => container(
            out,
            Container::DescriptionDetails,
            &n.attributes,
            &n.nodes,
            true,
        ),
        Node::Table(n) => container(out, Container::Table, &n.attributes, &n.nodes, false),
        Node::TableRow(n) => container(
            out,
            Container::TableRow { head: n.head },
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::TableCell(n) => container(
            out,
            Container::TableCell {
                alignment: match n.alignment {
                    AlignmentEx::Unspecified => Alignment::Unspecified,
                    AlignmentEx::Left => Alignment::Left,
                    AlignmentEx::Center => Alignment::Center,
                    AlignmentEx::Right => Alignment::Right,
                },
                head: n.head,
            },
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::Caption(n) => container(out, Container::Caption, &n.attributes, &n.nodes, false),
        Node::Footnote(n) => container(
            out,
            Container::Footnote {
                label: owned(&n.label),
            },
            &n.attributes,
            &n.nodes,
            true,
        ),
        Node::LinkDefinition(n) => literal(
            out,
            Container::LinkDefinition {
                label: owned(&n.label),
            },
            &n.attributes,
            &n.url,
        ),
        Node::CodeBlock(n) => literal(
            out,
            Container::CodeBlock {
                language: owned(&n.language),
            },
            &n.attributes,
            &n.literal,
        ),
        Node::RawBlock(n) => literal(
            out,
            Container::RawBlock {
                format: owned(&n.format),
            },
            &n.attributes,
            &n.literal,
        ),
        Node::ThematicBreak(n) => out.push(Event::ThematicBreak(attrs_from_ex(&n.attributes))),
        Node::Text(n) => out.push(Event::Str(owned(&n.literal))),
        Node::Span(n) => container(out, Container::Span, &n.attributes, &n.nodes, false),
        Node::Emphasis(n) => container(out, Container::Emphasis, &n.attributes, &n.nodes, false),
        Node::Strong(n) => container(out, Container::Strong, &n.attributes, &n.nodes, false),
        Node::Mark(n) => container(out, Container::Mark, &n.attributes, &n.nodes, false),
        Node::Insert(n) => container(out, Container::Insert, &n.attributes, &n.nodes, false),
        Node::Delete(n) => container(out, Container::Delete, &n.attributes, &n.nodes, false),
        Node::Superscript(n) => {
            container(out, Container::Superscript, &n.attributes, &n.nodes, false)
        }
        Node::Subscript(n) => container(out, Container::Subscript, &n.attributes, &n.nodes, false),
        Node::Link(n) => {
            let link_type = match n.link_type {
                LinkTypeEx::Autolink => LinkType::AutoLink,
                LinkTypeEx::Email => LinkType::Email,
                t => LinkType::Span(span_link(t)),
            };
            container(
                out,
                Container::Link(owned(&n.url), link_type),
                &n.attributes,
                &n.nodes,
                false,
            )
        }
        Node::Image(n) => container(
            out,
            Container::Image(owned(&n.url), span_link(n.link_type)),
            &n.attributes,
            &n.nodes,
            false,
        ),
        Node::Verbatim(n) => literal(out, Container::Verbatim, &n.attributes, &n.literal),
        Node::Math(n) => literal(
            out,
            Container::Math { display: n.display },
            &n.attributes,
            &n.literal,
        ),
        Node::RawInline(n) => literal(
            out,
            Container::RawInline {
                format: owned(&n.format),
            },
            &n.attributes,
            &n.literal,
        ),
        Node::FootnoteReference(n) => out.push(Event::FootnoteReference(owned(&n.label))),
        Node::Symbol(n) => out.push(Event::Symbol(owned(&n.name))),
        Node::SmartPunctuation(n) => out.push(match n.kind {
            PunctuationEx::LeftSingleQuote => Event::LeftSingleQuote,
            PunctuationEx::RightSingleQuote => Event::RightSingleQuote,
            PunctuationEx::LeftDoubleQuote => Event::LeftDoubleQuote,
            PunctuationEx::RightDoubleQuote => Event::RightDoubleQuote,
            PunctuationEx::Ellipsis => Event::Ellipsis,
            PunctuationEx::EnDash => Event::EnDash,
            PunctuationEx::EmDash => Event::EmDash,
        }),
        Node::NonBreakingSpace(_) => out.push(Event::NonBreakingSpace),
        Node::SoftBreak(_) => out.push(Event::Softbreak),
        Node::HardBreak(_) => out.push(Event::Hardbreak),
        Node::Raw(n) => {
            let format = Cow::Borrowed("html");
            let c = if block_parent {
                Container::RawBlock { format }
            } else {
                Container::RawInline { format }
            };
            literal(out, c, &Vec::new(), &n.literal)
        }
    }
}

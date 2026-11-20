//! HTML rendering shared by the source and AST paths.

use std::borrow::Cow;
use std::collections::VecDeque;

use jotdown::html::{Indentation, Renderer};
use jotdown::{AttributeKind, Container, Event, Render};

use crate::sanitize::{self, SanitizeOptions};

#[derive(Debug, Clone, Copy, NifUnitEnum)]
pub enum RendererEx {
    Default,
    Minified,
    Indented,
}

#[derive(Debug, NifMap)]
pub struct RenderOptions {
    pub renderer: RendererEx,
    pub indent_string: String,
    pub indent_initial_level: usize,
    pub heex: bool,
    pub sanitize: Option<SanitizeOptions>,
}

/// Code block attributes consumed by syntax highlighting; never rendered.
pub const DECORATORS: [&str; 6] = [
    "theme",
    "pre_class",
    "highlight_lines",
    "highlight_lines_style",
    "highlight_lines_class",
    "include_highlights",
];

pub fn render<'s>(
    events: impl Iterator<Item = Event<'s>>,
    opts: &RenderOptions,
) -> Result<String, String> {
    let events = EventAdapter::new(events, opts.heex);
    let mut html = String::new();

    let mut renderer = match opts.renderer {
        RendererEx::Default => Renderer::default(),
        RendererEx::Minified => Renderer::minified(),
        RendererEx::Indented => Renderer::indented(Indentation {
            string: opts.indent_string.clone(),
            initial_level: opts.indent_initial_level,
        }),
    };

    renderer
        .push_events(events, &mut html)
        .map_err(|_| "render failed".to_string())?;

    match &opts.sanitize {
        Some(s) => sanitize::clean(&html, s),
        None => Ok(html),
    }
}

/// Rewrites events before rendering: strips code block decorators, maps `heex`
/// raw formats to `html`, and escapes braces in text when rendering for HEEx.
struct EventAdapter<'s, I> {
    inner: I,
    heex: bool,
    raw_depth: usize,
    image_depth: usize,
    queue: VecDeque<Event<'s>>,
}

impl<'s, I> EventAdapter<'s, I> {
    fn new(inner: I, heex: bool) -> Self {
        Self {
            inner,
            heex,
            raw_depth: 0,
            image_depth: 0,
            queue: VecDeque::new(),
        }
    }

    fn escape_braces(&mut self, s: &str) {
        let mut rest = s;
        while let Some(i) = rest.find(['{', '}']) {
            if i > 0 {
                self.queue
                    .push_back(Event::Str(Cow::Owned(rest[..i].to_string())));
            }
            let entity = if rest.as_bytes()[i] == b'{' {
                "&lbrace;"
            } else {
                "&rbrace;"
            };
            let raw = Container::RawInline {
                format: Cow::Borrowed("html"),
            };
            self.queue
                .push_back(Event::Start(raw.clone(), Default::default()));
            self.queue.push_back(Event::Str(Cow::Borrowed(entity)));
            self.queue.push_back(Event::End(raw));
            rest = &rest[i + 1..];
        }
        if !rest.is_empty() {
            self.queue
                .push_back(Event::Str(Cow::Owned(rest.to_string())));
        }
    }
}

fn heex_to_html<'s>(c: Container<'s>) -> Container<'s> {
    match c {
        Container::RawBlock { format } if format == "heex" => Container::RawBlock {
            format: Cow::Borrowed("html"),
        },
        Container::RawInline { format } if format == "heex" => Container::RawInline {
            format: Cow::Borrowed("html"),
        },
        c => c,
    }
}

impl<'s, I: Iterator<Item = Event<'s>>> Iterator for EventAdapter<'s, I> {
    type Item = Event<'s>;

    fn next(&mut self) -> Option<Event<'s>> {
        if let Some(e) = self.queue.pop_front() {
            return Some(e);
        }

        match self.inner.next()? {
            Event::Start(c @ Container::CodeBlock { .. }, mut attrs) => {
                let mut classes = Vec::new();
                attrs.retain(|(kind, value)| match kind {
                    AttributeKind::Pair { key } if DECORATORS.contains(&key.as_ref()) => {
                        if key == "pre_class" {
                            classes.push(value.clone());
                        }
                        false
                    }
                    _ => true,
                });
                for value in classes {
                    attrs.push((AttributeKind::Class, value));
                }
                Some(Event::Start(c, attrs))
            }
            Event::Start(c, attrs) => {
                match c {
                    Container::RawBlock { .. } | Container::RawInline { .. } => self.raw_depth += 1,
                    Container::Image(..) => self.image_depth += 1,
                    _ => {}
                }
                let c = if self.heex { heex_to_html(c) } else { c };
                Some(Event::Start(c, attrs))
            }
            Event::End(c) => {
                match c {
                    Container::RawBlock { .. } | Container::RawInline { .. } => {
                        self.raw_depth = self.raw_depth.saturating_sub(1)
                    }
                    Container::Image(..) => self.image_depth = self.image_depth.saturating_sub(1),
                    _ => {}
                }
                let c = if self.heex { heex_to_html(c) } else { c };
                Some(Event::End(c))
            }
            Event::Str(s)
                if self.heex
                    && self.raw_depth == 0
                    && self.image_depth == 0
                    && s.contains(['{', '}']) =>
            {
                self.escape_braces(&s);
                self.queue.pop_front()
            }
            e => Some(e),
        }
    }
}

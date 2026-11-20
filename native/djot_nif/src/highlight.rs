//! syntect highlighting with the two-face syntax and theme sets.

use std::fmt::Write;
use std::sync::LazyLock;

use syntect::easy::HighlightLines;
use syntect::highlighting::{Color, ThemeSet};
use syntect::html::{styled_line_to_highlighted_html, IncludeBackground};
use syntect::parsing::SyntaxSet;
use syntect::util::LinesWithEndings;

use crate::sanitize::escape_html;

static SYNTAXES: LazyLock<SyntaxSet> = LazyLock::new(two_face::syntax::extra_newlines);
static THEMES: LazyLock<ThemeSet> = LazyLock::new(|| two_face::theme::extra().into());

#[derive(Debug, NifMap)]
pub struct SyntectOptions {
    pub theme: Option<String>,
    pub pre_class: Option<String>,
    pub pre_attrs: Vec<(String, String)>,
    pub highlight_lines: Vec<(usize, usize)>,
    pub highlight_lines_style: Option<String>,
    pub highlight_lines_class: Option<String>,
}

fn hex(c: Color) -> String {
    format!("#{:02x}{:02x}{:02x}", c.r, c.g, c.b)
}

pub fn highlight(source: &str, language: &str, o: &SyntectOptions) -> Result<String, String> {
    let theme_name = o
        .theme
        .as_deref()
        .unwrap_or(two_face::theme::EmbeddedThemeName::InspiredGithub.as_name());
    let theme = THEMES
        .themes
        .get(theme_name)
        .ok_or_else(|| format!("unknown syntect theme: {theme_name}"))?;
    let ss: &SyntaxSet = &SYNTAXES;
    let syntax = ss
        .find_syntax_by_token(language)
        .unwrap_or_else(|| ss.find_syntax_plain_text());

    let mut out = String::with_capacity(source.len() * 4);
    out.push_str("<pre class=\"syntect");
    if let Some(class) = o.pre_class.as_deref().filter(|c| !c.is_empty()) {
        out.push(' ');
        out.push_str(&escape_html(class));
    }
    out.push_str("\" style=\"");
    if let Some(fg) = theme.settings.foreground {
        let _ = write!(out, "color:{};", hex(fg));
    }
    if let Some(bg) = theme.settings.background {
        let _ = write!(out, "background-color:{};", hex(bg));
    }
    out.push('"');
    for (k, v) in &o.pre_attrs {
        let _ = write!(out, " {}=\"{}\"", escape_html(k), escape_html(v));
    }
    let _ = write!(out, "><code class=\"language-{}\">", escape_html(language));

    let line_style = match (&o.highlight_lines_style, theme.settings.line_highlight) {
        (Some(s), _) => escape_html(s),
        (None, Some(c)) => format!("background-color:{}{:02x};", hex(c), c.a),
        (None, None) => "background-color:rgba(127,127,127,0.2);".to_string(),
    };
    let line_class = o
        .highlight_lines_class
        .as_deref()
        .filter(|c| !c.is_empty())
        .map(|c| format!(" {}", escape_html(c)))
        .unwrap_or_default();

    let mut h = HighlightLines::new(syntax, theme);
    for (i, line) in LinesWithEndings::from(source).enumerate() {
        let n = i + 1;
        let regions = h.highlight_line(line, ss).map_err(|e| e.to_string())?;
        let html = styled_line_to_highlighted_html(&regions, IncludeBackground::No)
            .map_err(|e| e.to_string())?;
        if o.highlight_lines.iter().any(|&(a, b)| a <= n && n <= b) {
            let _ = write!(
                out,
                "<span class=\"line highlighted{line_class}\" data-line=\"{n}\" style=\"{line_style}\">{html}</span>"
            );
        } else {
            let _ = write!(out, "<span class=\"line\" data-line=\"{n}\">{html}</span>");
        }
    }
    out.push_str("</code></pre>");
    Ok(out)
}

pub fn theme_names() -> Vec<String> {
    let mut names: Vec<String> = THEMES.themes.keys().cloned().collect();
    names.sort();
    names
}

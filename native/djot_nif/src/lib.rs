#[macro_use]
extern crate rustler;

mod ast;
mod events;
mod highlight;
mod render;
mod sanitize;

use rustler::Term;

use crate::ast::Node;
use crate::highlight::SyntectOptions;
use crate::render::RenderOptions;
use crate::sanitize::SanitizeOptions;

// `Result<T, String>` returns encode as `{:ok, t} | {:error, message}`.

#[nif(schedule = "DirtyCpu")]
fn parse(source: &str) -> Vec<Node> {
    events::nodes_from_events(jotdown::Parser::new(source))
}

#[nif(schedule = "DirtyCpu")]
fn source_to_html(source: &str, options: RenderOptions) -> Result<String, String> {
    render::render(jotdown::Parser::new(source), &options)
}

#[nif(schedule = "DirtyCpu")]
fn nodes_to_html(nodes: Term, options: RenderOptions) -> Result<String, String> {
    let nodes: Vec<Node> = nodes
        .decode()
        .map_err(|_| "invalid djot node".to_string())?;
    render::render(events::events_from_nodes(&nodes).into_iter(), &options)
}

#[nif(schedule = "DirtyCpu")]
fn safe_html(
    html: &str,
    sanitize: Option<SanitizeOptions>,
    escape: bool,
) -> Result<String, String> {
    let html = match &sanitize {
        Some(s) => sanitize::clean(html, s)?,
        None => html.to_string(),
    };
    Ok(if escape {
        sanitize::escape_html(&html)
    } else {
        html
    })
}

#[nif(schedule = "DirtyCpu")]
fn syntect_highlight(
    source: &str,
    language: &str,
    options: SyntectOptions,
) -> Result<String, String> {
    highlight::highlight(source, language, &options)
}

#[nif]
fn syntect_themes() -> Vec<String> {
    highlight::theme_names()
}

rustler::init!("Elixir.Djot.Native");

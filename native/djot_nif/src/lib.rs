#[macro_use]
extern crate rustler;

mod options;
use crate::options::DjotOptions;

use jotdown::html::Indentation;
use jotdown::html::Renderer;
use jotdown::Render;
use rustler::nif;
use rustler::Encoder;
use rustler::Env;
use rustler::Error as RustlerError;
use rustler::Term;

rustler::atoms! {
  ok,
  djot_transform
}

#[nif(schedule = "DirtyCpu")]
pub fn to_html<'a>(env: Env<'a>, dj: &str, options: DjotOptions) -> Result<Term<'a>, RustlerError> {
    let events = jotdown::Parser::new(dj);
    let mut html = String::new();

    let renderer = match options.renderer {
        options::DjotRenderer::Default => Renderer::default(),
        options::DjotRenderer::Minified => Renderer::minified(),
        options::DjotRenderer::Indented => Renderer::indented(Indentation {
            string: options.indent_string.unwrap_or("\t".to_string()),
            initial_level: options.indent_initial_level.unwrap_or(0),
        }),
    };

    match renderer.push(events, &mut html) {
        Ok(()) => Ok((ok(), html).encode(env)),
        Err(_e) => Err(RustlerError::Term(Box::new(djot_transform()))),
    }
}

rustler::init!("Elixir.Djot.Native");

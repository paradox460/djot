extern crate rustler;

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
pub fn to_html<'a>(env: Env<'a>, dj: &str) -> Result<Term<'a>, RustlerError> {
    let events = jotdown::Parser::new(dj);
    let mut html = String::new();
    match jotdown::html::Renderer::default().push(events, &mut html) {
        Ok(()) => Ok((ok(), html).encode(env)),
        Err(_e) => Err(RustlerError::Term(Box::new(djot_transform()))),
    }
}

rustler::init!("Elixir.Djot.Native", [to_html]);

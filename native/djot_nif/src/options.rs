#[derive(Clone, Debug, NifUnitEnum)]
pub enum DjotRenderer {
    Default,
    Minified,
    Indented,
}

#[derive(Debug, NifStruct)]
#[module = "Djot.Options"]
pub struct DjotOptions {
    pub renderer: DjotRenderer,
    pub indent_string: Option<String>,
    pub indent_initial_level: Option<usize>,
}

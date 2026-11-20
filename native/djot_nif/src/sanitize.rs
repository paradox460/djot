//! ammonia HTML sanitization.
//!
//! Option mapping adapted from mdex_native (MIT),
//! https://github.com/leandrocp/mdex native/mdex_native_nif/src/types/options/sanitize.rs

use std::collections::{HashMap, HashSet};

use ammonia::{Builder, Url, UrlRelative};

#[derive(Debug, NifTaggedEnum)]
pub enum UrlRelativeEx {
    Deny,
    Passthrough,
    RewriteWithBase(String),
    RewriteWithRoot((String, String)),
}

#[derive(Debug, NifMap)]
pub struct SanitizeOptions {
    pub tags: Vec<String>,
    pub add_tags: Vec<String>,
    pub rm_tags: Vec<String>,
    pub clean_content_tags: Vec<String>,
    pub add_clean_content_tags: Vec<String>,
    pub rm_clean_content_tags: Vec<String>,
    pub tag_attributes: HashMap<String, Vec<String>>,
    pub add_tag_attributes: HashMap<String, Vec<String>>,
    pub rm_tag_attributes: HashMap<String, Vec<String>>,
    pub tag_attribute_values: HashMap<String, HashMap<String, Vec<String>>>,
    pub add_tag_attribute_values: HashMap<String, HashMap<String, Vec<String>>>,
    pub rm_tag_attribute_values: HashMap<String, HashMap<String, Vec<String>>>,
    pub set_tag_attribute_values: HashMap<String, HashMap<String, String>>,
    pub set_tag_attribute_value: HashMap<String, HashMap<String, String>>,
    pub rm_set_tag_attribute_value: HashMap<String, String>,
    pub generic_attribute_prefixes: Vec<String>,
    pub add_generic_attribute_prefixes: Vec<String>,
    pub rm_generic_attribute_prefixes: Vec<String>,
    pub generic_attributes: Vec<String>,
    pub add_generic_attributes: Vec<String>,
    pub rm_generic_attributes: Vec<String>,
    pub url_schemes: Vec<String>,
    pub add_url_schemes: Vec<String>,
    pub rm_url_schemes: Vec<String>,
    pub url_relative: UrlRelativeEx,
    pub link_rel: Option<String>,
    pub allowed_classes: HashMap<String, Vec<String>>,
    pub add_allowed_classes: HashMap<String, Vec<String>>,
    pub rm_allowed_classes: HashMap<String, Vec<String>>,
    pub strip_comments: bool,
    pub id_prefix: Option<String>,
}

fn set(v: &[String]) -> HashSet<&str> {
    v.iter().map(String::as_str).collect()
}

fn map_set(m: &HashMap<String, Vec<String>>) -> HashMap<&str, HashSet<&str>> {
    m.iter().map(|(k, v)| (k.as_str(), set(v))).collect()
}

fn map_map_set(
    m: &HashMap<String, HashMap<String, Vec<String>>>,
) -> HashMap<&str, HashMap<&str, HashSet<&str>>> {
    m.iter().map(|(k, v)| (k.as_str(), map_set(v))).collect()
}

fn map_map(m: &HashMap<String, HashMap<String, String>>) -> HashMap<&str, HashMap<&str, &str>> {
    m.iter()
        .map(|(k, v)| {
            (
                k.as_str(),
                v.iter().map(|(a, b)| (a.as_str(), b.as_str())).collect(),
            )
        })
        .collect()
}

pub fn clean(html: &str, o: &SanitizeOptions) -> Result<String, String> {
    let mut b = Builder::default();

    b.tags(set(&o.tags))
        .add_tags(&o.add_tags)
        .rm_tags(&o.rm_tags);

    b.clean_content_tags(set(&o.clean_content_tags))
        .add_clean_content_tags(&o.add_clean_content_tags)
        .rm_clean_content_tags(&o.rm_clean_content_tags);

    b.tag_attributes(map_set(&o.tag_attributes));
    for (tag, attrs) in &o.add_tag_attributes {
        b.add_tag_attributes(tag, attrs);
    }
    for (tag, attrs) in &o.rm_tag_attributes {
        b.rm_tag_attributes(tag, attrs);
    }

    b.tag_attribute_values(map_map_set(&o.tag_attribute_values));
    for (tag, attrs) in &o.add_tag_attribute_values {
        for (attr, values) in attrs {
            b.add_tag_attribute_values(tag, attr, values);
        }
    }
    for (tag, attrs) in &o.rm_tag_attribute_values {
        for (attr, values) in attrs {
            b.rm_tag_attribute_values(tag, attr, values);
        }
    }

    b.set_tag_attribute_values(map_map(&o.set_tag_attribute_values));
    for (tag, attrs) in &o.set_tag_attribute_value {
        for (attr, value) in attrs {
            b.set_tag_attribute_value(tag, attr, value);
        }
    }
    for (tag, attr) in &o.rm_set_tag_attribute_value {
        b.rm_set_tag_attribute_value(tag, attr);
    }

    b.generic_attribute_prefixes(set(&o.generic_attribute_prefixes))
        .add_generic_attribute_prefixes(&o.add_generic_attribute_prefixes)
        .rm_generic_attribute_prefixes(&o.rm_generic_attribute_prefixes);

    b.generic_attributes(set(&o.generic_attributes))
        .add_generic_attributes(&o.add_generic_attributes)
        .rm_generic_attributes(&o.rm_generic_attributes);

    b.url_schemes(set(&o.url_schemes))
        .add_url_schemes(&o.add_url_schemes)
        .rm_url_schemes(&o.rm_url_schemes);

    b.url_relative(match &o.url_relative {
        UrlRelativeEx::Deny => UrlRelative::Deny,
        UrlRelativeEx::Passthrough => UrlRelative::PassThrough,
        UrlRelativeEx::RewriteWithBase(base) => UrlRelative::RewriteWithBase(
            Url::parse(base).map_err(|e| format!("invalid url_relative base: {e}"))?,
        ),
        UrlRelativeEx::RewriteWithRoot((root, path)) => UrlRelative::RewriteWithRoot {
            root: Url::parse(root).map_err(|e| format!("invalid url_relative base: {e}"))?,
            path: path.clone(),
        },
    });

    b.link_rel(o.link_rel.as_deref());

    b.allowed_classes(map_set(&o.allowed_classes));
    for (tag, classes) in &o.add_allowed_classes {
        b.add_allowed_classes(tag, classes);
    }
    for (tag, classes) in &o.rm_allowed_classes {
        b.rm_allowed_classes(tag, classes);
    }

    b.strip_comments(o.strip_comments);
    b.id_prefix(o.id_prefix.as_deref());

    Ok(b.clean(html).to_string())
}

/// Escapes `& < > " '` for safe inclusion in HTML text or attribute values.
pub fn escape_html(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            c => out.push(c),
        }
    }
    out
}

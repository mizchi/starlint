///|
pub struct RuleConfig {
  enabled : Bool?
  severity : Severity?
}

///|
pub struct CategoryConfig {
  enabled : Bool?
  severity : Severity?
}

///|
pub struct LintConfig {
  rules : Map[String, RuleConfig]
  categories : Map[String, CategoryConfig]
}

///|
pub fn LintConfig::empty() -> LintConfig {
  { rules: Map::new(), categories: Map::new() }
}

///|
pub fn LintConfig::recommended() -> LintConfig {
  LintConfig::enable_categories(["fp", "size", "async", "error"])
}

///|
pub fn LintConfig::preset(name : String) -> LintConfig? {
  match name.to_lower() {
    "recommended" => Some(LintConfig::recommended())
    _ => None
  }
}

///|
fn parse_bool(json : Json) -> Bool? {
  match json {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
fn severity_from_string(value : String) -> Severity? {
  match value.to_lower() {
    "info" => Some(Severity::Info)
    "warn" => Some(Severity::Warning)
    "warning" => Some(Severity::Warning)
    "error" => Some(Severity::Error)
    _ => None
  }
}

///|
fn parse_severity(json : Json) -> Severity? {
  match json {
    String(value) => severity_from_string(value)
    _ => None
  }
}

///|
fn parse_rule_config(json : Json) -> RuleConfig? {
  match json {
    True => Some(RuleConfig::{ enabled: Some(true), severity: None })
    False => Some(RuleConfig::{ enabled: Some(false), severity: None })
    String(value) =>
      match value.to_lower() {
        "off" => Some(RuleConfig::{ enabled: Some(false), severity: None })
        _ =>
          match severity_from_string(value) {
            Some(severity) =>
              Some(RuleConfig::{ enabled: Some(true), severity: Some(severity) })
            None => None
          }
      }
    Object(obj) => {
      let enabled = match obj.get("enabled") {
        Some(value) => parse_bool(value)
        None => None
      }
      let severity = match obj.get("severity") {
        Some(value) => parse_severity(value)
        None => None
      }
      Some(RuleConfig::{ enabled, severity })
    }
    _ => None
  }
}

///|
fn parse_category_config(json : Json) -> CategoryConfig? {
  match json {
    True => Some(CategoryConfig::{ enabled: Some(true), severity: None })
    False => Some(CategoryConfig::{ enabled: Some(false), severity: None })
    String(value) =>
      match value.to_lower() {
        "off" => Some(CategoryConfig::{ enabled: Some(false), severity: None })
        _ =>
          match severity_from_string(value) {
            Some(severity) =>
              Some(CategoryConfig::{
                enabled: Some(true),
                severity: Some(severity),
              })
            None => None
          }
      }
    Object(obj) => {
      let enabled = match obj.get("enabled") {
        Some(value) => parse_bool(value)
        None => None
      }
      let severity = match obj.get("severity") {
        Some(value) => parse_severity(value)
        None => None
      }
      Some(CategoryConfig::{ enabled, severity })
    }
    _ => None
  }
}

///|
pub fn LintConfig::from_json(text : String) -> LintConfig raise {
  let json = @json.parse(text)
  let mut base = LintConfig::empty()
  match json {
    Object(obj) => {
      match obj.get("preset") {
        Some(String(name)) =>
          if LintConfig::preset(name) is Some(preset) {
            base = preset
          }
        _ => ()
      }
      let rules = base.rules
      let categories = base.categories
      match obj.get("rules") {
        Some(Object(rule_obj)) =>
          for name, value in rule_obj {
            match parse_rule_config(value) {
              Some(config) => rules.set(name, config)
              None => ()
            }
          }
        _ => ()
      }
      match obj.get("categories") {
        Some(Object(cat_obj)) =>
          for name, value in cat_obj {
            match parse_category_config(value) {
              Some(config) => categories.set(name, config)
              None => ()
            }
          }
        _ => ()
      }
      { rules, categories }
    }
    _ => base
  }
}

///|
pub fn LintConfig::enable_categories(tags : Array[String]) -> LintConfig {
  let categories = Map::new()
  for tag in tags {
    categories.set(tag, CategoryConfig::{ enabled: Some(true), severity: None })
  }
  { rules: Map::new(), categories }
}

///|
fn severity_rank(severity : Severity) -> Int {
  match severity {
    Severity::Info => 0
    Severity::Warning => 1
    Severity::Error => 2
  }
}

///|
fn max_severity(a : Severity, b : Severity) -> Severity {
  if severity_rank(a) >= severity_rank(b) {
    a
  } else {
    b
  }
}

///|
pub fn resolve_rule_settings(
  rule : Rule,
  config : LintConfig,
) -> (Bool, Severity) {
  let mut enabled = rule.enabled_by_default
  let mut severity = rule.default_severity
  let mut category_enabled : Bool? = None
  let mut category_severity : Severity? = None
  for tag in rule.tags {
    match config.categories.get(tag) {
      Some(cat) => {
        match cat.enabled {
          Some(true) =>
            if category_enabled is None {
              category_enabled = Some(true)
            }
          Some(false) => category_enabled = Some(false)
          None => ()
        }
        match cat.severity {
          Some(sev) =>
            category_severity = Some(
              match category_severity {
                Some(prev) => max_severity(prev, sev)
                None => sev
              },
            )
          None => ()
        }
      }
      None => ()
    }
  }
  match category_enabled {
    Some(true) => enabled = true
    Some(false) => enabled = false
    None => ()
  }
  match category_severity {
    Some(sev) => severity = sev
    None => ()
  }
  match config.rules.get(rule.id) {
    Some(rule_conf) => {
      match rule_conf.enabled {
        Some(v) => enabled = v
        None => ()
      }
      match rule_conf.severity {
        Some(sev) => severity = sev
        None => ()
      }
    }
    None => ()
  }
  (enabled, severity)
}

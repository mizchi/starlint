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
  ignore : Array[String]
  overrides : Array[OverrideConfig]
}

///|
pub struct OverrideConfig {
  files : Array[String]
  rules : Map[String, RuleConfig]
  categories : Map[String, CategoryConfig]
}

///|
pub fn LintConfig::empty() -> LintConfig {
  { rules: Map::new(), categories: Map::new(), ignore: [], overrides: [] }
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
      let mut ignore = base.ignore
      let mut overrides = base.overrides
      match obj.get("ignore") {
        Some(Array(items)) => {
          let paths = []
          for item in items {
            match item {
              String(value) => paths.push(value)
              _ => ()
            }
          }
          ignore = paths
        }
        _ => ()
      }
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
      match obj.get("overrides") {
        Some(Array(items)) => {
          let list = []
          for item in items {
            match item {
              Object(override_obj) =>
                match parse_override_config(override_obj) {
                  Some(override_config) => list.push(override_config)
                  None => ()
                }
              _ => ()
            }
          }
          overrides = list
        }
        _ => ()
      }
      { rules, categories, ignore, overrides }
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
  { rules: Map::new(), categories, ignore: [], overrides: [] }
}

///|
fn parse_override_config(obj : Map[String, Json]) -> OverrideConfig? {
  let files = match obj.get("files") {
    Some(Array(items)) => {
      let list = []
      for item in items {
        match item {
          String(value) => list.push(value)
          _ => ()
        }
      }
      list
    }
    _ => []
  }
  if files.length() == 0 {
    return None
  }
  let rules = Map::new()
  let categories = Map::new()
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
  Some(OverrideConfig::{ files, rules, categories })
}

///|
fn clone_rule_map(source : Map[String, RuleConfig]) -> Map[String, RuleConfig] {
  let out = Map::new()
  for name, value in source {
    out.set(name, value)
  }
  out
}

///|
fn clone_category_map(
  source : Map[String, CategoryConfig],
) -> Map[String, CategoryConfig] {
  let out = Map::new()
  for name, value in source {
    out.set(name, value)
  }
  out
}

///|
fn normalize_path(value : String) -> String {
  value.replace_all(old="\\", new="/")
}

///|
fn basename(path : String) -> String {
  let mut idx = path.length()
  while idx > 0 {
    idx = idx - 1
    if path[idx] == ('/' : UInt16) {
      let view_result : Result[StringView, Error] = try? path[idx + 1:]
      return match view_result {
        Ok(view) => view.to_string()
        Err(_) => path
      }
    }
  }
  path
}

///|
fn match_wildcard(pattern : String, value : String) -> Bool {
  let p = pattern
  let s = value
  let mut pi = 0
  let mut si = 0
  let mut star = -1
  let mut match_pos = 0
  while si < s.length() {
    if pi < p.length() && p[pi] == ('*' : UInt16) {
      star = pi
      match_pos = si
      pi = pi + 1
    } else if pi < p.length() && p[pi] == s[si] {
      pi = pi + 1
      si = si + 1
    } else if star != -1 {
      pi = star + 1
      match_pos = match_pos + 1
      si = match_pos
    } else {
      return false
    }
  }
  while pi < p.length() && p[pi] == ('*' : UInt16) {
    pi = pi + 1
  }
  pi == p.length()
}

///|
fn path_matches(pattern : String, filename : String) -> Bool {
  let pat = normalize_path(pattern)
  let file = normalize_path(filename)
  if !pat.contains("*") {
    return file == pat || file.has_suffix("/" + pat)
  }
  if pat.contains("/") {
    match_wildcard(pat, file)
  } else {
    match_wildcard(pat, basename(file))
  }
}

///|
pub fn LintConfig::is_ignored(self : LintConfig, filename : String) -> Bool {
  for pattern in self.ignore {
    if path_matches(pattern, filename) {
      return true
    }
  }
  false
}

///|
pub fn LintConfig::for_file(self : LintConfig, filename : String) -> LintConfig {
  let rules = clone_rule_map(self.rules)
  let categories = clone_category_map(self.categories)
  let merged = LintConfig::{
    rules,
    categories,
    ignore: self.ignore,
    overrides: [],
  }
  for override_ in self.overrides {
    let mut matched = false
    for pattern in override_.files {
      if path_matches(pattern, filename) {
        matched = true
      }
    }
    if matched {
      for name, value in override_.rules {
        merged.rules.set(name, value)
      }
      for name, value in override_.categories {
        merged.categories.set(name, value)
      }
    }
  }
  merged
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

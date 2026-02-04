///|
pub struct Fix {
  range : @basic.Location
  replacement : String
} derive(Show)

///|
pub fn Fix::new(range~ : @basic.Location, replacement~ : String) -> Fix {
  { range, replacement }
}

///|
pub enum Severity {
  Info
  Warning
  Error
} derive(Show, Eq)

///|
pub struct Diagnostic {
  rule_id : String
  loc : @basic.Location
  message : String
  detail : String?
  suggestion : String?
  fix : Fix?
  severity : Severity
} derive(Show)

///|
pub fn Diagnostic::new(
  rule_id~ : String,
  loc~ : @basic.Location,
  message~ : String,
  detail? : String,
  suggestion? : String,
  fix? : Fix,
  severity? : Severity = Severity::Warning,
) -> Diagnostic {
  { rule_id, loc, message, detail, suggestion, fix, severity }
}

///|
pub fn Diagnostic::with_severity(
  self : Diagnostic,
  severity : Severity,
) -> Diagnostic {
  let { rule_id, loc, message, detail, suggestion, fix, .. } = self
  { rule_id, loc, message, detail, suggestion, fix, severity }
}

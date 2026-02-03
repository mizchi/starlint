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
pub struct Diagnostic {
  rule_id : String
  loc : @basic.Location
  message : String
  detail : String?
  suggestion : String?
  fix : Fix?
} derive(Show)

///|
pub fn Diagnostic::new(
  rule_id~ : String,
  loc~ : @basic.Location,
  message~ : String,
  detail? : String,
  suggestion? : String,
  fix? : Fix,
) -> Diagnostic {
  { rule_id, loc, message, detail, suggestion, fix }
}

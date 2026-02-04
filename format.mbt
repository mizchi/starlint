///|
pub fn format_diagnostic(diag : Diagnostic) -> String {
  let sb = StringBuilder::new()
  sb
  ..write_string("Found ")
  ..write_string(diag.rule_id)
  ..write_string(" (")
  ..write_string(diag.severity.to_string())
  ..write_string(")")
  ..write_string(" at ")
  ..write_string(diag.loc.to_string())
  ..write_string(":\n\n")
  ..write_string(diag.message)
  match diag.detail {
    Some(detail) => sb..write_string("\n\n")..write_string(detail)
    None => ()
  }
  match diag.suggestion {
    Some(suggestion) =>
      sb..write_string("\n\nSuggestion: ")..write_string(suggestion)
    None => ()
  }
  match diag.fix {
    Some(fix) =>
      sb
      ..write_string("\n\nFix: replace ")
      ..write_string(fix.range.to_string())
      ..write_string(" with:\n")
      ..write_string(fix.replacement)
    None => ()
  }
  sb..write_string("\n")
  sb.to_string()
}

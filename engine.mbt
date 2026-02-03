///|
pub fn lint(input : LintInput, rules : Array[Rule]) -> Array[Diagnostic] {
  let diagnostics = Array::new(capacity=0)
  for rule in rules {
    for diag in rule.run(input) {
      diagnostics.push(diag)
    }
  } else {
    diagnostics
  }
}

///|
pub fn lint_impls(
  impls : @syntax.Impls,
  rules : Array[Rule],
) -> Array[Diagnostic] {
  lint(LintInput::new(impls~, source="", filename=""), rules)
}

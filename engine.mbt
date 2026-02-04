///|
pub fn lint(input : LintInput, rules : Array[Rule]) -> Array[Diagnostic] {
  lint_with_config(input, rules, LintConfig::empty())
}

///|
pub fn lint_with_config(
  input : LintInput,
  rules : Array[Rule],
  config : LintConfig,
) -> Array[Diagnostic] {
  let diagnostics = Array::new(capacity=0)
  for rule in rules {
    let (enabled, severity) = resolve_rule_settings(rule, config)
    if enabled {
      for diag in rule.apply(input) {
        diagnostics.push(diag.with_severity(severity))
      }
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

///|
pub fn lint_impls_with_config(
  impls : @syntax.Impls,
  rules : Array[Rule],
  config : LintConfig,
) -> Array[Diagnostic] {
  lint_with_config(
    LintInput::new(impls~, source="", filename=""),
    rules,
    config,
  )
}

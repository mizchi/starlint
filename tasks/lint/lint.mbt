///|

///|
/// Reference implementation for `mizchi/starlint/tasks/lint`.
/// Integrators can copy this module and replace `rules()` / composition logic
/// for environment-specific rule sets.
pub fn rules() -> Array[@starlint.Rule] {
  @rules.rules()
}

///|
pub fn lint(impls : @syntax.Impls) -> Array[@starlint.Diagnostic] {
  @starlint.lint_impls(impls, rules())
}

///|
pub fn lint_with_config(
  impls : @syntax.Impls,
  config : @starlint.LintConfig,
) -> Array[@starlint.Diagnostic] {
  @starlint.lint_impls_with_config(impls, rules(), config)
}

///|

///|
/// Compose the default rule set with environment-specific extra rules.
pub fn compose_rules(
  extra_rules : Array[@starlint.Rule],
) -> Array[@starlint.Rule] {
  let all = rules()
  for rule in extra_rules {
    all.push(rule)
  }
  all
}

///|
pub fn lint_with_extra_rules(
  impls : @syntax.Impls,
  extra_rules : Array[@starlint.Rule],
  config? : @starlint.LintConfig = @starlint.LintConfig::recommended(),
) -> Array[@starlint.Diagnostic] {
  @starlint.lint_impls_with_config(impls, compose_rules(extra_rules), config)
}

///|
pub fn lint_source(
  source : String,
  filename? : String = "<input>",
  config? : @starlint.LintConfig = @starlint.LintConfig::recommended(),
) -> (Array[@starlint.Diagnostic], Array[@basic.Report]) {
  let (impls, reports) = @starlint.parse_string_for_lint(source, name=filename)
  if reports.length() > 0 {
    ([], reports)
  } else {
    let input = @starlint.LintInput::new(impls~, source~, filename~)
    (@starlint.lint_with_config(input, rules(), config), [])
  }
}

///|
pub fn lint_source_with_extra_rules(
  source : String,
  extra_rules : Array[@starlint.Rule],
  filename? : String = "<input>",
  config? : @starlint.LintConfig = @starlint.LintConfig::recommended(),
) -> (Array[@starlint.Diagnostic], Array[@basic.Report]) {
  let (impls, reports) = @starlint.parse_string_for_lint(source, name=filename)
  if reports.length() > 0 {
    ([], reports)
  } else {
    let input = @starlint.LintInput::new(impls~, source~, filename~)
    (@starlint.lint_with_config(input, compose_rules(extra_rules), config), [])
  }
}

///|
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

///|
pub fn rules() -> Array[@moonlint.Rule] {
  @rules.rules()
}

///|
pub fn lint(impls : @syntax.Impls) -> Array[@moonlint.Diagnostic] {
  @moonlint.lint_impls(impls, rules())
}

///|
pub fn lint_with_config(
  impls : @syntax.Impls,
  config : @moonlint.LintConfig,
) -> Array[@moonlint.Diagnostic] {
  @moonlint.lint_impls_with_config(impls, rules(), config)
}

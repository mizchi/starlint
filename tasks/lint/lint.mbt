///|
pub fn rules() -> Array[@moonlint.Rule] {
  @rules.rules()
}

///|
pub fn lint(impls : @syntax.Impls) -> Array[@moonlint.Diagnostic] {
  @moonlint.lint_impls(impls, rules())
}

///|
let string_literal_multiply_number_rule_id : String = "string_literal_multiply_number"

///|
let string_literal_multiply_number_description : String = "Prefer .repeat(n) over literal * n for strings."

///|
priv struct StringLiteralMultiplyNumberEnv(Array[@starlint.Diagnostic])

///|
impl @syntax.IterVisitor for StringLiteralMultiplyNumberEnv with visit_Expr(
  env,
  expr,
) {
  if @starlint.match_infix(expr, "*") is Some((lhs, rhs, loc)) &&
    @starlint.match_constant_string(lhs) is Some(str_lit) {
    let message = "String literal multiplied by a number."
    let detail =
      #|"<string literal>" * n
    let suggestion =
      #|If n is an integer expression, rewrite to:
      #|
      #|"<string literal>".repeat(n)
    let fix = match @starlint.match_constant_int(rhs) {
      Some(int_lit) => {
        let replacement = "\"\{str_lit}\".repeat(\{int_lit})"
        Some(@starlint.Fix::new(range=loc, replacement~))
      }
      None => None
    }
    let diag = match fix {
      Some(fix) =>
        @starlint.Diagnostic::new(
          rule_id=string_literal_multiply_number_rule_id,
          loc~,
          message~,
          detail~,
          suggestion~,
          fix~,
        )
      None =>
        @starlint.Diagnostic::new(
          rule_id=string_literal_multiply_number_rule_id,
          loc~,
          message~,
          detail~,
          suggestion~,
        )
    }
    env.0.push(diag)
  }
  env.base().visit_Expr(expr)
}

///|
fn string_literal_multiply_number_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=string_literal_multiply_number_rule_id,
    description=string_literal_multiply_number_description,
    run=input => {
      let env = StringLiteralMultiplyNumberEnv(Array::new(capacity=8))
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        let StringLiteralMultiplyNumberEnv(diags) = env
        diags
      }
    },
  )
}

///|
let boolean_if_true_false_rule_id : String = "boolean_if_true_false"

///|
let boolean_if_true_false_description : String = "Prefer cond over if cond { true } else { false }."

///|
priv struct BooleanIfTrueFalseEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
impl @syntax.IterVisitor for BooleanIfTrueFalseEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.If(cond~, ifso~, ifnot=Some(ifnot), loc~) =>
      if @moonlint.match_constant_bool(ifso) == Some(true) &&
        @moonlint.match_constant_bool(ifnot) == Some(false) {
        let message = "if cond { true } else { false } is redundant."
        let detail =
          #|if cond { true } else { false }
        let suggestion =
          #|Use the condition directly:
          #|
          #|cond
        let fix = match @moonlint.expr_source(env.source, cond) {
          Some(cond_src) =>
            Some(@moonlint.Fix::new(range=loc, replacement=cond_src))
          None => None
        }
        let diag = match fix {
          Some(fix) =>
            @moonlint.Diagnostic::new(
              rule_id=boolean_if_true_false_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
              fix~,
            )
          None =>
            @moonlint.Diagnostic::new(
              rule_id=boolean_if_true_false_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            )
        }
        env.diags.push(diag)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn boolean_if_true_false_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=boolean_if_true_false_rule_id,
    description=boolean_if_true_false_description,
    run=input => {
      let env = BooleanIfTrueFalseEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

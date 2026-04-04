///|
let avoid_ignore_error_rule_id : String = "avoid_ignore_error"

///|
let avoid_ignore_error_description : String = "Avoid silently ignoring errors in catch blocks."

///|
priv struct AvoidIgnoreErrorEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
impl @syntax.IterVisitor for AvoidIgnoreErrorEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Try(catch_~, catch_loc~, ..) => {
      let cases = @internal.list_to_array(catch_)
      if cases.length() == 1 {
        let case_ = cases[0]
        if @internal.is_discard_pattern(case_.pattern) &&
          case_.guard_ is None &&
          @internal.is_unit_expr(case_.body) {
          let message = "Catch block silently ignores error."
          let detail =
            #|foo() catch { _ => () }
          let suggestion =
            #|Handle the error explicitly:
            #|
            #|foo() catch { err => raise err }
          env.diags.push(
            @starlint.Diagnostic::new(
              rule_id=avoid_ignore_error_rule_id,
              loc=catch_loc,
              message~,
              detail~,
              suggestion~,
            ),
          )
        }
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_ignore_error_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=avoid_ignore_error_rule_id,
    description=avoid_ignore_error_description,
    tags=["error"],
    run=input => {
      let env = AvoidIgnoreErrorEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

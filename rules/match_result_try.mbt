///|
let match_result_try_rule_id : String = "match_result_try"

///|
let match_result_try_description : String = "Prefer try/catch over match on try? results (covers constrained/as expressions)."

///|
priv struct MatchResultTryEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn is_try_question_expr(expr : @syntax.Expr, source : String) -> Bool {
  match @internal.unwrap_paren(expr) {
    @syntax.TryOperator(..) =>
      @internal.match_try_question(expr, source~) is Some(_)
    @syntax.Constraint(expr=inner, ..) => is_try_question_expr(inner, source)
    @syntax.As(expr=inner, ..) => is_try_question_expr(inner, source)
    _ => false
  }
}

///|
impl @syntax.IterVisitor for MatchResultTryEnv with fn visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases=_, match_loc=_, loc~) =>
      if is_try_question_expr(subject, env.source) {
        let message = "Avoid match (try? ...) for error handling."
        let detail =
          #|match (try? expr) {
          #|  Ok(value) => <branch_ok>
          #|  Err(err) => <branch_err>
          #|}
        let suggestion =
          #|try expr catch {
          #|  err => <branch_err>
          #|} noraise {
          #|  value => <branch_ok>
          #|}
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=match_result_try_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn match_result_try_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=match_result_try_rule_id,
    description=match_result_try_description,
    run=input => {
      let env = MatchResultTryEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

///|
let match_result_try_rule_id : String = "match_result_try"

///|
let match_result_try_description : String = "Prefer try/catch over match on try? results (covers constrained/as expressions)."

///|
priv struct MatchResultTryEnv(Array[@moonlint.Diagnostic])

///|
fn is_try_question_expr(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.TryOperator(kind=Question, ..) => true
    @syntax.Constraint(expr=inner, ..) => is_try_question_expr(inner)
    @syntax.As(expr=inner, ..) => is_try_question_expr(inner)
    _ => false
  }
}

///|
impl @syntax.IterVisitor for MatchResultTryEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases=_, match_loc=_, loc~) =>
      if is_try_question_expr(subject) {
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
        env.0.push(
          @moonlint.Diagnostic::new(
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
fn match_result_try_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=match_result_try_rule_id,
    description=match_result_try_description,
    run=input => {
      let env = MatchResultTryEnv(Array::new(capacity=8))
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        let MatchResultTryEnv(diags) = env
        diags
      }
    },
  )
}

///|
let match_try_question_rule_id : String = "match_try_question"

///|
let match_try_question_description : String = "Prefer try/catch over match on try? results."

///|
priv struct MatchTryQuestionEnv(Array[@moonlint.Diagnostic])

///|
impl @syntax.IterVisitor for MatchTryQuestionEnv with visit_Expr(env, expr) {
  if @moonlint.match_match_expr(expr) is Some((subject, loc)) &&
    @moonlint.match_try_question(subject) is Some(_) {
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
        rule_id=match_try_question_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      ),
    )
  }
  env.base().visit_Expr(expr)
}

///|
fn match_try_question_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=match_try_question_rule_id,
    description=match_try_question_description,
    run=input => {
      let env = MatchTryQuestionEnv(Array::new(capacity=8))
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        let MatchTryQuestionEnv(diags) = env
        diags
      }
    },
  )
}

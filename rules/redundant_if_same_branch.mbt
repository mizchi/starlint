///|
let redundant_if_same_branch_rule_id : String = "redundant_if_same_branch"

///|
let redundant_if_same_branch_description : String = "If both branches are identical, the condition is redundant."

///|
priv struct RedundantIfSameBranchEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
impl @syntax.IterVisitor for RedundantIfSameBranchEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.If(cond~, ifso~, ifnot=Some(ifnot), loc~) =>
      match
        (
          @moonlint.expr_source(env.source, ifso),
          @moonlint.expr_source(env.source, ifnot),
        ) {
        (Some(ifso_src), Some(ifnot_src)) if ifso_src == ifnot_src => {
          let message = "Both branches are identical."
          let detail =
            #|if cond { expr } else { expr }
          let suggestion =
            #|Replace the if-expression with the shared branch.
          let fix = if @moonlint.is_trivial_expr(cond) {
            Some(@moonlint.Fix::new(range=loc, replacement=ifso_src))
          } else {
            None
          }
          let diag = match fix {
            Some(fix) =>
              @moonlint.Diagnostic::new(
                rule_id=redundant_if_same_branch_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
                fix~,
              )
            None =>
              @moonlint.Diagnostic::new(
                rule_id=redundant_if_same_branch_rule_id,
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
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn redundant_if_same_branch_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=redundant_if_same_branch_rule_id,
    description=redundant_if_same_branch_description,
    run=input => {
      let env = RedundantIfSameBranchEnv::{
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

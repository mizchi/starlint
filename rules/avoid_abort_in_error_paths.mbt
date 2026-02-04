///|
let avoid_abort_in_error_paths_rule_id : String = "avoid_abort_in_error_paths"

///|
let avoid_abort_in_error_paths_description : String = "Avoid abort/panic in catch blocks."

///|
priv struct AvoidAbortInErrorPathsEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
priv struct AbortSearchEnv {
  mut found : Bool
}

///|
impl @syntax.IterVisitor for AbortSearchEnv with visit_Expr(env, expr) {
  if env.found {
    return
  }
  match @moonlint.match_call_name(expr) {
    Some(name) if name == "abort" || name == "panic" => env.found = true
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn contains_abort(expr : @syntax.Expr) -> Bool {
  let env = AbortSearchEnv::{ found: false }
  env.visit_Expr(expr)
  env.found
}

///|
fn push_avoid_abort_diag(
  env : AvoidAbortInErrorPathsEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Avoid abort/panic in catch; raise or return an error instead."
  let detail =
    #|foo() catch { _ => abort("unexpected") }
  let suggestion =
    #|foo() catch { error => raise error }
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=avoid_abort_in_error_paths_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for AvoidAbortInErrorPathsEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.Try(catch_~, catch_loc~, ..) => {
      let cases_array = @moonlint.list_to_array(catch_)
      let mut should_warn = false
      for case_ in cases_array {
        if contains_abort(case_.body) {
          should_warn = true
        }
      }
      if should_warn {
        push_avoid_abort_diag(env, catch_loc)
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_abort_in_error_paths_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_abort_in_error_paths_rule_id,
    description=avoid_abort_in_error_paths_description,
    tags=["error"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidAbortInErrorPathsEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

///|
let prefer_noraise_async_rule_id : String = "prefer_noraise_async"

///|
let prefer_noraise_async_description : String = "Prefer noraise for async functions without error effects."

///|
priv struct PreferNoraiseAsyncEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
priv struct ErrorEffectSearchEnv {
  mut found : Bool
}

///|
impl @syntax.IterVisitor for ErrorEffectSearchEnv with visit_Expr(env, expr) {
  if env.found {
    return
  }
  match expr {
    @syntax.Raise(..) => env.found = true
    @syntax.Try(..) => env.found = true
    @syntax.TryOperator(..) => env.found = true
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn contains_error_effect(expr : @syntax.Expr) -> Bool {
  let env = ErrorEffectSearchEnv::{ found: false }
  env.visit_Expr(expr)
  env.found
}

///|
fn should_suggest_noraise(
  error_type : @syntax.ErrorType,
  has_error : @basic.Location?,
) -> Bool {
  match has_error {
    Some(_) => false
    None =>
      match error_type {
        @syntax.ErrorType::Noraise(_) => false
        _ => true
      }
  }
}

///|
fn push_prefer_noraise_diag(
  env : PreferNoraiseAsyncEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Async function has no error effects; consider adding noraise."
  let detail =
    #|async fn f { ... }
  let suggestion =
    #|async fn f noraise { ... }
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=prefer_noraise_async_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for PreferNoraiseAsyncEnv with visit_Impl(env, impl_) {
  match impl_ {
    @syntax.Impl::TopFuncDef(fun_decl~, decl_body~, loc=_) =>
      if fun_decl.is_async is Some(_) &&
        should_suggest_noraise(fun_decl.error_type, fun_decl.has_error) {
        match decl_body {
          @syntax.DeclBody::DeclBody(local_types=_, expr~) =>
            if !contains_error_effect(expr) {
              push_prefer_noraise_diag(env, fun_decl.name.loc)
            }
          _ => ()
        }
      }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
impl @syntax.IterVisitor for PreferNoraiseAsyncEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Function(func~, loc~) =>
      if func.is_async is Some(_) &&
        should_suggest_noraise(func.error_type, func.has_error) &&
        !contains_error_effect(func.body) {
        push_prefer_noraise_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_noraise_async_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_noraise_async_rule_id,
    description=prefer_noraise_async_description,
    tags=["async"],
    enabled_by_default=false,
    run=input => {
      let env = PreferNoraiseAsyncEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

///|
let async_cancellation_must_propagate_rule_id : String = "async_cancellation_must_propagate"

///|
let async_cancellation_must_propagate_description : String = "Async catch should re-raise cancellation; avoid swallowing errors."

///|
priv struct AsyncCancellationMustPropagateEnv {
  diags : Array[@moonlint.Diagnostic]
  mut in_async : Bool
}

///|
priv struct RaiseSearchEnv {
  mut found : Bool
}

///|
impl @syntax.IterVisitor for RaiseSearchEnv with visit_Expr(env, expr) {
  if env.found {
    return
  }
  match expr {
    @syntax.Raise(..) => env.found = true
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn contains_raise(expr : @syntax.Expr) -> Bool {
  let env = RaiseSearchEnv::{ found: false }
  env.visit_Expr(expr)
  env.found
}

///|
fn push_async_cancellation_diag(
  env : AsyncCancellationMustPropagateEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Async catch swallows errors; check cancellation and re-raise when needed."
  let detail =
    #|async fn work {
    #|  foo() catch { _ => None }
    #|}
  let suggestion =
    #|foo() catch { error =>
    #|  if @async.is_being_cancelled() { raise error }
    #|  None
    #|}
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=async_cancellation_must_propagate_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for AsyncCancellationMustPropagateEnv with visit_Impl(
  env,
  impl_,
) {
  match impl_ {
    @syntax.Impl::TopFuncDef(fun_decl~, decl_body=_, loc=_) => {
      let prev = env.in_async
      env.in_async = fun_decl.is_async is Some(_) || prev
      env.base().visit_Impl(impl_)
      env.in_async = prev
      return
    }
    @syntax.Impl::TopTest(is_async~, ..) => {
      let prev = env.in_async
      env.in_async = is_async is Some(_) || prev
      env.base().visit_Impl(impl_)
      env.in_async = prev
      return
    }
    @syntax.Impl::TopExpr(is_async~, ..) => {
      let prev = env.in_async
      env.in_async = is_async is Some(_) || prev
      env.base().visit_Impl(impl_)
      env.in_async = prev
      return
    }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
impl @syntax.IterVisitor for AsyncCancellationMustPropagateEnv with visit_Func(
  env,
  func,
) {
  let prev = env.in_async
  if func.is_async is Some(_) {
    env.in_async = true
  }
  env.base().visit_Func(func)
  env.in_async = prev
}

///|
impl @syntax.IterVisitor for AsyncCancellationMustPropagateEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.Try(catch_~, catch_loc~, ..) =>
      if env.in_async {
        let cases_array = @moonlint.list_to_array(catch_)
        let mut should_warn = false
        for case_ in cases_array {
          if !contains_raise(case_.body) {
            should_warn = true
          }
        }
        if should_warn {
          push_async_cancellation_diag(env, catch_loc)
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn async_cancellation_must_propagate_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=async_cancellation_must_propagate_rule_id,
    description=async_cancellation_must_propagate_description,
    tags=["async"],
    enabled_by_default=false,
    run=input => {
      let env = AsyncCancellationMustPropagateEnv::{
        diags: Array::new(capacity=4),
        in_async: false,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

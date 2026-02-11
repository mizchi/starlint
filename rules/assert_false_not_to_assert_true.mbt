///|
let assert_false_not_to_assert_true_rule_id : String = "assert_false_not_to_assert_true"

///|
let assert_false_not_to_assert_true_description : String = "Prefer assert_true(x) over assert_false(not(x))."

///|
priv struct AssertFalseNotToAssertTrueEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
  mut in_test : Bool
}

///|
fn match_single_positional_arg(args : Array[@syntax.Argument]) -> @syntax.Expr? {
  if args.length() != 1 {
    return None
  }
  let arg = args[0]
  match arg.kind {
    @syntax.ArgumentKind::Positional => Some(arg.value)
    _ => None
  }
}

///|
fn match_not_call(expr : @syntax.Expr) -> @syntax.Expr? {
  match @internal.match_call_info(expr) {
    Some((name, args, _)) if name == "not" => match_single_positional_arg(args)
    _ => None
  }
}

///|
fn push_assert_false_not_to_assert_true_diag(
  env : AssertFalseNotToAssertTrueEnv,
  loc : @basic.Location,
  inner : @syntax.Expr,
) -> Unit {
  let message = "assert_false(not(x)) can be simplified to assert_true(x)."
  let detail =
    #|assert_false(not(expr))
  let suggestion =
    #|assert_true(expr)
  let fix = match @internal.expr_source(env.source, inner) {
    Some(inner_src) =>
      if !inner_src.contains("\n") {
        Some(
          @starlint.Fix::new(range=loc, replacement="assert_true(\{inner_src})"),
        )
      } else {
        None
      }
    None => None
  }
  let diag = match fix {
    Some(fix) =>
      @starlint.Diagnostic::new(
        rule_id=assert_false_not_to_assert_true_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      @starlint.Diagnostic::new(
        rule_id=assert_false_not_to_assert_true_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for AssertFalseNotToAssertTrueEnv with visit_Impl(
  env,
  impl_,
) {
  match impl_ {
    @syntax.Impl::TopTest(..) => {
      let prev = env.in_test
      env.in_test = true
      env.base().visit_Impl(impl_)
      env.in_test = prev
      return
    }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
impl @syntax.IterVisitor for AssertFalseNotToAssertTrueEnv with visit_Expr(
  env,
  expr,
) {
  match @internal.match_call_info(expr) {
    Some((name, args, loc)) if env.in_test && name == "assert_false" =>
      match match_single_positional_arg(args) {
        Some(arg) =>
          match match_not_call(arg) {
            Some(inner) =>
              push_assert_false_not_to_assert_true_diag(env, loc, inner)
            None => ()
          }
        None => ()
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn assert_false_not_to_assert_true_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=assert_false_not_to_assert_true_rule_id,
    description=assert_false_not_to_assert_true_description,
    tags=["test"],
    enabled_by_default=false,
    run=input => {
      let env = AssertFalseNotToAssertTrueEnv::{
        diags: Array::new(capacity=4),
        source: input.source,
        in_test: false,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

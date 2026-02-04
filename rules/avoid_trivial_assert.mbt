///|
let avoid_trivial_assert_rule_id : String = "avoid_trivial_assert"

///|
let avoid_trivial_assert_description : String = "Avoid trivial assertions in tests."

///|
priv struct AvoidTrivialAssertEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
  mut in_test : Bool
}

///|
fn is_simple_expr(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.Ident(..) => true
    @syntax.Constant(..) => true
    @syntax.Unit(..) => true
    _ => false
  }
}

///|
fn is_same_source(
  source : String,
  lhs : @syntax.Expr,
  rhs : @syntax.Expr,
) -> Bool {
  match
    (@starlint.expr_source(source, lhs), @starlint.expr_source(source, rhs)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

///|
fn push_trivial_assert_diag(
  env : AvoidTrivialAssertEnv,
  loc : @basic.Location,
  message : String,
  detail : String,
  suggestion : String,
) -> Unit {
  env.diags.push(
    @starlint.Diagnostic::new(
      rule_id=avoid_trivial_assert_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for AvoidTrivialAssertEnv with visit_Impl(env, impl_) {
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
impl @syntax.IterVisitor for AvoidTrivialAssertEnv with visit_Expr(env, expr) {
  match @starlint.match_call_info(expr) {
    Some((name, args, loc)) if env.in_test =>
      if name == "assert_true" || name == "assert_false" {
        match @starlint.first_positional_arg(args) {
          Some(arg) =>
            match @starlint.match_constant_bool(arg) {
              Some(value) => {
                let always_ok = (name == "assert_true" && value) ||
                  (name == "assert_false" && !value)
                let always_fail = !always_ok
                if always_ok {
                  push_trivial_assert_diag(
                    env, loc, "Assertion is always true; remove or assert on a value.",
                    "assert_true(true)", "assert_true(actual)",
                  )
                } else if always_fail {
                  push_trivial_assert_diag(
                    env, loc, "Assertion always fails; assert on a computed value.",
                    "assert_false(true)", "assert_false(actual)",
                  )
                }
              }
              None => ()
            }
          None => ()
        }
      } else if name == "assert_eq" {
        match @starlint.first_two_positional_args(args) {
          Some((lhs, rhs)) =>
            if is_simple_expr(lhs) &&
              is_simple_expr(rhs) &&
              is_same_source(env.source, lhs, rhs) {
              push_trivial_assert_diag(
                env, loc, "Assertion compares identical values; it is trivial.",
                "assert_eq(x, x)", "assert_eq(actual, expected)",
              )
            }
          None => ()
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_trivial_assert_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=avoid_trivial_assert_rule_id,
    description=avoid_trivial_assert_description,
    tags=["test"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidTrivialAssertEnv::{
        diags: Array::new(capacity=4),
        source: input.source,
        in_test: false,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

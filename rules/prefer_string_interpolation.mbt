///|
let prefer_string_interpolation_rule_id : String = "prefer_string_interpolation"

///|
let prefer_string_interpolation_description : String = "Prefer string interpolation over string concatenation with +."

///|
priv struct PreferStringInterpolationEnv {
  diags : Array[@starlint.Diagnostic]
  seen : Map[String, Bool]
}

///|
fn is_string_concat(expr : @syntax.Expr) -> Bool {
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, _)) =>
      @internal.is_string_literal_expr(lhs) ||
      @internal.is_string_literal_expr(rhs) ||
      is_string_concat(lhs) ||
      is_string_concat(rhs)
    None => false
  }
}

///|
fn count_concat_operands(expr : @syntax.Expr) -> Int {
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, _)) =>
      count_concat_operands(lhs) + count_concat_operands(rhs)
    None => 1
  }
}

///|
impl @syntax.IterVisitor for PreferStringInterpolationEnv with visit_Expr(
  env,
  expr,
) {
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, loc)) => {
      let key = @internal.location_key(loc)
      if !env.seen.contains(key) {
        // Only flag top-level concat (not sub-expressions of a larger concat)
        let has_string_literal = @internal.is_string_literal_expr(lhs) ||
          @internal.is_string_literal_expr(rhs) ||
          is_string_concat(lhs) ||
          is_string_concat(rhs)
        if has_string_literal && count_concat_operands(expr) >= 2 {
          // Mark all sub-locations to avoid duplicate reports
          env.seen.set(key, true)
          mark_sub_locs(env, lhs)
          mark_sub_locs(env, rhs)
          let message = "String concatenation with + can use interpolation."
          let detail =
            #|"Hello, " + name + "!"
          let suggestion =
            #|"Hello, \{name}!"
          env.diags.push(
            @starlint.Diagnostic::new(
              rule_id=prefer_string_interpolation_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            ),
          )
        }
      }
    }
    None => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn mark_sub_locs(
  env : PreferStringInterpolationEnv,
  expr : @syntax.Expr,
) -> Unit {
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, loc)) => {
      env.seen.set(@internal.location_key(loc), true)
      mark_sub_locs(env, lhs)
      mark_sub_locs(env, rhs)
    }
    None => ()
  }
}

///|
fn prefer_string_interpolation_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_string_interpolation_rule_id,
    description=prefer_string_interpolation_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferStringInterpolationEnv::{
        diags: Array::new(capacity=8),
        seen: Map::new(),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

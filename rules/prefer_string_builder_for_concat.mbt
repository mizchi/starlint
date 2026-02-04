///|
let prefer_string_builder_for_concat_rule_id : String = "prefer_string_builder_for_concat"

///|
let prefer_string_builder_for_concat_description : String = "Prefer StringBuilder/Buffer for repeated string concatenation."

///|
priv struct PreferStringBuilderForConcatEnv {
  diags : Array[@starlint.Diagnostic]
  mut loop_depth : Int
}

///|
fn is_self_concat_with_literal(name : String, expr : @syntax.Expr) -> Bool {
  match @starlint.match_infix(expr, "+") {
    Some((lhs, rhs, _)) => {
      let lhs_is_name = @starlint.match_ident_name(lhs) == Some(name)
      let rhs_is_name = @starlint.match_ident_name(rhs) == Some(name)
      (lhs_is_name && @starlint.is_string_literal_expr(rhs)) ||
      (rhs_is_name && @starlint.is_string_literal_expr(lhs))
    }
    None => false
  }
}

///|
fn is_augmented_plus(op : @syntax.Var?) -> Bool {
  match op {
    Some(var_) => @starlint.longident_right_name(var_.name) == "+"
    None => false
  }
}

///|
impl @syntax.IterVisitor for PreferStringBuilderForConcatEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.For(..)
    | @syntax.ForEach(..)
    | @syntax.While(..)
    | @syntax.Loop(..) => {
      let prev = env.loop_depth
      env.loop_depth = prev + 1
      env.base().visit_Expr(expr)
      env.loop_depth = prev
    }
    @syntax.Assign(var_~, expr=rhs, augmented_by~, loc~) =>
      if env.loop_depth > 0 {
        let name = @starlint.longident_right_name(var_.name)
        if is_augmented_plus(augmented_by) &&
          @starlint.is_string_literal_expr(rhs) {
          let message = "Repeated string concatenation can be costly; use StringBuilder/Buffer."
          let detail =
            #|s += "..."
          let suggestion =
            #|let sb = StringBuilder::new()
            #|sb.write_string("...")
          env.diags.push(
            @starlint.Diagnostic::new(
              rule_id=prefer_string_builder_for_concat_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            ),
          )
        } else if is_self_concat_with_literal(name, rhs) {
          let message = "Repeated string concatenation can be costly; use StringBuilder/Buffer."
          let detail =
            #|s = s + "..."
          let suggestion =
            #|let sb = StringBuilder::new()
            #|sb.write_string("...")
          env.diags.push(
            @starlint.Diagnostic::new(
              rule_id=prefer_string_builder_for_concat_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            ),
          )
        }
      }
    _ => env.base().visit_Expr(expr)
  }
}

///|
fn prefer_string_builder_for_concat_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_string_builder_for_concat_rule_id,
    description=prefer_string_builder_for_concat_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferStringBuilderForConcatEnv::{
        diags: Array::new(capacity=4),
        loop_depth: 0,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

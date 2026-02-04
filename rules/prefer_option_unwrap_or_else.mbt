///|
let prefer_option_unwrap_or_else_rule_id : String = "prefer_option_unwrap_or_else"

///|
let prefer_option_unwrap_or_else_description : String = "Prefer unwrap_or_else when default is computed."

///|
priv struct PreferOptionUnwrapOrElseEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn default_arg_from_unwrap_or(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @basic.Location)? {
  match @starlint.unwrap_paren(expr) {
    @syntax.DotApply(method_name~, args~, loc~, ..) =>
      if @starlint.label_name(method_name) != "unwrap_or" {
        None
      } else {
        let args_array = @starlint.list_to_array(args)
        if args_array.length() != 1 {
          None
        } else {
          let default_arg = args_array[0]
          match default_arg.kind {
            @syntax.ArgumentKind::Positional => Some((default_arg.value, loc))
            _ => None
          }
        }
      }
    _ => None
  }
}

///|
impl @syntax.IterVisitor for PreferOptionUnwrapOrElseEnv with visit_Expr(
  env,
  expr,
) {
  match default_arg_from_unwrap_or(expr) {
    Some((default_expr, loc)) if @starlint.is_call_expr(default_expr) => {
      let message = "unwrap_or default is evaluated eagerly; use unwrap_or_else for lazy evaluation."
      let detail =
        #|opt.unwrap_or(expensive())
      let suggestion =
        #|opt.unwrap_or_else(() => expensive())
      env.diags.push(
        @starlint.Diagnostic::new(
          rule_id=prefer_option_unwrap_or_else_rule_id,
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
fn prefer_option_unwrap_or_else_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_option_unwrap_or_else_rule_id,
    description=prefer_option_unwrap_or_else_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferOptionUnwrapOrElseEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

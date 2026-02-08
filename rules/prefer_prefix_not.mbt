///|
let prefer_prefix_not_rule_id : String = "prefer_prefix_not"

///|
let prefer_prefix_not_description : String = "Prefer !expr over not(expr)."

///|
priv struct NotCallToPrefixNotEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn match_unary_not_call(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @basic.Location)? {
  match @internal.unwrap_paren(expr) {
    @syntax.Apply(func=@syntax.Ident(id=ident, ..), args~, loc~, ..) => {
      if @internal.longident_pkg_name(ident.name) is Some(_) ||
        @internal.longident_right_name(ident.name) != "not" {
        return None
      }
      let args_array = @internal.list_to_array(args)
      if args_array.length() != 1 {
        return None
      }
      let arg = args_array[0]
      match arg.kind {
        @syntax.ArgumentKind::Positional => Some((arg.value, loc))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn push_prefer_prefix_not_diag(
  env : NotCallToPrefixNotEnv,
  loc : @basic.Location,
  arg : @syntax.Expr,
) -> Unit {
  let message = "not(expr) can be replaced with !expr."
  let detail =
    #|not(expr)
  let suggestion =
    #|!(expr)
  let replacement_from_arg = fn(arg_src : String) {
    match @internal.unwrap_paren(arg) {
      @syntax.Ident(..) => "!\{arg_src}"
      _ => "!(\{arg_src})"
    }
  }
  let fix = match @internal.expr_source(env.source, arg) {
    Some(arg_src) =>
      if !arg_src.contains("\n") {
        Some(
          @starlint.Fix::new(
            range=loc,
            replacement=replacement_from_arg(arg_src),
          ),
        )
      } else {
        None
      }
    None => None
  }
  let diag = match fix {
    Some(fix) =>
      @starlint.Diagnostic::new(
        rule_id=prefer_prefix_not_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      @starlint.Diagnostic::new(
        rule_id=prefer_prefix_not_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for NotCallToPrefixNotEnv with visit_Expr(env, expr) {
  match match_unary_not_call(expr) {
    Some((arg, loc)) => push_prefer_prefix_not_diag(env, loc, arg)
    None => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_prefix_not_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_prefix_not_rule_id,
    description=prefer_prefix_not_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = NotCallToPrefixNotEnv::{
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

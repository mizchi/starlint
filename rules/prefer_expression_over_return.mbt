///|
let prefer_expression_over_return_rule_id : String = "prefer_expression_over_return"

///|
let prefer_expression_over_return_description : String = "Prefer tail expressions over redundant return."

///|
priv struct PreferExpressionOverReturnEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn tail_return_expr(expr : @syntax.Expr) -> (@basic.Location, @syntax.Expr)? {
  match @starlint.unwrap_paren(expr) {
    @syntax.Return(return_value=Some(value), loc~) => Some((loc, value))
    @syntax.Sequence(exprs=_, last_expr~, loc=_) => tail_return_expr(last_expr)
    @syntax.Let(pattern=_, expr=_, body~, loc=_) => tail_return_expr(body)
    @syntax.LetMut(binder=_, ty=_, expr=_, body~, loc=_) =>
      tail_return_expr(body)
    @syntax.LetFn(name=_, func=_, body~, loc=_) => tail_return_expr(body)
    @syntax.LetRec(bindings=_, body~, loc=_) => tail_return_expr(body)
    @syntax.LetAnd(bindings=_, body~, loc=_) => tail_return_expr(body)
    @syntax.Defer(expr=_, body~, loc=_) => tail_return_expr(body)
    _ => None
  }
}

///|
fn push_prefer_expression_over_return_diag(
  env : PreferExpressionOverReturnEnv,
  loc : @basic.Location,
  value : @syntax.Expr,
) -> Unit {
  match @starlint.expr_source(env.source, value) {
    Some(value_src) => {
      let message = "Return at the tail position is redundant."
      let detail =
        #|fn f() {
        #|  return expr
        #|}
      let suggestion = value_src
      let fix = if loc.start.lnum == loc.end.lnum && !value_src.contains("\n") {
        Some(@starlint.Fix::new(range=loc, replacement=value_src))
      } else {
        None
      }
      let diag = match fix {
        Some(fix) =>
          @starlint.Diagnostic::new(
            rule_id=prefer_expression_over_return_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
            fix~,
          )
        None =>
          @starlint.Diagnostic::new(
            rule_id=prefer_expression_over_return_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          )
      }
      env.diags.push(diag)
    }
    None => ()
  }
}

///|
impl @syntax.IterVisitor for PreferExpressionOverReturnEnv with visit_Impl(
  env,
  impl_,
) {
  match impl_ {
    @syntax.Impl::TopFuncDef(fun_decl=_, decl_body~, loc=_) =>
      match decl_body {
        @syntax.DeclBody::DeclBody(local_types=_, expr~) =>
          match tail_return_expr(expr) {
            Some((loc, value)) =>
              push_prefer_expression_over_return_diag(env, loc, value)
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
impl @syntax.IterVisitor for PreferExpressionOverReturnEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.Function(func~, loc=_) =>
      match tail_return_expr(func.body) {
        Some((loc, value)) =>
          push_prefer_expression_over_return_diag(env, loc, value)
        None => ()
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_expression_over_return_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_expression_over_return_rule_id,
    description=prefer_expression_over_return_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferExpressionOverReturnEnv::{
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

///|
pub struct LintPluginContext {
  rule_id : String
  input : LintInput
  diagnostics : Array[Diagnostic]
}

///|
pub fn LintPluginContext::source(self : LintPluginContext) -> String {
  self.input.source
}

///|
pub fn LintPluginContext::filename(self : LintPluginContext) -> String {
  self.input.filename
}

///|
pub fn LintPluginContext::impls(self : LintPluginContext) -> @syntax.Impls {
  self.input.impls
}

///|
pub fn LintPluginContext::report(
  self : LintPluginContext,
  loc~ : @basic.Location,
  message~ : String,
  detail? : String = "",
  suggestion? : String = "",
  fix? : Fix?,
) -> Unit {
  let normalized_fix = match fix {
    Some(fix) => fix
    None => None
  }
  let diag = match normalized_fix {
    Some(fix) =>
      Diagnostic::new(
        rule_id=self.rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      Diagnostic::new(
        rule_id=self.rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  self.diagnostics.push(diag)
}

///|
pub fn LintPluginContext::unwrap_paren(
  self : LintPluginContext,
  expr : @syntax.Expr,
) -> @syntax.Expr {
  ignore(self)
  @internal.unwrap_paren(expr)
}

///|
pub fn LintPluginContext::match_call_info(
  self : LintPluginContext,
  expr : @syntax.Expr,
) -> (String, Array[@syntax.Argument], @basic.Location)? {
  ignore(self)
  @internal.match_call_info(expr)
}

///|
pub fn LintPluginContext::first_positional_arg(
  self : LintPluginContext,
  args : Array[@syntax.Argument],
) -> @syntax.Expr? {
  ignore(self)
  @internal.first_positional_arg(args)
}

///|
pub fn LintPluginContext::first_two_positional_args(
  self : LintPluginContext,
  args : Array[@syntax.Argument],
) -> (@syntax.Expr, @syntax.Expr)? {
  ignore(self)
  @internal.first_two_positional_args(args)
}

///|
pub fn LintPluginContext::match_constant_bool(
  self : LintPluginContext,
  expr : @syntax.Expr,
) -> Bool? {
  ignore(self)
  @internal.match_constant_bool(expr)
}

///|
pub fn LintPluginContext::match_ident_name(
  self : LintPluginContext,
  expr : @syntax.Expr,
) -> String? {
  ignore(self)
  @internal.match_ident_name(expr)
}

///|
pub fn LintPluginContext::expr_source(
  self : LintPluginContext,
  expr : @syntax.Expr,
) -> String? {
  @internal.expr_source(self.input.source, expr)
}

///|
pub fn LintPluginContext::pattern_source(
  self : LintPluginContext,
  pat : @syntax.Pattern,
) -> String? {
  @internal.pattern_source(self.input.source, pat)
}

///|
pub fn[T] LintPluginContext::list_to_array(
  self : LintPluginContext,
  xs : @list.List[T],
) -> Array[T] {
  ignore(self)
  @internal.list_to_array(xs)
}

///|
priv struct ExprVisitEnv {
  callback : (@syntax.Expr) -> Unit
}

///|
impl @syntax.IterVisitor for ExprVisitEnv with visit_Expr(env, expr) {
  (env.callback)(expr)
  env.base().visit_Expr(expr)
}

///|
pub fn LintPluginContext::visit_exprs(
  self : LintPluginContext,
  callback : (@syntax.Expr) -> Unit,
) -> Unit {
  let env = ExprVisitEnv::{ callback, }
  for impl_ in self.input.impls {
    env.visit_Impl(impl_)
  }
}

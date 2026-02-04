///|
let avoid_double_to_string_js_rule_id : String = "avoid_double_to_string_js"

///|
let avoid_double_to_string_js_description : String = "Avoid Double::to_string when JS bundle size is critical."

///|
priv struct AvoidDoubleToStringJsEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn is_double_literal(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Constant(c=@syntax.Constant::Double(_), ..) => true
    _ => false
  }
}

///|
fn push_double_to_string_diag(
  env : AvoidDoubleToStringJsEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Double::to_string can increase JS bundle size."
  let detail =
    #|JS target tends to include heavier floating formatting helpers.
  let suggestion =
    #|Consider a small custom formatter or precomputed strings when possible.
  let diag = @moonlint.Diagnostic::new(
    rule_id=avoid_double_to_string_js_rule_id,
    loc~,
    message~,
    detail~,
    suggestion~,
  )
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for AvoidDoubleToStringJsEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Method(type_name~, method_name~, loc~) =>
      if @moonlint.type_name_right_name(type_name) == "Double" &&
        @moonlint.label_name(method_name) == "to_string" {
        push_double_to_string_diag(env, loc)
      }
    @syntax.DotApply(self~, method_name~, loc~, ..) =>
      if @moonlint.label_name(method_name) == "to_string" &&
        is_double_literal(self) {
        push_double_to_string_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_double_to_string_js_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_double_to_string_js_rule_id,
    description=avoid_double_to_string_js_description,
    tags=["size"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidDoubleToStringJsEnv::{ diags: Array::new(capacity=8) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

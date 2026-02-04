///|
let prefer_string_view_usage_rule_id : String = "prefer_string_view_usage"

///|
let prefer_string_view_usage_description : String = "Prefer using StringView without immediate to_string()."

///|
priv struct PreferStringViewUsageEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn is_string_view_producer(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.ArrayGetSlice(..) => true
    @syntax.DotApply(method_name~, ..) =>
      @moonlint.label_name(method_name) == "view"
    @syntax.Apply(
      func=@syntax.Method(type_name~, method_name~, ..),
      attr=NoAttr,
      ..
    ) =>
      @moonlint.type_name_right_name(type_name) == "String" &&
      @moonlint.label_name(method_name) == "view"
    _ => false
  }
}

///|
fn push_string_view_usage_diag(
  env : PreferStringViewUsageEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Avoid to_string right after creating a StringView."
  let detail =
    #|let view = text[:][1:3]
    #|let s = view.to_string()
  let suggestion =
    #|Use StringView APIs or pass the view to functions accepting StringView.
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=prefer_string_view_usage_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for PreferStringViewUsageEnv with visit_Expr(env, expr) {
  match @moonlint.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, attr=NoAttr, loc~, ..) =>
      if @moonlint.label_name(method_name) == "to_string" &&
        is_string_view_producer(self) {
        push_string_view_usage_diag(env, loc)
      }
    @syntax.Apply(
      func=@syntax.Method(type_name~, method_name~, ..),
      args~,
      attr=NoAttr,
      loc~
    ) =>
      if @moonlint.type_name_right_name(type_name) == "StringView" &&
        @moonlint.label_name(method_name) == "to_string" {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() == 1 &&
          args_array[0].kind is @syntax.ArgumentKind::Positional &&
          is_string_view_producer(args_array[0].value) {
          push_string_view_usage_diag(env, loc)
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_string_view_usage_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_string_view_usage_rule_id,
    description=prefer_string_view_usage_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferStringViewUsageEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

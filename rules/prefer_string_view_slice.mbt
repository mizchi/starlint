///|
let prefer_string_view_slice_rule_id : String = "prefer_string_view_slice"

///|
let prefer_string_view_slice_description : String = "Prefer StringView slicing over substring copies."

///|
priv struct PreferStringViewSliceEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_substring_name(name : String) -> Bool {
  name == "substring" || name == "unsafe_substring"
}

///|
impl @syntax.IterVisitor for PreferStringViewSliceEnv with visit_Expr(env, expr) {
  match @starlint.unwrap_paren(expr) {
    @syntax.DotApply(method_name~, loc~, ..) =>
      if is_substring_name(@starlint.label_name(method_name)) {
        let message = "Substring allocates; prefer StringView slicing."
        let detail =
          #|text.substring(start=1, end=3)
        let suggestion =
          #|let view = text[:][1:3]
          #|// keep view as StringView when possible
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=prefer_string_view_slice_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    @syntax.Apply(
      func=@syntax.Method(type_name~, method_name~, ..),
      attr=NoAttr,
      loc~,
      ..
    ) =>
      if @starlint.type_name_right_name(type_name) == "String" &&
        is_substring_name(@starlint.label_name(method_name)) {
        let message = "Substring allocates; prefer StringView slicing."
        let detail =
          #|String::substring(text, start=1, end=3)
        let suggestion =
          #|let view = text[:][1:3]
          #|// keep view as StringView when possible
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=prefer_string_view_slice_rule_id,
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
fn prefer_string_view_slice_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_string_view_slice_rule_id,
    description=prefer_string_view_slice_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferStringViewSliceEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

///|
let prefer_unicode_safe_iteration_rule_id : String = "prefer_unicode_safe_iteration"

///|
let prefer_unicode_safe_iteration_description : String = "Prefer unicode-safe iteration over direct string indexing."

///|
priv struct PreferUnicodeSafeIterationEnv {
  diags : Array[@moonlint.Diagnostic]
  mut loop_depth : Int
}

///|
fn is_char_access_method(name : String) -> Bool {
  name == "get_char" ||
  name == "char_at" ||
  name == "charcode_at" ||
  name == "unsafe_get"
}

///|
impl @syntax.IterVisitor for PreferUnicodeSafeIterationEnv with visit_Expr(
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
    @syntax.ArrayGet(array~, index=_, loc~) =>
      if env.loop_depth > 0 && @moonlint.is_string_literal_expr(array) {
        let message = "Direct string indexing is UTF-16 based; prefer unicode-safe iteration."
        let detail =
          #|"text"[i]
        let suggestion =
          #|for c in text { ... } // or text.iter()
        env.diags.push(
          @moonlint.Diagnostic::new(
            rule_id=prefer_unicode_safe_iteration_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    @syntax.DotApply(method_name~, loc~, ..) =>
      if env.loop_depth > 0 &&
        is_char_access_method(@moonlint.label_name(method_name)) {
        let message = "Direct string indexing is UTF-16 based; prefer unicode-safe iteration."
        let detail =
          #|text.get_char(i)
        let suggestion =
          #|for c in text { ... } // or text.iter()
        env.diags.push(
          @moonlint.Diagnostic::new(
            rule_id=prefer_unicode_safe_iteration_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    _ => env.base().visit_Expr(expr)
  }
}

///|
fn prefer_unicode_safe_iteration_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_unicode_safe_iteration_rule_id,
    description=prefer_unicode_safe_iteration_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferUnicodeSafeIterationEnv::{
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

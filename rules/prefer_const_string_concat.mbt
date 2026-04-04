///|
let prefer_const_string_concat_rule_id : String = "prefer_const_string_concat"

///|
let prefer_const_string_concat_description : String = "Prefer const over let for top-level string literal concatenation."

///|
fn is_all_string_literal_concat(expr : @syntax.Expr) -> Bool {
  if @internal.is_string_literal_expr(expr) {
    return true
  }
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, _)) =>
      is_all_string_literal_concat(lhs) && is_all_string_literal_concat(rhs)
    None => false
  }
}

///|
fn prefer_const_string_concat_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_const_string_concat_rule_id,
    description=prefer_const_string_concat_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let diags : Array[@starlint.Diagnostic] = Array::new(capacity=4)
      for impl_ in input.impls {
        match impl_ {
          @syntax.Impl::TopLetDef(binder=_, expr~, is_constant=false, loc~, ..) =>
            if is_all_string_literal_concat(expr) {
              let message = "Top-level let with pure string literal concatenation can use const."
              let detail =
                #|let greeting : String = "Hello" + " " + "World"
              let suggestion =
                #|const Greeting : String = "Hello" + " " + "World"
              diags.push(
                @starlint.Diagnostic::new(
                  rule_id=prefer_const_string_concat_rule_id,
                  loc~,
                  message~,
                  detail~,
                  suggestion~,
                ),
              )
            }
          _ => ()
        }
      } nobreak {
        diags
      }
    },
  )
}

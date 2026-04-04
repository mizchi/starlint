///|
let prefer_is_empty_rule_id : String = "prefer_is_empty"

///|
let prefer_is_empty_description : String = "Prefer is_empty() over length() == 0."

///|
priv struct PreferIsEmptyEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn is_length_call(expr : @syntax.Expr) -> @syntax.Expr? {
  match @internal.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, args~, ..) =>
      if @internal.label_name(method_name) == "length" &&
        @internal.list_to_array(args).is_empty() {
        Some(self)
      } else {
        None
      }
    _ => None
  }
}

///|
fn is_zero_literal(expr : @syntax.Expr) -> Bool {
  @internal.match_constant_int(expr) == Some("0")
}

///|
impl @syntax.IterVisitor for PreferIsEmptyEnv with visit_Expr(env, expr) {
  match @internal.match_infix(expr, "==") {
    Some((lhs, rhs, loc)) => {
      let receiver = if is_zero_literal(rhs) {
        is_length_call(lhs)
      } else if is_zero_literal(lhs) {
        is_length_call(rhs)
      } else {
        None
      }
      match receiver {
        Some(receiver) => {
          let message = "Use is_empty() instead of length() == 0."
          let detail =
            #|x.length() == 0
          let suggestion =
            #|x.is_empty()
          let fix = match @internal.expr_source(env.source, receiver) {
            Some(receiver_src) => {
              let replacement = "\{receiver_src}.is_empty()"
              Some(@starlint.Fix::new(range=loc, replacement~))
            }
            None => None
          }
          let diag = match fix {
            Some(fix) =>
              @starlint.Diagnostic::new(
                rule_id=prefer_is_empty_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
                fix~,
              )
            None =>
              @starlint.Diagnostic::new(
                rule_id=prefer_is_empty_rule_id,
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
    None => ()
  }
  // Also detect length() != 0 → !is_empty()
  match @internal.match_infix(expr, "!=") {
    Some((lhs, rhs, loc)) => {
      let receiver = if is_zero_literal(rhs) {
        is_length_call(lhs)
      } else if is_zero_literal(lhs) {
        is_length_call(rhs)
      } else {
        None
      }
      match receiver {
        Some(receiver) => {
          let message = "Use !is_empty() instead of length() != 0."
          let detail =
            #|x.length() != 0
          let suggestion =
            #|!x.is_empty()
          let fix = match @internal.expr_source(env.source, receiver) {
            Some(receiver_src) => {
              let replacement = "!\{receiver_src}.is_empty()"
              Some(@starlint.Fix::new(range=loc, replacement~))
            }
            None => None
          }
          let diag = match fix {
            Some(fix) =>
              @starlint.Diagnostic::new(
                rule_id=prefer_is_empty_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
                fix~,
              )
            None =>
              @starlint.Diagnostic::new(
                rule_id=prefer_is_empty_rule_id,
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
    None => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_is_empty_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_is_empty_rule_id,
    description=prefer_is_empty_description,
    run=input => {
      let env = PreferIsEmptyEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

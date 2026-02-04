///|
let prefer_string_pattern_rule_id : String = "prefer_string_pattern"

///|
let prefer_string_pattern_description : String = "Prefer string pattern matching for empty/prefix checks."

///|
priv struct PreferStringPatternEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_empty_string_expr(expr : @syntax.Expr) -> Bool {
  @starlint.match_constant_string(expr) == Some("")
}

///|
fn match_empty_string_compare(expr : @syntax.Expr) -> @syntax.Expr? {
  match @starlint.match_infix(expr, "==") {
    Some((lhs, rhs, _)) =>
      if is_empty_string_expr(lhs) {
        Some(rhs)
      } else if is_empty_string_expr(rhs) {
        Some(lhs)
      } else {
        None
      }
    None =>
      match @starlint.match_infix(expr, "!=") {
        Some((lhs, rhs, _)) =>
          if is_empty_string_expr(lhs) {
            Some(rhs)
          } else if is_empty_string_expr(rhs) {
            Some(lhs)
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn match_starts_with(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.DotApply(self=_, method_name~, args~, return_self=_, attr=_, loc=_) =>
      if @starlint.label_name(method_name) != "starts_with" {
        false
      } else {
        let args_array = @starlint.list_to_array(args)
        if args_array.length() != 1 {
          false
        } else {
          let arg = args_array[0]
          match arg.kind {
            @syntax.ArgumentKind::Positional =>
              match @starlint.match_constant_string(arg.value) {
                Some(prefix) if prefix != "" => true
                _ => false
              }
            _ => false
          }
        }
      }
    _ => false
  }
}

///|
impl @syntax.IterVisitor for PreferStringPatternEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.If(cond~, ifso=_, ifnot=Some(_), loc~) =>
      if match_empty_string_compare(cond) is Some(_) {
        let message = "Empty string check can be replaced with string pattern matching."
        let detail =
          #|if s == "" { ... } else { ... }
        let suggestion =
          #|match s {
          #|  "" => { ... }
          #|  _ => { ... }
          #|}
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=prefer_string_pattern_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      } else if match_starts_with(cond) {
        let message = "Prefix check can be replaced with string pattern matching."
        let detail =
          #|if s.starts_with("prefix") { ... } else { ... }
        let suggestion =
          #|match s {
          #|  [.."prefix", ..rest] => { ... }
          #|  _ => { ... }
          #|}
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=prefer_string_pattern_rule_id,
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
fn prefer_string_pattern_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_string_pattern_rule_id,
    description=prefer_string_pattern_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferStringPatternEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

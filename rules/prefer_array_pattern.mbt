///|
let prefer_array_pattern_rule_id : String = "prefer_array_pattern"

///|
let prefer_array_pattern_description : String = "Prefer array pattern matching for empty/first-element checks."

///|
priv struct PreferArrayPatternEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn match_get_zero(expr : @syntax.Expr) -> @syntax.Expr? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, args~, return_self=_, attr=_, loc=_) =>
      if @moonlint.label_name(method_name) != "get" {
        None
      } else {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() != 1 {
          None
        } else {
          let arg = args_array[0]
          match arg.kind {
            @syntax.ArgumentKind::Positional =>
              if @moonlint.match_constant_int(arg.value) == Some("0") {
                Some(self)
              } else {
                None
              }
            _ => None
          }
        }
      }
    _ => None
  }
}

///|
fn match_length_call(expr : @syntax.Expr) -> @syntax.Expr? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, args~, return_self=_, attr=_, loc=_) =>
      if @moonlint.label_name(method_name) != "length" {
        None
      } else if @moonlint.list_to_array(args).length() == 0 {
        Some(self)
      } else {
        None
      }
    _ => None
  }
}

///|
fn is_zero_expr(expr : @syntax.Expr) -> Bool {
  @moonlint.match_constant_int(expr) == Some("0")
}

///|
fn match_length_compare_zero(expr : @syntax.Expr) -> @syntax.Expr? {
  match @moonlint.match_infix(expr, "==") {
    Some((lhs, rhs, _)) =>
      if is_zero_expr(lhs) {
        match_length_call(rhs)
      } else if is_zero_expr(rhs) {
        match_length_call(lhs)
      } else {
        None
      }
    None =>
      match @moonlint.match_infix(expr, "!=") {
        Some((lhs, rhs, _)) =>
          if is_zero_expr(lhs) {
            match_length_call(rhs)
          } else if is_zero_expr(rhs) {
            match_length_call(lhs)
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn has_some_none_cases(cases_array : Array[@syntax.Case]) -> Bool {
  let mut has_some = false
  let mut has_none = false
  for case_ in cases_array {
    if case_.guard_ is None {
      if @moonlint.is_some_pattern(case_.pattern) {
        has_some = true
      } else if @moonlint.is_none_pattern(case_.pattern) {
        has_none = true
      }
    }
  }
  has_some && has_none
}

///|
impl @syntax.IterVisitor for PreferArrayPatternEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
      match match_get_zero(subject) {
        Some(_) => {
          let cases_array = @moonlint.list_to_array(cases)
          if cases_array.length() == 2 && has_some_none_cases(cases_array) {
            let message = "Match on get(0) can be replaced with array pattern matching."
            let detail =
              #|match xs.get(0) {
              #|  Some(v) => { ... }
              #|  None => ()
              #|}
            let suggestion =
              #|match xs {
              #|  [head, ..] => { ... }
              #|  [] => ()
              #|}
            env.diags.push(
              @moonlint.Diagnostic::new(
                rule_id=prefer_array_pattern_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
              ),
            )
          }
        }
        None => ()
      }
    @syntax.If(cond~, ifso=_, ifnot=Some(_), loc~) =>
      if match_length_compare_zero(cond) is Some(_) {
        let message = "Length check can be replaced with array pattern matching."
        let detail =
          #|if xs.length() == 0 { ... } else { ... }
        let suggestion =
          #|match xs {
          #|  [] => { ... }
          #|  [head, ..] => { ... }
          #|}
        env.diags.push(
          @moonlint.Diagnostic::new(
            rule_id=prefer_array_pattern_rule_id,
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
fn prefer_array_pattern_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_array_pattern_rule_id,
    description=prefer_array_pattern_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferArrayPatternEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

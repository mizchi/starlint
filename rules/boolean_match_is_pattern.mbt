///|
let boolean_match_is_pattern_rule_id : String = "boolean_match_is_pattern"

///|
let boolean_match_is_pattern_description : String = "Prefer is-pattern checks over boolean match."

///|
priv struct BooleanMatchIsPatternEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn match_boolean_pattern(
  cases : @list.List[@syntax.Case],
) -> (@syntax.Pattern, Bool)? {
  let cases_array = @internal.list_to_array(cases)
  if cases_array.length() != 2 {
    return None
  }
  let mut non_wild_pattern : @syntax.Pattern? = None
  let mut non_wild_value : Bool? = None
  let mut wild_value : Bool? = None
  for case_ in cases_array {
    if case_.guard_ is Some(_) {
      return None
    }
    let value = match @internal.match_constant_bool(case_.body) {
      Some(v) => v
      None => return None
    }
    if @internal.is_discard_pattern(case_.pattern) {
      match wild_value {
        Some(_) => return None
        None => wild_value = Some(value)
      }
    } else {
      match non_wild_pattern {
        Some(_) => return None
        None => {
          non_wild_pattern = Some(case_.pattern)
          non_wild_value = Some(value)
        }
      }
    }
  }
  match (non_wild_pattern, non_wild_value, wild_value) {
    (Some(pattern), Some(left), Some(right)) =>
      if left != right {
        Some((pattern, left))
      } else {
        None
      }
    _ => None
  }
}

///|
fn push_boolean_match_is_pattern_diag(
  env : BooleanMatchIsPatternEnv,
  loc : @basic.Location,
  subject : @syntax.Expr,
  pattern : @syntax.Pattern,
  pattern_when_true : Bool,
) -> Unit {
  let message = "Boolean match can be replaced with is-pattern."
  let detail =
    #|match expr {
    #|  T(_) => true
    #|  _ => false
    #|}
  let suggestion = if pattern_when_true {
    "expr is T(_)"
  } else {
    "!(expr is T(_))"
  }
  let fix = match
    (
      @internal.expr_source(env.source, subject),
      @internal.pattern_source(env.source, pattern),
    ) {
    (Some(subject_src), Some(pattern_src)) =>
      if !subject_src.contains("\n") && !pattern_src.contains("\n") {
        let replacement = if pattern_when_true {
          "(\{subject_src}) is \{pattern_src}"
        } else {
          "!((\{subject_src}) is \{pattern_src})"
        }
        Some(@starlint.Fix::new(range=loc, replacement~))
      } else {
        None
      }
    _ => None
  }
  let diag = match fix {
    Some(fix) =>
      @starlint.Diagnostic::new(
        rule_id=boolean_match_is_pattern_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      @starlint.Diagnostic::new(
        rule_id=boolean_match_is_pattern_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for BooleanMatchIsPatternEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
      match match_boolean_pattern(cases) {
        Some((pattern, pattern_when_true)) =>
          push_boolean_match_is_pattern_diag(
            env, loc, subject, pattern, pattern_when_true,
          )
        None => ()
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn boolean_match_is_pattern_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=boolean_match_is_pattern_rule_id,
    description=boolean_match_is_pattern_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = BooleanMatchIsPatternEnv::{
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

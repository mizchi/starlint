///|
let match_guard_to_if_rule_id : String = "match_guard_to_if"

///|
let match_guard_to_if_description : String = "Prefer if/else chain when all match cases are guarded wildcards."

///|
priv struct MatchGuardToIfEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_guard_case(case_ : @syntax.Case) -> Bool {
  case_.guard_ is Some(_) && @starlint.is_discard_pattern(case_.pattern)
}

///|
fn is_else_case(case_ : @syntax.Case) -> Bool {
  case_.guard_ is None && @starlint.is_discard_pattern(case_.pattern)
}

///|
fn is_guard_chain_cases(cases : @list.List[@syntax.Case]) -> Bool {
  let cases_array = @starlint.list_to_array(cases)
  if cases_array.length() < 2 {
    return false
  }
  let mut has_guard = false
  for i in 0..<cases_array.length() {
    let case_ = cases_array[i]
    if i == cases_array.length() - 1 {
      if is_guard_case(case_) {
        has_guard = true
      } else if !is_else_case(case_) {
        return false
      }
    } else if is_guard_case(case_) {
      has_guard = true
    } else {
      return false
    }
  } else {
    has_guard
  }
}

///|
fn push_match_guard_to_if_diag(
  env : MatchGuardToIfEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "All cases are guarded wildcards; prefer if/else chain instead of match."
  let detail =
    #|match x {
    #|  _ if cond1 => { ... }
    #|  _ if cond2 => { ... }
    #|  _ => { ... }
    #|}
  let suggestion =
    #|if cond1 { ... } else if cond2 { ... } else { ... }
  let diag = @starlint.Diagnostic::new(
    rule_id=match_guard_to_if_rule_id,
    loc~,
    message~,
    detail~,
    suggestion~,
  )
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for MatchGuardToIfEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=_, cases~, match_loc=_, loc~) =>
      if is_guard_chain_cases(cases) {
        push_match_guard_to_if_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn match_guard_to_if_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=match_guard_to_if_rule_id,
    description=match_guard_to_if_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = MatchGuardToIfEnv::{ diags: Array::new(capacity=8) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

///|
let prefer_guard_chain_rule_id : String = "prefer_guard_chain"

///|
let prefer_guard_chain_description : String = "Prefer guard/if for nested matches with trivial fallback branches."

///|
priv struct PreferGuardChainEnv {
  diags : Array[@starlint.Diagnostic]
  skip_locs : Map[String, Bool]
}

///|
fn is_noop_pattern(pat : @syntax.Pattern) -> Bool {
  @starlint.is_discard_pattern(pat) || @starlint.is_none_pattern(pat)
}

///|
fn is_terminal_expr(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.Raise(..) => true
    @syntax.Return(..) => true
    @syntax.Break(..) => true
    @syntax.Continue(..) => true
    @syntax.Apply(
      func=@syntax.Field(record=_, accessor=@syntax.Accessor::Label(label), ..),
      args=_,
      attr=NoAttr,
      loc=_
    ) => is_terminal_name(@starlint.label_name(label))
    @syntax.Apply(
      func=@syntax.Method(type_name=_, method_name~, ..),
      args=_,
      attr=NoAttr,
      loc=_
    ) => is_terminal_name(@starlint.label_name(method_name))
    @syntax.Apply(func=@syntax.Ident(id=ident, ..), args=_, attr=NoAttr, loc=_) =>
      is_terminal_name(@starlint.longident_right_name(ident.name))
    @syntax.DotApply(method_name~, ..) =>
      is_terminal_name(@starlint.label_name(method_name))
    _ => false
  }
}

///|
fn is_terminal_name(name : String) -> Bool {
  name == "abort" || name == "fail" || name == "panic"
}

///|
fn is_trivial_fallback_case(case_ : @syntax.Case) -> Bool {
  case_.guard_ is None &&
  is_noop_pattern(case_.pattern) &&
  (@starlint.is_unit_expr(case_.body) || is_terminal_expr(case_.body))
}

///|
fn active_case_from_cases(cases : @list.List[@syntax.Case]) -> @syntax.Case? {
  let cases_array = @starlint.list_to_array(cases)
  let mut active_case : @syntax.Case? = None
  let mut has_fallback = false
  for case_ in cases_array {
    if case_.guard_ is Some(_) {
      return None
    }
    if is_trivial_fallback_case(case_) {
      has_fallback = true
    } else {
      match active_case {
        Some(_) => return None
        None => active_case = Some(case_)
      }
    }
  }
  if has_fallback {
    active_case
  } else {
    None
  }
}

///|
fn match_expr_info(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @list.List[@syntax.Case], @basic.Location)? {
  match @starlint.unwrap_paren(expr) {
    @syntax.Match(expr=_, cases~, match_loc=_, loc~) => Some((expr, cases, loc))
    _ => None
  }
}

///|
fn match_expr_from_body(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @list.List[@syntax.Case], @basic.Location)? {
  match match_expr_info(expr) {
    Some(info) => Some(info)
    None =>
      match @starlint.unwrap_paren(expr) {
        @syntax.Sequence(exprs~, last_expr~, loc=_) => {
          let items = @starlint.list_to_array(exprs)
          if items.length() == 1 && @starlint.is_unit_expr(last_expr) {
            match match_expr_info(items[0]) {
              Some(info) => Some(info)
              None => None
            }
          } else {
            None
          }
        }
        _ => None
      }
  }
}

///|
fn collect_match_chain_locs_from(
  expr : @syntax.Expr,
  locs : Array[@basic.Location],
) -> Bool {
  match match_expr_from_body(expr) {
    Some((_, cases, loc)) =>
      match active_case_from_cases(cases) {
        Some(active_case) => {
          locs.push(loc)
          match match_expr_from_body(active_case.body) {
            Some((next_expr, _, _)) =>
              collect_match_chain_locs_from(next_expr, locs)
            None => true
          }
        }
        None => false
      }
    None => false
  }
}

///|
fn collect_match_chain_locs(expr : @syntax.Expr) -> Array[@basic.Location]? {
  let locs = Array::new(capacity=2)
  let ok = collect_match_chain_locs_from(expr, locs)
  if ok && locs.length() >= 2 {
    Some(locs)
  } else {
    None
  }
}

///|
fn push_prefer_guard_chain_diag(
  env : PreferGuardChainEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Nested match with trivial fallback; prefer guard/if early return to reduce nesting."
  let detail =
    #|match a {
    #|  A(x) => match b {
    #|    B(y) => { ... }
    #|    _ => ()
    #|  }
    #|  _ => ()
    #|}
  let suggestion =
    #|guard a is A(x) else { return () }
    #|guard b is B(y) else { return () }
    #|...
  let diag = @starlint.Diagnostic::new(
    rule_id=prefer_guard_chain_rule_id,
    loc~,
    message~,
    detail~,
    suggestion~,
  )
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for PreferGuardChainEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(loc~, ..) =>
      if env.skip_locs.get(@starlint.location_key(loc)) is None {
        match collect_match_chain_locs(expr) {
          Some(locs) => {
            for i in 1..<locs.length() {
              env.skip_locs.set(@starlint.location_key(locs[i]), true)
            }
            push_prefer_guard_chain_diag(env, locs[0])
          }
          None => ()
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_guard_chain_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_guard_chain_rule_id,
    description=prefer_guard_chain_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferGuardChainEnv::{
        diags: Array::new(capacity=8),
        skip_locs: Map::new(),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

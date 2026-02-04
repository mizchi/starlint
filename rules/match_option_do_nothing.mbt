///|
let match_option_do_nothing_rule_id : String = "match_option_do_nothing"

///|
let match_option_do_nothing_description : String = "Prefer if-let when None branch is ()."

///|
priv struct MatchOptionDoNothingEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
  skip_locs : Map[String, Bool]
}

///|
fn push_match_option_do_nothing_diag(
  env : MatchOptionDoNothingEnv,
  subject : @syntax.Expr,
  cases : @list.List[@syntax.Case],
  loc : @basic.Location,
  require_some_unit : Bool,
) -> Unit {
  let cases_array = @moonlint.list_to_array(cases)
  if cases_array.length() != 2 {
    return
  }
  let mut some_case : @syntax.Case? = None
  let mut none_case : @syntax.Case? = None
  for case_ in cases_array {
    if case_.guard_ is None {
      if @moonlint.is_some_pattern(case_.pattern) {
        some_case = Some(case_)
      } else if @moonlint.is_none_pattern(case_.pattern) {
        none_case = Some(case_)
      }
    }
  }
  match (some_case, none_case) {
    (Some(some_case), Some(none_case)) if @moonlint.is_unit_expr(none_case.body) &&
      (!require_some_unit || @moonlint.is_unit_expr(some_case.body)) => {
      let message = "None branch is empty; prefer if-let."
      let detail =
        #|match opt {
        #|  Some(v) => { ... }
        #|  None => ()
        #|}
      let suggestion =
        #|if opt is Some(v) { ... }
      let pattern_text = match
        @moonlint.pattern_source(env.source, some_case.pattern) {
        Some(src) => Some(src)
        None =>
          match @moonlint.some_binder_name(some_case.pattern) {
            Some(name) => Some("Some(\{name})")
            None => None
          }
      }
      let fix = match
        (
          @moonlint.expr_source(env.source, subject),
          pattern_text,
          @moonlint.expr_source(env.source, some_case.body),
        ) {
        (Some(subject_src), Some(pattern_src), Some(body_src)) => {
          let replacement = "if (\{subject_src}) is \{pattern_src} { \{body_src} }"
          Some(@moonlint.Fix::new(range=loc, replacement~))
        }
        _ => None
      }
      let diag = match fix {
        Some(fix) =>
          @moonlint.Diagnostic::new(
            rule_id=match_option_do_nothing_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
            fix~,
          )
        None =>
          @moonlint.Diagnostic::new(
            rule_id=match_option_do_nothing_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          )
      }
      env.diags.push(diag)
    }
    _ => ()
  }
}

///|
impl @syntax.IterVisitor for MatchOptionDoNothingEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Sequence(exprs~, last_expr=_, loc=_) => {
      let items = @moonlint.list_to_array(exprs)
      for item in items {
        match item {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) => {
            env.skip_locs.set(@moonlint.location_key(loc), true)
            push_match_option_do_nothing_diag(env, subject, cases, loc, false)
          }
          _ => ()
        }
      }
    }
    @syntax.Let(pattern~, expr=bound, body=_, loc=_) =>
      if @moonlint.is_discard_pattern(pattern) {
        match bound {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) => {
            env.skip_locs.set(@moonlint.location_key(loc), true)
            push_match_option_do_nothing_diag(env, subject, cases, loc, false)
          }
          _ => ()
        }
      }
    @syntax.LetMut(binder~, ty=_, expr=bound, body=_, loc=_) =>
      if binder.name == "_" {
        match bound {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) => {
            env.skip_locs.set(@moonlint.location_key(loc), true)
            push_match_option_do_nothing_diag(env, subject, cases, loc, false)
          }
          _ => ()
        }
      }
    @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
      if env.skip_locs.get(@moonlint.location_key(loc)) is None {
        push_match_option_do_nothing_diag(env, subject, cases, loc, true)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn match_option_do_nothing_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=match_option_do_nothing_rule_id,
    description=match_option_do_nothing_description,
    run=input => {
      let env = MatchOptionDoNothingEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
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

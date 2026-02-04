///|
let match_to_if_let_rule_id : String = "match_to_if_let"

///|
let match_to_if_let_description : String = "Prefer if-let when matching only Some/None."

///|
priv struct MatchToIfLetEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
fn push_match_to_if_let_diag(
  env : MatchToIfLetEnv,
  subject : @syntax.Expr,
  cases : @list.List[@syntax.Case],
  loc : @basic.Location,
) -> Unit {
  let cases_array = @moonlint.list_to_array(cases)
  if cases_array.length() != 2 {
    return
  }
  let mut some_case : @syntax.Case? = None
  let mut none_case : @syntax.Case? = None
  let mut binder_name : String? = None
  for case_ in cases_array {
    if case_.guard_ is None {
      match @moonlint.some_binder_name(case_.pattern) {
        Some(name) => {
          some_case = Some(case_)
          binder_name = Some(name)
        }
        None =>
          if @moonlint.is_none_pattern(case_.pattern) {
            none_case = Some(case_)
          }
      }
    }
  }
  match (some_case, none_case, binder_name) {
    (Some(some_case), Some(none_case), Some(name)) =>
      if @moonlint.is_none_expr(none_case.body) ||
        @moonlint.is_unit_expr(none_case.body) ||
        @moonlint.match_ident_name(some_case.body) == Some(name) {
        ()
      } else {
        let message = "Match can be replaced with if-let."
        let detail =
          #|match opt {
          #|  Some(v) => expr1
          #|  None => expr2
          #|}
        let suggestion =
          #|if opt is Some(v) { expr1 } else { expr2 }
        let fix = match
          (
            @moonlint.expr_source(env.source, subject),
            @moonlint.pattern_source(env.source, some_case.pattern),
            @moonlint.expr_source(env.source, some_case.body),
            @moonlint.expr_source(env.source, none_case.body),
          ) {
          (Some(subject_src), Some(pattern_src), Some(some_src), Some(none_src)) => {
            let replacement = "if (\{subject_src}) is \{pattern_src} { \{some_src} } else { \{none_src} }"
            Some(@moonlint.Fix::new(range=loc, replacement~))
          }
          _ => None
        }
        let diag = match fix {
          Some(fix) =>
            @moonlint.Diagnostic::new(
              rule_id=match_to_if_let_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
              fix~,
            )
          None =>
            @moonlint.Diagnostic::new(
              rule_id=match_to_if_let_rule_id,
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
impl @syntax.IterVisitor for MatchToIfLetEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Sequence(exprs~, last_expr=_, loc=_) => {
      let items = @moonlint.list_to_array(exprs)
      for item in items {
        match item {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
            push_match_to_if_let_diag(env, subject, cases, loc)
          _ => ()
        }
      }
    }
    @syntax.Let(pattern~, expr=bound, body=_, loc=_) =>
      if @moonlint.is_discard_pattern(pattern) {
        match bound {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
            push_match_to_if_let_diag(env, subject, cases, loc)
          _ => ()
        }
      }
    @syntax.LetMut(binder~, ty=_, expr=bound, body=_, loc=_) =>
      if binder.name == "_" {
        match bound {
          @syntax.Match(expr=subject, cases~, match_loc=_, loc~) =>
            push_match_to_if_let_diag(env, subject, cases, loc)
          _ => ()
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn match_to_if_let_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=match_to_if_let_rule_id,
    description=match_to_if_let_description,
    run=input => {
      let env = MatchToIfLetEnv::{
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

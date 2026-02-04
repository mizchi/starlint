///|
let match_option_unwrap_or_rule_id : String = "match_option_unwrap_or"

///|
let match_option_unwrap_or_description : String = "Prefer unwrap_or for match on Some/None."

///|
priv struct MatchOptionUnwrapOrEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn is_safe_unwrap_or_default(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.Constant(..) => true
    @syntax.MultilineString(..) => true
    _ => @starlint.is_none_expr(expr) || @starlint.is_unit_expr(expr)
  }
}

///|
impl @syntax.IterVisitor for MatchOptionUnwrapOrEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases~, match_loc=_, loc~) => {
      let cases_array = @starlint.list_to_array(cases)
      if cases_array.length() == 2 {
        let mut some_case : @syntax.Case? = None
        let mut none_case : @syntax.Case? = None
        let mut binder_name : String? = None
        for case_ in cases_array {
          if case_.guard_ is None {
            match @starlint.some_binder_name(case_.pattern) {
              Some(name) => {
                some_case = Some(case_)
                binder_name = Some(name)
              }
              None =>
                if @starlint.is_none_pattern(case_.pattern) {
                  none_case = Some(case_)
                }
            }
          }
        }
        match (some_case, none_case, binder_name) {
          (Some(some_case), Some(none_case), Some(name)) =>
            if @starlint.match_ident_name(some_case.body) == Some(name) &&
              is_safe_unwrap_or_default(none_case.body) {
              let message = "Match can be replaced with unwrap_or."
              let detail =
                #|match opt {
                #|  Some(v) => v
                #|  None => default
                #|}
              let suggestion =
                #|opt.unwrap_or(default)
              let fix = match
                (
                  @starlint.expr_source(env.source, subject),
                  @starlint.expr_source(env.source, none_case.body),
                ) {
                (Some(subject_src), Some(default_src)) => {
                  let replacement = "\{subject_src}.unwrap_or(\{default_src})"
                  Some(@starlint.Fix::new(range=loc, replacement~))
                }
                _ => None
              }
              let diag = match fix {
                Some(fix) =>
                  @starlint.Diagnostic::new(
                    rule_id=match_option_unwrap_or_rule_id,
                    loc~,
                    message~,
                    detail~,
                    suggestion~,
                    fix~,
                  )
                None =>
                  @starlint.Diagnostic::new(
                    rule_id=match_option_unwrap_or_rule_id,
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
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn match_option_unwrap_or_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=match_option_unwrap_or_rule_id,
    description=match_option_unwrap_or_description,
    run=input => {
      let env = MatchOptionUnwrapOrEnv::{
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

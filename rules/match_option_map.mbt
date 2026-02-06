///|
let match_option_map_rule_id : String = "match_option_map"

///|
let match_option_map_description : String = "Prefer map for match on Some/None returning None."

///|
priv struct MatchOptionMapEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
impl @syntax.IterVisitor for MatchOptionMapEnv with visit_Expr(env, expr) {
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
          (Some(some_case), Some(none_case), Some(name)) if @starlint.is_none_expr(
              none_case.body,
            ) => {
            let message = "Match can be replaced with map."
            let detail =
              #|match opt {
              #|  Some(v) => f(v)
              #|  None => None
              #|}
            let suggestion =
              #|opt.map(v => f(v))
            let fix = match
              (
                @starlint.expr_source(env.source, subject),
                @starlint.expr_source(env.source, some_case.body),
              ) {
              (Some(subject_src), Some(body_src)) =>
                if !body_src.contains("\n") {
                  let replacement = "\{subject_src}.map(\{name} => \{body_src})"
                  Some(@starlint.Fix::new(range=loc, replacement~))
                } else {
                  None
                }
              _ => None
            }
            let diag = match fix {
              Some(fix) =>
                @starlint.Diagnostic::new(
                  rule_id=match_option_map_rule_id,
                  loc~,
                  message~,
                  detail~,
                  suggestion~,
                  fix~,
                )
              None =>
                @starlint.Diagnostic::new(
                  rule_id=match_option_map_rule_id,
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
fn match_option_map_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=match_option_map_rule_id,
    description=match_option_map_description,
    run=input => {
      let env = MatchOptionMapEnv::{
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

///|
let prefer_option_filter_rule_id : String = "prefer_option_filter"

///|
let prefer_option_filter_description : String = "Prefer Option::filter for conditional Some/None match."

///|
priv struct PreferOptionFilterEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn match_some_guard_some_none(
  cases_array : Array[@syntax.Case],
) -> (String, @syntax.Expr, @syntax.Case, @syntax.Case)? {
  if cases_array.length() != 2 {
    return None
  }
  let mut some_case : @syntax.Case? = None
  let mut none_case : @syntax.Case? = None
  let mut binder_name : String? = None
  for case_ in cases_array {
    match @internal.some_binder_name(case_.pattern) {
      Some(name) => {
        some_case = Some(case_)
        binder_name = Some(name)
      }
      None =>
        if (
            @internal.is_none_pattern(case_.pattern) ||
            @internal.is_discard_pattern(case_.pattern)
          ) &&
          case_.guard_ is None {
          none_case = Some(case_)
        }
    }
  }
  match (some_case, none_case, binder_name) {
    (Some(sc), Some(nc), Some(name)) =>
      match sc.guard_ {
        Some(guard_expr) if @internal.is_none_expr(nc.body) =>
          // Check that Some branch returns Some(same_binder)
          match @internal.match_some_apply(sc.body) {
            Some(inner) =>
              if @internal.match_ident_name(inner) == Some(name) {
                Some((name, guard_expr, sc, nc))
              } else {
                None
              }
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
impl @syntax.IterVisitor for PreferOptionFilterEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Match(expr=subject, cases~, match_loc=_, loc~) => {
      let cases_array = @internal.list_to_array(cases)
      match match_some_guard_some_none(cases_array) {
        Some((name, guard_expr, _, _)) => {
          let message = "Match can be replaced with filter."
          let detail =
            #|match opt {
            #|  Some(v) if cond(v) => Some(v)
            #|  _ => None
            #|}
          let suggestion =
            #|opt.filter(fn(v) { cond(v) })
          let fix = match
            (
              @internal.expr_source(env.source, subject),
              @internal.expr_source(env.source, guard_expr),
            ) {
            (Some(subject_src), Some(guard_src)) =>
              if !guard_src.contains("\n") {
                let replacement = "\{subject_src}.filter(fn(\{name}) { \{guard_src} })"
                Some(@starlint.Fix::new(range=loc, replacement~))
              } else {
                None
              }
            _ => None
          }
          let diag = match fix {
            Some(fix) =>
              @starlint.Diagnostic::new(
                rule_id=prefer_option_filter_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
                fix~,
              )
            None =>
              @starlint.Diagnostic::new(
                rule_id=prefer_option_filter_rule_id,
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
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_option_filter_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_option_filter_rule_id,
    description=prefer_option_filter_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferOptionFilterEnv::{
        diags: Array::new(capacity=4),
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

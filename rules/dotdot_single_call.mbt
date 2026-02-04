///|
let dotdot_single_call_rule_id : String = "dotdot_single_call"

///|
let dotdot_single_call_description : String = "Prefer . when .. is not chained."

///|
priv struct DotdotSingleCallEnv {
  diags : Array[@starlint.Diagnostic]
  skip_locs : Map[String, Bool]
  source : String
}

///|
fn dotdot_single_replacement(
  source : String,
  expr : @syntax.Expr,
  receiver : @syntax.Expr,
) -> String? {
  let receiver_src = match @starlint.expr_source(source, receiver) {
    Some(src) => src
    None => return None
  }
  let call_src = match @starlint.expr_source(source, expr) {
    Some(src) => src
    None => return None
  }
  match call_src.strip_prefix("\{receiver_src}..") {
    Some(view) => {
      let sb = StringBuilder::new()
      sb..write_view(receiver_src)..write_char('.')..write_view(view)
      Some(sb.to_string())
    }
    None => None
  }
}

///|
impl @syntax.IterVisitor for DotdotSingleCallEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.DotApply(self~, return_self=true, loc~, ..) => {
      match self {
        @syntax.DotApply(return_self=true, loc=inner_loc, ..) =>
          env.skip_locs.set(@starlint.location_key(inner_loc), true)
        _ => ()
      }
      if env.skip_locs.get(@starlint.location_key(loc)) is None {
        match self {
          @syntax.DotApply(return_self=true, ..) => ()
          _ => {
            let message = "Single .. call can be replaced with ."
            let detail =
              #|obj..method()
            let suggestion =
              #|obj.method()
            let fix = match dotdot_single_replacement(env.source, expr, self) {
              Some(replacement) =>
                Some(@starlint.Fix::new(range=loc, replacement~))
              None => None
            }
            let diag = match fix {
              Some(fix) =>
                @starlint.Diagnostic::new(
                  rule_id=dotdot_single_call_rule_id,
                  loc~,
                  message~,
                  detail~,
                  suggestion~,
                  fix~,
                )
              None =>
                @starlint.Diagnostic::new(
                  rule_id=dotdot_single_call_rule_id,
                  loc~,
                  message~,
                  detail~,
                  suggestion~,
                )
            }
            env.diags.push(diag)
          }
        }
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn dotdot_single_call_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=dotdot_single_call_rule_id,
    description=dotdot_single_call_description,
    run=input => {
      let env = DotdotSingleCallEnv::{
        diags: Array::new(capacity=8),
        skip_locs: Map::new(),
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

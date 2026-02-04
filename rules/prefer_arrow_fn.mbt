///|
let prefer_arrow_fn_rule_id : String = "prefer_arrow_fn"

///|
let prefer_arrow_fn_description : String = "Prefer arrow functions for single-expression lambdas."

///|
priv struct PreferArrowFnEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
fn params_to_arrow_source(params : Array[@syntax.Parameter]) -> String? {
  if params.length() == 0 {
    return Some("()")
  }
  let names = Array::new(capacity=params.length())
  for param in params {
    match param {
      @syntax.Parameter::Positional(binder~, ty=None) => names.push(binder.name)
      _ => return None
    }
  } else {
    let joined = names.join(", ")
    if names.length() == 1 {
      Some(joined)
    } else {
      Some("(\{joined})")
    }
  }
}

///|
fn single_expr_body(expr : @syntax.Expr) -> @syntax.Expr? {
  match expr {
    @syntax.Sequence(exprs~, last_expr~, loc=_) => {
      let items = @moonlint.list_to_array(exprs)
      if items.length() != 0 {
        return None
      }
      match last_expr {
        @syntax.Unit(faked=true, ..) => None
        _ => Some(last_expr)
      }
    }
    _ => Some(expr)
  }
}

///|
fn has_call_suffix(source : String, loc : @basic.Location) -> Bool {
  if source == "" {
    return false
  }
  let start = loc.end.cnum
  if start < 0 || start > source.length() {
    return false
  }
  let view_result : Result[StringView, Error] = try? source[start:]
  match view_result {
    Ok(view) => view.trim_start().has_prefix("(")
    Err(_) => false
  }
}

///|
impl @syntax.IterVisitor for PreferArrowFnEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Function(func~, loc~) =>
      if func.return_type is None &&
        func.is_async is None &&
        func.has_error is None {
        let is_lambda = match func.kind {
          @syntax.FnKind::Lambda => true
          _ => false
        }
        let no_error = match func.error_type {
          @syntax.ErrorType::NoErrorType => true
          _ => false
        }
        if is_lambda && no_error {
          let params = @moonlint.list_to_array(func.parameters)
          match params_to_arrow_source(params) {
            Some(params_src) =>
              match single_expr_body(func.body) {
                Some(body_expr) =>
                  match @moonlint.expr_source(env.source, body_expr) {
                    Some(body_src) if !body_src.contains("\n") &&
                      !body_src.contains(";") => {
                      let message = "Single-expression fn can be written with =>."
                      let detail =
                        #|fn(a){ a }
                      let suggestion = "\{params_src} => \{body_src}"
                      let replacement = suggestion
                      let fix = if loc.start.lnum == loc.end.lnum &&
                        !has_call_suffix(env.source, loc) {
                        Some(@moonlint.Fix::new(range=loc, replacement~))
                      } else {
                        None
                      }
                      let diag = match fix {
                        Some(fix) =>
                          @moonlint.Diagnostic::new(
                            rule_id=prefer_arrow_fn_rule_id,
                            loc~,
                            message~,
                            detail~,
                            suggestion~,
                            fix~,
                          )
                        None =>
                          @moonlint.Diagnostic::new(
                            rule_id=prefer_arrow_fn_rule_id,
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
                None => ()
              }
            None => ()
          }
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_arrow_fn_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_arrow_fn_rule_id,
    description=prefer_arrow_fn_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferArrowFnEnv::{
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

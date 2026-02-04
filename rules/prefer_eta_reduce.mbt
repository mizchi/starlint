///|
let prefer_eta_reduce_rule_id : String = "prefer_eta_reduce"

///|
let prefer_eta_reduce_description : String = "Prefer eta-reduction for lambdas that only call another function."

///|
priv struct PreferEtaReduceEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
fn params_to_names(params : Array[@syntax.Parameter]) -> Array[String]? {
  let names = Array::new(capacity=params.length())
  for param in params {
    match param {
      @syntax.Parameter::Positional(binder~, ty=None) =>
        if binder.name == "_" {
          return None
        } else {
          names.push(binder.name)
        }
      _ => return None
    }
  } else {
    Some(names)
  }
}

///|
fn eta_reduce_single_expr_body(expr : @syntax.Expr) -> @syntax.Expr? {
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
fn is_eta_target(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Ident(..) => true
    @syntax.Method(..) => true
    @syntax.Constr(..) => true
    _ => false
  }
}

///|
fn eta_call_target(
  expr : @syntax.Expr,
  params : Array[String],
) -> @syntax.Expr? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, attr=NoAttr, ..) => {
      if !is_eta_target(func) {
        return None
      }
      let args_array = @moonlint.list_to_array(args)
      if args_array.length() != params.length() {
        return None
      }
      for i in 0..<params.length() {
        let arg = args_array[i]
        match arg.kind {
          @syntax.ArgumentKind::Positional => ()
          _ => return None
        }
        match @moonlint.match_ident_name(arg.value) {
          Some(name) if name == params[i] => ()
          _ => return None
        }
      } else {
        Some(func)
      }
    }
    _ => None
  }
}

///|
fn eta_reduce_has_call_suffix(source : String, loc : @basic.Location) -> Bool {
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
impl @syntax.IterVisitor for PreferEtaReduceEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Function(func~, loc~) =>
      if func.return_type is None &&
        func.is_async is None &&
        func.has_error is None {
        let is_lambda = match func.kind {
          @syntax.FnKind::Lambda => true
          @syntax.FnKind::Arrow => true
        }
        let no_error = match func.error_type {
          @syntax.ErrorType::NoErrorType => true
          _ => false
        }
        if is_lambda && no_error {
          let params = @moonlint.list_to_array(func.parameters)
          match params_to_names(params) {
            Some(param_names) =>
              match eta_reduce_single_expr_body(func.body) {
                Some(body_expr) =>
                  match eta_call_target(body_expr, param_names) {
                    Some(target_expr) =>
                      match @moonlint.expr_source(env.source, target_expr) {
                        Some(target_src) => {
                          let message = "Lambda can be eta-reduced."
                          let detail =
                            #|fn(x){ f(x) }
                          let suggestion = target_src
                          let fix = if loc.start.lnum == loc.end.lnum &&
                            !eta_reduce_has_call_suffix(env.source, loc) &&
                            !target_src.contains("\n") {
                            Some(
                              @moonlint.Fix::new(
                                range=loc,
                                replacement=target_src,
                              ),
                            )
                          } else {
                            None
                          }
                          let diag = match fix {
                            Some(fix) =>
                              @moonlint.Diagnostic::new(
                                rule_id=prefer_eta_reduce_rule_id,
                                loc~,
                                message~,
                                detail~,
                                suggestion~,
                                fix~,
                              )
                            None =>
                              @moonlint.Diagnostic::new(
                                rule_id=prefer_eta_reduce_rule_id,
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
                    None => ()
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
fn prefer_eta_reduce_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_eta_reduce_rule_id,
    description=prefer_eta_reduce_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferEtaReduceEnv::{
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

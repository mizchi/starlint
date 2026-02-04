///|
let legacy_call_syntax_rule_id : String = "legacy_call_syntax"

///|
let legacy_call_syntax_description : String = "Legacy call syntax f!(...) / f(...)? is deprecated."

///|
priv struct LegacyCallSyntaxEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn remove_at(source : String, index : Int) -> String? {
  if index < 0 || index >= source.length() {
    return None
  }
  let prefix_result : Result[StringView, Error] = try? source[:index]
  let suffix_result : Result[StringView, Error] = try? source[index + 1:]
  match (prefix_result, suffix_result) {
    (Ok(prefix), Ok(suffix)) => {
      let sb = StringBuilder::new()
      sb..write_view(prefix)..write_view(suffix)
      Some(sb.to_string())
    }
    _ => None
  }
}

///|
fn remove_bang_before_paren(call_src : String) -> String? {
  match call_src.find("!(") {
    Some(index) => remove_at(call_src, index)
    None =>
      match call_src.find("! (") {
        Some(index) => remove_at(call_src, index)
        None => None
      }
  }
}

///|
fn remove_question_mark(call_src : String) -> String? {
  match call_src.find("?(") {
    Some(index) => remove_at(call_src, index)
    None =>
      match call_src.find("? (") {
        Some(index) => remove_at(call_src, index)
        None =>
          if !call_src.has_suffix("?") {
            None
          } else {
            let end = call_src.length() - 1
            let view_result : Result[StringView, Error] = try? call_src[:end]
            match view_result {
              Ok(view) => Some(view.to_string())
              Err(_) => None
            }
          }
      }
  }
}

///|
impl @syntax.IterVisitor for LegacyCallSyntaxEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Apply(attr=Exclamation, loc~, ..) => {
      let message = "Legacy call syntax f!(...) is deprecated."
      let detail =
        #|f!(args)
      let suggestion =
        #|Use a normal call:
        #|
        #|f(args)
      let fix = match @starlint.expr_source(env.source, expr) {
        Some(call_src) =>
          match remove_bang_before_paren(call_src) {
            Some(replacement) =>
              Some(@starlint.Fix::new(range=loc, replacement~))
            None => None
          }
        None => None
      }
      let diag = match fix {
        Some(fix) =>
          @starlint.Diagnostic::new(
            rule_id=legacy_call_syntax_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
            fix~,
          )
        None =>
          @starlint.Diagnostic::new(
            rule_id=legacy_call_syntax_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          )
      }
      env.diags.push(diag)
    }
    @syntax.Apply(attr=Question, loc~, ..) => {
      let message = "Legacy call syntax f(...)? is deprecated."
      let detail =
        #|f(args)?
      let suggestion =
        #|Use try? for Result conversion:
        #|
        #|try? f(args)
      let fix = match @starlint.expr_source(env.source, expr) {
        Some(call_src) =>
          match remove_question_mark(call_src) {
            Some(call_without_question) =>
              Some(
                @starlint.Fix::new(
                  range=loc,
                  replacement="try? \{call_without_question}",
                ),
              )
            None => None
          }
        None => None
      }
      let diag = match fix {
        Some(fix) =>
          @starlint.Diagnostic::new(
            rule_id=legacy_call_syntax_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
            fix~,
          )
        None =>
          @starlint.Diagnostic::new(
            rule_id=legacy_call_syntax_rule_id,
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
  env.base().visit_Expr(expr)
}

///|
fn legacy_call_syntax_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=legacy_call_syntax_rule_id,
    description=legacy_call_syntax_description,
    run=input => {
      let env = LegacyCallSyntaxEnv::{
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

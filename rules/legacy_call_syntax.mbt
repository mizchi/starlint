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
  let prefix : StringView = source[:index]
  let suffix : StringView = source[index + 1:]
  let sb = StringBuilder::new()
  sb..write_view(prefix).write_view(suffix)
  Some(sb.to_string())
}

///|
impl @syntax.IterVisitor for LegacyCallSyntaxEnv with fn visit_Expr(env, expr) {
  // Only inspect the call's own callee boundary and closing parenthesis.
  // Searching the full call text could accidentally rewrite a nested call or string.
  if @internal.legacy_call_marker(env.source, expr)
    is Some((marker, question, loc)) {
    let message = if question {
      "Legacy call syntax f(...)? is deprecated."
    } else {
      "Legacy call syntax f!(...) is deprecated."
    }
    let detail = if question { "f(args)?" } else { "f!(args)" }
    let suggestion = if question {
      "Use try? for Result conversion:\n\ntry? f(args)"
    } else {
      "Use a normal call:\n\nf(args)"
    }
    let fix = match @internal.source_slice(env.source, loc) {
      Some(call_src) =>
        match remove_at(call_src, marker - loc.start.cnum) {
          Some(unmarked) => {
            let replacement = if question {
              "try? \{unmarked}"
            } else {
              unmarked
            }
            Some(@starlint.Fix::new(range=loc, replacement~))
          }
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
      } nobreak {
        env.diags
      }
    },
  )
}

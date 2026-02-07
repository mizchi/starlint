///|
fn stmt_indent(source : String, loc : @basic.Location) -> String {
  if source == "" {
    return ""
  }
  let start = loc.start.cnum
  if start <= 0 || start > source.length() {
    return ""
  }
  let prefix_result : Result[StringView, Error] = try? source[:start]
  match prefix_result {
    Ok(prefix) => {
      let line_start = match prefix.rev_find("\n") {
        Some(idx) => idx + 1
        None => 0
      }
      let line_text_result : Result[StringView, Error] = try? source[line_start:start]
      match line_text_result {
        Ok(line_text) => {
          let trimmed = line_text.trim_start()
          let ws_len = line_text.length() - trimmed.length()
          if ws_len == 0 {
            ""
          } else {
            let ws_result : Result[StringView, Error] = try? source[line_start:line_start +
              ws_len]
            match ws_result {
              Ok(ws) => ws.to_string()
              Err(_) => ""
            }
          }
        }
        Err(_) => ""
      }
    }
    Err(_) => ""
  }
}

///|
let if_let_to_match_rule_id : String = "if_let_to_match"

///|
let if_let_to_match_description : String = "Prefer match when if-let has both branches."

///|
priv struct IfLetToMatchEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
  skip_locs : Map[String, Bool]
}

///|
fn push_if_let_to_match_diag(
  env : IfLetToMatchEnv,
  subject : @syntax.Expr,
  pat : @syntax.Pattern,
  ifso : @syntax.Expr,
  ifnot : @syntax.Expr,
  loc : @basic.Location,
) -> Unit {
  let message = "if-let can be replaced with match."
  let detail =
    #|if opt is Some(v) { expr1 } else { expr2 }
  let suggestion =
    #|match opt {
    #|  Some(v) => expr1
    #|  None => expr2
    #|}
  let fix = match
    (
      @starlint.expr_source(env.source, subject),
      @starlint.pattern_source(env.source, pat),
      @starlint.expr_source(env.source, ifso),
      @starlint.expr_source(env.source, ifnot),
    ) {
    (Some(subject_src), Some(pattern_src), Some(ifso_src), Some(ifnot_src)) =>
      if loc.start.lnum == loc.end.lnum &&
        !ifso_src.contains("\n") &&
        !ifnot_src.contains("\n") {
        let indent = stmt_indent(env.source, loc)
        let replacement = "match \{subject_src} {\n\{indent}  \{pattern_src} => \{ifso_src}\n\{indent}  None => \{ifnot_src}\n\{indent}}"
        Some(@starlint.Fix::new(range=loc, replacement~))
      } else {
        None
      }
    _ => None
  }
  let diag = match fix {
    Some(fix) =>
      @starlint.Diagnostic::new(
        rule_id=if_let_to_match_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      @starlint.Diagnostic::new(
        rule_id=if_let_to_match_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  env.diags.push(diag)
}

///|

///|
impl @syntax.IterVisitor for IfLetToMatchEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Sequence(exprs~, last_expr=_, loc=_) => {
      let items = @starlint.list_to_array(exprs)
      for item in items {
        match item {
          @syntax.If(
            cond=@syntax.Is(expr=_, pat~, loc=_),
            ifso=_,
            ifnot=Some(_),
            loc~
          ) =>
            if @starlint.is_some_pattern(pat) {
              env.skip_locs.set(@starlint.location_key(loc), true)
            }
          _ => ()
        }
      }
    }
    @syntax.Let(pattern~, expr=bound, body=_, loc=_) =>
      if @starlint.is_discard_pattern(pattern) {
        match bound {
          @syntax.If(
            cond=@syntax.Is(expr=_, pat~, loc=_),
            ifso=_,
            ifnot=Some(_),
            loc~
          ) =>
            if @starlint.is_some_pattern(pat) {
              env.skip_locs.set(@starlint.location_key(loc), true)
            }
          _ => ()
        }
      }
    @syntax.LetMut(binder~, ty=_, expr=bound, body=_, loc=_) =>
      if binder.name == "_" {
        match bound {
          @syntax.If(
            cond=@syntax.Is(expr=_, pat~, loc=_),
            ifso=_,
            ifnot=Some(_),
            loc~
          ) =>
            if @starlint.is_some_pattern(pat) {
              env.skip_locs.set(@starlint.location_key(loc), true)
            }
          _ => ()
        }
      }
    @syntax.If(
      cond=@syntax.Is(expr=subject, pat~, loc=_),
      ifso~,
      ifnot=Some(ifnot),
      loc~
    ) =>
      if @starlint.is_some_pattern(pat) &&
        env.skip_locs.get(@starlint.location_key(loc)) is None {
        push_if_let_to_match_diag(env, subject, pat, ifso, ifnot, loc)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn if_let_to_match_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=if_let_to_match_rule_id,
    description=if_let_to_match_description,
    run=input => {
      let env = IfLetToMatchEnv::{
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

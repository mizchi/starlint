///|
let c_style_for_simple_range_rule_id : String = "c_style_for_simple_range"

///|
let c_style_for_simple_range_description : String = "Prefer range for-loop for simple incrementing loops."

///|
priv struct CStyleForSimpleRangeEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
priv struct ContinueFinder {
  mut found : Bool
}

///|
impl @syntax.IterVisitor for ContinueFinder with visit_Expr(env, expr) {
  if env.found {
    return
  }
  match expr {
    @syntax.Continue(..) => env.found = true
    @syntax.For(..)
    | @syntax.ForEach(..)
    | @syntax.While(..)
    | @syntax.Loop(..) => ()
    _ => env.base().visit_Expr(expr)
  }
}

///|
fn contains_continue(expr : @syntax.Expr) -> Bool {
  let env = ContinueFinder::{ found: false }
  env.visit_Expr(expr)
  env.found
}

///|
fn[T] list_to_array_for(xs : @list.List[T]) -> Array[T] {
  let out = Array::new(capacity=4)
  for item in xs {
    out.push(item)
  } nobreak {
    out
  }
}

///|
fn match_simple_update(binder_name : String, expr : @syntax.Expr) -> Bool {
  match @internal.match_infix(expr, "+") {
    Some((lhs, rhs, _)) =>
      @internal.match_ident_name(lhs) == Some(binder_name) &&
      @internal.match_constant_int(rhs) == Some("1")
    None => false
  }
}

///|
fn range_side_needs_paren(raw_src : String) -> Bool {
  let src = raw_src.trim().to_string()
  if src == "" {
    return false
  }
  if src.has_prefix("(") && src.has_suffix(")") {
    return false
  }
  src.contains("+") ||
  src.contains("-") ||
  src.contains("*") ||
  src.contains("/") ||
  src.contains("%") ||
  src.contains("&&") ||
  src.contains("||") ||
  src.contains("&") ||
  src.contains("|") ||
  src.contains("^") ||
  src.contains("==") ||
  src.contains("!=") ||
  src.contains("<") ||
  src.contains(">")
}

///|
fn format_range_side(src : String) -> String {
  if range_side_needs_paren(src) {
    "(\{src})"
  } else {
    src
  }
}

///|
impl @syntax.IterVisitor for CStyleForSimpleRangeEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.For(
      binders~,
      condition=Some(condition),
      continue_block~,
      body~,
      for_else=None,
      label=None,
      loc~,
      ..
    ) => {
      let binders_array = list_to_array_for(binders)
      let continue_array = list_to_array_for(continue_block)
      if binders_array.length() == 1 && continue_array.length() == 1 {
        let (binder, init_expr) = binders_array[0]
        let (cont_binder, cont_expr) = continue_array[0]
        let binder_name = binder.name
        let cont_name = cont_binder.name
        if binder_name == cont_name &&
          match_simple_update(binder_name, cont_expr) &&
          !contains_continue(body) {
          let mut inclusive = false
          let mut bound_expr : @syntax.Expr? = None
          match @internal.match_infix(condition, "<") {
            Some((lhs, rhs, _)) if @internal.match_ident_name(lhs) ==
              Some(binder_name) => {
              inclusive = false
              bound_expr = Some(rhs)
            }
            _ =>
              match @internal.match_infix(condition, "<=") {
                Some((lhs, rhs, _)) if @internal.match_ident_name(lhs) ==
                  Some(binder_name) => {
                  inclusive = true
                  bound_expr = Some(rhs)
                }
                _ => ()
              }
          }
          match bound_expr {
            Some(bound_expr) => {
              let message = "C-style for-loop can be a range for-loop."
              let detail =
                #|for i = start; i < end; i = i + 1 { ... }
              let suggestion =
                #|for i in start..<end { ... }
              let fix = match
                (
                  @internal.expr_source(env.source, init_expr),
                  @internal.expr_source(env.source, bound_expr),
                  @internal.expr_source(env.source, body),
                ) {
                (Some(init_src), Some(bound_src), Some(body_src)) =>
                  if !body_src.contains("\n") {
                    let range_op = if inclusive { "..=" } else { "..<" }
                    let start_src = format_range_side(init_src)
                    let end_src = format_range_side(bound_src)
                    let replacement = "for \{binder_name} in \{start_src}\{range_op}\{end_src} { \{body_src} }"
                    Some(@starlint.Fix::new(range=loc, replacement~))
                  } else {
                    None
                  }
                _ => None
              }
              let diag = match fix {
                Some(fix) =>
                  @starlint.Diagnostic::new(
                    rule_id=c_style_for_simple_range_rule_id,
                    loc~,
                    message~,
                    detail~,
                    suggestion~,
                    fix~,
                  )
                None =>
                  @starlint.Diagnostic::new(
                    rule_id=c_style_for_simple_range_rule_id,
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
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn c_style_for_simple_range_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=c_style_for_simple_range_rule_id,
    description=c_style_for_simple_range_description,
    run=input => {
      let env = CStyleForSimpleRangeEnv::{
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

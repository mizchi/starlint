///|
let c_style_for_simple_range_rule_id : String = "c_style_for_simple_range"

///|
let c_style_for_simple_range_description : String = "Prefer range for-loop for simple incrementing loops."

///|
priv struct CStyleForSimpleRangeEnv {
  diags : Array[@moonlint.Diagnostic]
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
  } else {
    out
  }
}

///|
fn match_simple_update(binder_name : String, expr : @syntax.Expr) -> Bool {
  match @moonlint.match_infix(expr, "+") {
    Some((lhs, rhs, _)) =>
      @moonlint.match_ident_name(lhs) == Some(binder_name) &&
      @moonlint.match_constant_int(rhs) == Some("1")
    None => false
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
          match @moonlint.match_infix(condition, "<") {
            Some((lhs, rhs, _)) if @moonlint.match_ident_name(lhs) ==
              Some(binder_name) => {
              inclusive = false
              bound_expr = Some(rhs)
            }
            _ =>
              match @moonlint.match_infix(condition, "<=") {
                Some((lhs, rhs, _)) if @moonlint.match_ident_name(lhs) ==
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
                  @moonlint.expr_source(env.source, init_expr),
                  @moonlint.expr_source(env.source, bound_expr),
                  @moonlint.expr_source(env.source, body),
                ) {
                (Some(init_src), Some(bound_src), Some(body_src)) => {
                  let range_op = if inclusive { "..=" } else { "..<" }
                  let replacement = "for \{binder_name} in \{init_src}\{range_op}\{bound_src} { \{body_src} }"
                  Some(@moonlint.Fix::new(range=loc, replacement~))
                }
                _ => None
              }
              let diag = match fix {
                Some(fix) =>
                  @moonlint.Diagnostic::new(
                    rule_id=c_style_for_simple_range_rule_id,
                    loc~,
                    message~,
                    detail~,
                    suggestion~,
                    fix~,
                  )
                None =>
                  @moonlint.Diagnostic::new(
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
fn c_style_for_simple_range_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=c_style_for_simple_range_rule_id,
    description=c_style_for_simple_range_description,
    run=input => {
      let env = CStyleForSimpleRangeEnv::{
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

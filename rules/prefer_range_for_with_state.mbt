///|
let prefer_range_for_with_state_rule_id : String = "prefer_range_for_with_state"

///|
let prefer_range_for_with_state_description : String = "Prefer for..in with state variables over C-style for-loop with index and accumulators."

///|
priv struct PreferRangeForWithStateEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
impl @syntax.IterVisitor for PreferRangeForWithStateEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.For(
      binders~,
      condition=Some(condition),
      continue_block~,
      body~,
      for_else=_,
      label=_,
      loc~,
      ..
    ) => {
      let binders_array = list_to_array_for(binders)
      let continue_array = list_to_array_for(continue_block)
      // Need 2+ binders (single binder is handled by c_style_for_simple_range)
      if binders_array.length() >= 2 &&
        binders_array.length() == continue_array.length() &&
        !contains_continue(body) {
        // Find the index binder: starts at 0 and has i + 1 in continue
        let mut index_pos : Int? = None
        let mut array_name : String? = None
        for i = 0; i < binders_array.length(); i = i + 1 {
          let (binder, init_expr) = binders_array[i]
          let (cont_binder, cont_expr) = continue_array[i]
          if binder.name == cont_binder.name &&
            @internal.match_constant_int(init_expr) == Some("0") &&
            match_simple_update(binder.name, cont_expr) {
            // Check condition is `binder < something.length()`
            match @internal.match_infix(condition, "<") {
              Some((lhs, rhs, _)) =>
                if @internal.match_ident_name(lhs) == Some(binder.name) {
                  match match_dot_length_call(rhs) {
                    Some(arr_expr) =>
                      match @internal.match_ident_name(arr_expr) {
                        Some(name) => {
                          index_pos = Some(i)
                          array_name = Some(name)
                        }
                        None => ()
                      }
                    None => ()
                  }
                }
              None => ()
            }
          }
        }
        match (index_pos, array_name) {
          (Some(idx), Some(arr_name)) => {
            let (index_binder, _) = binders_array[idx]
            let binder_name = index_binder.name
            // Verify index var is only used for array access on arr_name
            let finder = IndexAccessFinder::{
              binder_name,
              array_name: arr_name,
              found_index_access: false,
              found_other_use: false,
            }
            finder.visit_Expr(body)
            // Also check continue expressions for other uses of index
            // (skip the index's own continue expr)
            for j = 0; j < continue_array.length(); j = j + 1 {
              if j != idx {
                let (_, cont_expr) = continue_array[j]
                finder.visit_Expr(cont_expr)
              }
            }
            if finder.found_index_access && !finder.found_other_use {
              let message = "C-style for-loop with index and state can use for..in with state variables."
              let detail =
                #|for i = 0, acc = init; i < arr.length() { continue i + 1, acc + arr[i] }
              let suggestion =
                #|for x in arr; acc = init { continue acc + x }
              env.diags.push(
                @starlint.Diagnostic::new(
                  rule_id=prefer_range_for_with_state_rule_id,
                  loc~,
                  message~,
                  detail~,
                  suggestion~,
                ),
              )
            }
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
fn prefer_range_for_with_state_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_range_for_with_state_rule_id,
    description=prefer_range_for_with_state_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferRangeForWithStateEnv::{
        diags: Array::new(capacity=4),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

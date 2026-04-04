///|
let prefer_for_each_over_index_rule_id : String = "prefer_for_each_over_index"

///|
let prefer_for_each_over_index_description : String = "Prefer for-each over index-based loop when only indexing the iterable."

///|
priv struct PreferForEachOverIndexEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn match_dot_length_call(expr : @syntax.Expr) -> @syntax.Expr? {
  match @internal.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, args~, ..) =>
      if @internal.label_name(method_name) == "length" &&
        @internal.list_to_array(args).is_empty() {
        Some(self)
      } else {
        None
      }
    _ => None
  }
}

///|
priv struct IndexAccessFinder {
  binder_name : String
  array_name : String
  mut found_index_access : Bool
  mut found_other_use : Bool
}

///|
impl @syntax.IterVisitor for IndexAccessFinder with visit_Expr(env, expr) {
  if env.found_other_use {
    return
  }
  match expr {
    @syntax.ArrayGet(array~, index~, ..) =>
      if @internal.match_ident_name(array) == Some(env.array_name) &&
        @internal.match_ident_name(index) == Some(env.binder_name) {
        env.found_index_access = true
        return
      } else if @internal.match_ident_name(index) == Some(env.binder_name) {
        env.found_other_use = true
        return
      }
    @syntax.Ident(id={ name: @syntax.LongIdent::Ident(name~), .. }, ..) if name ==
      env.binder_name => {
      env.found_other_use = true
      return
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
impl @syntax.IterVisitor for PreferForEachOverIndexEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.ForEach(binders~, expr=iter_expr, body~, else_block=None, loc~, ..) => {
      let binders_array = @internal.list_to_array(binders)
      if binders_array.length() == 1 {
        match binders_array[0] {
          Some(binder) => {
            let binder_name = binder.name
            // Check iter is 0..<something.length()
            match @internal.match_infix(iter_expr, "..<") {
              Some((lhs, rhs, _)) =>
                if @internal.match_constant_int(lhs) == Some("0") {
                  match match_dot_length_call(rhs) {
                    Some(array_expr) =>
                      match @internal.match_ident_name(array_expr) {
                        Some(array_name) => {
                          let finder = IndexAccessFinder::{
                            binder_name,
                            array_name,
                            found_index_access: false,
                            found_other_use: false,
                          }
                          finder.visit_Expr(body)
                          if finder.found_index_access &&
                            !finder.found_other_use {
                            let message = "Index loop over 0..<\{array_name}.length() can be a for-each loop."
                            let detail =
                              #|for i in 0..<arr.length() { use(arr[i]) }
                            let suggestion =
                              #|for item in arr { use(item) }
                            env.diags.push(
                              @starlint.Diagnostic::new(
                                rule_id=prefer_for_each_over_index_rule_id,
                                loc~,
                                message~,
                                detail~,
                                suggestion~,
                              ),
                            )
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                }
              None => ()
            }
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
fn prefer_for_each_over_index_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_for_each_over_index_rule_id,
    description=prefer_for_each_over_index_description,
    enabled_by_default=false,
    run=input => {
      let env = PreferForEachOverIndexEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

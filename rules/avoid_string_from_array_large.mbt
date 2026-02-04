///|
let avoid_string_from_array_large_rule_id : String = "avoid_string_from_array_large"

///|
let avoid_string_from_array_large_description : String = "Avoid String::from_array for large data."

///|
priv struct AvoidStringFromArrayLargeEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn should_warn_from_array_arg(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Array(exprs~, ..) => @moonlint.list_to_array(exprs).length() >= 8
    @syntax.ArraySpread(..) => true
    _ => false
  }
}

///|
impl @syntax.IterVisitor for AvoidStringFromArrayLargeEnv with visit_Expr(
  env,
  expr,
) {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(
      func=@syntax.Method(type_name~, method_name~, ..),
      args~,
      attr=NoAttr,
      loc~
    ) =>
      if @moonlint.type_name_right_name(type_name) == "String" &&
        @moonlint.label_name(method_name) == "from_array" {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() == 1 {
          let arg = args_array[0]
          match arg.kind {
            @syntax.ArgumentKind::Positional =>
              if should_warn_from_array_arg(arg.value) {
                let message = "String::from_array can be costly for large data."
                let detail =
                  #|String::from_array(chars)
                let suggestion =
                  #|Use StringBuilder/Buffer when building strings incrementally.
                env.diags.push(
                  @moonlint.Diagnostic::new(
                    rule_id=avoid_string_from_array_large_rule_id,
                    loc~,
                    message~,
                    detail~,
                    suggestion~,
                  ),
                )
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
fn avoid_string_from_array_large_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_string_from_array_large_rule_id,
    description=avoid_string_from_array_large_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidStringFromArrayLargeEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

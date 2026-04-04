///|
let avoid_single_variant_match_rule_id : String = "avoid_single_variant_match"

///|
let avoid_single_variant_match_description : String = "Prefer let destructuring over single-case match."

///|
priv struct AvoidSingleVariantMatchEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_irrefutable_pattern(pat : @syntax.Pattern) -> Bool {
  match pat {
    @syntax.Pattern::Var(_) => true
    @syntax.Pattern::Any(..) => true
    @syntax.Pattern::Tuple(..) => true
    @syntax.Pattern::Constr(constr~, ..) => {
      let name = @internal.constructor_name(constr)
      // Enum constructors (Some, None, Ok, Err, etc.) are refutable
      !(name == "Some" ||
      name == "None" ||
      name == "Ok" ||
      name == "Err" ||
      name == "True" ||
      name == "False")
    }
    _ => false
  }
}

///|
impl @syntax.IterVisitor for AvoidSingleVariantMatchEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.Match(cases~, loc~, ..) => {
      let cases_array = @internal.list_to_array(cases)
      if cases_array.length() == 1 {
        let case_ = cases_array[0]
        if case_.guard_ is None &&
          !@internal.is_discard_pattern(case_.pattern) &&
          is_irrefutable_pattern(case_.pattern) {
          let message = "Single-case match can be a let destructuring."
          let detail =
            #|match x { Foo(a, b) => use(a, b) }
          let suggestion =
            #|let Foo(a, b) = x
            #|use(a, b)
          env.diags.push(
            @starlint.Diagnostic::new(
              rule_id=avoid_single_variant_match_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            ),
          )
        }
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_single_variant_match_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=avoid_single_variant_match_rule_id,
    description=avoid_single_variant_match_description,
    run=input => {
      let env = AvoidSingleVariantMatchEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } nobreak {
        env.diags
      }
    },
  )
}

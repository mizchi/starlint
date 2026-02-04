///|
let no_hole_placeholder_rule_id : String = "no_hole_placeholder"

///|
let no_hole_placeholder_description : String = "Avoid placeholder holes (e.g. `...`) in code."

///|
priv struct NoHolePlaceholderEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn hole_kind_label(kind : @syntax.Hole) -> String {
  match kind {
    @syntax.Hole::Todo => "todo"
    @syntax.Hole::Incomplete => "incomplete"
    @syntax.Hole::Synthesized => "synthesized"
  }
}

///|
impl @syntax.IterVisitor for NoHolePlaceholderEnv with visit_Expr_Hole(
  env,
  loc~,
  kind~,
) {
  match kind {
    @syntax.Hole::Todo | @syntax.Hole::Incomplete => {
      let message = "Placeholder hole (\{hole_kind_label(kind)}) found."
      let suggestion = "Replace placeholder with implementation."
      env.diags.push(
        @moonlint.Diagnostic::new(
          rule_id=no_hole_placeholder_rule_id,
          loc~,
          message~,
          suggestion~,
        ),
      )
    }
    @syntax.Hole::Synthesized => ()
  }
  env.base().visit_Expr_Hole(loc~, kind~)
}

///|
fn no_hole_placeholder_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=no_hole_placeholder_rule_id,
    description=no_hole_placeholder_description,
    tags=["error"],
    enabled_by_default=false,
    run=input => {
      let env = NoHolePlaceholderEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

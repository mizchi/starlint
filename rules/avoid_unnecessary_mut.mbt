///|
let avoid_unnecessary_mut_rule_id : String = "avoid_unnecessary_mut"

///|
let avoid_unnecessary_mut_description : String = "Avoid let mut when the binding is never reassigned."

///|
priv struct AvoidUnnecessaryMutEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
priv struct AssignDetector {
  name : String
  mut found : Bool
}

///|
impl @syntax.IterVisitor for AssignDetector with visit_Expr(env, expr) {
  if env.found {
    return
  }
  match expr {
    @syntax.Assign(var_~, expr=_, augmented_by=_, loc=_) =>
      if @starlint.longident_right_name(var_.name) == env.name {
        env.found = true
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn has_assignment(name : String, expr : @syntax.Expr) -> Bool {
  let detector = AssignDetector::{ name, found: false }
  detector.visit_Expr(expr)
  detector.found
}

///|
impl @syntax.IterVisitor for AvoidUnnecessaryMutEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.LetMut(binder~, ty=_, expr=_, body~, loc~) =>
      if not(has_assignment(binder.name, body)) {
        let message = "let mut is unnecessary because the binding is never reassigned."
        let detail =
          #|let mut x = expr
          #|... // x is never reassigned
        let suggestion =
          #|let x = expr
        env.diags.push(
          @starlint.Diagnostic::new(
            rule_id=avoid_unnecessary_mut_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn avoid_unnecessary_mut_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=avoid_unnecessary_mut_rule_id,
    description=avoid_unnecessary_mut_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidUnnecessaryMutEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

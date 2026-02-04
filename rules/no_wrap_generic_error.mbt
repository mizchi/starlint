///|
let no_wrap_generic_error_rule_id : String = "no_wrap_generic_error"

///|
let no_wrap_generic_error_description : String = "Avoid wrapping generic Error inside suberror."

///|
priv struct NoWrapGenericErrorEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn is_error_type(ty : @syntax.Type) -> Bool {
  match ty {
    @syntax.Type::Name(constr_id~, tys=_, loc=_) =>
      @moonlint.constr_id_right_name(constr_id) == "Error"
    _ => false
  }
}

///|
fn push_no_wrap_generic_error_diag(
  env : NoWrapGenericErrorEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Avoid wrapping generic Error; prefer specific error variants."
  let detail =
    #|suberror WrapA(Error)
  let suggestion =
    #|suberror WrapA { ... }
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=no_wrap_generic_error_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for NoWrapGenericErrorEnv with visit_TypeDecl(
  env,
  decl,
) {
  match decl.components {
    @syntax.TypeDesc::Error(exception) =>
      match exception {
        @syntax.ExceptionDecl::SinglePayload(ty) =>
          if is_error_type(ty) {
            push_no_wrap_generic_error_diag(env, decl.loc)
          }
        @syntax.ExceptionDecl::EnumPayload(constrs) => {
          let items = @moonlint.list_to_array(constrs)
          for constr in items {
            match constr.args {
              Some(args) => {
                let params = @moonlint.list_to_array(args)
                if params.length() == 1 && is_error_type(params[0].ty) {
                  push_no_wrap_generic_error_diag(env, constr.loc)
                }
              }
              None => ()
            }
          }
        }
        _ => ()
      }
    _ => ()
  }
  env.base().visit_TypeDecl(decl)
}

///|
fn no_wrap_generic_error_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=no_wrap_generic_error_rule_id,
    description=no_wrap_generic_error_description,
    tags=["error"],
    enabled_by_default=false,
    run=input => {
      let env = NoWrapGenericErrorEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

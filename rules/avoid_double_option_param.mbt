///|
let avoid_double_option_param_rule_id : String = "avoid_double_option_param"

///|
let avoid_double_option_param_description : String = "Avoid optional parameters whose type is already Option."

///|
priv struct AvoidDoubleOptionParamEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_option_type(ty : @syntax.Type) -> Bool {
  match ty {
    @syntax.Type::Option(..) => true
    @syntax.Type::Name(constr_id~, tys=_, loc=_) =>
      @starlint.constr_id_right_name(constr_id) == "Option"
    _ => false
  }
}

///|
fn push_double_option_diag(
  env : AvoidDoubleOptionParamEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Optional parameter already uses Option; avoid double Option."
  let detail =
    #|fn f(arg? : Int?) { ... }
  let suggestion =
    #|fn f(arg? : Int) { ... }
  env.diags.push(
    @starlint.Diagnostic::new(
      rule_id=avoid_double_option_param_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for AvoidDoubleOptionParamEnv with visit_Parameter(
  env,
  param,
) {
  match param {
    @syntax.Parameter::Optional(binder=_, default=_, ty=Some(ty)) =>
      if is_option_type(ty) {
        push_double_option_diag(env, param.loc())
      }
    @syntax.Parameter::QuestionOptional(binder=_, ty=Some(ty)) =>
      if is_option_type(ty) {
        push_double_option_diag(env, param.loc())
      }
    _ => ()
  }
  env.base().visit_Parameter(param)
}

///|
fn avoid_double_option_param_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=avoid_double_option_param_rule_id,
    description=avoid_double_option_param_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidDoubleOptionParamEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

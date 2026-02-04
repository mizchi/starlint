///|
let avoid_json_js_rule_id : String = "avoid_json_js"

///|
let avoid_json_js_description : String = "Avoid Json usage when JS bundle size is critical."

///|
priv struct AvoidJsonJsEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn is_json_type_name(type_name : @syntax.TypeName) -> Bool {
  @moonlint.type_name_right_name(type_name) == "Json"
}

///|
fn is_json_constr_id(constr_id : @syntax.ConstrId) -> Bool {
  @moonlint.constr_id_right_name(constr_id) == "Json"
}

///|
fn is_json_pkg_ident(binding : @syntax.Var) -> Bool {
  @moonlint.longident_pkg_name(binding.name) == Some("json")
}

///|
fn is_json_constructor(constr : @syntax.Constructor) -> Bool {
  @moonlint.constructor_type_name(constr) == Some("Json")
}

///|
fn push_json_diag(env : AvoidJsonJsEnv, loc : @basic.Location) -> Unit {
  let message = "Json usage can increase JS bundle size."
  let detail =
    #|JS target tends to include heavier JSON runtime helpers.
  let suggestion =
    #|When size matters, consider a tiny hand-rolled encoder or plain structs.
  let diag = @moonlint.Diagnostic::new(
    rule_id=avoid_json_js_rule_id,
    loc~,
    message~,
    detail~,
    suggestion~,
  )
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for AvoidJsonJsEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Ident(id=binding, loc~) =>
      if is_json_pkg_ident(binding) {
        push_json_diag(env, loc)
      }
    @syntax.Method(type_name~, loc~, ..) =>
      if is_json_type_name(type_name) {
        push_json_diag(env, loc)
      }
    @syntax.Constr(constr~, loc~) =>
      if is_json_constructor(constr) {
        push_json_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
impl @syntax.IterVisitor for AvoidJsonJsEnv with visit_Type(env, ty) {
  match ty {
    @syntax.Type::Name(constr_id~, tys=_, loc~) =>
      if is_json_constr_id(constr_id) {
        push_json_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Type(ty)
}

///|
fn avoid_json_js_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_json_js_rule_id,
    description=avoid_json_js_description,
    tags=["size"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidJsonJsEnv::{ diags: Array::new(capacity=8) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

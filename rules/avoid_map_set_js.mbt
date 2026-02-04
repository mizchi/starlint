///|
let avoid_map_set_js_rule_id : String = "avoid_map_set_js"

///|
let avoid_map_set_js_description : String = "Avoid Map/Set when JS bundle size is critical."

///|
priv struct AvoidMapSetJsEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn map_set_kind_from_type_name(type_name : @syntax.TypeName) -> String? {
  let name = @moonlint.type_name_right_name(type_name)
  if name == "Map" || name == "Set" {
    Some(name)
  } else {
    None
  }
}

///|
fn map_set_kind_from_constr_id(constr_id : @syntax.ConstrId) -> String? {
  let name = @moonlint.constr_id_right_name(constr_id)
  if name == "Map" || name == "Set" {
    Some(name)
  } else {
    None
  }
}

///|
fn push_map_set_diag(
  env : AvoidMapSetJsEnv,
  loc : @basic.Location,
  kind : String,
) -> Unit {
  let message = "\{kind} can increase JS bundle size."
  let detail =
    #|JS target tends to pull in heavier runtime support for Map/Set.
  let suggestion =
    #|When size matters, consider Array[(K, V)] or a small custom record.
  let diag = @moonlint.Diagnostic::new(
    rule_id=avoid_map_set_js_rule_id,
    loc~,
    message~,
    detail~,
    suggestion~,
  )
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for AvoidMapSetJsEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Map(elems=_, loc~) => push_map_set_diag(env, loc, "Map")
    @syntax.Method(type_name~, loc~, ..) =>
      match map_set_kind_from_type_name(type_name) {
        Some(kind) => push_map_set_diag(env, loc, kind)
        None => ()
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
impl @syntax.IterVisitor for AvoidMapSetJsEnv with visit_Type(env, ty) {
  match ty {
    @syntax.Type::Name(constr_id~, tys=_, loc~) =>
      match map_set_kind_from_constr_id(constr_id) {
        Some(kind) => push_map_set_diag(env, loc, kind)
        None => ()
      }
    _ => ()
  }
  env.base().visit_Type(ty)
}

///|
fn avoid_map_set_js_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_map_set_js_rule_id,
    description=avoid_map_set_js_description,
    tags=["size"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidMapSetJsEnv::{ diags: Array::new(capacity=8) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

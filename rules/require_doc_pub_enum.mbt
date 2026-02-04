///|
let require_doc_pub_enum_rule_id : String = "require_doc_pub_enum"

///|
let require_doc_pub_enum_description : String = "Public enums should have doc comments."

///|
priv struct RequireDocPubEnumEnv {
  diags : Array[@moonlint.Diagnostic]
}

///|
fn has_doc_content_pub_enum(doc : @syntax.DocString) -> Bool {
  let lines = @moonlint.list_to_array(doc.content)
  for line in lines {
    if !line.is_blank() {
      return true
    }
  } else {
    false
  }
}

///|
fn push_require_doc_pub_enum_diag(
  env : RequireDocPubEnumEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Public enum should have a doc comment."
  let detail =
    #|pub enum E { A }
  let suggestion =
    #|/// Description
    #|pub enum E { A }
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=require_doc_pub_enum_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for RequireDocPubEnumEnv with visit_TypeDecl(env, decl) {
  match decl.type_vis {
    @syntax.Visibility::Pub(..) =>
      match decl.components {
        @syntax.TypeDesc::Variant(_) =>
          if !has_doc_content_pub_enum(decl.doc) {
            push_require_doc_pub_enum_diag(env, decl.tycon_loc)
          }
        _ => ()
      }
    _ => ()
  }
  env.base().visit_TypeDecl(decl)
}

///|
fn require_doc_pub_enum_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=require_doc_pub_enum_rule_id,
    description=require_doc_pub_enum_description,
    tags=["module"],
    enabled_by_default=false,
    run=input => {
      let env = RequireDocPubEnumEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}

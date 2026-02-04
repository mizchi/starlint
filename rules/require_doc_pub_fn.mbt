///|
let require_doc_pub_fn_rule_id : String = "require_doc_pub_fn"

///|
let require_doc_pub_fn_description : String = "Public functions should have doc comments."

///|
priv struct RequireDocPubFnEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn has_doc_content_pub_fn(doc : @syntax.DocString) -> Bool {
  let lines = @starlint.list_to_array(doc.content)
  for line in lines {
    if !line.is_blank() {
      return true
    }
  } else {
    false
  }
}

///|
fn push_require_doc_pub_fn_diag(
  env : RequireDocPubFnEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Public function should have a doc comment."
  let detail =
    #|pub fn f() { ... }
  let suggestion =
    #|/// Description
    #|pub fn f() { ... }
  env.diags.push(
    @starlint.Diagnostic::new(
      rule_id=require_doc_pub_fn_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for RequireDocPubFnEnv with visit_Impl(env, impl_) {
  match impl_ {
    @syntax.Impl::TopFuncDef(fun_decl~, decl_body=_, loc=_) =>
      match fun_decl.vis {
        @syntax.Visibility::Pub(..) =>
          if !has_doc_content_pub_fn(fun_decl.doc) {
            push_require_doc_pub_fn_diag(env, fun_decl.name.loc)
          }
        _ => ()
      }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
fn require_doc_pub_fn_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=require_doc_pub_fn_rule_id,
    description=require_doc_pub_fn_description,
    tags=["module"],
    enabled_by_default=false,
    run=input => {
      let env = RequireDocPubFnEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
